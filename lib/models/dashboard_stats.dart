/// Dashboard Statistics Model
/// 
/// Represents aggregated statistics for the dashboard
class DashboardStats {
  final int active;
  final int pendingReturn;
  final double todayCollection;
  final int completed;
  final int scheduled;
  final int partiallyReturned;
  final int totalOrders;
  final int totalCustomers;
  final int lateReturn;

  DashboardStats({
    required this.active,
    required this.pendingReturn,
    required this.todayCollection,
    required this.completed,
    this.scheduled = 0,
    this.partiallyReturned = 0,
    this.totalOrders = 0,
    this.totalCustomers = 0,
    this.lateReturn = 0,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      active: json['active'] as int? ?? 0,
      pendingReturn: json['pending_return'] as int? ?? 0,
      todayCollection: (json['today_collection'] as num?)?.toDouble() ?? 0.0,
      completed: json['completed'] as int? ?? 0,
      scheduled: json['scheduled'] as int? ?? 0,
      partiallyReturned: json['partially_returned'] as int? ?? 0,
      totalOrders: json['total_orders'] as int? ?? 0,
      totalCustomers: json['total_customers'] as int? ?? 0,
      lateReturn: json['late_return'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'active': active,
      'pending_return': pendingReturn,
      'today_collection': todayCollection,
      'completed': completed,
      'scheduled': scheduled,
      'partially_returned': partiallyReturned,
      'total_orders': totalOrders,
      'total_customers': totalCustomers,
      'late_return': lateReturn,
    };
  }
}

