/// Dashboard Statistics Model
/// 
/// Represents aggregated statistics for the dashboard
class DashboardStats {
  final int active;
  final int pendingReturn;
  final double todayCollection;
  final int completed;

  DashboardStats({
    required this.active,
    required this.pendingReturn,
    required this.todayCollection,
    required this.completed,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      active: json['active'] as int? ?? 0,
      pendingReturn: json['pending_return'] as int? ?? 0,
      todayCollection: (json['today_collection'] as num?)?.toDouble() ?? 0.0,
      completed: json['completed'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'active': active,
      'pending_return': pendingReturn,
      'today_collection': todayCollection,
      'completed': completed,
    };
  }
}

