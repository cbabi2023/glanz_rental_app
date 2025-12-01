import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/orders_service.dart';
import '../models/order.dart';

/// Orders Service Provider
final ordersServiceProvider = Provider<OrdersService>((ref) {
  return OrdersService();
});

/// Orders List Provider
/// 
/// Fetches orders with optional filters
final ordersProvider = FutureProvider.family<List<Order>, OrdersParams>(
  (ref, params) async {
    final service = ref.watch(ordersServiceProvider);
    return await service.getOrders(
      branchId: params.branchId,
      status: params.status,
      startDate: params.startDate,
      endDate: params.endDate,
      limit: params.limit,
      offset: params.offset,
    );
  },
);

/// Order Stream Provider
/// 
/// Provides real-time stream of orders
final ordersStreamProvider = StreamProvider.family<List<Order>, String?>(
  (ref, branchId) {
    final service = ref.watch(ordersServiceProvider);
    return service.watchOrders(branchId: branchId);
  },
);

/// Single Order Provider
final orderProvider = FutureProvider.family<Order?, String>(
  (ref, orderId) async {
    final service = ref.watch(ordersServiceProvider);
    return await service.getOrder(orderId);
  },
);

/// Customer Orders Provider
final customerOrdersProvider = FutureProvider.family<List<Order>, String>(
  (ref, customerId) async {
    final service = ref.watch(ordersServiceProvider);
    return await service.getCustomerOrders(customerId);
  },
);

/// Orders Parameters
class OrdersParams {
  final String? branchId;
  final OrderStatus? status;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? limit;
  final int? offset;

  OrdersParams({
    this.branchId,
    this.status,
    this.startDate,
    this.endDate,
    this.limit,
    this.offset,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrdersParams &&
          runtimeType == other.runtimeType &&
          branchId == other.branchId &&
          status == other.status &&
          startDate == other.startDate &&
          endDate == other.endDate &&
          limit == other.limit &&
          offset == other.offset;

  @override
  int get hashCode =>
      branchId.hashCode ^
      status.hashCode ^
      startDate.hashCode ^
      endDate.hashCode ^
      limit.hashCode ^
      offset.hashCode;
}

