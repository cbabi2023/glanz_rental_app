import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
  DateTime? _lastBackPressTime;
  Timer? _backPressTimer;
  static const _exitInterval = Duration(seconds: 2);

  @override
  void dispose() {
    _backPressTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleBackPress() async {
    final now = DateTime.now();

    // Check if this is the second back press within the exit interval
    if (_lastBackPressTime != null &&
        now.difference(_lastBackPressTime!) < _exitInterval) {
      // Second back press within interval - exit the app
      _backPressTimer?.cancel();
      SystemNavigator.pop();
      return;
    }

    // First back press - show toast message and start timer
    _lastBackPressTime = now;

    // Show toast message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Press back again to exit',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.grey.shade800,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: _exitInterval,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );

    // Reset timer after exit interval expires
    _backPressTimer?.cancel();
    _backPressTimer = Timer(_exitInterval, () {
      if (mounted) {
        setState(() {
          _lastBackPressTime = null;
        });
      }
    });
  }

  Widget _buildCompanyLogo(String? logoUrl) {
    if (logoUrl != null && logoUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: logoUrl,
        fit: BoxFit.contain,
        errorWidget: (context, url, error) => _buildLogoFallback(),
        placeholder: (context, url) =>
            Image.asset('lib/assets/png/glanz.png', fit: BoxFit.contain),
      );
    }
    // Fallback to asset logo
    return Image.asset(
      'lib/assets/png/glanz.png',
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Image.asset(
          'lib/assets/png/glanzicon.png',
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const SizedBox.shrink();
          },
        );
      },
    );
  }

  Widget _buildLogoFallback() {
    return Image.asset(
      'lib/assets/png/glanz.png',
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Image.asset(
          'lib/assets/png/glanzicon.png',
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const SizedBox.shrink();
          },
        );
      },
    );
  }

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

  /// Format currency in compact format (k, M, etc.)
  String _formatCompactCurrency(double amount) {
    if (amount < 1000) {
      return '₹${NumberFormat('#,##0').format(amount)}';
    } else if (amount < 1000000) {
      // Thousands (1k, 20.8k)
      final thousands = amount / 1000;
      if (thousands % 1 == 0) {
        return '₹${thousands.toInt()}k';
      } else {
        return '₹${thousands.toStringAsFixed(1)}k';
      }
    } else {
      // Millions (1M, 2.5M)
      final millions = amount / 1000000;
      if (millions % 1 == 0) {
        return '₹${millions.toInt()}M';
      } else {
        return '₹${millions.toStringAsFixed(1)}M';
      }
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        // Handle gesture back directly in dashboard screen
        if (!didPop) {
          await _handleBackPress();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F9FB),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          leadingWidth: 60,
          leading: userProfile.when(
            data: (profile) => Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 8.0,
              ),
              child: _buildCompanyLogo(profile?.companyLogoUrl),
            ),
            loading: () => Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 8.0,
              ),
              child: Image.asset(
                'lib/assets/png/glanz.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Image.asset(
                    'lib/assets/png/glanzicon.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const SizedBox.shrink();
                    },
                  );
                },
              ),
            ),
            error: (_, __) => Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 8.0,
              ),
              child: Image.asset(
                'lib/assets/png/glanz.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Image.asset(
                    'lib/assets/png/glanzicon.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const SizedBox.shrink();
                    },
                  );
                },
              ),
            ),
          ),
          title: Row(
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [
                    Color(0xFF0F1724),
                    Color(0xFF1F2A7A),
                    Color(0xFF0F1724),
                  ],
                ).createShader(bounds),
                child: const Text(
                  'Dashboard',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          // actions: [
          //   IconButton(
          //     icon: const Icon(Icons.person_outline, color: Color(0xFF0F1724)),
          //     onPressed: () => context.push('/profile'),
          //     tooltip: 'Profile',
          //   ),
          // ],
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
                // Modern Filter Chips Container
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 6),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _ModernFilterChip(
                          label: 'All Time',
                          selected: _selectedFilter == _DashboardFilter.allTime,
                          onTap: () {
                            setState(() {
                              _selectedFilter = _DashboardFilter.allTime;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        _ModernFilterChip(
                          label: 'Today',
                          selected: _selectedFilter == _DashboardFilter.today,
                          onTap: () {
                            setState(() {
                              _selectedFilter = _DashboardFilter.today;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        _ModernFilterChip(
                          label: 'Yesterday',
                          selected:
                              _selectedFilter == _DashboardFilter.yesterday,
                          onTap: () {
                            setState(() {
                              _selectedFilter = _DashboardFilter.yesterday;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        _ModernFilterChip(
                          label: 'This Week',
                          selected:
                              _selectedFilter == _DashboardFilter.thisWeek,
                          onTap: () {
                            setState(() {
                              _selectedFilter = _DashboardFilter.thisWeek;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        _ModernFilterChip(
                          label: 'This Month',
                          selected:
                              _selectedFilter == _DashboardFilter.thisMonth,
                          onTap: () {
                            setState(() {
                              _selectedFilter = _DashboardFilter.thisMonth;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        _ModernFilterChip(
                          label: 'Last 7 Days',
                          selected:
                              _selectedFilter == _DashboardFilter.last7Days,
                          onTap: () {
                            setState(() {
                              _selectedFilter = _DashboardFilter.last7Days;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        _ModernFilterChip(
                          label: _getFilterLabel(_DashboardFilter.custom),
                          selected: _selectedFilter == _DashboardFilter.custom,
                          onTap: _showCustomDatePicker,
                          icon: Icons.calendar_today_rounded,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Statistics Cards - Website Style Three Sections
                dashboardStats.when(
                  data: (stats) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Operational Overview Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.flash_on,
                                size: 20,
                                color: const Color(0xFF1F2A7A),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Operational Overview',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F1724),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _getFilterLabel(_selectedFilter),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.25,
                        children: [
                          _PremiumStatCard(
                            title: _selectedFilter == _DashboardFilter.allTime
                                ? 'Scheduled Orders'
                                : 'Scheduled',
                            value: stats.scheduled.toString(),
                            icon: Icons.calendar_today_outlined,
                            variant: 'primary',
                            blinking: stats.scheduled > 0,
                            onTap: () => context.go('/orders?tab=scheduled'),
                          ),
                          _PremiumStatCard(
                            title: 'Ongoing Rentals',
                            value: stats.active.toString(),
                            icon: Icons.shopping_bag_outlined,
                            variant: 'success',
                            onTap: () => context.go('/orders?tab=ongoing'),
                          ),
                          _PremiumStatCard(
                            title: 'Late Returns',
                            value: stats.lateReturn.toString(),
                            icon: Icons.warning_amber_rounded,
                            variant: 'danger',
                            blinking: stats.lateReturn > 0,
                            onTap: () => context.go('/orders?tab=late'),
                          ),
                          _PremiumStatCard(
                            title: 'Partial Returns',
                            value: stats.partiallyReturned.toString(),
                            icon: Icons.history_outlined,
                            variant: 'warning',
                            blinking: stats.partiallyReturned > 0,
                            onTap: () =>
                                context.go('/orders?tab=partially_returned'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // 2. Business Metrics Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.trending_up,
                                size: 20,
                                color: const Color(0xFF1F2A7A),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Business Metrics',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F1724),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _getFilterLabel(_selectedFilter),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.25,
                        children: [
                          _PremiumStatCard(
                            title: 'Total Orders',
                            value: stats.totalOrders.toString(),
                            icon: Icons.receipt_long_outlined,
                            variant: 'default',
                            onTap: () => context.go('/orders'),
                          ),
                          _PremiumStatCard(
                            title: 'Total Completed',
                            value: stats.completed.toString(),
                            icon: Icons.check_circle_outline,
                            variant: 'success',
                            onTap: () => context.go('/orders'),
                          ),
                          _PremiumStatCard(
                            title: 'Total Revenue',
                            value: _formatCompactCurrency(
                              stats.todayCollection,
                            ),
                            icon: Icons.currency_rupee,
                            variant: 'primary',
                            onTap: () => context.push('/reports'),
                          ),
                          _PremiumStatCard(
                            title: 'Total Customers',
                            value: stats.totalCustomers.toString(),
                            icon: Icons.people_outline,
                            variant: 'default',
                            onTap: () => context.go('/customers'),
                          ),
                        ],
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

                // Recent Activity Section - Website Style
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 20,
                          color: const Color(0xFF1F2A7A),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Recent Activity',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F1724),
                          ),
                        ),
                      ],
                    ),
                    TextButton.icon(
                      onPressed: () => context.go('/orders'),
                      icon: const Icon(Icons.arrow_forward, size: 16),
                      label: const Text(
                        'View all',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2A7A),
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

/// Premium Stat Card matching website design
class _PremiumStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final String variant; // 'default', 'primary', 'success', 'warning', 'danger'
  final bool blinking;
  final String? badge;
  final VoidCallback? onTap;

  const _PremiumStatCard({
    required this.title,
    required this.value,
    required this.icon,
    this.variant = 'default',
    this.blinking = false,
    this.badge,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final variantStyles = {
      'default': {
        'iconBg': Colors.grey.shade100,
        'iconColor': Colors.grey.shade600,
        'border': Colors.grey.shade200,
        'accent': Colors.grey.shade600,
        'cardBg': Colors.white,
      },
      'primary': {
        'iconBg': const Color(0xFF1F2A7A).withOpacity(0.1),
        'iconColor': const Color(0xFF1F2A7A),
        'border': const Color(0xFF1F2A7A).withOpacity(0.2),
        'accent': const Color(0xFF1F2A7A),
        'cardBg': Colors.white,
      },
      'success': {
        'iconBg': Colors.green.shade50,
        'iconColor': Colors.green.shade600,
        'border': Colors.green.shade200,
        'accent': Colors.green.shade600,
        'cardBg': Colors.white,
      },
      'warning': {
        'iconBg': Colors.orange.shade50,
        'iconColor': Colors.orange.shade600,
        'border': Colors.orange.shade200,
        'accent': Colors.orange.shade600,
        'cardBg': Colors.white,
      },
      'danger': {
        'iconBg': Colors.red.shade50,
        'iconColor': const Color(0xFFE7342F),
        'border': Colors.red.shade200,
        'accent': const Color(0xFFE7342F),
        'cardBg': Colors.white,
      },
    };

    final styles = variantStyles[variant]!;
    final isClickable = onTap != null;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: blinking && variant == 'danger'
              ? Colors.red.shade300
              : blinking && variant == 'warning'
              ? Colors.orange.shade300
              : styles['border'] as Color,
          width: 1,
        ),
      ),
      color: styles['cardBg'] as Color,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade500,
                        letterSpacing: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF1F2A7A).withOpacity(0.1),
                            const Color(0xFF1F2A7A).withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFF1F2A7A).withOpacity(0.2),
                        ),
                      ),
                      child: Text(
                        badge!,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2A7A),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: styles['iconBg'] as Color,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      color: styles['iconColor'] as Color,
                      size: 20,
                    ),
                  ),
                ],
              ),
              if (isClickable) ...[
                const SizedBox(height: 12),
                Divider(height: 1, color: Colors.grey.shade200),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'View details',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.arrow_forward,
                      size: 12,
                      color: Colors.grey.shade500,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
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
          backgroundColor: const Color(0xFF1F2A7A),
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
        foregroundColor: const Color(0xFF1F2A7A),
        side: const BorderSide(color: Color(0xFF1F2A7A), width: 1.5),
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
      case OrderStatus.completedWithIssues:
        return Colors.orange;
      case OrderStatus.cancelled:
        return Colors.grey;
      case OrderStatus.partiallyReturned:
        return const Color(0xFF1F2A7A);
      case OrderStatus.flagged:
        return Colors.orange;
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
      case OrderStatus.completedWithIssues:
        return 'Completed (Issues)';
      case OrderStatus.cancelled:
        return 'Cancelled';
      case OrderStatus.partiallyReturned:
        return 'Partially Returned';
      case OrderStatus.flagged:
        return 'Flagged';
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
                  Expanded(
                    child: Row(
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
                        Flexible(
                          child: Text(
                            order.invoiceNumber,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F1724),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
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

/// Modern Filter Chip with attractive design
class _ModernFilterChip extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  const _ModernFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  State<_ModernFilterChip> createState() => _ModernFilterChipState();
}

class _ModernFilterChipState extends State<_ModernFilterChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _animationController.forward(),
      onTapUp: (_) {
        _animationController.reverse();
        widget.onTap();
      },
      onTapCancel: () => _animationController.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: widget.selected
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF6366F1),
                      Color(0xFF8B5CF6),
                      Color(0xFFA855F7),
                    ],
                  )
                : null,
            color: widget.selected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: widget.selected
                ? [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  size: 16,
                  color: widget.selected
                      ? Colors.white
                      : const Color(0xFF64748B),
                ),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: widget.selected
                        ? Colors.white
                        : const Color(0xFF64748B),
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
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
