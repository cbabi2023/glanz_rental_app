import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/orders_service.dart';
import '../models/order.dart';

/// Orders Service Provider
final ordersServiceProvider = Provider<OrdersService>((ref) {
  return OrdersService();
});

/// Refresh trigger for orders list
/// Increment this to force orders list to refresh
final ordersRefreshTriggerProvider = StateProvider<int>((ref) => 0);

/// Orders Infinite Scroll State
class OrdersInfiniteState {
  final List<Order> orders;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;
  final int currentPage;

  OrdersInfiniteState({
    this.orders = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
    this.currentPage = 0,
  });

  OrdersInfiniteState copyWith({
    List<Order>? orders,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? error,
    int? currentPage,
  }) {
    return OrdersInfiniteState(
      orders: orders ?? this.orders,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: error,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}

/// Orders Infinite Scroll Notifier
class OrdersInfiniteNotifier extends StateNotifier<OrdersInfiniteState> {
  final OrdersService _ordersService;
  final OrdersParams _baseParams;

  OrdersInfiniteNotifier(this._ordersService, this._baseParams)
      : super(OrdersInfiniteState()) {
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    state = state.copyWith(isLoading: true, error: null, currentPage: 0);
    try {
      final orders = await _ordersService.getOrders(
        branchId: _baseParams.branchId,
        status: _baseParams.status,
        startDate: _baseParams.startDate,
        endDate: _baseParams.endDate,
        limit: 10, // Match website: 10 items per page
        offset: 0,
      );
      state = state.copyWith(
        orders: orders,
        isLoading: false,
        hasMore: orders.length == 10, // If we got 10, there might be more
        currentPage: 0,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);
    try {
      final nextPage = state.currentPage + 1;
      final orders = await _ordersService.getOrders(
        branchId: _baseParams.branchId,
        status: _baseParams.status,
        startDate: _baseParams.startDate,
        endDate: _baseParams.endDate,
        limit: 10,
        offset: nextPage * 10,
      );

      if (orders.isEmpty) {
        state = state.copyWith(
          isLoadingMore: false,
          hasMore: false,
        );
      } else {
        state = state.copyWith(
          orders: [...state.orders, ...orders],
          isLoadingMore: false,
          hasMore: orders.length == 10,
          currentPage: nextPage,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoadingMore: false,
        error: e.toString(),
      );
    }
  }

  Future<void> refresh() async {
    state = OrdersInfiniteState();
    await _loadInitial();
  }
}

/// Orders Infinite Provider
final ordersInfiniteProvider = StateNotifierProvider.family<
    OrdersInfiniteNotifier, OrdersInfiniteState, OrdersParams>(
  (ref, params) {
    final service = ref.watch(ordersServiceProvider);
    // Watch refresh trigger to reset state
    ref.watch(ordersRefreshTriggerProvider);
    return OrdersInfiniteNotifier(service, params);
  },
);

/// Orders List Provider
/// 
/// Fetches orders with optional filters
/// Automatically refreshes when ordersRefreshTriggerProvider changes
final ordersProvider = FutureProvider.family<List<Order>, OrdersParams>(
  (ref, params) async {
    // Watch the refresh trigger to automatically refetch when it changes
    ref.watch(ordersRefreshTriggerProvider);
    
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

