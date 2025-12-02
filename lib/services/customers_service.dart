import '../core/supabase_client.dart';
import '../models/customer.dart';

/// Customers Service
///
/// Handles all customer-related database operations
class CustomersService {
  final _supabase = SupabaseService.client;

  /// Get customers with optional search and pagination
  Future<Map<String, dynamic>> getCustomers({
    String? searchQuery,
    int page = 1,
    int pageSize = 20,
  }) async {
    final from = (page - 1) * pageSize;
    final to = from + pageSize - 1;

    // Build query - apply filters before ordering
    dynamic query = _supabase.from('customers').select('*');

    // Apply search filter if provided (before ordering)
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      query = query.or('name.ilike.%$searchQuery%,phone.ilike.%$searchQuery%');
    }

    // Apply ordering
    query = query.order('created_at', ascending: false);

    // Apply pagination
    query = query.range(from, to);

    final response = await query;
    final customers = (response as List)
        .map((json) => Customer.fromJson(json as Map<String, dynamic>))
        .toList();

    // Calculate dues for customers - optimized to fetch all orders at once
    if (customers.isNotEmpty) {
      final customerIds = customers.map((c) => c.id).toSet().toList();
      final duesMap = <String, double>{};

      try {
        // Fetch all pending orders for all customers in a single query
        // This is much faster than querying individually
        final ordersResponse = await _supabase
            .from('orders')
            .select('customer_id, total_amount, status')
            .or('status.eq.active,status.eq.pending_return');

        // Process all orders and calculate dues
        for (final order in ordersResponse) {
          final customerId = order['customer_id']?.toString();
          if (customerId != null && customerIds.contains(customerId)) {
            final amount = (order['total_amount'] as num?)?.toDouble() ?? 0.0;
            duesMap[customerId] = (duesMap[customerId] ?? 0.0) + amount;
          }
        }
      } catch (e) {
        // If query fails, skip dues calculation - customers will show 0 dues
        print('Error fetching orders for dues calculation: $e');
      }

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
    }

    // Note: Getting exact count requires a separate count query in Supabase Flutter
    // For now, using length as approximation
    final count = customers.length;

    return {
      'data': customers,
      'total': count,
      'page': page,
      'pageSize': pageSize,
      'totalPages': (count / pageSize).ceil(),
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
      print('Error fetching customer: $e');
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
