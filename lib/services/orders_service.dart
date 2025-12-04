import 'dart:math';
import '../core/supabase_client.dart';
import '../models/order.dart';

/// Item Return Model for processing returns
class ItemReturn {
  final String itemId;
  final String returnStatus; // 'returned', 'missing', or 'not_yet_returned' (to unreturn)
  final DateTime? actualReturnDate;
  final String? missingNote;
  
  ItemReturn({
    required this.itemId,
    required this.returnStatus,
    this.actualReturnDate,
    this.missingNote,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'item_id': itemId,
      'return_status': returnStatus,
      'actual_return_date': actualReturnDate?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'missing_note': missingNote,
    };
  }
}

/// Orders Service
///
/// Handles all order-related database operations
class OrdersService {
  final _supabase = SupabaseService.client;
  
  /// Generate auto invoice number in format: GLAORD-YYYYMMDD-XXXX
  String generateInvoiceNumber() {
    final now = DateTime.now();
    final year = now.year.toString();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final random = Random().nextInt(10000).toString().padLeft(4, '0');
    
    return 'GLAORD-$year$month$day-$random';
  }

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
          'booking_date, start_date, end_date, start_datetime, end_datetime, '
          'status, total_amount, subtotal, gst_amount, late_fee, created_at, '
          'customer:customers(id, name, phone, customer_number), '
          'branch:branches(id, name), '
          'items:order_items(id, photo_url, product_name, quantity, price_per_day, days, line_total, return_status, actual_return_date, late_return, missing_note)',
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
            'id, invoice_number, branch_id, staff_id, customer_id, '
            'booking_date, start_date, end_date, start_datetime, end_datetime, '
            'status, total_amount, subtotal, gst_amount, late_fee, created_at, '
            'customer:customers(*), '
            'staff:profiles(id, full_name, upi_id), '
            'branch:branches(*), '
            'items:order_items(id, photo_url, product_name, quantity, price_per_day, days, line_total, return_status, actual_return_date, late_return, missing_note)',
          )
          .eq('id', orderId)
          .single();

      return Order.fromJson(response);
    } catch (e, stackTrace) {
      print('Error fetching order $orderId: $e');
      print('Stack trace: $stackTrace');
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
    String? invoiceNumber,
    required String startDate,
    required String endDate,
    required String? startDatetime,
    required String? endDatetime,
    required double totalAmount,
    double? subtotal,
    double? gstAmount,
    required List<Map<String, dynamic>> items,
  }) async {
    // Parse start date to determine status
    final startDateParsed = DateTime.parse(startDate);
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final startDateOnly = DateTime(startDateParsed.year, startDateParsed.month, startDateParsed.day);
    
    // Calculate status: scheduled if future date, active if today or past
    final orderStatus = startDateOnly.isAfter(todayStart) 
      ? OrderStatus.scheduled 
      : OrderStatus.active;
    
    // Generate invoice number if not provided
    final finalInvoiceNumber = invoiceNumber?.trim().isEmpty ?? true
      ? generateInvoiceNumber()
      : invoiceNumber!;
    
    // Prepare order data
    final startDateOnlyStr = startDate.split('T')[0];
    final endDateOnlyStr = endDate.split('T')[0];

    final orderData = {
      'branch_id': branchId,
      'staff_id': staffId,
      'customer_id': customerId,
      'invoice_number': finalInvoiceNumber,
      'booking_date': DateTime.now().toIso8601String(), // Always set booking date
      'start_date': startDateOnlyStr,
      'end_date': endDateOnlyStr,
      'start_datetime': startDatetime,
      'end_datetime': endDatetime,
      'status': orderStatus.value, // Use calculated status
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

  /// Start rental - converts scheduled order to active
  Future<Order> startRental(String orderId) async {
    try {
      final response = await _supabase
        .from('orders')
        .update({
          'status': OrderStatus.active.value,
          'start_datetime': DateTime.now().toIso8601String(),
        })
        .eq('id', orderId)
        .select()
        .single();
      
      if (response.isEmpty) {
        throw Exception('Failed to start rental: Order not found');
      }
      
      final updatedOrder = await getOrder(orderId);
      if (updatedOrder == null) {
        throw Exception('Failed to retrieve updated order');
      }
      return updatedOrder;
    } catch (e) {
      throw Exception('Error starting rental: $e');
    }
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
  
  /// Process order return with item-wise tracking
  /// Uses RPC function process_order_return_optimized
  Future<Map<String, dynamic>> processOrderReturn({
    required String orderId,
    required List<ItemReturn> itemReturns,
    required String userId,
    double lateFee = 0,
  }) async {
    try {
      final itemReturnsJson = itemReturns.map((ir) => ir.toJson()).toList();
      
      final response = await _supabase.rpc('process_order_return_optimized', params: {
        'p_order_id': orderId,
        'p_item_returns': itemReturnsJson,
        'p_user_id': userId,
        'p_late_fee': lateFee,
      });
      
      // RPC returns data directly as Map
      if (response is Map<String, dynamic>) {
        return response;
      } else if (response is Map) {
        return Map<String, dynamic>.from(response);
      } else {
        // If response is not a Map, wrap it
        return {'success': true, 'data': response};
      }
    } catch (e) {
      print('Error processing order return: $e');
      rethrow;
    }
  }

  /// Get orders for a specific customer
  Future<List<Order>> getCustomerOrders(String customerId) async {
    final response = await _supabase
        .from('orders')
        .select('*, branch:branches(*), staff:profiles(id, full_name, upi_id)')
        .eq('customer_id', customerId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => Order.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
