import '../core/supabase_client.dart';
import '../core/logger.dart';
import '../models/customer.dart';

/// Customers Service
///
/// Handles all customer-related database operations
class CustomersService {
  final _supabase = SupabaseService.client;

  /// Get customer statistics from server
  Future<Map<String, dynamic>> getCustomerStats({
    String? searchQuery,
    bool duesOnly = false,
  }) async {
    try {
      // Get total count - fetch all IDs and count them
      dynamic countQuery = _supabase.from('customers').select('id');
      
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        countQuery = countQuery.or('name.ilike.%$searchQuery%,phone.ilike.%$searchQuery%');
      }
      
      final countResponse = await countQuery;
      final total = countResponse is List ? countResponse.length : 0;
      
      // Get all customer IDs (for dues calculation)
      dynamic customerIdsQuery = _supabase.from('customers').select('id');
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        customerIdsQuery = customerIdsQuery.or('name.ilike.%$searchQuery%,phone.ilike.%$searchQuery%');
      }
      final customerIdsResponse = await customerIdsQuery;
      final customerIds = (customerIdsResponse as List)
          .map((json) => (json as Map<String, dynamic>)['id'] as String)
          .toList();
      
      // Calculate dues for all customers
      Map<String, double> duesMap = {};
      if (customerIds.isNotEmpty) {
        // Build filter for customer IDs and status
        // Use multiple OR conditions for customer IDs since .in() is not available
        dynamic ordersQuery = _supabase.from('orders').select('customer_id, total_amount, status');
        
        // Filter by status first
        ordersQuery = ordersQuery.or('status.eq.active,status.eq.pending_return');
        
        // Then filter by customer IDs - we'll filter in code after fetching
        final ordersResponse = await ordersQuery;
        
        // Filter orders by customer IDs in code
        final filteredOrders = (ordersResponse as List)
            .where((order) {
              final orderCustomerId = order['customer_id']?.toString();
              return orderCustomerId != null && customerIds.contains(orderCustomerId);
            })
            .toList();
        
        for (final order in filteredOrders) {
          final customerId = order['customer_id']?.toString();
          if (customerId != null) {
            final amount = (order['total_amount'] as num?)?.toDouble() ?? 0.0;
            duesMap[customerId] = (duesMap[customerId] ?? 0.0) + amount;
          }
        }
      }
      
      // Calculate stats
      int withDues = 0;
      double totalDues = 0.0;
      
      for (final customerId in customerIds) {
        final dueAmount = duesMap[customerId] ?? 0.0;
        if (dueAmount > 0) {
          withDues++;
          totalDues += dueAmount;
        }
      }
      
      return {
        'total': total,
        'withDues': withDues,
        'totalDues': totalDues,
      };
    } catch (e) {
      AppLogger.error('Error fetching customer stats', e);
      return {
        'total': 0,
        'withDues': 0,
        'totalDues': 0.0,
      };
    }
  }

  /// Get customers with optional search, filter, and pagination
  Future<Map<String, dynamic>> getCustomers({
    String? searchQuery,
    bool duesOnly = false,
    int page = 1,
    int pageSize = 20,
  }) async {
    final from = (page - 1) * pageSize;

    // Get all customer IDs first to calculate dues for filtering
    dynamic customerIdsQuery = _supabase.from('customers').select('id');
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      customerIdsQuery = customerIdsQuery.or('name.ilike.%$searchQuery%,phone.ilike.%$searchQuery%');
    }
    final customerIdsResponse = await customerIdsQuery;
    final allCustomerIds = (customerIdsResponse as List)
        .map((json) => (json as Map<String, dynamic>)['id'] as String)
        .toList();

    // Calculate dues for all customers (for filtering)
    Map<String, double> duesMap = {};
    if (allCustomerIds.isNotEmpty) {
      try {
        final ordersResponse = await _supabase
            .from('orders')
            .select('customer_id, total_amount, status')
            .or('status.eq.active,status.eq.pending_return');

        // Filter orders by customer IDs in code
        final filteredOrders = (ordersResponse as List)
            .where((order) {
              final orderCustomerId = order['customer_id']?.toString();
              return orderCustomerId != null && allCustomerIds.contains(orderCustomerId);
            })
            .toList();

        for (final order in filteredOrders) {
          final customerId = order['customer_id']?.toString();
          if (customerId != null) {
            final amount = (order['total_amount'] as num?)?.toDouble() ?? 0.0;
            duesMap[customerId] = (duesMap[customerId] ?? 0.0) + amount;
          }
        }
      } catch (e) {
        AppLogger.error('Error fetching orders for dues calculation', e);
      }
    }

    // Filter customers with dues on server side if duesOnly is true
    List<String> customerIdsToFetch = allCustomerIds;
    int totalCount = allCustomerIds.length;
    if (duesOnly) {
      customerIdsToFetch = allCustomerIds
          .where((id) => (duesMap[id] ?? 0.0) > 0)
          .toList();
      totalCount = customerIdsToFetch.length;
      if (customerIdsToFetch.isEmpty) {
        // No customers with dues, return empty result
        return {
          'data': <Customer>[],
          'total': 0,
          'page': page,
          'pageSize': pageSize,
          'totalPages': 0,
        };
      }
    }

    // Build query - fetch all matching customers first (we'll paginate after filtering)
    dynamic query = _supabase.from('customers').select('*');

    // Apply search filter if provided (before ordering)
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      query = query.or('name.ilike.%$searchQuery%,phone.ilike.%$searchQuery%');
    }

    // Apply ordering
    query = query.order('created_at', ascending: false);

    // Fetch all matching customers (before pagination if duesOnly filter is applied)
    final response = await query;
    List customersList = response as List;
    
    // Filter by customer IDs if duesOnly is true (before pagination)
    if (duesOnly && customerIdsToFetch.isNotEmpty) {
      customersList = customersList.where((json) {
        final customerId = (json as Map<String, dynamic>)['id'] as String?;
        return customerId != null && customerIdsToFetch.contains(customerId);
      }).toList();
    }
    
    // Apply pagination after filtering
    final paginatedCustomersList = customersList.skip(from).take(pageSize).toList();
    
    final customers = paginatedCustomersList
        .map((json) => Customer.fromJson(json as Map<String, dynamic>))
        .toList();

    // Add due amounts to customers
    for (var i = 0; i < customers.length; i++) {
      final customer = customers[i];
      customers[i] = Customer(
        id: customer.id,
        customerNumber: customer.customerNumber,
        name: customer.name,
        phone: customer.phone,
        email: customer.email,
        address: customer.address,
        idProofType: customer.idProofType,
        idProofNumber: customer.idProofNumber,
        idProofFrontUrl: customer.idProofFrontUrl,
        idProofBackUrl: customer.idProofBackUrl,
        createdAt: customer.createdAt,
        dueAmount: duesMap[customer.id] ?? 0.0,
      );
    }

    return {
      'data': customers,
      'total': totalCount,
      'page': page,
      'pageSize': pageSize,
      'totalPages': (totalCount / pageSize).ceil(),
    };
  }

  /// Get a single customer by ID
  Future<Customer?> getCustomer(String customerId) async {
    try {
      final response = await _supabase
          .from('customers')
          .select()
          .eq('id', customerId)
          .single();

      return Customer.fromJson(response);
    } catch (e) {
      AppLogger.error('Error fetching customer', e);
      return null;
    }
  }

  /// Stream customers in real-time
  Stream<List<Customer>> watchCustomers() {
    return _supabase.from('customers').stream(primaryKey: ['id']).map((data) {
      final customers = (data as List)
          .map((json) => Customer.fromJson(json as Map<String, dynamic>))
          .toList();
      // Sort by created_at descending
      customers.sort((a, b) {
        final aDate = a.createdAt ?? DateTime(1970);
        final bDate = b.createdAt ?? DateTime(1970);
        return bDate.compareTo(aDate);
      });
      return customers;
    });
  }

  /// Create a new customer
  Future<Customer> createCustomer({
    required String name,
    required String phone,
    String? email,
    String? address,
    IdProofType? idProofType,
    String? idProofNumber,
    String? idProofFrontUrl,
    String? idProofBackUrl,
  }) async {
    final response = await _supabase
        .from('customers')
        .insert({
          'name': name.trim(),
          'phone': phone.trim(),
          'email': email?.trim(),
          'address': address?.trim(),
          'id_proof_type': idProofType?.value,
          'id_proof_number': idProofNumber?.trim(),
          'id_proof_front_url': idProofFrontUrl,
          'id_proof_back_url': idProofBackUrl,
        })
        .select()
        .single();

    return Customer.fromJson(response);
  }

  /// Update an existing customer
  Future<Customer> updateCustomer({
    required String customerId,
    String? name,
    String? phone,
    String? email,
    String? address,
    IdProofType? idProofType,
    String? idProofNumber,
    String? idProofFrontUrl,
    String? idProofBackUrl,
  }) async {
    final updateData = <String, dynamic>{};

    if (name != null) updateData['name'] = name.trim();
    if (phone != null) updateData['phone'] = phone.trim();
    if (email != null) updateData['email'] = email.trim();
    if (address != null) updateData['address'] = address.trim();
    if (idProofType != null) updateData['id_proof_type'] = idProofType.value;
    if (idProofNumber != null)
      updateData['id_proof_number'] = idProofNumber.trim();
    if (idProofFrontUrl != null)
      updateData['id_proof_front_url'] = idProofFrontUrl;
    if (idProofBackUrl != null)
      updateData['id_proof_back_url'] = idProofBackUrl;

    final response = await _supabase
        .from('customers')
        .update(updateData)
        .eq('id', customerId)
        .select()
        .single();

    return Customer.fromJson(response);
  }

  /// Delete a customer
  Future<void> deleteCustomer(String customerId) async {
    await _supabase.from('customers').delete().eq('id', customerId);
  }
}
