import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../models/order.dart';

/// Dashboard Screen
///
/// Modern, attractive dashboard with statistics, filters, and recent activity
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

enum _DashboardFilter {
  today,
  yesterday,
  thisWeek,
  thisMonth,
  last7Days,
  allTime,
  custom,
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  _DashboardFilter _selectedFilter = _DashboardFilter.today;
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  DateTime _startForFilter(_DashboardFilter filter) {
    final now = DateTime.now();
    switch (filter) {
      case _DashboardFilter.today:
        return DateTime(now.year, now.month, now.day);
      case _DashboardFilter.yesterday:
        final yesterday = now.subtract(const Duration(days: 1));
        return DateTime(yesterday.year, yesterday.month, yesterday.day);
      case _DashboardFilter.thisWeek:
        // Start of week (Monday)
        final weekday = now.weekday;
        final daysFromMonday = weekday == 7 ? 0 : weekday - 1;
        final startOfWeek = now.subtract(Duration(days: daysFromMonday));
        return DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
      case _DashboardFilter.thisMonth:
        return DateTime(now.year, now.month, 1);
      case _DashboardFilter.last7Days:
        final start = now.subtract(const Duration(days: 6));
        return DateTime(start.year, start.month, start.day);
      case _DashboardFilter.allTime:
        // Not used (handled by null dates), fallback to a wide range start
        return DateTime(2020, 1, 1);
      case _DashboardFilter.custom:
        return _customStartDate ?? DateTime(now.year, now.month, now.day);
    }
  }

  DateTime _endForFilter(_DashboardFilter filter) {
    final now = DateTime.now();
    switch (filter) {
      case _DashboardFilter.today:
        return DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
      case _DashboardFilter.yesterday:
        final yesterday = now.subtract(const Duration(days: 1));
        return DateTime(
          yesterday.year,
          yesterday.month,
          yesterday.day,
          23,
          59,
          59,
          999,
        );
      case _DashboardFilter.thisWeek:
      case _DashboardFilter.thisMonth:
      case _DashboardFilter.last7Days:
        return DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
      case _DashboardFilter.allTime:
        // Not used (handled by null dates), fallback to now
        return DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
      case _DashboardFilter.custom:
        return _customEndDate ??
            DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    }
  }

  Future<void> _showCustomDatePicker() async {
    final now = DateTime.now();
    final initialStart =
        _customStartDate ?? now.subtract(const Duration(days: 6));
    final initialEnd = _customEndDate ?? now;

    final pickedStart = await showDatePicker(
      context: context,
      initialDate: initialStart,
      firstDate: DateTime(2020),
      lastDate: now,
      helpText: 'Select Start Date',
    );

    if (pickedStart == null) return;

    final pickedEnd = await showDatePicker(
      context: context,
      initialDate: initialEnd.isBefore(pickedStart) ? pickedStart : initialEnd,
      firstDate: pickedStart,
      lastDate: now,
      helpText: 'Select End Date',
    );

    if (pickedEnd != null) {
      setState(() {
        _customStartDate = DateTime(
          pickedStart.year,
          pickedStart.month,
          pickedStart.day,
        );
        _customEndDate = DateTime(
          pickedEnd.year,
          pickedEnd.month,
          pickedEnd.day,
          23,
          59,
          59,
          999,
        );
        _selectedFilter = _DashboardFilter.custom;
      });
    }
  }

  String _getFilterLabel(_DashboardFilter filter) {
    switch (filter) {
      case _DashboardFilter.today:
        return 'Today';
      case _DashboardFilter.yesterday:
        return 'Yesterday';
      case _DashboardFilter.thisWeek:
        return 'This Week';
      case _DashboardFilter.thisMonth:
        return 'This Month';
      case _DashboardFilter.last7Days:
        return 'Last 7 Days';
      case _DashboardFilter.allTime:
        return 'All Time';
      case _DashboardFilter.custom:
        if (_customStartDate != null && _customEndDate != null) {
          final startFormat = DateFormat('dd MMM').format(_customStartDate!);
          final endFormat = DateFormat('dd MMM yyyy').format(_customEndDate!);
          return '$startFormat - $endFormat';
        }
        return 'Custom';
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProfile = ref.watch(userProfileProvider);
    final branchId = userProfile.value?.branchId;

    final DateTime? startDate = _selectedFilter == _DashboardFilter.allTime
        ? null
        : _startForFilter(_selectedFilter);
    final DateTime? endDate = _selectedFilter == _DashboardFilter.allTime
        ? null
        : _endForFilter(_selectedFilter);

    final statsParams = DashboardStatsParams(
      branchId: branchId,
      startDate: startDate,
      endDate: endDate,
    );

    final dashboardStats = ref.watch(dashboardStatsProvider(statsParams));
    final recentOrders = ref.watch(recentOrdersProvider(branchId));

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Dashboard',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F1724),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline, color: Color(0xFF0F1724)),
            onPressed: () => context.push('/profile'),
            tooltip: 'Profile',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardStatsProvider(statsParams));
          ref.invalidate(recentOrdersProvider(branchId));
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'All Time',
                      selected: _selectedFilter == _DashboardFilter.allTime,
                      onSelected: () {
                        setState(() {
                          _selectedFilter = _DashboardFilter.allTime;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Today',
                      selected: _selectedFilter == _DashboardFilter.today,
                      onSelected: () {
                        setState(() {
                          _selectedFilter = _DashboardFilter.today;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Yesterday',
                      selected: _selectedFilter == _DashboardFilter.yesterday,
                      onSelected: () {
                        setState(() {
                          _selectedFilter = _DashboardFilter.yesterday;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'This Week',
                      selected: _selectedFilter == _DashboardFilter.thisWeek,
                      onSelected: () {
                        setState(() {
                          _selectedFilter = _DashboardFilter.thisWeek;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'This Month',
                      selected: _selectedFilter == _DashboardFilter.thisMonth,
                      onSelected: () {
                        setState(() {
                          _selectedFilter = _DashboardFilter.thisMonth;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Last 7 Days',
                      selected: _selectedFilter == _DashboardFilter.last7Days,
                      onSelected: () {
                        setState(() {
                          _selectedFilter = _DashboardFilter.last7Days;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: _getFilterLabel(_DashboardFilter.custom),
                      selected: _selectedFilter == _DashboardFilter.custom,
                      onSelected: _showCustomDatePicker,
                      isCustom: true,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Statistics Cards
              dashboardStats.when(
                data: (stats) => GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.3,
                  children: [
                    _ModernStatCard(
                      title: 'Active Orders',
                      value: stats.active.toString(),
                      icon: Icons.shopping_bag_outlined,
                      borderColor: Colors.green,
                      iconColor: Colors.green,
                      bgColor: Colors.white,
                    ),
                    _ModernStatCard(
                      title: 'Pending Return',
                      value: stats.pendingReturn.toString(),
                      icon: Icons.warning_amber_rounded,
                      borderColor: Colors.red,
                      iconColor: Colors.red,
                      bgColor: Colors.red.shade50,
                      textColor: Colors.red.shade700,
                      blinking: stats.pendingReturn > 0,
                    ),
                    _ModernStatCard(
                      title: 'Today Collection',
                      value:
                          '₹${NumberFormat('#,##0').format(stats.todayCollection)}',
                      icon: Icons.currency_rupee,
                      borderColor: const Color(0xFF0B63FF),
                      iconColor: const Color(0xFF0B63FF),
                      bgColor: const Color(0xFF0B63FF).withOpacity(0.05),
                      textColor: const Color(0xFF0B63FF),
                    ),
                    _ModernStatCard(
                      title: 'Completed',
                      value: stats.completed.toString(),
                      icon: Icons.check_circle_outline,
                      borderColor: Colors.grey,
                      iconColor: Colors.grey.shade600,
                      bgColor: Colors.grey.shade50,
                      textColor: Colors.grey.shade700,
                    ),
                  ],
                ),
                loading: () => GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.3,
                  children: List.generate(4, (index) => _StatCardSkeleton()),
                ),
                error: (error, stack) => Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  color: Colors.red.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.red.shade700,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Error loading statistics',
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          error.toString(),
                          style: TextStyle(
                            color: Colors.red.shade600,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Quick Actions
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      onPressed: () => context.push('/orders/new'),
                      icon: Icons.add_circle_outline,
                      label: 'New Order',
                      isPrimary: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionButton(
                      onPressed: () => context.go('/orders'),
                      icon: Icons.list_alt,
                      label: 'View Orders',
                      isPrimary: false,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Recent Activity Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Activity',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F1724),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go('/orders'),
                    child: const Text(
                      'View All',
                      style: TextStyle(
                        color: Color(0xFF0B63FF),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              recentOrders.when(
                data: (orders) {
                  if (orders.isEmpty) {
                    return _EmptyStateCard();
                  }

                  return Column(
                    children: orders
                        .map((order) => _ModernOrderCard(order: order))
                        .toList(),
                  );
                },
                loading: () => Column(
                  children: List.generate(4, (index) => _OrderCardSkeleton()),
                ),
                error: (error, stack) => Card(
                  color: Colors.red.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.red.shade700,
                          size: 32,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Error loading recent activity',
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () {
                            ref.invalidate(recentOrdersProvider(branchId));
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade700,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

/// Modern Stat Card with left border accent
class _ModernStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color borderColor;
  final Color iconColor;
  final Color bgColor;
  final Color? textColor;
  final bool blinking;

  const _ModernStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.borderColor,
    required this.iconColor,
    required this.bgColor,
    this.textColor,
    this.blinking = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Colored left border
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 4,
              decoration: BoxDecoration(
                color: borderColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: textColor ?? Colors.grey.shade900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Stat Card Skeleton
class _StatCardSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 12,
              width: 80,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              height: 24,
              width: 60,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Modern Action Button
class _ActionButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final bool isPrimary;

  const _ActionButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    if (isPrimary) {
      return ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0B63FF),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF0B63FF),
        side: const BorderSide(color: Color(0xFF0B63FF), width: 1.5),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Modern Order Card
class _ModernOrderCard extends StatelessWidget {
  final Order order;

  const _ModernOrderCard({required this.order});

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.scheduled:
        return Colors.grey;
      case OrderStatus.active:
        return Colors.green;
      case OrderStatus.pendingReturn:
        return Colors.red;
      case OrderStatus.completed:
        return Colors.grey;
      case OrderStatus.cancelled:
        return Colors.grey;
      case OrderStatus.partiallyReturned:
        return Colors.blue;
    }
  }

  String _getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.scheduled:
        return 'Scheduled';
      case OrderStatus.active:
        return 'Active';
      case OrderStatus.pendingReturn:
        return 'Pending';
      case OrderStatus.completed:
        return 'Completed';
      case OrderStatus.cancelled:
        return 'Cancelled';
      case OrderStatus.partiallyReturned:
        return 'Partially Returned';
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(order.status);
    final isPendingReturn = order.status == OrderStatus.pendingReturn;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: isPendingReturn ? Colors.red.shade50 : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isPendingReturn ? Colors.red.shade300 : Colors.grey.shade200,
          width: isPendingReturn ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => context.push('/orders/${order.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: statusColor.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          _getStatusText(order.status),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        order.invoiceNumber,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F1724),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    _formatTimeAgo(order.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            order.customer?.name ?? 'Unknown',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F1724),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '₹${NumberFormat('#,##0').format(order.totalAmount)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Order Card Skeleton
class _OrderCardSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      height: 24,
                      width: 60,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      height: 16,
                      width: 100,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
                Container(
                  height: 14,
                  width: 50,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  height: 16,
                  width: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Container(
                  height: 24,
                  width: 70,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Small filter chip used for date range selection
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final bool isCustom;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.isCustom = false,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isCustom) ...[
            const Icon(Icons.calendar_today, size: 14),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: selected ? Colors.white : Colors.grey.shade700,
                fontSize: isCustom ? 12 : 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: const Color(0xFF0B63FF),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selected ? const Color(0xFF0B63FF) : Colors.grey.shade300,
          width: selected ? 1.5 : 1,
        ),
      ),
    );
  }
}

/// Empty State Card
class _EmptyStateCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.inbox_outlined,
                size: 48,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No recent activity',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Orders will appear here once created',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
