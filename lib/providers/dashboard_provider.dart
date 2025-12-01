import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/dashboard_service.dart';
import '../models/dashboard_stats.dart';
import '../models/order.dart';

/// Dashboard Stats Parameters
///
/// Includes branch and optional date range for filtering
class DashboardStatsParams {
  final String? branchId;
  final DateTime? startDate;
  final DateTime? endDate;

  const DashboardStatsParams({
    this.branchId,
    this.startDate,
    this.endDate,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DashboardStatsParams &&
        other.branchId == branchId &&
        other.startDate == startDate &&
        other.endDate == endDate;
  }

  @override
  int get hashCode => Object.hash(branchId, startDate, endDate);
}

/// Dashboard Service Provider
final dashboardServiceProvider = Provider<DashboardService>((ref) {
  return DashboardService();
});

/// Dashboard Stats Provider
///
/// Fetches dashboard statistics for a branch and optional date range
final dashboardStatsProvider =
    FutureProvider.family<DashboardStats, DashboardStatsParams>(
  (ref, params) async {
    final service = ref.watch(dashboardServiceProvider);
    return await service.getDashboardStats(
      branchId: params.branchId,
      startDate: params.startDate,
      endDate: params.endDate,
    );
  },
);

/// Recent Orders Provider
/// 
/// Fetches recent orders for dashboard (limit 10)
final recentOrdersProvider = FutureProvider.family<List<Order>, String?>(
  (ref, branchId) async {
    final service = ref.watch(dashboardServiceProvider);
    return await service.getRecentOrders(branchId: branchId, limit: 10);
  },
);

