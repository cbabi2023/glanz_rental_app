import 'dart:math';
import '../core/supabase_client.dart';
import '../core/logger.dart';
import '../models/order.dart';

/// Item Return Model for processing returns
class ItemReturn {
  final String itemId;
  final String returnStatus; // 'returned', 'missing', or 'not_yet_returned' (to unreturn)
  final DateTime? actualReturnDate;
  final String? missingNote;
  final int? returnedQuantity; // Number of items to return (for partial returns)
  final double? damageCost; // Cost for damaged/missing items
  final String? description; // Description for missing/damaged items
  
  ItemReturn({
    required this.itemId,
    required this.returnStatus,
    this.actualReturnDate,
    this.missingNote,
    this.returnedQuantity,
    this.damageCost,
    this.description,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'item_id': itemId,
      'return_status': returnStatus,
      'actual_return_date': actualReturnDate?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'missing_note': missingNote,
      if (returnedQuantity != null) 'returned_quantity': returnedQuantity,
      if (damageCost != null) 'damage_cost': damageCost,
      if (description != null) 'description': description,
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
          'status, total_amount, subtotal, gst_amount, late_fee, damage_fee_total, '
          'security_deposit_amount, security_deposit_collected, security_deposit_refunded, security_deposit_refunded_amount, security_deposit_refund_date, additional_amount_collected, deposit_balance, created_at, '
          'customer:customers(id, name, phone, customer_number), '
          'branch:branches(id, name), '
          'items:order_items(id, photo_url, product_name, quantity, price_per_day, days, line_total, return_status, actual_return_date, late_return, missing_note, returned_quantity, damage_fee)',
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
            'status, total_amount, subtotal, gst_amount, late_fee, damage_fee_total, '
            'security_deposit_amount, security_deposit_collected, security_deposit_refunded, security_deposit_refunded_amount, security_deposit_refund_date, additional_amount_collected, deposit_balance, created_at, '
            'customer:customers(*), '
            'staff:profiles(id, full_name, upi_id), '
            'branch:branches(*), '
            'items:order_items(id, photo_url, product_name, quantity, price_per_day, days, line_total, return_status, actual_return_date, late_return, missing_note, returned_quantity, damage_fee)',
          )
          .eq('id', orderId)
          .single();

      return Order.fromJson(response);
    } catch (e, stackTrace) {
      AppLogger.error('Error fetching order $orderId', e, stackTrace);
      return null;
    }
  }

  /// Stream orders in real-time
  /// 
  /// ⚠️ IMPORTANT: This watches the 'orders' table.
  /// Note: Order items changes (return status) also affect order categorization.
  /// The provider layer should invalidate/refetch when order_items change via RPC calls.
  /// 
  /// For complete real-time updates including order_items, consider using
  /// a combination of this stream + manual invalidation after return processing.
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
    double? securityDeposit,
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
      // Insert security deposit amount (numeric) and collected flag (boolean)
      if (securityDeposit != null && securityDeposit > 0) 
        'security_deposit_amount': securityDeposit,
      if (securityDeposit != null && securityDeposit > 0) 
        'security_deposit_collected': true, // Boolean flag indicating deposit was collected
      // Note: security_deposit_refunded is a boolean flag, so we don't set it during creation
      // Note: security_deposit_refunded_amount and security_deposit_refund_date are set during refund process
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
    String? customerId,
    required String invoiceNumber,
    required String startDate,
    required String endDate,
    required String? startDatetime,
    required String? endDatetime,
    required double totalAmount,
    double? subtotal,
    double? gstAmount,
    double? securityDeposit,
    required List<Map<String, dynamic>> items,
  }) async {
    final startDateOnly = startDate.split('T')[0];
    final endDateOnly = endDate.split('T')[0];

    // Build update map
    final updateData = <String, dynamic>{
      'invoice_number': invoiceNumber,
      'start_date': startDateOnly,
      'end_date': endDateOnly,
      'start_datetime': startDatetime,
      'end_datetime': endDatetime,
      'total_amount': totalAmount,
      'subtotal': subtotal,
      'gst_amount': gstAmount,
      // Update security deposit amount (numeric) and collected flag (boolean)
      if (securityDeposit != null && securityDeposit > 0) 
        'security_deposit_amount': securityDeposit,
      if (securityDeposit != null && securityDeposit > 0) 
        'security_deposit_collected': true, // Boolean flag indicating deposit was collected
      // Note: security_deposit_refunded is a boolean flag, so we don't update it here
      // Note: security_deposit_refunded_amount and security_deposit_refund_date are set during refund process
    };

    // Add customer_id if provided
    if (customerId != null) {
      updateData['customer_id'] = customerId;
    }

    // Update order
    await _supabase
        .from('orders')
        .update(updateData)
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

  /// Update late fee for an order
  Future<Order> updateLateFee({
    required String orderId,
    required double lateFee,
  }) async {
    try {
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
            'late_fee': lateFee,
            'total_amount': newTotal,
          })
          .eq('id', orderId);

      final updatedOrder = await getOrder(orderId);
      if (updatedOrder == null) {
        throw Exception('Failed to retrieve updated order');
      }
      return updatedOrder;
    } catch (e) {
      AppLogger.error('Error updating late fee', e);
      rethrow;
    }
  }

  /// Refund security deposit for an order using transaction-based approach
  /// Matches website's useRefundDepositTransaction() logic
  Future<Order> refundSecurityDeposit({
    required String orderId,
    required double amount,
    String? method,
    String? reference,
    String? notes,
  }) async {
    try {
      // Validate amount
      if (amount <= 0) {
        throw Exception('Amount must be greater than zero');
      }

      // Get current order to validate refund
      final orderResponse = await _supabase
          .from('orders')
          .select(
              'deposit_balance, security_deposit_amount, security_deposit_refunded_amount')
          .eq('id', orderId)
          .single();

      if (orderResponse.isEmpty) {
        throw Exception('Order not found');
      }

      // Validate sufficient balance
      final dbBalance =
          (orderResponse['deposit_balance'] as num?)?.toDouble() ?? 0.0;
      final depositAmount =
          (orderResponse['security_deposit_amount'] as num?)?.toDouble() ?? 0.0;
      final alreadyRefunded = (orderResponse['security_deposit_refunded_amount']
                  as num?)
              ?.toDouble() ??
          0.0;

      // Fallback balance = deposit - already refunded
      final fallbackBalance =
          (depositAmount - alreadyRefunded).clamp(0.0, double.infinity);

      // Effective balance prefers db balance if present, otherwise fallback
      double effectiveBalance = dbBalance > 0 ? dbBalance : fallbackBalance;
      if (effectiveBalance <= 0 && depositAmount > 0) {
        // As a final fallback, allow full deposit amount (per user request to refund full deposit)
        effectiveBalance = depositAmount;
      }

      // Only block if we have a positive effective balance and the requested amount exceeds it
      if (effectiveBalance > 0 && amount > effectiveBalance + 0.01) {
        throw Exception(
          'Cannot refund ₹${amount.toStringAsFixed(2)}. Current deposit balance is ₹${effectiveBalance.toStringAsFixed(2)}',
        );
      }

      // Get current user
      final userResponse = await _supabase.auth.getUser();
      if (userResponse.user == null) {
        throw Exception('Not authenticated');
      }

      // Insert refund transaction
      final transactionResponse = await _supabase
          .from('order_payment_transactions')
          .insert({
            'order_id': orderId,
            'type': 'deposit_refund',
            'amount': amount,
            'method': method,
            'reference': reference,
            'notes': notes,
            'created_by': userResponse.user!.id,
          })
          .select()
          .single();

      if (transactionResponse.isEmpty) {
        throw Exception('Failed to create refund transaction');
      }

      // Recalculate order balances using database function
      try {
        await _supabase.rpc(
          'recalculate_order_balances',
          params: {'p_order_id': orderId},
        );
      } catch (rpcError) {
        AppLogger.warning('Failed to recalculate balances: $rpcError');
        // Continue even if RPC fails - balances may be calculated by triggers
      }

      // Update legacy fields for backward compatibility
      final updatedOrderResponse = await _supabase
          .from('orders')
          .select('deposit_balance')
          .eq('id', orderId)
          .single();

      final updatedBalance = (updatedOrderResponse['deposit_balance'] as num?)?.toDouble() ?? 0.0;
      final isFullyRefunded = updatedBalance < 0.01;

      if (isFullyRefunded) {
        await _supabase
            .from('orders')
            .update({
              'security_deposit_refunded': true,
              'security_deposit_refund_date': DateTime.now().toIso8601String(),
            })
            .eq('id', orderId);
      }

      // Return updated order
      final updatedOrder = await getOrder(orderId);
      if (updatedOrder == null) {
        throw Exception('Failed to retrieve updated order');
      }
      return updatedOrder;
    } catch (e) {
      AppLogger.error('Error refunding security deposit', e);
      rethrow;
    }
  }

  /// Collect outstanding amount for an order
  /// This updates the security_deposit_amount to include the collected outstanding amount
  /// Following website logic: when collecting outstanding, add to security_deposit_amount
  /// so that outstanding amount becomes zero (security deposit now covers rental + GST)
  Future<Order> collectOutstandingAmount({
    required String orderId,
    required double amount,
  }) async {
    try {
      // Get current order
      final currentOrder = await getOrder(orderId);
      if (currentOrder == null) {
        throw Exception('Order not found');
      }

      // Validate amount
      if (amount <= 0) {
        throw Exception('Amount must be greater than zero');
      }

      // Get current security deposit and additional amount collected
      final currentSecurityDeposit = currentOrder.securityDepositAmount ?? 0.0;
      final currentAdditionalCollected = currentOrder.additionalAmountCollected ?? 0.0;
      
      // Calculate current outstanding amount
      // Outstanding = (Rental + GST + Damage + Late Fee) - Security Deposit - Additional Amount Collected
      final rentalAmount = currentOrder.subtotal ?? 0.0;
      final gstAmount = currentOrder.gstAmount ?? 0.0;
      final damageFees = currentOrder.damageFeeTotal ?? 0.0;
      final lateFee = currentOrder.lateFee ?? 0.0;
      final totalCharges = rentalAmount + gstAmount + damageFees + lateFee;
      final currentOutstanding = (totalCharges - currentSecurityDeposit - currentAdditionalCollected).clamp(0.0, double.infinity);
      
      // Validate: cannot collect more than outstanding (with small tolerance for floating-point precision)
      // Round to 2 decimal places to avoid floating-point precision issues
      final roundedAmount = (amount * 100).round() / 100;
      final roundedOutstanding = (currentOutstanding * 100).round() / 100;
      
      if (roundedAmount > roundedOutstanding + 0.01) { // Allow 0.01 tolerance
        throw Exception('Cannot collect more than outstanding amount: ₹${currentOutstanding.toStringAsFixed(2)}');
      }
      
      // Use rounded amount for consistency
      final finalAmount = roundedAmount.clamp(0.0, roundedOutstanding);
      
      // Add the collected amount to additional_amount_collected (following website logic)
      // Website stores collected outstanding amounts in additional_amount_collected field
      final newAdditionalCollected = currentAdditionalCollected + finalAmount;

      // Update the order with additional amount collected
      await _supabase
          .from('orders')
          .update({
            'additional_amount_collected': newAdditionalCollected,
            'security_deposit_collected': true, // Mark as collected
          })
          .eq('id', orderId);

      // Return updated order
      final updatedOrder = await getOrder(orderId);
      if (updatedOrder == null) {
        throw Exception('Failed to retrieve updated order');
      }
      return updatedOrder;
    } catch (e) {
      AppLogger.error('Error collecting outstanding amount', e);
      rethrow;
    }
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
      AppLogger.error('Error processing order return', e);
      rethrow;
    }
  }

  /// Get orders for a specific customer
  Future<List<Order>> getCustomerOrders(String customerId) async {
    final response = await _supabase
        .from('orders')
        .select(
          'id, invoice_number, branch_id, staff_id, customer_id, '
          'booking_date, start_date, end_date, start_datetime, end_datetime, '
          'status, total_amount, subtotal, gst_amount, late_fee, damage_fee_total, '
          'security_deposit_amount, security_deposit_collected, security_deposit_refunded, security_deposit_refunded_amount, security_deposit_refund_date, additional_amount_collected, deposit_balance, created_at, '
          'customer:customers(*), '
          'branch:branches(*), '
          'staff:profiles(id, full_name, upi_id), '
          'items:order_items(id, photo_url, product_name, quantity, price_per_day, days, line_total, return_status, actual_return_date, late_return, missing_note, returned_quantity, damage_fee)',
        )
        .eq('customer_id', customerId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => Order.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Get order timeline events from audit logs
  Future<List<Map<String, dynamic>>> getOrderTimeline(String orderId) async {
    try {
      // Fetch audit logs for this order
      final auditResponse = await _supabase
          .from('order_return_audit')
          .select(
            'id, order_id, order_item_id, action, previous_status, new_status, '
            'user_id, notes, created_at, '
            'user:profiles!order_return_audit_user_id_fkey(full_name, username)',
          )
          .eq('order_id', orderId)
          .order('created_at', ascending: true);

      final auditLogs = (auditResponse as List).cast<Map<String, dynamic>>();

      // Also get order creation info from orders table
      final orderResponse = await _supabase
          .from('orders')
          .select(
            'id, created_at, status, staff_id, '
            'staff:profiles!orders_staff_id_fkey(full_name, username)',
          )
          .eq('id', orderId)
          .single();

      final events = <Map<String, dynamic>>[];

      // Add audit log events
      for (final log in auditLogs) {
        final user = log['user'] as Map<String, dynamic>?;
        events.add({
          'id': log['id'],
          'order_id': log['order_id'],
          'order_item_id': log['order_item_id'],
          'action': log['action'],
          'previous_status': log['previous_status'],
          'new_status': log['new_status'],
          'user_id': log['user_id'],
          'user_name': user?['full_name'] ?? user?['username'] ?? 'Unknown',
          'notes': log['notes'],
          'created_at': log['created_at'],
        });
      }

      // Check if order_created event already exists in audit logs
      final hasOrderCreatedEvent = auditLogs.any(
        (log) => log['action'] == 'order_created',
      );

      // Add order creation event only if not already in audit logs
      if (!hasOrderCreatedEvent) {
        final orderData = orderResponse;
        final staff = orderData['staff'] as Map<String, dynamic>?;
        events.add({
          'id': 'created-${orderData['id']}',
          'order_id': orderData['id'],
          'action': 'order_created',
          'new_status': orderData['status'],
          'user_id': orderData['staff_id'],
          'user_name': staff?['full_name'] ?? staff?['username'] ?? 'Unknown',
          'created_at': orderData['created_at'],
        });
      }

      // Sort by created_at ascending (oldest first for timeline flow)
      events.sort((a, b) {
        final dateA = DateTime.parse(a['created_at'] as String);
        final dateB = DateTime.parse(b['created_at'] as String);
        return dateA.compareTo(dateB);
      });

      return events;
    } catch (e) {
      AppLogger.error('Error fetching order timeline', e);
      return [];
    }
  }

  /// Update order item quantity
  Future<void> updateItemQuantity({
    required String itemId,
    required int quantity,
  }) async {
    try {
      // Get the item to calculate new line_total
      final itemResponse = await _supabase
          .from('order_items')
          .select('order_id, price_per_day')
          .eq('id', itemId)
          .single();
      
      final orderId = itemResponse['order_id'] as String;
      final pricePerDay = (itemResponse['price_per_day'] as num).toDouble();
      
      // Calculate new line_total (without multiplying by days)
      final newLineTotal = quantity * pricePerDay;
      
      // Update the item
      await _supabase
          .from('order_items')
          .update({
            'quantity': quantity,
            'line_total': newLineTotal,
          })
          .eq('id', itemId);
      
      // Recalculate order totals
      final allItemsResponse = await _supabase
          .from('order_items')
          .select('line_total')
          .eq('order_id', orderId);
      
      final subtotal = (allItemsResponse as List)
          .map((item) => (item['line_total'] as num).toDouble())
          .fold<double>(0.0, (sum, total) => sum + total);
      
      // Get order to calculate GST
      final orderResponse = await _supabase
          .from('orders')
          .select('gst_amount, late_fee, damage_fee_total')
          .eq('id', orderId)
          .single();
      
      final previousGstAmount = (orderResponse['gst_amount'] as num?)?.toDouble() ?? 0.0;
      final previousSubtotal = subtotal - previousGstAmount; // Approximate previous subtotal
      
      // Calculate GST if it was applied before (maintain same rate)
      double gstAmount = 0.0;
      if (previousGstAmount > 0 && previousSubtotal > 0) {
        final gstRate = (previousGstAmount / previousSubtotal) * 100;
        gstAmount = subtotal * (gstRate / 100);
      }
      
      final lateFee = (orderResponse['late_fee'] as num?)?.toDouble() ?? 0.0;
      final damageFeeTotal = (orderResponse['damage_fee_total'] as num?)?.toDouble() ?? 0.0;
      final totalAmount = subtotal + gstAmount + lateFee + damageFeeTotal;
      
      // Update order totals
      await _supabase
          .from('orders')
          .update({
            'subtotal': subtotal,
            'gst_amount': gstAmount,
            'total_amount': totalAmount,
          })
          .eq('id', orderId);
    } catch (e) {
      AppLogger.error('Error updating item quantity', e);
      rethrow;
    }
  }

  /// Update order item damage cost and description
  Future<void> updateItemDamage({
    required String itemId,
    double? damageCost,
    String? damageDescription,
  }) async {
    try {
      // First get the order_id for this item
      final itemResponse = await _supabase
          .from('order_items')
          .select('order_id')
          .eq('id', itemId)
          .single();
      
      final orderId = itemResponse['order_id'] as String;
      
      final updateData = <String, dynamic>{};
      
      if (damageCost != null && damageCost > 0) {
        updateData['damage_fee'] = damageCost;
      } else {
        updateData['damage_fee'] = null;
      }
      
      // Store damage description in missing_note if provided
      if (damageDescription != null && damageDescription.trim().isNotEmpty) {
        updateData['missing_note'] = damageDescription.trim();
      } else if (damageCost == null || damageCost == 0) {
        // Clear missing_note if no damage
        updateData['missing_note'] = null;
      }
      
      await _supabase
          .from('order_items')
          .update(updateData)
          .eq('id', itemId);
      
      // Recalculate order damage_fee_total
      final allItemsResponse = await _supabase
          .from('order_items')
          .select('damage_fee')
          .eq('order_id', orderId);
      
      final totalDamage = (allItemsResponse as List)
          .map((item) => (item['damage_fee'] as num?)?.toDouble() ?? 0.0)
          .fold<double>(0.0, (sum, cost) => sum + cost);
      
      await _supabase
          .from('orders')
          .update({'damage_fee_total': totalDamage})
          .eq('id', orderId);
    } catch (e) {
      AppLogger.error('Error updating item damage', e);
      rethrow;
    }
  }
}
