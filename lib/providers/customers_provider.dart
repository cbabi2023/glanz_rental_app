import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/customers_service.dart';
import '../models/customer.dart';

/// Customers Service Provider
final customersServiceProvider = Provider<CustomersService>((ref) {
  return CustomersService();
});

/// Customers Infinite Scroll State
class CustomersInfiniteState {
  final List<Customer> customers;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;
  final int currentPage;

  CustomersInfiniteState({
    this.customers = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
    this.currentPage = 1,
  });

  CustomersInfiniteState copyWith({
    List<Customer>? customers,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? error,
    int? currentPage,
  }) {
    return CustomersInfiniteState(
      customers: customers ?? this.customers,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: error,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}

/// Customers Infinite Scroll Parameters
class CustomersInfiniteParams {
  final String? searchQuery;
  final bool duesOnly;

  CustomersInfiniteParams({
    this.searchQuery,
    this.duesOnly = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomersInfiniteParams &&
          runtimeType == other.runtimeType &&
          searchQuery == other.searchQuery &&
          duesOnly == other.duesOnly;

  @override
  int get hashCode => searchQuery.hashCode ^ duesOnly.hashCode;
}

/// Customers Infinite Scroll Notifier
class CustomersInfiniteNotifier extends StateNotifier<CustomersInfiniteState> {
  final CustomersService _customersService;
  final CustomersInfiniteParams _params;

  CustomersInfiniteNotifier(this._customersService, this._params)
      : super(CustomersInfiniteState()) {
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    state = state.copyWith(isLoading: true, error: null, currentPage: 1);
    try {
      final result = await _customersService.getCustomers(
        searchQuery: _params.searchQuery,
        duesOnly: _params.duesOnly,
        page: 1,
        pageSize: 25, // Match website: 25 items per page
      );
      final customers = result['data'] as List<Customer>;
      state = state.copyWith(
        customers: customers,
        isLoading: false,
        hasMore: customers.length == 25,
        currentPage: 1,
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
      final result = await _customersService.getCustomers(
        searchQuery: _params.searchQuery,
        duesOnly: _params.duesOnly,
        page: nextPage,
        pageSize: 25,
      );
      final customers = result['data'] as List<Customer>;

      if (customers.isEmpty) {
        state = state.copyWith(
          isLoadingMore: false,
          hasMore: false,
        );
      } else {
        state = state.copyWith(
          customers: [...state.customers, ...customers],
          isLoadingMore: false,
          hasMore: customers.length == 25,
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
    state = CustomersInfiniteState();
    await _loadInitial();
  }
}

/// Customers Infinite Provider
final customersInfiniteProvider = StateNotifierProvider.family<
    CustomersInfiniteNotifier, CustomersInfiniteState, CustomersInfiniteParams>(
  (ref, params) {
    final service = ref.watch(customersServiceProvider);
    return CustomersInfiniteNotifier(service, params);
  },
);

/// Customer Stats Provider
final customerStatsProvider = FutureProvider.family<Map<String, dynamic>, CustomersInfiniteParams>(
  (ref, params) async {
    final service = ref.watch(customersServiceProvider);
    return await service.getCustomerStats(
      searchQuery: params.searchQuery,
      duesOnly: params.duesOnly,
    );
  },
);

/// Customers List Provider
/// 
/// Fetches customers with pagination and search
final customersProvider = FutureProvider.family<
    Map<String, dynamic>, CustomersParams>(
  (ref, params) async {
    final service = ref.watch(customersServiceProvider);
    return await service.getCustomers(
      searchQuery: params.searchQuery,
      page: params.page,
      pageSize: params.pageSize,
    );
  },
);

/// Customers Stream Provider
/// 
/// Provides real-time stream of customers
final customersStreamProvider = StreamProvider<List<Customer>>((ref) {
  final service = ref.watch(customersServiceProvider);
  return service.watchCustomers();
});

/// Single Customer Provider
final customerProvider = FutureProvider.family<Customer?, String>(
  (ref, customerId) async {
    final service = ref.watch(customersServiceProvider);
    return await service.getCustomer(customerId);
  },
);

/// Customers Parameters
class CustomersParams {
  final String? searchQuery;
  final int page;
  final int pageSize;

  CustomersParams({
    this.searchQuery,
    this.page = 1,
    this.pageSize = 20,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomersParams &&
          runtimeType == other.runtimeType &&
          searchQuery == other.searchQuery &&
          page == other.page &&
          pageSize == other.pageSize;

  @override
  int get hashCode => searchQuery.hashCode ^ page.hashCode ^ pageSize.hashCode;
}

