import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/order.dart';
import '../models/order_item.dart';
import '../models/user_profile.dart';
import '../core/supabase_client.dart';
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
    final newItems = [item, ...state.items];
    state = state.copyWith(items: newItems);
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
    // Use datetime fields if available, otherwise use date fields
    final startDate = order.startDatetime ?? order.startDate;
    final endDate = order.endDatetime ?? order.endDate;
    
    state = OrderDraftState(
      customerId: order.customerId,
      customerName: order.customer?.name,
      customerPhone: order.customer?.phone,
      startDate: startDate,
      endDate: endDate,
      invoiceNumber: order.invoiceNumber,
      items: order.items ?? [],
      securityDeposit: order.securityDeposit,
    );
  }

  void clear() {
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
    gstEnabled = (user.gstRate != null && user.gstRate! > 0) ||
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
    gstEnabled = (user.gstRate != null && user.gstRate! > 0) ||
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
      print('No super admin found');
      return null;
    }
    
    final admin = UserProfile.fromJson(response);
    print('Super admin found: ${admin.fullName}, GST enabled: ${admin.gstEnabled}, GST rate: ${admin.gstRate}');
    return admin;
  } catch (e) {
    print('Error fetching super admin profile: $e');
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

