import '../core/supabase_client.dart';
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
      // Base query for orders
      dynamic baseQuery = _supabase
          .from('orders')
          .select('status, total_amount');

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

      if (ordersResponse == null || ordersResponse is! List) {
        return DashboardStats(
          active: 0,
          pendingReturn: 0,
          todayCollection: 0.0,
          completed: 0,
        );
      }

      int activeCount = 0;
      int pendingCount = 0;
      int completedCount = 0;
      double collection = 0.0;

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
          default:
            break;
        }
      }

      return DashboardStats(
        active: activeCount,
        pendingReturn: pendingCount,
        todayCollection: collection,
        completed: completedCount,
      );
    } catch (e) {
      print('Error fetching dashboard stats: $e');
      return DashboardStats(
        active: 0,
        pendingReturn: 0,
        todayCollection: 0.0,
        completed: 0,
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

      return DashboardStats(
        active: activeCount,
        pendingReturn: pendingCount,
        todayCollection: todayCollection,
        completed: completedCount,
      );
    } catch (e) {
      print('Error fetching dashboard stats: $e');
      return DashboardStats(
        active: 0,
        pendingReturn: 0,
        todayCollection: 0.0,
        completed: 0,
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
        print('Recent orders query returned null');
        return [];
      }

      if (response is! List) {
        print('Recent orders query returned non-list: ${response.runtimeType}');
        return [];
      }

      final orders = response
          .map((json) {
            try {
              if (json is! Map<String, dynamic>) {
                print('Order item is not a map: ${json.runtimeType}');
                return null;
              }
              return Order.fromJson(json);
            } catch (e) {
              print('Error parsing order: $e');
              print('Order JSON: $json');
              return null;
            }
          })
          .whereType<Order>()
          .toList();

      print('Successfully fetched ${orders.length} recent orders');
      return orders;
    } catch (e, stackTrace) {
      print('Error fetching recent orders: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }
}
