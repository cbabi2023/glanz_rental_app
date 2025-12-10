import '../core/supabase_client.dart';
import '../core/logger.dart';
import '../models/dashboard_stats.dart';
import '../models/order.dart';

/// Dashboard Service
///
/// Handles dashboard statistics and analytics
class DashboardService {
  final _supabase = SupabaseService.client;

  /// Get dashboard statistics for a branch and date range
  ///
  /// If [startDate] and [endDate] are null, all time is used (no date filter).
  Future<DashboardStats> getDashboardStats({
    String? branchId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // Base query for orders - need end_date/end_datetime for late calculation
      dynamic baseQuery = _supabase
          .from('orders')
          .select('status, total_amount, end_date, end_datetime');

      // Apply date range filter only when provided
      if (startDate != null && endDate != null) {
        final effectiveStart = DateTime(
          startDate.year,
          startDate.month,
          startDate.day,
        );
        final effectiveEnd = DateTime(
          endDate.year,
          endDate.month,
          endDate.day,
          23,
          59,
          59,
          999,
        );

        baseQuery = baseQuery
            .gte('created_at', effectiveStart.toIso8601String())
            .lte('created_at', effectiveEnd.toIso8601String());
      }

      if (branchId != null) {
        baseQuery = baseQuery.eq('branch_id', branchId);
      }

      final ordersResponse = await baseQuery;
      
      // Get total orders count
      int totalOrdersCount = ordersResponse is List ? ordersResponse.length : 0;
      
      // Get total customers count (all customers, not filtered by branch)
      int totalCustomersCount = 0;
      try {
        final customersResponse = await _supabase.from('customers').select('id');
        totalCustomersCount = (customersResponse as List).length;
      } catch (e) {
        AppLogger.error('Error fetching customers count', e);
      }

      if (ordersResponse == null || ordersResponse is! List) {
        return DashboardStats(
          active: 0,
          pendingReturn: 0,
          todayCollection: 0.0,
          completed: 0,
          scheduled: 0,
          partiallyReturned: 0,
          totalOrders: 0,
          totalCustomers: 0,
          lateReturn: 0,
        );
      }

      int activeCount = 0;
      int pendingCount = 0;
      int completedCount = 0;
      int scheduledCount = 0;
      int partiallyReturnedCount = 0;
      int lateReturnCount = 0;
      double collection = 0.0;
      final now = DateTime.now();

      for (final raw in ordersResponse) {
        final map = raw as Map<String, dynamic>;
        final status = map['status'] as String?;
        final amount = (map['total_amount'] as num?)?.toDouble() ?? 0.0;

        switch (status) {
          case 'active':
            activeCount++;
            break;
          case 'pending_return':
            pendingCount++;
            break;
          case 'completed':
            completedCount++;
            collection += amount;
            break;
          case 'scheduled':
            scheduledCount++;
            break;
          case 'partially_returned':
            partiallyReturnedCount++;
            break;
          default:
            break;
        }
        
        // Check if order is late (past end date but not completed/cancelled/partially returned)
        if (status != 'completed' && status != 'cancelled' && status != 'partially_returned') {
          try {
            final endStr = map['end_datetime']?.toString() ?? map['end_date']?.toString();
            if (endStr != null && endStr.isNotEmpty) {
              final endDate = DateTime.parse(endStr);
              if (now.isAfter(endDate)) {
                lateReturnCount++;
              }
            }
          } catch (e) {
            // Skip if date parsing fails
          }
        }
      }

      return DashboardStats(
        active: activeCount,
        pendingReturn: pendingCount,
        todayCollection: collection,
        completed: completedCount,
        scheduled: scheduledCount,
        partiallyReturned: partiallyReturnedCount,
        totalOrders: totalOrdersCount,
        totalCustomers: totalCustomersCount,
        lateReturn: lateReturnCount,
      );
    } catch (e) {
      AppLogger.error('Error fetching dashboard stats', e);
        return DashboardStats(
          active: 0,
          pendingReturn: 0,
          todayCollection: 0.0,
          completed: 0,
          scheduled: 0,
          partiallyReturned: 0,
          totalOrders: 0,
          totalCustomers: 0,
          lateReturn: 0,
        );
    }
  }

  /// Legacy method kept for compatibility (defaults to today's stats)
  Future<DashboardStats> getDashboardStatsForToday({String? branchId}) async {
    try {
      // Get active orders count
      var activeQuery = _supabase
          .from('orders')
          .select('id')
          .eq('status', 'active');

      if (branchId != null) {
        activeQuery = activeQuery.eq('branch_id', branchId);
      }

      final activeResponse = await activeQuery;
      final activeCount = activeResponse.length;

      // Get pending return orders count
      var pendingQuery = _supabase
          .from('orders')
          .select('id')
          .eq('status', 'pending_return');

      if (branchId != null) {
        pendingQuery = pendingQuery.eq('branch_id', branchId);
      }

      final pendingResponse = await pendingQuery;
      final pendingCount = pendingResponse.length;

      // Get completed orders count
      var completedQuery = _supabase
          .from('orders')
          .select('id')
          .eq('status', 'completed');

      if (branchId != null) {
        completedQuery = completedQuery.eq('branch_id', branchId);
      }

      final completedResponse = await completedQuery;
      final completedCount = completedResponse.length;

      // Get today's collection (sum of completed orders today)
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      var todayCollectionQuery = _supabase
          .from('orders')
          .select('total_amount')
          .eq('status', 'completed')
          .gte('created_at', startOfDay.toIso8601String())
          .lt('created_at', endOfDay.toIso8601String());

      if (branchId != null) {
        todayCollectionQuery = todayCollectionQuery.eq('branch_id', branchId);
      }

      final todayOrders = await todayCollectionQuery;
      double todayCollection = 0.0;
      for (final order in todayOrders) {
        todayCollection += (order['total_amount'] as num?)?.toDouble() ?? 0.0;
      }

      // Also get scheduled and partially returned counts
      var scheduledQuery = _supabase
          .from('orders')
          .select('id')
          .eq('status', 'scheduled');

      if (branchId != null) {
        scheduledQuery = scheduledQuery.eq('branch_id', branchId);
      }

      final scheduledResponse = await scheduledQuery;
      final scheduledCount = scheduledResponse.length;

      var partiallyReturnedQuery = _supabase
          .from('orders')
          .select('id')
          .eq('status', 'partially_returned');

      if (branchId != null) {
        partiallyReturnedQuery = partiallyReturnedQuery.eq('branch_id', branchId);
      }

      final partiallyReturnedResponse = await partiallyReturnedQuery;
      final partiallyReturnedCount = partiallyReturnedResponse.length;

      // Get total orders and customers counts
      int totalOrdersCount = 0;
      int totalCustomersCount = 0;
      try {
        final allOrdersResponse = await _supabase.from('orders').select('id');
        totalOrdersCount = (allOrdersResponse as List).length;
        
        final allCustomersResponse = await _supabase.from('customers').select('id');
        totalCustomersCount = (allCustomersResponse as List).length;
      } catch (e) {
        AppLogger.error('Error fetching total counts', e);
      }

      return DashboardStats(
        active: activeCount,
        pendingReturn: pendingCount,
        todayCollection: todayCollection,
        completed: completedCount,
        scheduled: scheduledCount,
        partiallyReturned: partiallyReturnedCount,
        totalOrders: totalOrdersCount,
        totalCustomers: totalCustomersCount,
        lateReturn: 0, // Late return requires date checking, skip in legacy method
      );
    } catch (e) {
      AppLogger.error('Error fetching dashboard stats', e);
      return DashboardStats(
        active: 0,
        pendingReturn: 0,
        todayCollection: 0.0,
        completed: 0,
        scheduled: 0,
        partiallyReturned: 0,
        totalOrders: 0,
        totalCustomers: 0,
        lateReturn: 0,
      );
    }
  }

  /// Get recent orders for dashboard (limit 10)
  Future<List<Order>> getRecentOrders({
    String? branchId,
    int limit = 10,
  }) async {
    try {
      // Build base query
      dynamic query = _supabase
          .from('orders')
          .select(
            'id, invoice_number, branch_id, staff_id, customer_id, '
            'start_date, end_date, start_datetime, end_datetime, '
            'status, total_amount, subtotal, gst_amount, late_fee, created_at, '
            'customer:customers(id, name, phone, customer_number), '
            'branch:branches(id, name)',
          );

      // Apply branch filter first (if provided)
      if (branchId != null) {
        query = query.eq('branch_id', branchId);
      }

      // Then apply ordering and limit
      query = query.order('created_at', ascending: false).limit(limit);

      final response = await query;

      if (response == null) {
        AppLogger.warning('Recent orders query returned null');
        return [];
      }

      if (response is! List) {
        AppLogger.warning('Recent orders query returned non-list: ${response.runtimeType}');
        return [];
      }

      final orders = response
          .map((json) {
            try {
              if (json is! Map<String, dynamic>) {
                AppLogger.warning('Order item is not a map: ${json.runtimeType}');
                return null;
              }
              return Order.fromJson(json);
            } catch (e) {
              AppLogger.error('Error parsing order', e);
              AppLogger.debug('Order JSON: $json');
              return null;
            }
          })
          .whereType<Order>()
          .toList();

      AppLogger.success('Successfully fetched ${orders.length} recent orders');
      return orders;
    } catch (e, stackTrace) {
      AppLogger.error('Error fetching recent orders', e, stackTrace);
      return [];
    }
  }
}
