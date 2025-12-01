import '../core/supabase_client.dart';
import '../models/order.dart';

/// Orders Service
///
/// Handles all order-related database operations
class OrdersService {
  final _supabase = SupabaseService.client;

  /// Get orders with optional filters
  Future<List<Order>> getOrders({
    String? branchId,
    OrderStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
    int? offset,
  }) async {
    // Build query - apply all filters first, then ordering, then pagination
    dynamic query = _supabase
        .from('orders')
        .select(
          'id, invoice_number, branch_id, staff_id, customer_id, '
          'start_date, end_date, start_datetime, end_datetime, '
          'status, total_amount, subtotal, gst_amount, late_fee, created_at, '
          'customer:customers(id, name, phone, customer_number), '
          'branch:branches(id, name), '
          'items:order_items(id, photo_url, product_name, quantity, price_per_day, days, line_total)',
        );

    // Apply filters
    if (branchId != null) {
      query = query.eq('branch_id', branchId);
    }

    if (status != null) {
      query = query.eq('status', status.value);
    }

    if (startDate != null) {
      query = query.gte('created_at', startDate.toIso8601String());
    }

    if (endDate != null) {
      query = query.lte('created_at', endDate.toIso8601String());
    }

    // Apply ordering after filters
    query = query.order('created_at', ascending: false);

    // Apply pagination
    if (limit != null) {
      query = query.limit(limit);
    }

    if (offset != null && limit != null) {
      query = query.range(offset, offset + limit - 1);
    }

    final response = await query;
    return (response as List)
        .map((json) => Order.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Get a single order by ID with full details
  Future<Order?> getOrder(String orderId) async {
    try {
      final response = await _supabase
          .from('orders')
          .select(
            '*, '
            'customer:customers(*), '
            'staff:profiles(id, full_name), '
            'branch:branches(*), '
            'items:order_items(*)',
          )
          .eq('id', orderId)
          .single();

      return Order.fromJson(response);
    } catch (e) {
      print('Error fetching order: $e');
      return null;
    }
  }

  /// Stream orders in real-time
  Stream<List<Order>> watchOrders({String? branchId}) {
    var query = _supabase.from('orders').stream(primaryKey: ['id']);

    // Note: Filtering on streams needs to be done in the map function
    // as the stream builder doesn't support eq() directly
    return query.map((data) {
      var orders = (data as List)
          .map((json) => Order.fromJson(json as Map<String, dynamic>))
          .toList();

      // Filter by branchId if provided
      if (branchId != null) {
        orders = orders.where((order) => order.branchId == branchId).toList();
      }

      // Sort by created_at descending
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return orders;
    });
  }

  /// Create a new order
  Future<Order> createOrder({
    required String branchId,
    required String staffId,
    required String customerId,
    required String invoiceNumber,
    required String startDate,
    required String endDate,
    required String? startDatetime,
    required String? endDatetime,
    required double totalAmount,
    double? subtotal,
    double? gstAmount,
    required List<Map<String, dynamic>> items,
  }) async {
    // Prepare order data
    final startDateOnly = startDate.split('T')[0];
    final endDateOnly = endDate.split('T')[0];

    final orderData = {
      'branch_id': branchId,
      'staff_id': staffId,
      'customer_id': customerId,
      'invoice_number': invoiceNumber,
      'start_date': startDateOnly,
      'end_date': endDateOnly,
      'start_datetime': startDatetime,
      'end_datetime': endDatetime,
      'status': 'active',
      'total_amount': totalAmount,
      'subtotal': subtotal,
      'gst_amount': gstAmount,
    };

    // Create the order
    final orderResponse = await _supabase
        .from('orders')
        .insert(orderData)
        .select('id')
        .single();

    final orderId = orderResponse['id'] as String;

    // Prepare items with order_id
    final itemsWithOrderId = items.map((item) {
      final itemData = Map<String, dynamic>.from(item);
      itemData['order_id'] = orderId;
      return itemData;
    }).toList();

    // Batch insert all items
    await _supabase.from('order_items').insert(itemsWithOrderId);

    // Return the created order
    final createdOrder = await getOrder(orderId);
    if (createdOrder == null) {
      throw Exception('Failed to retrieve created order');
    }
    return createdOrder;
  }

  /// Update an existing order
  Future<Order> updateOrder({
    required String orderId,
    required String invoiceNumber,
    required String startDate,
    required String endDate,
    required String? startDatetime,
    required String? endDatetime,
    required double totalAmount,
    double? subtotal,
    double? gstAmount,
    required List<Map<String, dynamic>> items,
  }) async {
    final startDateOnly = startDate.split('T')[0];
    final endDateOnly = endDate.split('T')[0];

    // Update order
    await _supabase
        .from('orders')
        .update({
          'invoice_number': invoiceNumber,
          'start_date': startDateOnly,
          'end_date': endDateOnly,
          'start_datetime': startDatetime,
          'end_datetime': endDatetime,
          'total_amount': totalAmount,
          'subtotal': subtotal,
          'gst_amount': gstAmount,
        })
        .eq('id', orderId);

    // Delete existing items
    await _supabase.from('order_items').delete().eq('order_id', orderId);

    // Insert updated items
    final itemsWithOrderId = items.map((item) {
      final itemData = Map<String, dynamic>.from(item);
      itemData['order_id'] = orderId;
      return itemData;
    }).toList();

    await _supabase.from('order_items').insert(itemsWithOrderId);

    // Return updated order
    final updatedOrder = await getOrder(orderId);
    if (updatedOrder == null) {
      throw Exception('Failed to retrieve updated order');
    }
    return updatedOrder;
  }

  /// Update order status
  Future<Order> updateOrderStatus({
    required String orderId,
    required OrderStatus status,
    double lateFee = 0.0,
  }) async {
    // Get current order to calculate new total
    final currentOrder = await getOrder(orderId);
    if (currentOrder == null) {
      throw Exception('Order not found');
    }

    final originalTotal =
        currentOrder.totalAmount - (currentOrder.lateFee ?? 0);
    final newTotal = originalTotal + lateFee;

    await _supabase
        .from('orders')
        .update({
          'status': status.value,
          'late_fee': lateFee,
          'total_amount': newTotal,
        })
        .eq('id', orderId);

    final updatedOrder = await getOrder(orderId);
    if (updatedOrder == null) {
      throw Exception('Failed to retrieve updated order');
    }
    return updatedOrder;
  }

  /// Get orders for a specific customer
  Future<List<Order>> getCustomerOrders(String customerId) async {
    final response = await _supabase
        .from('orders')
        .select('*, branch:branches(*), staff:profiles(id, full_name)')
        .eq('customer_id', customerId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => Order.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
