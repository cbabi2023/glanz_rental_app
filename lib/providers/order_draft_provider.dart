import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/order.dart';
import '../models/order_item.dart';
import '../models/user_profile.dart';
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

  OrderDraftState({
    this.customerId,
    this.customerName,
    this.customerPhone,
    required this.startDate,
    required this.endDate,
    required this.invoiceNumber,
    required this.items,
  });

  OrderDraftState copyWith({
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? startDate,
    String? endDate,
    String? invoiceNumber,
    List<OrderItem>? items,
  }) {
    return OrderDraftState(
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      items: items ?? this.items,
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
int calculateDays(String startDate, String endDate) {
  try {
    final start = DateTime.parse(startDate);
    final end = DateTime.parse(endDate);
    return end.difference(start).inDays + 1; // Include both start and end day
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
  if (user?.gstEnabled != true) return 0.0;

  final gstRate = (user?.gstRate ?? 5.0) / 100;
  final gstIncluded = user?.gstIncluded ?? false;

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
  if (user?.gstEnabled != true) return subtotal;

  final gstAmount = calculateGstAmount(subtotal: subtotal, user: user);
  final gstIncluded = user?.gstIncluded ?? false;

  return gstIncluded ? subtotal : subtotal + gstAmount;
}

/// Subtotal Provider
final orderSubtotalProvider = Provider<double>((ref) {
  final draft = ref.watch(orderDraftProvider);
  return calculateSubtotal(draft.items);
});

/// GST Amount Provider
final orderGstAmountProvider = Provider<double>((ref) {
  final subtotal = ref.watch(orderSubtotalProvider);
  final userProfile = ref.watch(userProfileProvider).value;
  return calculateGstAmount(subtotal: subtotal, user: userProfile);
});

/// Grand Total Provider
final orderGrandTotalProvider = Provider<double>((ref) {
  final subtotal = ref.watch(orderSubtotalProvider);
  final userProfile = ref.watch(userProfileProvider).value;
  return calculateGrandTotal(subtotal: subtotal, user: userProfile);
});

