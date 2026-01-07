import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/order.dart';
import '../models/order_item.dart';
import '../models/user_profile.dart';
import '../core/supabase_client.dart';
import '../core/logger.dart';
import 'auth_provider.dart';

/// Order Draft State
class OrderDraftState {
  final String? customerId;
  final String? customerName;
  final String? customerPhone;
  final String startDate;
  final String endDate;
  final String invoiceNumber;
  final List<OrderItem> items;
  final double? securityDeposit;

  OrderDraftState({
    this.customerId,
    this.customerName,
    this.customerPhone,
    required this.startDate,
    required this.endDate,
    required this.invoiceNumber,
    required this.items,
    this.securityDeposit,
  });

  OrderDraftState copyWith({
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? startDate,
    String? endDate,
    String? invoiceNumber,
    List<OrderItem>? items,
    double? securityDeposit,
  }) {
    return OrderDraftState(
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      items: items ?? this.items,
      securityDeposit: securityDeposit ?? this.securityDeposit,
    );
  }

  OrderDraftState clear() {
    final now = DateTime.now();
    final nextDay = now.add(const Duration(days: 1));
    return OrderDraftState(
      startDate: now.toIso8601String(),
      endDate: nextDay.toIso8601String(),
      invoiceNumber: '',
      items: [],
    );
  }
}

/// Order Draft Notifier
class OrderDraftNotifier extends StateNotifier<OrderDraftState> {
  OrderDraftNotifier() : super(_initialState());

  // Lock to prevent modifications during critical operations
  bool _isLocked = false;
  String? _lastLoadedOrderId; // Track which order was last loaded

  static OrderDraftState _initialState() {
    final now = DateTime.now();
    final nextDay = now.add(const Duration(days: 1));
    return OrderDraftState(
      startDate: now.toIso8601String(),
      endDate: nextDay.toIso8601String(),
      invoiceNumber: '',
      items: [],
    );
  }

  void setCustomer({
    required String customerId,
    String? customerName,
    String? customerPhone,
  }) {
    state = state.copyWith(
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
    );
  }

  void setStartDate(String date) {
    state = state.copyWith(startDate: date);
  }

  void setEndDate(String date) {
    state = state.copyWith(endDate: date);
  }

  void setInvoiceNumber(String number) {
    state = state.copyWith(invoiceNumber: number);
  }

  void setSecurityDeposit(double? amount) {
    state = state.copyWith(securityDeposit: amount);
  }

  void addItem(OrderItem item) {
    AppLogger.debug(
      'addItem called. Current items count: ${state.items.length}',
    );
    AppLogger.debug(
      'Item to add - ID: ${item.id}, photoUrl: ${item.photoUrl}, productName: ${item.productName}',
    );

    // Don't allow adding items if locked (during critical operations)
    if (_isLocked) {
      AppLogger.warning('addItem BLOCKED - draft is locked');
      return;
    }

    // Check for duplicates before adding
    // Use item ID if available, otherwise use composite key
    final existingItemIds = state.items
        .where((i) => i.id != null && i.id!.isNotEmpty)
        .map((i) => i.id!)
        .toSet();

    // If item has an ID, check if it already exists
    if (item.id != null && item.id!.isNotEmpty) {
      if (existingItemIds.contains(item.id)) {
        // Item with this ID already exists, don't add duplicate
        AppLogger.warning('addItem BLOCKED - duplicate ID: ${item.id}');
        return;
      }
    }

    // For items without ID, check using composite key (include days and lineTotal for better uniqueness)
    final itemKey =
        '${item.photoUrl}_${item.productName ?? ''}_${item.quantity}_${item.pricePerDay}_${item.days}_${item.lineTotal}';
    final existingKeys = state.items
        .where((i) => i.id == null || i.id!.isEmpty)
        .map(
          (i) =>
              '${i.photoUrl}_${i.productName ?? ''}_${i.quantity}_${i.pricePerDay}_${i.days}_${i.lineTotal}',
        )
        .toSet();

    if (existingKeys.contains(itemKey)) {
      // Duplicate item found, don't add
      AppLogger.warning('addItem BLOCKED - duplicate composite key: $itemKey');
      return;
    }

    final newItems = [item, ...state.items];
    state = state.copyWith(items: newItems);
    AppLogger.success(
      'addItem SUCCESS. New items count: ${state.items.length}',
    );
  }

  void updateItem(int index, OrderItem updatedItem) {
    final newItems = List<OrderItem>.from(state.items);
    if (index >= 0 && index < newItems.length) {
      newItems[index] = updatedItem;
      state = state.copyWith(items: newItems);
    }
  }

  void removeItem(int index) {
    final newItems = List<OrderItem>.from(state.items);
    if (index >= 0 && index < newItems.length) {
      newItems.removeAt(index);
      state = state.copyWith(items: newItems);
    }
  }

  void loadOrder(Order order) {
    // DEBUG: Log when loadOrder is called
    AppLogger.debug('loadOrder called for order: ${order.id}');
    AppLogger.debug('Current state items count: ${state.items.length}');
    AppLogger.debug('Order items count from DB: ${order.items?.length ?? 0}');

    // CRITICAL: Prevent loading the same order multiple times
    // If we're already loading this order, don't load again
    if (_isLocked && _lastLoadedOrderId == order.id) {
      AppLogger.warning(
        'loadOrder BLOCKED - already loading order ${order.id}',
      );
      return;
    }

    // Lock to prevent any modifications during loading
    _isLocked = true;
    _lastLoadedOrderId = order.id;

    try {
      // CRITICAL: First, completely clear the state to ensure we start fresh
      // This prevents any possibility of items being appended instead of replaced
      final itemsBeforeClear = state.items.length;
      state = _initialState();
      AppLogger.debug(
        'Cleared state. Items before: $itemsBeforeClear, after: ${state.items.length}',
      );

      // Use datetime fields if available, otherwise use date fields
      final startDate = order.startDatetime ?? order.startDate;
      final endDate = order.endDatetime ?? order.endDate;

      // CRITICAL: Remove ALL duplicates from order items
      // Use a single Map-based approach for simplicity and reliability
      final uniqueItemsMap = <String, OrderItem>{};
      final duplicateKeys = <String>[];

      // Process ALL items and remove duplicates
      for (final item in (order.items ?? [])) {
        String key;

        // Use item ID if available (most reliable)
        if (item.id != null && item.id!.isNotEmpty) {
          key = 'id_${item.id}';
        } else {
          // For items without ID, create a comprehensive composite key
          // Include ALL identifying fields to ensure uniqueness
          final photoUrl = item.photoUrl;
          final productName = item.productName ?? '';
          final quantity = item.quantity;
          final pricePerDay = item.pricePerDay;
          final days = item.days;
          final lineTotal = item.lineTotal;

          // Create a comprehensive key that includes all identifying information
          key =
              'key_${photoUrl}_${productName}_${quantity}_${pricePerDay}_${days}_$lineTotal';
        }

        // Only add if we haven't seen this key before
        // This ensures each item appears exactly once
        if (!uniqueItemsMap.containsKey(key)) {
          uniqueItemsMap[key] = item;
        } else {
          duplicateKeys.add(key);
          AppLogger.warning('DUPLICATE FOUND: $key');
        }
      }

      AppLogger.debug('Unique items map size: ${uniqueItemsMap.length}');
      AppLogger.debug('Duplicates found: ${duplicateKeys.length}');
      if (duplicateKeys.isNotEmpty) {
        AppLogger.warning('Duplicate keys: $duplicateKeys');
      }

      // Convert map values to list - this guarantees unique items only
      // Create a completely new list to avoid any reference issues
      final finalUniqueItems = List<OrderItem>.from(uniqueItemsMap.values);

      // FINAL VERIFICATION: Double-check for duplicates (safety measure)
      // This catches any edge cases where duplicate detection might have failed
      final verifiedUniqueItems = <String, OrderItem>{};
      final verificationDuplicates = <String>[];
      for (final item in finalUniqueItems) {
        String key;
        if (item.id != null && item.id!.isNotEmpty) {
          key = 'id_${item.id}';
        } else {
          key =
              'key_${item.photoUrl}_${item.productName ?? ''}_${item.quantity}_${item.pricePerDay}_${item.days}_${item.lineTotal}';
        }
        if (!verifiedUniqueItems.containsKey(key)) {
          verifiedUniqueItems[key] = item;
        } else {
          verificationDuplicates.add(key);
          AppLogger.warning('VERIFICATION DUPLICATE FOUND: $key');
        }
      }
      final verifiedItems = List<OrderItem>.from(verifiedUniqueItems.values);

      AppLogger.debug('Verified items count: ${verifiedItems.length}');
      AppLogger.debug(
        'Verification duplicates: ${verificationDuplicates.length}',
      );

      // IMPORTANT: Create a completely new state to replace existing state
      // This ensures items are replaced, not appended
      state = OrderDraftState(
        customerId: order.customerId,
        customerName: order.customer?.name,
        customerPhone: order.customer?.phone,
        startDate: startDate,
        endDate: endDate,
        invoiceNumber: order.invoiceNumber,
        items:
            verifiedItems, // This is a new list, completely replacing old items
        securityDeposit: order.securityDeposit,
      );

      AppLogger.success(
        'loadOrder COMPLETE. Final state items count: ${state.items.length}',
      );
    } finally {
      // Always unlock after loading
      _isLocked = false;
    }
  }

  void clear() {
    // CRITICAL: Completely reset state to initial state
    // This ensures all items are removed, not just cleared
    _isLocked = false; // Reset lock as well
    _lastLoadedOrderId = null; // Reset loaded order ID
    state = _initialState();
  }
}

/// Order Draft Provider
final orderDraftProvider =
    StateNotifierProvider<OrderDraftNotifier, OrderDraftState>((ref) {
      return OrderDraftNotifier();
    });

/// Calculate days between two dates
/// Normalizes dates to midnight to ensure accurate day calculation
/// For rental purposes:
/// - Same day (Day 8 to Day 8) = 1 day rental
/// - Next day (Day 8 to Day 9) = 1 day rental (overnight)
/// - Day 8 to Day 10 = 2 days rental
int calculateDays(String startDate, String endDate) {
  try {
    final start = DateTime.parse(startDate);
    final end = DateTime.parse(endDate);

    // Normalize to date only (midnight) to avoid time component issues
    final startDateOnly = DateTime(start.year, start.month, start.day);
    final endDateOnly = DateTime(end.year, end.month, end.day);

    // Calculate difference in days
    // For rental: same day = 1 day, next day = 1 day (overnight), etc.
    // Use max(1, ...) to ensure at least 1 day for same-day rentals
    final daysDifference = endDateOnly.difference(startDateOnly).inDays;
    return daysDifference < 1 ? 1 : daysDifference;
  } catch (e) {
    return 0;
  }
}

/// Calculate subtotal from items
double calculateSubtotal(List<OrderItem> items) {
  return items.fold(0.0, (sum, item) {
    return sum + item.lineTotal;
  });
}

/// Calculate GST amount
double calculateGstAmount({
  required double subtotal,
  required UserProfile? user,
}) {
  if (user == null) return 0.0;

  // Determine if GST should be applied.
  // Check gstEnabled flag first, then fall back to presence of gstRate or gstNumber
  bool gstEnabled;
  if (user.gstEnabled != null) {
    gstEnabled = user.gstEnabled!;
  } else {
    // Infer from gstRate or gstNumber
    gstEnabled =
        (user.gstRate != null && user.gstRate! > 0) ||
        (user.gstNumber != null && user.gstNumber!.isNotEmpty);
  }

  if (!gstEnabled) return 0.0;

  final gstRate = (user.gstRate ?? 5.0) / 100;
  final gstIncluded = user.gstIncluded ?? false;

  if (gstIncluded) {
    // GST is included in price, so extract it
    return subtotal * (gstRate / (1 + gstRate));
  } else {
    // GST is added on top
    return subtotal * gstRate;
  }
}

/// Calculate grand total
double calculateGrandTotal({
  required double subtotal,
  required UserProfile? user,
}) {
  if (user == null) return subtotal;

  // Determine if GST should be applied
  bool gstEnabled;
  if (user.gstEnabled != null) {
    gstEnabled = user.gstEnabled!;
  } else {
    // Infer from gstRate or gstNumber
    gstEnabled =
        (user.gstRate != null && user.gstRate! > 0) ||
        (user.gstNumber != null && user.gstNumber!.isNotEmpty);
  }

  if (!gstEnabled) return subtotal;

  final gstAmount = calculateGstAmount(subtotal: subtotal, user: user);
  final gstIncluded = user.gstIncluded ?? false;

  return gstIncluded ? subtotal : subtotal + gstAmount;
}

/// Subtotal Provider
final orderSubtotalProvider = Provider<double>((ref) {
  final draft = ref.watch(orderDraftProvider);
  return calculateSubtotal(draft.items);
});

/// Super Admin Profile Provider (for GST settings when staff/branch admin creates orders)
final superAdminProfileProvider = FutureProvider<UserProfile?>((ref) async {
  try {
    final response = await SupabaseService.client
        .from('profiles')
        .select()
        .eq('role', 'super_admin')
        .limit(1)
        .maybeSingle();

    if (response == null) {
      AppLogger.warning('No super admin found');
      return null;
    }

    final admin = UserProfile.fromJson(response);
    AppLogger.info(
      'Super admin found: ${admin.fullName}, GST enabled: ${admin.gstEnabled}, GST rate: ${admin.gstRate}',
    );
    return admin;
  } catch (e) {
    AppLogger.error('Error fetching super admin profile', e);
    return null;
  }
});

/// GST Amount Provider
final orderGstAmountProvider = Provider<double>((ref) {
  final subtotal = ref.watch(orderSubtotalProvider);
  final userProfile = ref.watch(userProfileProvider).value;

  // If user is staff or branch admin, get super admin's GST settings
  if (userProfile?.isStaff == true || userProfile?.isBranchAdmin == true) {
    final superAdminAsync = ref.watch(superAdminProfileProvider);
    // Handle async state: if loading, wait; if loaded, use it; if error/null, fallback
    return superAdminAsync.when(
      data: (superAdmin) {
        if (superAdmin != null) {
          return calculateGstAmount(subtotal: subtotal, user: superAdmin);
        }
        // Super admin not found, fallback to user profile
        return calculateGstAmount(subtotal: subtotal, user: userProfile);
      },
      loading: () {
        // While loading, return 0 (will update when loaded)
        return 0.0;
      },
      error: (_, __) {
        // On error, fallback to user profile
        return calculateGstAmount(subtotal: subtotal, user: userProfile);
      },
    );
  }

  // For super admin, use their own GST settings
  return calculateGstAmount(subtotal: subtotal, user: userProfile);
});

/// Grand Total Provider
final orderGrandTotalProvider = Provider<double>((ref) {
  final subtotal = ref.watch(orderSubtotalProvider);
  final userProfile = ref.watch(userProfileProvider).value;

  // If user is staff or branch admin, get super admin's GST settings
  if (userProfile?.isStaff == true || userProfile?.isBranchAdmin == true) {
    final superAdminAsync = ref.watch(superAdminProfileProvider);
    // Handle async state: if loading, wait; if loaded, use it; if error/null, fallback
    return superAdminAsync.when(
      data: (superAdmin) {
        if (superAdmin != null) {
          return calculateGrandTotal(subtotal: subtotal, user: superAdmin);
        }
        // Super admin not found, fallback to user profile
        return calculateGrandTotal(subtotal: subtotal, user: userProfile);
      },
      loading: () {
        // While loading, return subtotal (will update when loaded)
        return subtotal;
      },
      error: (_, __) {
        // On error, fallback to user profile
        return calculateGrandTotal(subtotal: subtotal, user: userProfile);
      },
    );
  }

  // For super admin, use their own GST settings
  return calculateGrandTotal(subtotal: subtotal, user: userProfile);
});
