import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_client.dart';
import '../core/logger.dart';
import '../models/order.dart';
import '../models/order_item.dart';

/// Item Return Model for processing returns
class ItemReturn {
  final String itemId;
  final String
  returnStatus; // 'returned', 'missing', or 'not_yet_returned' (to unreturn)
  final DateTime? actualReturnDate;
  final String? missingNote;
  final int?
  returnedQuantity; // Number of items to return (for partial returns)
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
      'actual_return_date':
          actualReturnDate?.toIso8601String() ??
          DateTime.now().toIso8601String(),
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

  /// Helper function to parse datetime with timezone handling
  static DateTime _parseDateTimeWithTimezone(String dateString) {
    try {
      final trimmed = dateString.trim();
      final hasTimezone =
          trimmed.endsWith('Z') ||
          RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(trimmed);

      if (hasTimezone) {
        return DateTime.parse(trimmed).toLocal();
      } else {
        final parsed = DateTime.parse(trimmed);
        final utcDate = DateTime.utc(
          parsed.year,
          parsed.month,
          parsed.day,
          parsed.hour,
          parsed.minute,
          parsed.second,
          parsed.millisecond,
          parsed.microsecond,
        );
        return utcDate.toLocal();
      }
    } catch (e) {
      return DateTime.now();
    }
  }

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
    String? searchQuery,
    int? limit,
    int? offset,
    bool?
    includePartialReturns, // Special flag to load orders for partial returns detection
    bool?
    includeLateOrders, // Special flag to load late orders (active/pending_return with end_datetime < now)
  }) async {
    // Build query - apply all filters first, then ordering, then pagination
    dynamic query = _supabase
        .from('orders')
        .select(
          'id, invoice_number, branch_id, staff_id, customer_id, '
          'booking_date, start_date, end_date, start_datetime, end_datetime, '
          'status, total_amount, subtotal, gst_amount, late_fee, discount_amount, damage_fee_total, '
          'security_deposit_amount, security_deposit_collected, security_deposit_refunded, security_deposit_refunded_amount, security_deposit_refund_date, additional_amount_collected, deposit_balance, created_at, '
          'customer:customers(id, name, phone, customer_number), '
          'branch:branches(id, name), '
          'items:order_items(id, photo_url, product_name, quantity, price_per_day, days, line_total, return_status, actual_return_date, late_return, missing_note, returned_quantity, damage_fee, damage_description)',
        );

    // Apply filters
    if (branchId != null) {
      query = query.eq('branch_id', branchId);
    }

    if (status != null) {
      query = query.eq('status', status.value);
    } else if (includeLateOrders == true) {
      // For late orders: load orders with status IN ('active', 'pending_return')
      // AND end_datetime < now (or end_date < today if end_datetime is null)
      // This is server-side filtering to ensure all late orders are fetched with pagination
      final now = DateTime.now().toUtc().toIso8601String();
      query = query.or('status.eq.active,status.eq.pending_return');
      // Filter by end_datetime < now to get only late orders
      // Use end_datetime first, fallback to end_date for ordering
      query = query.lt('end_datetime', now);
    } else if (includePartialReturns == true) {
      // For partial returns: load orders with status IN ('partially_returned', 'active', 'pending_return')
      // This is server-side filtering to reduce data load
      query = query.or(
        'status.eq.partially_returned,status.eq.active,status.eq.pending_return',
      );
    }
    // If status is null and includePartialReturns/includeLateOrders is false/null, load all orders (for client-side filtering)

    if (startDate != null) {
      query = query.gte('created_at', startDate.toIso8601String());
    }

    if (endDate != null) {
      query = query.lte('created_at', endDate.toIso8601String());
    }

    // Apply search filter if provided
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      // First, find matching customers by name or phone
      List<String> customerIds = [];
      try {
        final customerQuery = _supabase
            .from('customers')
            .select('id')
            .or('name.ilike.%$searchQuery%,phone.ilike.%$searchQuery%');

        final customerResponse = await customerQuery;
        customerIds = (customerResponse as List)
            .map((json) => (json as Map<String, dynamic>)['id'] as String)
            .toList();
      } catch (e) {
        AppLogger.warning('Error searching customers for order search', e);
      }

      // Build OR filter: Invoice Number OR Customer ID Match
      // Use PostgREST filter syntax that works with Supabase Flutter
      if (customerIds.isNotEmpty) {
        // Build OR filter: invoice_number.ilike OR customer_id matches
        // Limit to first 50 customer IDs to avoid query length issues
        final limitedCustomerIds = customerIds.take(50).toList();
        final customerIdFilters = limitedCustomerIds
            .map((id) => 'customer_id.eq.$id')
            .join(',');
        // Use .or() with invoice_number search and customer_id filters
        query = query.or(
          'invoice_number.ilike.%$searchQuery%,$customerIdFilters',
        );
      } else {
        // No matching customers, only search by invoice number
        // This is the critical path for invoice number search
        query = query.ilike('invoice_number', '%$searchQuery%');
      }
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

  /// Get order statistics from server
  Future<Map<String, dynamic>> getOrderStats({
    String? branchId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // Build base query for all orders
      dynamic baseQuery = _supabase
          .from('orders')
          .select('id, status, end_date, end_datetime');

      if (branchId != null) {
        baseQuery = baseQuery.eq('branch_id', branchId);
      }

      if (startDate != null) {
        baseQuery = baseQuery.gte('created_at', startDate.toIso8601String());
      }

      if (endDate != null) {
        baseQuery = baseQuery.lte('created_at', endDate.toIso8601String());
      }

      final ordersResponse = await baseQuery;
      final orders = (ordersResponse as List).cast<Map<String, dynamic>>();

      // Calculate stats from server data
      int total = orders.length;
      int scheduled = 0;
      int ongoing = 0;
      int late = 0;
      int returned = 0;
      int partiallyReturned = 0;
      int cancelled = 0;

      final now = DateTime.now();

      for (final order in orders) {
        final statusStr = order['status'] as String?;
        if (statusStr == null) continue;

        // Parse status
        OrderStatus? status;
        try {
          status = OrderStatus.values.firstWhere(
            (s) => s.value == statusStr,
            orElse: () => OrderStatus.active,
          );
        } catch (e) {
          status = OrderStatus.active;
        }

        // Count by status
        if (status == OrderStatus.scheduled) {
          scheduled++;
        } else if (status == OrderStatus.active ||
            status == OrderStatus.pendingReturn) {
          // Check if late first
          bool isLate = false;
          final endDateStr =
              order['end_datetime'] as String? ?? order['end_date'] as String?;
          if (endDateStr != null) {
            try {
              final endDate = _parseDateTimeWithTimezone(endDateStr);
              if (now.isAfter(endDate)) {
                isLate = true;
                late++;
              }
            } catch (e) {
              // If date parsing fails, don't count as late
            }
          }

          // Only count as ongoing if NOT late
          if (!isLate) {
            ongoing++;
          }
        } else if (status == OrderStatus.completed ||
            status == OrderStatus.completedWithIssues ||
            status == OrderStatus.flagged) {
          returned++;
        } else if (status == OrderStatus.partiallyReturned) {
          partiallyReturned++;
        } else if (status == OrderStatus.cancelled) {
          cancelled++;
        }
      }

      // Note: late orders are excluded from ongoing count
      // Late orders are counted separately in the 'late' category

      return {
        'total': total,
        'scheduled': scheduled,
        'ongoing': ongoing,
        'late': late,
        'returned': returned,
        'partiallyReturned': partiallyReturned,
        'cancelled': cancelled,
      };
    } catch (e) {
      AppLogger.error('Error fetching order stats', e);
      return {
        'total': 0,
        'scheduled': 0,
        'ongoing': 0,
        'late': 0,
        'returned': 0,
        'partiallyReturned': 0,
        'cancelled': 0,
      };
    }
  }

  /// Get a single order by ID with full details
  Future<Order?> getOrder(String orderId) async {
    try {
      final response = await _supabase
          .from('orders')
          .select(
            'id, invoice_number, branch_id, staff_id, customer_id, '
            'booking_date, start_date, end_date, start_datetime, end_datetime, '
            'status, total_amount, subtotal, gst_amount, late_fee, discount_amount, damage_fee_total, '
            'security_deposit_amount, security_deposit_collected, security_deposit_refunded, security_deposit_refunded_amount, security_deposit_refund_date, additional_amount_collected, deposit_balance, created_at, '
            'customer:customers(*), '
            'staff:profiles(id, full_name, upi_id), '
            'branch:branches(*), '
            'items:order_items(id, photo_url, product_name, quantity, price_per_day, days, line_total, return_status, actual_return_date, late_return, missing_note, returned_quantity, damage_fee, damage_description)',
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
    final startDateOnly = DateTime(
      startDateParsed.year,
      startDateParsed.month,
      startDateParsed.day,
    );

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

    // Convert local times to UTC for database storage
    // Database stores times in UTC, so we need to convert local time to UTC
    final bookingDateUtc = DateTime.now().toUtc().toIso8601String();

    // Ensure start_datetime and end_datetime are in UTC
    String? startDatetimeUtc;
    String? endDatetimeUtc;

    if (startDatetime != null) {
      try {
        // Parse as local time, then convert to UTC
        final parsed = DateTime.parse(startDatetime);
        final localTime = parsed.isUtc ? parsed.toLocal() : parsed;
        startDatetimeUtc = localTime.toUtc().toIso8601String();
      } catch (e) {
        AppLogger.error('Error parsing start_datetime for UTC conversion', e);
        startDatetimeUtc = startDatetime; // Fallback to original
      }
    }

    if (endDatetime != null) {
      try {
        // Parse as local time, then convert to UTC
        final parsed = DateTime.parse(endDatetime);
        final localTime = parsed.isUtc ? parsed.toLocal() : parsed;
        endDatetimeUtc = localTime.toUtc().toIso8601String();
      } catch (e) {
        AppLogger.error('Error parsing end_datetime for UTC conversion', e);
        endDatetimeUtc = endDatetime; // Fallback to original
      }
    }

    final orderData = {
      'branch_id': branchId,
      'staff_id': staffId,
      'customer_id': customerId,
      'invoice_number': finalInvoiceNumber,
      'booking_date': bookingDateUtc, // Store as UTC
      'start_date': startDateOnlyStr,
      'end_date': endDateOnlyStr,
      'start_datetime': startDatetimeUtc, // Store as UTC
      'end_datetime': endDatetimeUtc, // Store as UTC
      'status': orderStatus.value, // Use calculated status
      'total_amount': totalAmount,
      'subtotal': subtotal,
      'gst_amount': gstAmount,
      // Insert security deposit amount (numeric) and collected flag (boolean)
      if (securityDeposit != null && securityDeposit > 0)
        'security_deposit_amount': securityDeposit,
      if (securityDeposit != null && securityDeposit > 0)
        'security_deposit_collected':
            true, // Boolean flag indicating deposit was collected
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
        'security_deposit_collected':
            true, // Boolean flag indicating deposit was collected
      // Note: security_deposit_refunded is a boolean flag, so we don't update it here
      // Note: security_deposit_refunded_amount and security_deposit_refund_date are set during refund process
    };

    // Add customer_id if provided
    if (customerId != null) {
      updateData['customer_id'] = customerId;
    }

    // Update order
    await _supabase.from('orders').update(updateData).eq('id', orderId);

    // DEBUG: Log items being sent to update
    print('🟠 updateOrder called for order: $orderId');
    print('🟠 Items count received: ${items.length}');

    // CRITICAL: First, remove duplicates from incoming items
    // This ensures we don't process duplicates
    print('🟠 Removing duplicates from incoming items...');
    final seenItemKeys = <String>{};
    final deduplicatedItems = <Map<String, dynamic>>[];

    for (final item in items) {
      final photoUrl = item['photo_url'] as String? ?? '';
      final productName = item['product_name'] as String? ?? '';
      final quantity = item['quantity'] as int? ?? 0;
      final pricePerDay = item['price_per_day'] as double? ?? 0.0;
      final days = item['days'] as int? ?? 0;
      final lineTotal = item['line_total'] as double? ?? 0.0;
      final key =
          '${photoUrl}_${productName}_${quantity}_${pricePerDay}_${days}_$lineTotal';

      if (!seenItemKeys.contains(key)) {
        seenItemKeys.add(key);
        deduplicatedItems.add(item);
      }
    }

    print('🟠 Items before deduplication: ${items.length}');
    print('🟠 Items after deduplication: ${deduplicatedItems.length}');

    // Use deduplicated items for the rest of the process
    final processedItems = deduplicatedItems;

    // CRITICAL: Use UPDATE/UPSERT approach instead of DELETE+INSERT
    // This avoids RLS policy issues with deletes
    print('🟠 Updating order items using upsert approach for order: $orderId');

    // Get existing items to compare
    final existingItemsResponse = await _supabase
        .from('order_items')
        .select(
          'id, photo_url, product_name, quantity, price_per_day, days, line_total',
        )
        .eq('order_id', orderId);
    final existingItems = (existingItemsResponse as List)
        .cast<Map<String, dynamic>>();
    final existingItemsCount = existingItems.length;
    print('🟠 Existing items count: $existingItemsCount');

    // Create maps for different lookup strategies
    // 1. Map by ID (for items that have IDs - most reliable)
    final existingItemsById = <String, Map<String, dynamic>>{};
    // 2. Map by composite key (for items without IDs or as fallback)
    final existingItemsByKey = <String, Map<String, dynamic>>{};

    for (final item in existingItems) {
      final itemId = item['id'] as String?;
      if (itemId != null && itemId.isNotEmpty) {
        existingItemsById[itemId] = item;
      }

      // Also index by composite key for fallback matching
      final photoUrl = item['photo_url'] as String? ?? '';
      final productName = item['product_name'] as String? ?? '';
      final quantity = item['quantity'] as int? ?? 0;
      final pricePerDay = (item['price_per_day'] as num?)?.toDouble() ?? 0.0;
      final days = item['days'] as int? ?? 0;
      final lineTotal = (item['line_total'] as num?)?.toDouble() ?? 0.0;
      final key =
          '${photoUrl}_${productName}_${quantity}_${pricePerDay}_${days}_$lineTotal';
      existingItemsByKey[key] = item;
    }

    // Process new items and determine what to do with each
    final itemsToUpdate = <Map<String, dynamic>>[];
    final itemsToInsert = <Map<String, dynamic>>[];
    final existingItemIdsToKeep = <String>{};
    final processedItemIds = <String>{};

    print('🟠 Processing ${processedItems.length} unique items...');
    for (final item in processedItems) {
      // CRITICAL: Check if item has an ID first (from frontend)
      // If it has an ID, try to match by ID (even if properties changed)
      final itemId = item['id'] as String?;
      Map<String, dynamic>? existingItem;
      String? matchedItemId;

      if (itemId != null &&
          itemId.isNotEmpty &&
          existingItemsById.containsKey(itemId)) {
        // Item has ID and exists in database - update it (even if properties changed)
        existingItem = existingItemsById[itemId];
        matchedItemId = itemId;
        print('🟢 Matching item by ID: $itemId');
      } else {
        // No ID or ID doesn't match - try matching by composite key
        final photoUrl = item['photo_url'] as String? ?? '';
        final productName = item['product_name'] as String? ?? '';
        final quantity = item['quantity'] as int? ?? 0;
        final pricePerDay = item['price_per_day'] as double? ?? 0.0;
        final days = item['days'] as int? ?? 0;
        final lineTotal = item['line_total'] as double? ?? 0.0;
        final key =
            '${photoUrl}_${productName}_${quantity}_${pricePerDay}_${days}_$lineTotal';

        if (existingItemsByKey.containsKey(key)) {
          existingItem = existingItemsByKey[key];
          matchedItemId = existingItem!['id'] as String?;
          print('🟢 Matching item by composite key: $key');
        }
      }

      if (existingItem != null &&
          matchedItemId != null &&
          matchedItemId.isNotEmpty) {
        // Item exists - update it
        if (!processedItemIds.contains(matchedItemId)) {
          existingItemIdsToKeep.add(matchedItemId);
          processedItemIds.add(matchedItemId);

          final photoUrl = item['photo_url'] as String? ?? '';
          final productName = item['product_name'] as String? ?? '';
          final quantity = item['quantity'] as int? ?? 0;
          final pricePerDay = item['price_per_day'] as double? ?? 0.0;
          final days = item['days'] as int? ?? 0;
          final lineTotal = item['line_total'] as double? ?? 0.0;

          final updateData = {
            'photo_url': photoUrl,
            'product_name': productName,
            'quantity': quantity,
            'price_per_day': pricePerDay,
            'days': days,
            'line_total': lineTotal,
          };

          try {
            await _supabase
                .from('order_items')
                .update(updateData)
                .eq('id', matchedItemId);
            itemsToUpdate.add(item);
            print('🟢 Updated item $matchedItemId');
          } catch (e) {
            print('🔴 Error updating item $matchedItemId: $e');
            // If update fails, try insert instead
            final itemData = Map<String, dynamic>.from(item);
            itemData.remove('id'); // Remove ID for new insert
            itemData['order_id'] = orderId;
            itemsToInsert.add(itemData);
          }
        } else {
          print(
            '🟡 Skipping duplicate item (already processed): $matchedItemId',
          );
        }
      } else {
        // New item - insert it
        final itemData = Map<String, dynamic>.from(item);
        itemData.remove('id'); // Remove ID for new insert
        itemData['order_id'] = orderId;
        itemsToInsert.add(itemData);
        print('🟢 New item to insert');
      }
    }

    print('🟠 Items to update: ${itemsToUpdate.length}');
    print('🟠 Items to insert: ${itemsToInsert.length}');

    // Insert new items
    if (itemsToInsert.isNotEmpty) {
      print('🟠 Inserting ${itemsToInsert.length} new items...');
      await _supabase.from('order_items').insert(itemsToInsert);
      print('🟢 New items inserted');
    }

    // Delete items that no longer exist in the new list
    final itemsToDelete = existingItems
        .where((item) => !existingItemIdsToKeep.contains(item['id'] as String))
        .map((item) => item['id'] as String)
        .toList();

    if (itemsToDelete.isNotEmpty) {
      print(
        '🟠 Deleting ${itemsToDelete.length} items that are no longer needed...',
      );
      print('🟠 Item IDs to delete: $itemsToDelete');

      // CRITICAL FIX: Use RPC function to bypass RLS policies
      // The delete_order_items function uses SECURITY DEFINER to bypass RLS
      try {
        final result = await _supabase.rpc(
          'delete_order_items',
          params: {'p_order_id': orderId, 'p_item_ids': itemsToDelete},
        );

        print('🟠 RPC delete_order_items result: $result');

        if (result != null && result['success'] == true) {
          print(
            '🟢 Successfully deleted ${result['deleted_count']} items via RPC',
          );
        } else {
          print('🔴 RPC delete failed: ${result?['error'] ?? 'Unknown error'}');

          // Fallback: Try direct delete (may fail due to RLS)
          print('🟡 Attempting fallback direct delete...');
          for (final itemId in itemsToDelete) {
            try {
              await _supabase
                  .from('order_items')
                  .delete()
                  .eq('id', itemId)
                  .eq('order_id', orderId);
              print('� Direct delete executed for item $itemId');
            } catch (e) {
              print('🔴 Direct delete failed for item $itemId: $e');
            }
          }
        }
      } catch (e) {
        print('🔴 RPC call failed: $e');
        print(
          '🟡 This likely means the RPC function is not yet created in Supabase',
        );
        print(
          '� Please run the SQL from supabase/migrations/supabase_delete_order_items.sql in Supabase SQL Editor',
        );

        // Fallback: Try direct delete (may fail due to RLS)
        for (final itemId in itemsToDelete) {
          try {
            await _supabase
                .from('order_items')
                .delete()
                .eq('id', itemId)
                .eq('order_id', orderId);
            print('🟡 Direct delete attempted for item $itemId');
          } catch (e2) {
            print('🔴 Direct delete also failed for item $itemId: $e2');
          }
        }
      }

      // Verify deletion worked by counting remaining items
      final remainingItems = await _supabase
          .from('order_items')
          .select('id')
          .eq('order_id', orderId)
          .inFilter('id', itemsToDelete);

      final remainingCount = (remainingItems as List).length;
      if (remainingCount == 0) {
        print('🟢 All ${itemsToDelete.length} items successfully deleted');
      } else {
        print(
          '🔴 DELETION FAILED: $remainingCount/${itemsToDelete.length} items still exist in database',
        );
        print(
          '🔴 Remaining item IDs: ${remainingItems.map((i) => i['id']).toList()}',
        );
        print(
          '🔴 Please run the SQL from supabase/migrations/supabase/migrations/supabase_delete_order_items.sql in Supabase SQL Editor',
        );
      }
    }

    // Verify final state
    await Future.delayed(const Duration(milliseconds: 200));
    final finalItems = await _supabase
        .from('order_items')
        .select('id')
        .eq('order_id', orderId);
    final finalItemsCount = (finalItems as List).length;
    print('🟠 Final items count: $finalItemsCount');
    print('🟠 Expected items count: ${processedItems.length}');

    if (finalItemsCount > processedItems.length) {
      print(
        '🟡 WARNING: More items than expected (some deletions may have failed due to RLS)',
      );
      print(
        '🟡 This is acceptable - the extra items will be cleaned up on next update',
      );
    } else if (finalItemsCount < processedItems.length) {
      print(
        '🟡 WARNING: Fewer items than expected - some inserts may have failed',
      );
    } else {
      print('🟢 SUCCESS: Item count matches expected count');
    }

    // Return updated order
    final updatedOrder = await getOrder(orderId);
    if (updatedOrder == null) {
      throw Exception('Failed to retrieve updated order');
    }

    if (updatedOrder.items != null) {
      print(
        '🟠 Final order items count from getOrder: ${updatedOrder.items!.length}',
      );
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
  /// Total calculation: Subtotal + GST + Damage Fees + Late Fee - Discount
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

      // Calculate base total: Subtotal + GST (if not included)
      final baseTotal = currentOrder.subtotal ?? 0.0;
      final gstAmount = currentOrder.gstAmount ?? 0.0;
      final gstIncluded = currentOrder.staff?.gstIncluded ?? false;
      final baseWithGst = gstIncluded ? baseTotal : baseTotal + gstAmount;

      // Add damage fees, late fee, and subtract discount
      final damageFees = currentOrder.damageFeeTotal ?? 0.0;
      final discount = currentOrder.discountAmount ?? 0.0;
      final newTotal = baseWithGst + damageFees + lateFee - discount;

      await _supabase
          .from('orders')
          .update({'late_fee': lateFee, 'total_amount': newTotal})
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

  /// Update discount for an order
  /// Total calculation: Subtotal + GST + Damage Fees + Late Fee - Discount
  Future<Order> updateDiscount({
    required String orderId,
    required double discount,
  }) async {
    try {
      // Get current order to calculate new total
      final currentOrder = await getOrder(orderId);
      if (currentOrder == null) {
        throw Exception('Order not found');
      }

      // Calculate base total: Subtotal + GST (if not included)
      final baseTotal = currentOrder.subtotal ?? 0.0;
      final gstAmount = currentOrder.gstAmount ?? 0.0;
      final gstIncluded = currentOrder.staff?.gstIncluded ?? false;
      final baseWithGst = gstIncluded ? baseTotal : baseTotal + gstAmount;

      // Add damage fees, late fee, and subtract discount
      final damageFees = currentOrder.damageFeeTotal ?? 0.0;
      final lateFee = currentOrder.lateFee ?? 0.0;
      final newTotal = baseWithGst + damageFees + lateFee - discount;

      await _supabase
          .from('orders')
          .update({'discount_amount': discount, 'total_amount': newTotal})
          .eq('id', orderId);

      final updatedOrder = await getOrder(orderId);
      if (updatedOrder == null) {
        throw Exception('Failed to retrieve updated order');
      }
      return updatedOrder;
    } catch (e) {
      AppLogger.error('Error updating discount', e);
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
            'deposit_balance, security_deposit_amount, security_deposit_refunded_amount',
          )
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
      final alreadyRefunded =
          (orderResponse['security_deposit_refunded_amount'] as num?)
              ?.toDouble() ??
          0.0;

      // Fallback balance = deposit - already refunded
      final fallbackBalance = (depositAmount - alreadyRefunded).clamp(
        0.0,
        double.infinity,
      );

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

      final updatedBalance =
          (updatedOrderResponse['deposit_balance'] as num?)?.toDouble() ?? 0.0;
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
      final currentAdditionalCollected =
          currentOrder.additionalAmountCollected ?? 0.0;

      // Calculate current outstanding amount
      // Outstanding = (Rental + GST + Damage + Late Fee) - Security Deposit - Additional Amount Collected
      final rentalAmount = currentOrder.subtotal ?? 0.0;
      final gstAmount = currentOrder.gstAmount ?? 0.0;
      final damageFees = currentOrder.damageFeeTotal ?? 0.0;
      final lateFee = currentOrder.lateFee ?? 0.0;
      final totalCharges = rentalAmount + gstAmount + damageFees + lateFee;
      final currentOutstanding =
          (totalCharges - currentSecurityDeposit - currentAdditionalCollected)
              .clamp(0.0, double.infinity);

      // Validate: cannot collect more than outstanding (with small tolerance for floating-point precision)
      // Round to 2 decimal places to avoid floating-point precision issues
      final roundedAmount = (amount * 100).round() / 100;
      final roundedOutstanding = (currentOutstanding * 100).round() / 100;

      if (roundedAmount > roundedOutstanding + 0.01) {
        // Allow 0.01 tolerance
        throw Exception(
          'Cannot collect more than outstanding amount: ₹${currentOutstanding.toStringAsFixed(2)}',
        );
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
  /// Matches website logic: saves late fee and discount together with item returns
  Future<Map<String, dynamic>> processOrderReturn({
    required String orderId,
    required List<ItemReturn> itemReturns,
    required String userId,
    double lateFee = 0,
    double? discount,
  }) async {
    try {
      // Get current order to calculate new total
      final currentOrder = await getOrder(orderId);
      if (currentOrder == null) {
        throw Exception('Order not found');
      }

      // Update items in parallel (like website)
      if (itemReturns.isNotEmpty) {
        final itemUpdatePromises = itemReturns.map((itemReturn) {
          final itemUpdate = <String, dynamic>{
            'return_status': itemReturn.returnStatus,
          };

          if (itemReturn.returnedQuantity != null) {
            itemUpdate['returned_quantity'] = itemReturn.returnedQuantity;
          }
          if (itemReturn.actualReturnDate != null) {
            itemUpdate['actual_return_date'] = itemReturn.actualReturnDate!
                .toIso8601String();
          }
          if (itemReturn.damageCost != null) {
            itemUpdate['damage_fee'] = itemReturn.damageCost;
          }
          // Store damage description in damage_description field (matching website schema)
          if (itemReturn.description != null &&
              itemReturn.description!.trim().isNotEmpty) {
            itemUpdate['damage_description'] = itemReturn.description!.trim();
          } else {
            // Clear damage_description if empty
            itemUpdate['damage_description'] = null;
          }
          // missing_note is separate - only for missing items
          if (itemReturn.missingNote != null &&
              itemReturn.missingNote!.trim().isNotEmpty) {
            itemUpdate['missing_note'] = itemReturn.missingNote!.trim();
          }

          return _supabase
              .from('order_items')
              .update(itemUpdate)
              .eq('id', itemReturn.itemId);
        });

        // Wait for all item updates to complete
        // Supabase will throw an exception if there's an error, so we don't need to check status
        await Future.wait(itemUpdatePromises);
      }

      // Calculate damage fee total from all items in database (matching website logic)
      // This ensures we get the complete total, not just from items being processed
      final allItemsResponse = await _supabase
          .from('order_items')
          .select('damage_fee')
          .eq('order_id', orderId);

      final calcDamageFeeTotal = (allItemsResponse as List)
          .map((item) => (item['damage_fee'] as num?)?.toDouble() ?? 0.0)
          .fold<double>(0.0, (sum, cost) => sum + cost);

      // Determine new order status based on item returns being processed
      // Matching website logic: determineOrderStatusFromReturns
      // Fetch updated order to check current item state after updates
      OrderStatus? newStatus;
      final updatedOrderForStatus = await getOrder(orderId);

      if (updatedOrderForStatus != null) {
        final allItems = updatedOrderForStatus.items ?? [];

        if (allItems.isNotEmpty) {
          // Check if all items are fully returned
          final allReturned = allItems.every((item) {
            final returnedQty = item.returnedQuantity ?? 0;
            return item.returnStatus == ReturnStatus.returned &&
                returnedQty == item.quantity;
          });

          // Check for missing items (return_status = 'missing')
          final hasMissing = allItems.any(
            (item) => item.returnStatus == ReturnStatus.missing,
          );

          // Check for items not yet returned
          final hasNotReturned = allItems.any((item) {
            final returnedQty = item.returnedQuantity ?? 0;
            return (item.returnStatus == null ||
                    item.returnStatus == ReturnStatus.notYetReturned) &&
                returnedQty == 0;
          });

          // Check for partial returns (returnedQuantity > 0 AND returnedQuantity < quantity)
          final hasPartialReturns = allItems.any((item) {
            final returnedQty = item.returnedQuantity ?? 0;
            return returnedQty > 0 && returnedQty < item.quantity;
          });

          // Check for damage (damage_fee > 0 OR damage_description exists)
          final hasDamage =
              calcDamageFeeTotal > 0 ||
              allItems.any(
                (item) =>
                    (item.damageCost != null && item.damageCost! > 0) ||
                    (item.damageDescription != null &&
                        item.damageDescription!.trim().isNotEmpty),
              );

          // Priority 1: All items fully returned, no damage, no missing, no partial returns → completed
          if (allReturned && !hasPartialReturns && !hasDamage && !hasMissing) {
            newStatus = OrderStatus.completed;
          }
          // Priority 2: Any damage OR partial returns OR missing items → flagged
          else if (hasDamage || hasPartialReturns || hasMissing) {
            newStatus = OrderStatus.flagged;
          }
          // Priority 3: Some items returned but no damage and no missing → partially_returned
          else if (!hasNotReturned && !allReturned) {
            newStatus = OrderStatus.partiallyReturned;
          }
          // Priority 4: No items returned yet → keep current status (don't update)
        }
      }

      // Calculate base total: Subtotal + GST (if not included)
      final baseTotal = currentOrder.subtotal ?? 0.0;
      final gstAmount = currentOrder.gstAmount ?? 0.0;
      final gstIncluded = currentOrder.staff?.gstIncluded ?? false;
      final baseWithGst = gstIncluded ? baseTotal : baseTotal + gstAmount;

      // Add damage fees, late fee, and subtract discount
      final discountAmount = discount ?? 0.0;
      final newTotal =
          baseWithGst + calcDamageFeeTotal + lateFee - discountAmount;

      // Update order with late fee, discount, damage fees, new total, and status (matching website logic)
      final orderUpdate = <String, dynamic>{'total_amount': newTotal};

      // Update status if determined
      OrderStatus? statusToSet = newStatus;
      if (statusToSet != null) {
        orderUpdate['status'] = statusToSet.value;
      }

      // Always update damage_fee_total (even if 0) to match website logic
      orderUpdate['damage_fee_total'] = calcDamageFeeTotal;
      if (lateFee > 0 || currentOrder.lateFee != null) {
        orderUpdate['late_fee'] = lateFee;
      }
      if (discount != null && discount > 0) {
        orderUpdate['discount_amount'] = discount;
      } else if (discount != null &&
          discount == 0 &&
          currentOrder.discountAmount != null) {
        // Clear discount if explicitly set to 0
        orderUpdate['discount_amount'] = 0;
      }

      // Try to update the order
      // If status constraint fails (e.g., completed_with_issues not allowed), fallback to completed
      dynamic orderUpdateResult;
      try {
        orderUpdateResult = await _supabase
            .from('orders')
            .update(orderUpdate)
            .eq('id', orderId)
            .select()
            .single();
      } on PostgrestException catch (statusError) {
        // If status constraint error (code 23514), retry with completed status
        final isConstraintError =
            statusError.code == '23514' ||
            statusError.message.contains('orders_status_check') ||
            statusError.message.contains('check constraint');

        if (isConstraintError && statusToSet != null) {
          AppLogger.warning(
            'Status ${statusToSet.value} not allowed by database constraint, falling back to completed',
          );
          // Use completed status instead
          orderUpdate['status'] = OrderStatus.completed.value;
          try {
            orderUpdateResult = await _supabase
                .from('orders')
                .update(orderUpdate)
                .eq('id', orderId)
                .select()
                .single();
          } catch (retryError) {
            AppLogger.error(
              'Failed to update order with completed status',
              retryError,
            );
            rethrow;
          }
        } else {
          // Re-throw if it's a different error
          rethrow;
        }
      } catch (e) {
        // Re-throw any other exceptions
        rethrow;
      }

      if (orderUpdateResult.isEmpty) {
        throw Exception('Failed to update order');
      }

      return {'success': true, 'data': orderUpdateResult};
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
          'status, total_amount, subtotal, gst_amount, late_fee, discount_amount, damage_fee_total, '
          'security_deposit_amount, security_deposit_collected, security_deposit_refunded, security_deposit_refunded_amount, security_deposit_refund_date, additional_amount_collected, deposit_balance, created_at, '
          'customer:customers(*), '
          'branch:branches(*), '
          'staff:profiles(id, full_name, upi_id), '
          'items:order_items(id, photo_url, product_name, quantity, price_per_day, days, line_total, return_status, actual_return_date, late_return, missing_note, returned_quantity, damage_fee, damage_description)',
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
        final dateA = _parseDateTimeWithTimezone(a['created_at'] as String);
        final dateB = _parseDateTimeWithTimezone(b['created_at'] as String);
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
          .update({'quantity': quantity, 'line_total': newLineTotal})
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

      final previousGstAmount =
          (orderResponse['gst_amount'] as num?)?.toDouble() ?? 0.0;
      final previousSubtotal =
          subtotal - previousGstAmount; // Approximate previous subtotal

      // Calculate GST if it was applied before (maintain same rate)
      double gstAmount = 0.0;
      if (previousGstAmount > 0 && previousSubtotal > 0) {
        final gstRate = (previousGstAmount / previousSubtotal) * 100;
        gstAmount = subtotal * (gstRate / 100);
      }

      final lateFee = (orderResponse['late_fee'] as num?)?.toDouble() ?? 0.0;
      final damageFeeTotal =
          (orderResponse['damage_fee_total'] as num?)?.toDouble() ?? 0.0;
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

      // Store damage description in damage_description field (matching website schema)
      if (damageDescription != null && damageDescription.trim().isNotEmpty) {
        updateData['damage_description'] = damageDescription.trim();
      } else {
        // Clear damage_description if empty
        updateData['damage_description'] = null;
      }

      await _supabase.from('order_items').update(updateData).eq('id', itemId);

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
