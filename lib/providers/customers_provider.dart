import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/customers_service.dart';
import '../models/customer.dart';

/// Customers Service Provider
final customersServiceProvider = Provider<CustomersService>((ref) {
  return CustomersService();
});

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

