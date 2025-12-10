import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/branches_provider.dart';
import '../../models/dashboard_stats.dart';
import '../../models/branch.dart';

/// Reports Screen
///
/// Analytics dashboard with date range filters matching website functionality
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedBranchId;

  @override
  void initState() {
    super.initState();
    // Default to current month
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1F2A7A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = DateTime(
          picked.end.year,
          picked.end.month,
          picked.end.day,
          23,
          59,
          59,
        );
      });
      // Refresh stats with new date range
      ref.invalidate(dashboardStatsProvider);
    }
  }

  void _applyQuickFilter(String filter) {
    final now = DateTime.now();
    setState(() {
      switch (filter) {
        case 'today':
          _startDate = DateTime(now.year, now.month, now.day);
          _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case 'week':
          final weekStart = now.subtract(Duration(days: now.weekday - 1));
          _startDate = DateTime(weekStart.year, weekStart.month, weekStart.day);
          _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case 'month':
          _startDate = DateTime(now.year, now.month, 1);
          _endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
          break;
        case 'year':
          _startDate = DateTime(now.year, 1, 1);
          _endDate = DateTime(now.year, 12, 31, 23, 59, 59);
          break;
        case 'all':
          _startDate = null;
          _endDate = null;
          break;
      }
    });
    // Refresh stats
    ref.invalidate(dashboardStatsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final userProfile = ref.watch(userProfileProvider);
    final isSuperAdmin = userProfile.value?.isSuperAdmin ?? false;
    final userBranchId = userProfile.value?.branchId;

    // Use selected branch or user's branch
    final branchId = isSuperAdmin ? _selectedBranchId : userBranchId;

    // Fetch branches for super admin
    final branchesAsync = ref.watch(branchesProvider);

    // Fetch dashboard stats with date range
    final dashboardStats = ref.watch(
      dashboardStatsProvider(
        DashboardStatsParams(
          branchId: branchId,
          startDate: _startDate,
          endDate: _endDate,
        ),
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Reports & Analytics',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F1724),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(
            dashboardStatsProvider(
              DashboardStatsParams(
                branchId: branchId,
                startDate: _startDate,
                endDate: _endDate,
              ),
            ),
          );
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Date Range Selector
              _DateRangeCard(
                startDate: _startDate,
                endDate: _endDate,
                onTap: () => _selectDateRange(context),
              ),
              const SizedBox(height: 16),

              // Quick Filters
              _QuickFilters(
                onFilterSelected: _applyQuickFilter,
              ),
              const SizedBox(height: 16),

              // Branch Filter (Super Admin only)
              if (isSuperAdmin) ...[
                branchesAsync.when(
                  data: (branches) => _BranchFilter(
                    branches: branches,
                    selectedBranchId: _selectedBranchId,
                    onBranchSelected: (branchId) {
                      setState(() {
                        _selectedBranchId = branchId;
                      });
                      ref.invalidate(dashboardStatsProvider);
                    },
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 16),
              ],

              // Statistics Cards
              dashboardStats.when(
                data: (stats) => _StatsGrid(stats: stats),
                loading: () => const _LoadingState(),
                error: (error, stack) => _ErrorState(
                  error: error.toString(),
                  onRetry: () {
                    ref.invalidate(
                      dashboardStatsProvider(
                        DashboardStatsParams(
                          branchId: branchId,
                          startDate: _startDate,
                          endDate: _endDate,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Additional Analytics
              dashboardStats.when(
                data: (stats) => _AnalyticsSection(stats: stats),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Date Range Card
class _DateRangeCard extends StatelessWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final VoidCallback onTap;

  const _DateRangeCard({
    required this.startDate,
    required this.endDate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.calendar_today, color: Colors.grey.shade600, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Date Range',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      startDate != null && endDate != null
                          ? '${dateFormat.format(startDate!)} - ${dateFormat.format(endDate!)}'
                          : 'All Time',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F1724),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}

/// Quick Filters
class _QuickFilters extends StatelessWidget {
  final Function(String) onFilterSelected;

  const _QuickFilters({required this.onFilterSelected});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _QuickFilterChip(
            label: 'Today',
            onTap: () => onFilterSelected('today'),
          ),
          const SizedBox(width: 8),
          _QuickFilterChip(
            label: 'This Week',
            onTap: () => onFilterSelected('week'),
          ),
          const SizedBox(width: 8),
          _QuickFilterChip(
            label: 'This Month',
            onTap: () => onFilterSelected('month'),
          ),
          const SizedBox(width: 8),
          _QuickFilterChip(
            label: 'This Year',
            onTap: () => onFilterSelected('year'),
          ),
          const SizedBox(width: 8),
          _QuickFilterChip(
            label: 'All Time',
            onTap: () => onFilterSelected('all'),
          ),
        ],
      ),
    );
  }
}

/// Quick Filter Chip
class _QuickFilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickFilterChip({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      onSelected: (_) => onTap(),
      selectedColor: const Color(0xFF1F2A7A).withValues(alpha: 0.2),
      checkmarkColor: const Color(0xFF1F2A7A),
      labelStyle: const TextStyle(
        fontWeight: FontWeight.w500,
        color: Color(0xFF0F1724),
      ),
      side: BorderSide(
        color: Colors.grey.shade300,
        width: 1,
      ),
    );
  }
}

/// Branch Filter (Super Admin only)
class _BranchFilter extends StatelessWidget {
  final List<Branch> branches;
  final String? selectedBranchId;
  final Function(String?) onBranchSelected;

  const _BranchFilter({
    required this.branches,
    required this.selectedBranchId,
    required this.onBranchSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.store, color: Colors.grey.shade600, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Branch',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedBranchId,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('All Branches'),
                ),
                ...branches.map((branch) {
                  return DropdownMenuItem<String>(
                    value: branch.id,
                    child: Text(branch.name),
                  );
                }),
              ],
              onChanged: (value) => onBranchSelected(value),
            ),
          ],
        ),
      ),
    );
  }
}

/// Statistics Grid
class _StatsGrid extends StatelessWidget {
  final DashboardStats stats;

  const _StatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.3,
      children: [
        _StatCard(
          title: 'Total Revenue',
          value: '₹${NumberFormat('#,##0.00').format(stats.todayCollection)}',
          icon: Icons.currency_rupee,
          color: const Color(0xFF1F2A7A),
        ),
        _StatCard(
          title: 'Total Orders',
          value: stats.totalOrders.toString(),
          icon: Icons.shopping_bag_outlined,
          color: Colors.green,
        ),
        _StatCard(
          title: 'Active Rentals',
          value: stats.active.toString(),
          icon: Icons.inventory_2_outlined,
          color: Color(0xFF1F2A7A),
        ),
        _StatCard(
          title: 'Completed',
          value: stats.completed.toString(),
          icon: Icons.check_circle_outline,
          color: Colors.green.shade600,
        ),
        _StatCard(
          title: 'Pending Return',
          value: stats.pendingReturn.toString(),
          icon: Icons.warning_amber_rounded,
          color: Colors.orange,
        ),
        _StatCard(
          title: 'Late Returns',
          value: stats.lateReturn.toString(),
          icon: Icons.schedule,
          color: Colors.red,
        ),
      ],
    );
  }
}

/// Stat Card
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.2), width: 1.5),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              color.withValues(alpha: 0.03),
            ],
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Analytics Section
class _AnalyticsSection extends StatelessWidget {
  final DashboardStats stats;

  const _AnalyticsSection({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics_outlined, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                const Text(
                  'Additional Statistics',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F1724),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _AnalyticsRow(
              label: 'Total Customers',
              value: stats.totalCustomers.toString(),
            ),
            const Divider(height: 24),
            _AnalyticsRow(
              label: 'Scheduled Orders',
              value: stats.scheduled.toString(),
            ),
            const Divider(height: 24),
            _AnalyticsRow(
              label: 'Partially Returned',
              value: stats.partiallyReturned.toString(),
            ),
            if (stats.totalOrders > 0) ...[
              const Divider(height: 24),
              _AnalyticsRow(
                label: 'Average Order Value',
                value: '₹${NumberFormat('#,##0.00').format(stats.todayCollection / stats.totalOrders)}',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Analytics Row
class _AnalyticsRow extends StatelessWidget {
  final String label;
  final String value;

  const _AnalyticsRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F1724),
          ),
        ),
      ],
    );
  }
}

/// Loading State
class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

/// Error State
class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text(
              'Error loading reports',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1F2A7A),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

