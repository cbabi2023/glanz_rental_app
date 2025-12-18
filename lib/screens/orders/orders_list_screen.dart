import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/orders_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../models/order.dart';

/// Orders List Screen
///
/// Modern orders list with filters, stats, and attractive cards
class OrdersListScreen extends ConsumerStatefulWidget {
  const OrdersListScreen({super.key});

  @override
  ConsumerState<OrdersListScreen> createState() => _OrdersListScreenState();
}

enum _OrdersTab {
  all,
  scheduled,
  ongoing,
  late,
  returned,
  partiallyReturned,
  cancelled,
  flagged,
}

enum _DateFilter {
  allTime,
  today,
  yesterday,
  thisWeek,
  thisMonth,
  last7Days,
  custom,
}

class _OrdersListScreenState extends ConsumerState<OrdersListScreen> with WidgetsBindingObserver {
  _OrdersTab _selectedTab = _OrdersTab.all;
  final _searchController = TextEditingController();
  String? _searchQuery; // Used for provider (backend search)
  _DateFilter _selectedDateFilter = _DateFilter.allTime;
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounceTimer;
  final _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onSearchChanged(String value) {
    // Cancel previous timer if it exists
    _searchDebounceTimer?.cancel();

    // Debounce the backend search - wait 500ms after user stops typing
    _searchDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        final newSearchQuery = value.trim().isEmpty ? null : value.trim();
        if (_searchQuery != newSearchQuery) {
          // Update search query state - this triggers Consumer rebuild
          setState(() {
            _searchQuery = newSearchQuery;
          });
          
          // Refresh provider with new search query (will load from backend)
          // The Consumer widget will automatically rebuild only the list part
          final userProfile = ref.read(userProfileProvider).value;
          // Super admin should see all orders (branchId = null), others see their branch orders
          final branchId = userProfile?.isSuperAdmin == true 
              ? null 
              : userProfile?.branchId;
          {
            final startDate = _startForFilter(_selectedDateFilter);
            final endDate = _endForFilter(_selectedDateFilter);
            
            // Map tab to status
            OrderStatus? status;
            switch (_selectedTab) {
              case _OrdersTab.scheduled:
                status = OrderStatus.scheduled;
                break;
              case _OrdersTab.ongoing:
                status = OrderStatus.active;
                break;
              case _OrdersTab.returned:
                status = OrderStatus.completed;
                break;
              case _OrdersTab.cancelled:
                status = OrderStatus.cancelled;
                break;
              case _OrdersTab.flagged:
                status = OrderStatus.flagged;
                break;
              case _OrdersTab.partiallyReturned:
                status = OrderStatus.partiallyReturned;
                break;
              case _OrdersTab.late:
              case _OrdersTab.all:
                status = null;
                break;
            }
            
            final params = OrdersParams(
              branchId: branchId,
              status: status,
              startDate: startDate,
              endDate: endDate,
              searchQuery: newSearchQuery,
            );
            
            ref.read(ordersInfiniteProvider(params).notifier).refresh();
          }
        }
      }
    });
  }

  void _onScroll() {
    // Load more when user scrolls to 80% of the list
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      final userProfile = ref.read(userProfileProvider).value;
      // Super admin should see all orders (branchId = null), others see their branch orders
      final branchId = userProfile?.isSuperAdmin == true 
          ? null 
          : userProfile?.branchId;

      final startDate = _startForFilter(_selectedDateFilter);
      final endDate = _endForFilter(_selectedDateFilter);
      
      // Map tab to status for server-side filtering (where applicable)
      OrderStatus? status;
      switch (_selectedTab) {
        case _OrdersTab.scheduled:
          status = OrderStatus.scheduled;
          break;
        case _OrdersTab.ongoing:
          status = OrderStatus.active;
          break;
        case _OrdersTab.returned:
          status = OrderStatus.completed;
          break;
        case _OrdersTab.cancelled:
          status = OrderStatus.cancelled;
          break;
        case _OrdersTab.flagged:
          status = OrderStatus.flagged;
          break;
        case _OrdersTab.partiallyReturned:
          status = OrderStatus.partiallyReturned;
          break;
        case _OrdersTab.late:
        case _OrdersTab.all:
          // These require client-side filtering
          status = null;
          break;
      }
      
      final params = OrdersParams(
        branchId: branchId,
        status: status,
        startDate: startDate,
        endDate: endDate,
        searchQuery: _searchQuery,
      );
      
      ref.read(ordersInfiniteProvider(params).notifier).loadMore();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh orders when app comes to foreground
    if (state == AppLifecycleState.resumed) {
      final userProfile = ref.read(userProfileProvider).value;
      // Super admin should see all orders (branchId = null), others see their branch orders
      final branchId = userProfile?.isSuperAdmin == true 
          ? null 
          : userProfile?.branchId;
      {
        final startDate = _startForFilter(_selectedDateFilter);
        final endDate = _endForFilter(_selectedDateFilter);
        
        // Map tab to status
        OrderStatus? status;
        switch (_selectedTab) {
          case _OrdersTab.scheduled:
            status = OrderStatus.scheduled;
            break;
          case _OrdersTab.ongoing:
            status = OrderStatus.active;
            break;
          case _OrdersTab.returned:
            status = OrderStatus.completed;
            break;
          case _OrdersTab.cancelled:
            status = OrderStatus.cancelled;
            break;
          case _OrdersTab.flagged:
            status = OrderStatus.flagged;
            break;
          case _OrdersTab.partiallyReturned:
            status = OrderStatus.partiallyReturned;
            break;
          case _OrdersTab.late:
          case _OrdersTab.all:
            status = null;
            break;
        }
        
        final params = OrdersParams(
          branchId: branchId,
          status: status,
          startDate: startDate,
          endDate: endDate,
          searchQuery: _searchQuery,
        );
        ref.read(ordersInfiniteProvider(params).notifier).refresh();
      }
    }
  }

  // Helper function to parse datetime with timezone handling
  DateTime _parseDateTimeWithTimezone(String dateString) {
    try {
      final trimmed = dateString.trim();
      final hasTimezone = trimmed.endsWith('Z') || 
                         RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(trimmed);
      
      if (hasTimezone) {
        return DateTime.parse(trimmed).toLocal();
      } else {
        final parsed = DateTime.parse(trimmed);
        final utcDate = DateTime.utc(
          parsed.year, parsed.month, parsed.day,
          parsed.hour, parsed.minute, parsed.second, 
          parsed.millisecond, parsed.microsecond
        );
        return utcDate.toLocal();
      }
    } catch (e) {
      return DateTime.now();
    }
  }

  DateTime? _startForFilter(_DateFilter filter) {
    if (filter == _DateFilter.allTime) return null;

    final now = DateTime.now();
    switch (filter) {
      case _DateFilter.allTime:
        return null;
      case _DateFilter.today:
        return DateTime(now.year, now.month, now.day);
      case _DateFilter.yesterday:
        final yesterday = now.subtract(const Duration(days: 1));
        return DateTime(yesterday.year, yesterday.month, yesterday.day);
      case _DateFilter.thisWeek:
        final weekday = now.weekday;
        final daysFromMonday = weekday == 7 ? 0 : weekday - 1;
        final startOfWeek = now.subtract(Duration(days: daysFromMonday));
        return DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
      case _DateFilter.thisMonth:
        return DateTime(now.year, now.month, 1);
      case _DateFilter.last7Days:
        final start = now.subtract(const Duration(days: 6));
        return DateTime(start.year, start.month, start.day);
      case _DateFilter.custom:
        return _customStartDate;
    }
  }

  DateTime? _endForFilter(_DateFilter filter) {
    if (filter == _DateFilter.allTime) return null;

    final now = DateTime.now();
    switch (filter) {
      case _DateFilter.allTime:
        return null;
      case _DateFilter.today:
        return DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
      case _DateFilter.yesterday:
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
      case _DateFilter.thisWeek:
      case _DateFilter.thisMonth:
      case _DateFilter.last7Days:
        return DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
      case _DateFilter.custom:
        return _customEndDate;
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
        _selectedDateFilter = _DateFilter.custom;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    // Read query parameters from route to set tab filter
    final uri = GoRouterState.of(context).uri;
    final tabParam = uri.queryParameters['tab'];
    
    _OrdersTab targetTab;
    
    if (tabParam == null || tabParam.isEmpty) {
      // No tab parameter means "All" tab
      targetTab = _OrdersTab.all;
    } else {
      switch (tabParam) {
        case 'scheduled':
          targetTab = _OrdersTab.scheduled;
          break;
        case 'ongoing':
          targetTab = _OrdersTab.ongoing;
          break;
        case 'late':
          targetTab = _OrdersTab.late;
          break;
        case 'partially_returned':
          targetTab = _OrdersTab.partiallyReturned;
          break;
        case 'completed':
          targetTab = _OrdersTab.returned;
          break;
        case 'cancelled':
          targetTab = _OrdersTab.cancelled;
          break;
        case 'flagged':
          targetTab = _OrdersTab.flagged;
          break;
        default:
          targetTab = _OrdersTab.all;
      }
    }
    
    if (_selectedTab != targetTab) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _selectedTab = targetTab;
          });
        }
      });
    }
    // Watch refresh trigger - this ensures the widget rebuilds when a new order is created
    // The ordersProvider also watches this, so it will refetch automatically
    ref.watch(ordersRefreshTriggerProvider);

    final startDate = _startForFilter(_selectedDateFilter);
    final endDate = _endForFilter(_selectedDateFilter);

    // Map tab to status for server-side filtering (where applicable)
    OrderStatus? status;
    switch (_selectedTab) {
      case _OrdersTab.scheduled:
        status = OrderStatus.scheduled;
        break;
      case _OrdersTab.ongoing:
        status = OrderStatus.active;
        break;
      case _OrdersTab.returned:
        status = OrderStatus.completed;
        break;
      case _OrdersTab.cancelled:
        status = OrderStatus.cancelled;
        break;
      case _OrdersTab.flagged:
        status = OrderStatus.flagged;
        break;
      case _OrdersTab.partiallyReturned:
        status = OrderStatus.partiallyReturned;
        break;
      case _OrdersTab.late:
      case _OrdersTab.all:
        // These require client-side filtering
        status = null;
        break;
    }

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F9FB),
        appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leadingWidth: 60,
        leading: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 12.0,
            vertical: 8.0,
          ),
          child: Image.asset(
            'lib/assets/png/glanz.png',
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const SizedBox.shrink();
            },
          ),
        ),
        title: const Text(
          'Orders',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F1724),
          ),
        ),
        actions: [
          // Date Filter Dropdown
          Builder(
            builder: (context) => PopupMenuButton<_DateFilter>(
              offset: const Offset(0, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              icon: Stack(
                children: [
                  const Icon(Icons.filter_list, color: Color(0xFF1F2A7A)),
                  if (_selectedDateFilter != _DateFilter.allTime)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                      ),
                    ),
                ],
              ),
              tooltip: 'Date Filter',
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: _DateFilter.allTime,
                  child: Row(
                    children: [
                      Icon(
                        Icons.all_inclusive,
                        size: 20,
                        color: _selectedDateFilter == _DateFilter.allTime
                            ? const Color(0xFF1F2A7A)
                            : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'All Time',
                        style: TextStyle(
                          fontWeight: _selectedDateFilter == _DateFilter.allTime
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: _selectedDateFilter == _DateFilter.allTime
                              ? const Color(0xFF1F2A7A)
                              : Colors.grey.shade700,
                        ),
                      ),
                      if (_selectedDateFilter == _DateFilter.allTime) ...[
                        const Spacer(),
                        Icon(
                          Icons.check,
                          size: 18,
                          color: const Color(0xFF1F2A7A),
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: _DateFilter.today,
                  child: Row(
                    children: [
                      Icon(
                        Icons.today,
                        size: 20,
                        color: _selectedDateFilter == _DateFilter.today
                            ? const Color(0xFF1F2A7A)
                            : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Today',
                        style: TextStyle(
                          fontWeight: _selectedDateFilter == _DateFilter.today
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: _selectedDateFilter == _DateFilter.today
                              ? const Color(0xFF1F2A7A)
                              : Colors.grey.shade700,
                        ),
                      ),
                      if (_selectedDateFilter == _DateFilter.today) ...[
                        const Spacer(),
                        Icon(
                          Icons.check,
                          size: 18,
                          color: const Color(0xFF1F2A7A),
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: _DateFilter.yesterday,
                  child: Row(
                    children: [
                      Icon(
                        Icons.history,
                        size: 20,
                        color: _selectedDateFilter == _DateFilter.yesterday
                            ? const Color(0xFF1F2A7A)
                            : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Yesterday',
                        style: TextStyle(
                          fontWeight:
                              _selectedDateFilter == _DateFilter.yesterday
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: _selectedDateFilter == _DateFilter.yesterday
                              ? const Color(0xFF1F2A7A)
                              : Colors.grey.shade700,
                        ),
                      ),
                      if (_selectedDateFilter == _DateFilter.yesterday) ...[
                        const Spacer(),
                        Icon(
                          Icons.check,
                          size: 18,
                          color: const Color(0xFF1F2A7A),
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: _DateFilter.thisWeek,
                  child: Row(
                    children: [
                      Icon(
                        Icons.date_range,
                        size: 20,
                        color: _selectedDateFilter == _DateFilter.thisWeek
                            ? const Color(0xFF1F2A7A)
                            : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'This Week',
                        style: TextStyle(
                          fontWeight:
                              _selectedDateFilter == _DateFilter.thisWeek
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: _selectedDateFilter == _DateFilter.thisWeek
                              ? const Color(0xFF1F2A7A)
                              : Colors.grey.shade700,
                        ),
                      ),
                      if (_selectedDateFilter == _DateFilter.thisWeek) ...[
                        const Spacer(),
                        Icon(
                          Icons.check,
                          size: 18,
                          color: const Color(0xFF1F2A7A),
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: _DateFilter.thisMonth,
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_month,
                        size: 20,
                        color: _selectedDateFilter == _DateFilter.thisMonth
                            ? const Color(0xFF1F2A7A)
                            : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'This Month',
                        style: TextStyle(
                          fontWeight:
                              _selectedDateFilter == _DateFilter.thisMonth
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: _selectedDateFilter == _DateFilter.thisMonth
                              ? const Color(0xFF1F2A7A)
                              : Colors.grey.shade700,
                        ),
                      ),
                      if (_selectedDateFilter == _DateFilter.thisMonth) ...[
                        const Spacer(),
                        Icon(
                          Icons.check,
                          size: 18,
                          color: const Color(0xFF1F2A7A),
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: _DateFilter.last7Days,
                  child: Row(
                    children: [
                      Icon(
                        Icons.view_week,
                        size: 20,
                        color: _selectedDateFilter == _DateFilter.last7Days
                            ? const Color(0xFF1F2A7A)
                            : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Last 7 Days',
                        style: TextStyle(
                          fontWeight:
                              _selectedDateFilter == _DateFilter.last7Days
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: _selectedDateFilter == _DateFilter.last7Days
                              ? const Color(0xFF1F2A7A)
                              : Colors.grey.shade700,
                        ),
                      ),
                      if (_selectedDateFilter == _DateFilter.last7Days) ...[
                        const Spacer(),
                        Icon(
                          Icons.check,
                          size: 18,
                          color: const Color(0xFF1F2A7A),
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: _DateFilter.custom,
                  child: Row(
                    children: [
                      Icon(
                        Icons.event_note,
                        size: 20,
                        color: _selectedDateFilter == _DateFilter.custom
                            ? const Color(0xFF1F2A7A)
                            : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedDateFilter == _DateFilter.custom &&
                                  _customStartDate != null &&
                                  _customEndDate != null
                              ? '${DateFormat('dd MMM').format(_customStartDate!)} - ${DateFormat('dd MMM yyyy').format(_customEndDate!)}'
                              : 'Custom',
                          style: TextStyle(
                            fontWeight:
                                _selectedDateFilter == _DateFilter.custom
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: _selectedDateFilter == _DateFilter.custom
                                ? const Color(0xFF1F2A7A)
                                : Colors.grey.shade700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_selectedDateFilter == _DateFilter.custom)
                        Icon(
                          Icons.check,
                          size: 18,
                          color: const Color(0xFF1F2A7A),
                        ),
                    ],
                  ),
                ),
              ],
              onSelected: (filter) {
                if (filter == _DateFilter.custom) {
                  _showCustomDatePicker();
                } else {
                  setState(() {
                    _selectedDateFilter = filter;
                  });
                }
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'orders_fab',
        onPressed: () => context.push('/orders/new'),
        backgroundColor: const Color(0xFF1F2A7A),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text(
          'New Order',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      // Use Column to place search bar outside Consumer (so it doesn't rebuild)
      body: Column(
        children: [
          // Search Bar (always visible, outside Consumer so it doesn't rebuild)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: _OrdersSearchBar(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: _onSearchChanged,
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
            // Only this part watches the provider and rebuilds when data changes
            Expanded(
              child: Consumer(
                builder: (context, ref, child) {
                  // Get branchId inside Consumer to ensure it uses latest userProfile
                  final userProfile = ref.watch(userProfileProvider);
                  // Super admin should see all orders (branchId = null), others see their branch orders
                  final branchId = userProfile.value?.isSuperAdmin == true 
                      ? null 
                      : userProfile.value?.branchId;
                  
                  final params = OrdersParams(
                    branchId: branchId,
                    status: status,
                    startDate: startDate,
                    endDate: endDate,
                    searchQuery: _searchQuery,
                  );
                  final ordersState = ref.watch(ordersInfiniteProvider(params));
                  final statsParams = OrdersStatsParams(
                    branchId: branchId,
                    startDate: startDate,
                    endDate: endDate,
                  );
                  final statsAsync = ref.watch(orderStatsProvider(statsParams));
                  return _buildOrdersBody(ordersState, params, branchId, startDate, endDate, statsAsync);
                },
              ),
            ),
        ],
      ),
      ),
    );
  }

  Widget _buildOrdersBody(
    OrdersInfiniteState ordersState,
    OrdersParams params,
    String? branchId,
    DateTime? startDate,
    DateTime? endDate,
    AsyncValue<Map<String, dynamic>> statsAsync,
  ) {
    // Get stats from server (or use default if loading/error)
    final statsData = statsAsync.value ?? {
      'total': 0,
      'scheduled': 0,
      'ongoing': 0,
      'late': 0,
      'returned': 0,
      'partiallyReturned': 0,
      'cancelled': 0,
    };
    final stats = _OrdersStats(
      total: statsData['total'] as int? ?? 0,
      scheduled: statsData['scheduled'] as int? ?? 0,
      ongoing: statsData['ongoing'] as int? ?? 0,
      late: statsData['late'] as int? ?? 0,
      returned: statsData['returned'] as int? ?? 0,
      partiallyReturned: statsData['partiallyReturned'] as int? ?? 0,
      cancelled: statsData['cancelled'] as int? ?? 0,
    );

    // Apply client-side category filters only (late tab needs date checking)
    // Search is now handled server-side
    final filtered = _filterOrdersByCategory(ordersState.orders);
    
    // Check if this is initial empty state (no filters, no search, no orders)
    final isInitialEmpty = ordersState.orders.isEmpty && 
                          !ordersState.isLoading && 
                          ordersState.error == null &&
                          _searchQuery == null &&
                          _selectedTab == _OrdersTab.all;

    return Column(
      children: [
        // Scrollable Content (Tabs, Stats, Orders)
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              final statsParams = OrdersStatsParams(
                branchId: branchId,
                startDate: startDate,
                endDate: endDate,
              );
              await Future.wait([
                ref.read(ordersInfiniteProvider(params).notifier).refresh(),
                ref.refresh(orderStatsProvider(statsParams).future),
              ]);
              ref.invalidate(recentOrdersProvider(branchId));
            },
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _OrdersTabs(
                          selected: _selectedTab,
                          onChanged: (tab) {
                            // Update URL to reflect tab change
                            String tabParam = '';
                            switch (tab) {
                              case _OrdersTab.all:
                                tabParam = '';
                                break;
                              case _OrdersTab.scheduled:
                                tabParam = 'scheduled';
                                break;
                              case _OrdersTab.ongoing:
                                tabParam = 'ongoing';
                                break;
                              case _OrdersTab.late:
                                tabParam = 'late';
                                break;
                              case _OrdersTab.returned:
                                tabParam = 'completed';
                                break;
                              case _OrdersTab.partiallyReturned:
                                tabParam = 'partially_returned';
                                break;
                              case _OrdersTab.cancelled:
                                tabParam = 'cancelled';
                                break;
                              case _OrdersTab.flagged:
                                tabParam = 'flagged';
                                break;
                            }
                            
                            if (tabParam.isEmpty) {
                              context.go('/orders');
                            } else {
                              context.go('/orders?tab=$tabParam');
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        _OrdersStatsRow(stats: stats),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
                // Show loading indicator during initial load
                if (ordersState.isLoading && ordersState.orders.isEmpty)
                  const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  )
                // Show error state
                else if (ordersState.error != null && ordersState.orders.isEmpty)
                  SliverFillRemaining(
                    child: _ErrorState(
                      message: 'Error loading orders: ${ordersState.error}',
                      onRetry: () {
                        ref.read(ordersInfiniteProvider(params).notifier).refresh();
                        ref.invalidate(recentOrdersProvider(branchId));
                      },
                    ),
                  )
                // Show empty state only for initial empty (no filters, no search)
                else if (isInitialEmpty)
                  SliverFillRemaining(
                    child: _EmptyOrdersState(
                      onNewOrder: () => context.push('/orders/new'),
                    ),
                  )
                // Show no results message when filtered list is empty
                else if (filtered.isEmpty)
                  SliverFillRemaining(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: _NoResultsState(),
                    ),
                  )
                // Show order list
                else
                  SliverList.builder(
                    itemCount: filtered.length + (ordersState.isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= filtered.length) {
                        // Show loading indicator at bottom
                        return const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final order = filtered[index];
                      return _OrderCardItem(order: order);
                    },
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Categorize order based on dates and status
  /// CRITICAL: Scheduled orders ALWAYS return "scheduled" - do NOT check dates for scheduled status
  _OrderCategory _getOrderCategory(Order order) {
    final status = order.status;

    // Fast path: Check status first
    if (status == OrderStatus.cancelled) return _OrderCategory.cancelled;
    if (status == OrderStatus.flagged) return _OrderCategory.flagged;
    if (status == OrderStatus.partiallyReturned)
      return _OrderCategory.partiallyReturned;
    if (status == OrderStatus.completed || 
        status == OrderStatus.completedWithIssues) {
      return _OrderCategory.returned;
    }

    // ⚠️ CRITICAL: Scheduled orders ALWAYS return "scheduled" regardless of date
    // Do NOT check dates for scheduled orders - they remain scheduled until explicitly started
    if (status == OrderStatus.scheduled) {
      return _OrderCategory.scheduled;
    }

    // Check for partial returns via items (if status is active but some items returned)
    if (order.items != null && order.items!.isNotEmpty) {
      final hasReturned = order.items!.any((item) => item.isReturned);
      final hasNotReturned = order.items!.any((item) => item.isPending);

      // If some items are returned but not all, it's partially returned
      if (hasReturned && hasNotReturned) {
        return _OrderCategory.partiallyReturned;
      }
    }

    // Parse dates for active orders
    DateTime? endDate;

    try {
      final endStr = order.endDatetime ?? order.endDate;
      endDate = _parseDateTimeWithTimezone(endStr);
    } catch (e) {
      // If parsing fails, treat as ongoing
      return _OrderCategory.ongoing;
    }

    // Check if late (end date passed and not completed/cancelled)
    final isLate =
        DateTime.now().isAfter(endDate) &&
        status != OrderStatus.completed &&
        status != OrderStatus.completedWithIssues &&
        status != OrderStatus.flagged &&
        status != OrderStatus.cancelled &&
        status != OrderStatus.partiallyReturned;

    if (isLate) return _OrderCategory.late;
    if (status == OrderStatus.active) return _OrderCategory.ongoing;

    // Default to ongoing
    return _OrderCategory.ongoing;
  }

  List<Order> _filterOrdersByCategory(List<Order> orders) {
    // Only filter by category/tab (late tab needs client-side date checking)
    // Search is now handled server-side
    if (_selectedTab == _OrdersTab.all) {
      return orders;
    }

    return orders.where((order) {
      final category = _getOrderCategory(order);
      switch (_selectedTab) {
        case _OrdersTab.scheduled:
          return category == _OrderCategory.scheduled;
        case _OrdersTab.ongoing:
          return category == _OrderCategory.ongoing;
        case _OrdersTab.late:
          return category == _OrderCategory.late;
        case _OrdersTab.returned:
          return category == _OrderCategory.returned;
        case _OrdersTab.partiallyReturned:
          return category == _OrderCategory.partiallyReturned;
        case _OrdersTab.cancelled:
          return category == _OrderCategory.cancelled;
        case _OrdersTab.flagged:
          return category == _OrderCategory.flagged;
        case _OrdersTab.all:
          return true;
      }
    }).toList();
  }

}

enum _OrderCategory {
  scheduled,
  ongoing,
  late,
  returned,
  partiallyReturned,
  cancelled,
  flagged,
}

class _OrdersStats {
  final int total;
  final int scheduled;
  final int ongoing;
  final int late;
  final int returned;
  final int partiallyReturned;
  final int cancelled;

  const _OrdersStats({
    required this.total,
    required this.scheduled,
    required this.ongoing,
    required this.late,
    required this.returned,
    required this.partiallyReturned,
    required this.cancelled,
  });
}

class _OrdersSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  const _OrdersSearchBar({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const ValueKey('order_search_field'),
      controller: controller,
      focusNode: focusNode,
      decoration: InputDecoration(
        hintText: 'Search by invoice, customer, or phone',
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1F2A7A), width: 1.5),
        ),
      ),
      onChanged: onChanged,
    );
  }
}

class _OrdersTabs extends StatelessWidget {
  final _OrdersTab selected;
  final ValueChanged<_OrdersTab> onChanged;

  const _OrdersTabs({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _OrdersTabChip(
            label: 'All',
            icon: Icons.list_alt,
            selected: selected == _OrdersTab.all,
            onTap: () => onChanged(_OrdersTab.all),
          ),
          const SizedBox(width: 8),
          _OrdersTabChip(
            label: 'Scheduled',
            icon: Icons.calendar_today,
            selected: selected == _OrdersTab.scheduled,
            onTap: () => onChanged(_OrdersTab.scheduled),
          ),
          const SizedBox(width: 8),
          _OrdersTabChip(
            label: 'Ongoing',
            icon: Icons.play_circle_outline,
            selected: selected == _OrdersTab.ongoing,
            onTap: () => onChanged(_OrdersTab.ongoing),
          ),
          const SizedBox(width: 8),
          _OrdersTabChip(
            label: 'Late',
            icon: Icons.warning_amber_rounded,
            selected: selected == _OrdersTab.late,
            onTap: () => onChanged(_OrdersTab.late),
            isWarning: true,
          ),
          const SizedBox(width: 8),
          _OrdersTabChip(
            label: 'Returned',
            icon: Icons.check_circle_outline,
            selected: selected == _OrdersTab.returned,
            onTap: () => onChanged(_OrdersTab.returned),
          ),
          const SizedBox(width: 8),
          _OrdersTabChip(
            label: 'Partially Returned',
            icon: Icons.history,
            selected: selected == _OrdersTab.partiallyReturned,
            onTap: () => onChanged(_OrdersTab.partiallyReturned),
          ),
          const SizedBox(width: 8),
          _OrdersTabChip(
            label: 'Cancelled',
            icon: Icons.cancel_outlined,
            selected: selected == _OrdersTab.cancelled,
            onTap: () => onChanged(_OrdersTab.cancelled),
          ),
          const SizedBox(width: 8),
          _OrdersTabChip(
            label: 'Flagged',
            icon: Icons.flag_outlined,
            selected: selected == _OrdersTab.flagged,
            onTap: () => onChanged(_OrdersTab.flagged),
            isWarning: true,
          ),
        ],
      ),
    );
  }
}

class _OrdersTabChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final bool isWarning;

  const _OrdersTabChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.isWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    final warningColor = Colors.red.shade600;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: selected
                ? Colors.white
                : (isWarning ? warningColor : Colors.grey.shade700),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 13,
              color: selected
                  ? Colors.white
                  : (isWarning ? warningColor : Colors.grey.shade700),
            ),
          ),
        ],
      ),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: isWarning ? warningColor : const Color(0xFF1F2A7A),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selected
              ? (isWarning ? warningColor : const Color(0xFF1F2A7A))
              : (isWarning
                    ? warningColor.withValues(alpha: 0.5)
                    : Colors.grey.shade300),
        ),
      ),
    );
  }
}

class _OrdersStatsRow extends StatelessWidget {
  final _OrdersStats stats;

  const _OrdersStatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _StatPill(label: 'Total', value: stats.total, icon: Icons.list_alt),
          const SizedBox(width: 8),
          _StatPill(
            label: 'Scheduled',
            value: stats.scheduled,
            icon: Icons.calendar_today,
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 8),
          _StatPill(
            label: 'Ongoing',
            value: stats.ongoing,
            icon: Icons.play_circle_outline,
            color: Colors.orange.shade600,
          ),
          const SizedBox(width: 8),
          _StatPill(
            label: 'Late',
            value: stats.late,
            icon: Icons.warning_amber_rounded,
            color: Colors.red.shade600,
          ),
          const SizedBox(width: 8),
          _StatPill(
            label: 'Returned',
            value: stats.returned,
            icon: Icons.check_circle_outline,
            color: Colors.green.shade600,
          ),
          const SizedBox(width: 8),
          _StatPill(
            label: 'Partially Returned',
            value: stats.partiallyReturned,
            icon: Icons.history,
            color: Color(0xFF1F2A7A),
          ),
          const SizedBox(width: 8),
          _StatPill(
            label: 'Cancelled',
            value: stats.cancelled,
            icon: Icons.cancel_outlined,
            color: Colors.grey.shade500,
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color? color;

  const _StatPill({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = color ?? Colors.grey.shade700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: baseColor),
          const SizedBox(width: 6),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: baseColor,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

class _OrderCardItem extends ConsumerStatefulWidget {
  final Order order;

  const _OrderCardItem({required this.order});

  @override
  ConsumerState<_OrderCardItem> createState() => _OrderCardItemState();
}

class _OrderCardItemState extends ConsumerState<_OrderCardItem> {
  bool _isUpdating = false;

  // Helper function to parse datetime with timezone handling
  DateTime _parseDateTimeWithTimezone(String dateString) {
    try {
      final trimmed = dateString.trim();
      final hasTimezone = trimmed.endsWith('Z') || 
                         RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(trimmed);
      
      if (hasTimezone) {
        return DateTime.parse(trimmed).toLocal();
      } else {
        final parsed = DateTime.parse(trimmed);
        final utcDate = DateTime.utc(
          parsed.year, parsed.month, parsed.day,
          parsed.hour, parsed.minute, parsed.second, 
          parsed.millisecond, parsed.microsecond
        );
        return utcDate.toLocal();
      }
    } catch (e) {
      return DateTime.now();
    }
  }

  _OrderCategory _getOrderCategory(Order order) {
    final status = order.status;

    // Fast path: Check status first
    if (status == OrderStatus.cancelled) return _OrderCategory.cancelled;
    if (status == OrderStatus.flagged) return _OrderCategory.flagged;
    if (status == OrderStatus.partiallyReturned)
      return _OrderCategory.partiallyReturned;
    if (status == OrderStatus.completed || 
        status == OrderStatus.completedWithIssues) {
      return _OrderCategory.returned;
    }

    // ⚠️ CRITICAL: Scheduled orders ALWAYS return "scheduled" regardless of date
    // Do NOT check dates for scheduled orders - they remain scheduled until explicitly started
    if (status == OrderStatus.scheduled) {
      return _OrderCategory.scheduled;
    }

    // Check for partial returns via items (if status is active but some items returned)
    if (order.items != null && order.items!.isNotEmpty) {
      final hasReturned = order.items!.any((item) => item.isReturned);
      final hasNotReturned = order.items!.any((item) => item.isPending);

      // If some items are returned but not all, it's partially returned
      if (hasReturned && hasNotReturned) {
        return _OrderCategory.partiallyReturned;
      }
    }

    // Parse dates for active orders
    DateTime? endDate;

    try {
      final endStr = order.endDatetime ?? order.endDate;
      endDate = _parseDateTimeWithTimezone(endStr);
    } catch (e) {
      // If parsing fails, treat as ongoing
      return _OrderCategory.ongoing;
    }

    // Check if late (end date passed and not completed/cancelled/flagged)
    final isLate =
        DateTime.now().isAfter(endDate) &&
        status != OrderStatus.completed &&
        status != OrderStatus.completedWithIssues &&
        status != OrderStatus.flagged &&
        status != OrderStatus.cancelled &&
        status != OrderStatus.partiallyReturned;

    if (isLate) return _OrderCategory.late;
    if (status == OrderStatus.active) return _OrderCategory.ongoing;

    // Default to ongoing
    return _OrderCategory.ongoing;
  }

  Map<String, dynamic> _getDateInfo(Order order) {
    DateTime? startDate;
    DateTime? endDate;

    try {
      final startStr = order.startDatetime ?? order.startDate;
      startDate = _parseDateTimeWithTimezone(startStr);
    } catch (e) {
      return {'error': 'Invalid start date'};
    }

    try {
      final endStr = order.endDatetime ?? order.endDate;
      endDate = _parseDateTimeWithTimezone(endStr);
    } catch (e) {
      return {'error': 'Invalid end date'};
    }

    // Normalize to date only (midnight) to ensure accurate day calculation
    // For rental: same day = 1 day, next day = 1 day (overnight), etc.
    final startDateOnly = DateTime(startDate.year, startDate.month, startDate.day);
    final endDateOnly = DateTime(endDate.year, endDate.month, endDate.day);
    
    final duration = endDateOnly.difference(startDateOnly);
    final daysDifference = duration.inDays;
    // Use same logic as calculateDays: at least 1 day for same-day rentals
    final days = daysDifference < 1 ? 1 : daysDifference;
    
    // Only show hours if days is 0 (shouldn't happen with our logic, but keep for edge cases)
    final hours = days == 0 ? (endDate.difference(startDate).inHours % 24) : 0;

    return {
      'startDate': startDate,
      'endDate': endDate,
      'days': days,
      'hours': hours,
    };
  }

  void _showLateFeeDialog(Order order) {
    final lateFeeController = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Late Fee'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'This order is late. Please enter any late fee (if applicable).',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: lateFeeController,
              decoration: const InputDecoration(
                labelText: 'Late Fee (₹)',
                border: OutlineInputBorder(),
                prefixText: '₹ ',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final lateFee = double.tryParse(lateFeeController.text) ?? 0.0;
              Navigator.pop(context);
              _markAsReturned(order, lateFee);
            },
            child: const Text('Mark as Returned'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleMarkReturned(Order order) async {
    // Navigate to order details screen and scroll to items section
    context.push('/orders/${order.id}?scrollToItems=true');
  }

  Future<void> _markAsReturned(Order order, double lateFee) async {
    setState(() {
      _isUpdating = true;
    });

    try {
      final ordersService = ref.read(ordersServiceProvider);
      await ordersService.updateOrderStatus(
        orderId: order.id,
        status: OrderStatus.completed,
        lateFee: lateFee,
      );

      // Invalidate order queries to refresh the list
      final userProfile = ref.read(userProfileProvider).value;
      final branchId = userProfile?.isSuperAdmin == true 
          ? null 
          : userProfile?.branchId;
      ref.invalidate(ordersProvider(OrdersParams(branchId: branchId)));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order marked as returned'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  Future<void> _handleCancelOrder(Order order) async {
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order'),
        content: Text(
          'Are you sure you want to cancel order ${order.invoiceNumber}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (shouldCancel != true) {
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      final ordersService = ref.read(ordersServiceProvider);
      await ordersService.updateOrderStatus(
        orderId: order.id,
        status: OrderStatus.cancelled,
        lateFee: 0.0,
      );

      // Invalidate order queries to refresh the list
      final userProfile = ref.read(userProfileProvider).value;
      final branchId = userProfile?.isSuperAdmin == true 
          ? null 
          : userProfile?.branchId;
      ref.invalidate(ordersProvider(OrdersParams(branchId: branchId)));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order cancelled successfully'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  Color _statusColor(_OrderCategory category) {
    switch (category) {
      case _OrderCategory.scheduled:
        return Colors.grey.shade600;
      case _OrderCategory.ongoing:
        return Colors.orange.shade600;
      case _OrderCategory.late:
        return Colors.red.shade600;
      case _OrderCategory.returned:
        return Colors.green.shade600;
      case _OrderCategory.partiallyReturned:
        return Color(0xFF1F2A7A);
      case _OrderCategory.cancelled:
        return Colors.grey.shade500;
      case _OrderCategory.flagged:
        return Colors.purple.shade600;
    }
  }

  String _statusText(_OrderCategory category) {
    switch (category) {
      case _OrderCategory.scheduled:
        return 'Scheduled';
      case _OrderCategory.ongoing:
        return 'Ongoing';
      case _OrderCategory.late:
        return 'Late';
      case _OrderCategory.returned:
        return 'Returned';
      case _OrderCategory.partiallyReturned:
        return 'Partial';
      case _OrderCategory.cancelled:
        return 'Cancelled';
      case _OrderCategory.flagged:
        return 'Flagged';
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final category = _getOrderCategory(order);
    final statusColor = _statusColor(category);
    final customerName = order.customer?.name ?? 'Unknown';
    final phone = order.customer?.phone ?? '';
    final dateInfo = _getDateInfo(order);
    // Show return button if order has pending items to return (not scheduled, completed, or cancelled)
    final canMarkReturned =
        order.hasPendingReturnItems && 
        !order.isScheduled && 
        !order.isCompleted && 
        !order.isCancelled;
    final canCancel = order.canCancel();
    final itemsCount = order.items?.length ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: category == _OrderCategory.late
                ? Colors.red.shade200
                : Colors.grey.shade200,
            width: category == _OrderCategory.late ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/orders/${order.id}'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Status, Invoice, Amount
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                constraints: const BoxConstraints(
                                  maxWidth: 120,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: statusColor.withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.circle,
                                      size: 8,
                                      color: statusColor,
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        _statusText(category),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: statusColor,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '#${order.invoiceNumber}',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F1724),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Customer Info
                          Row(
                            children: [
                              Icon(
                                Icons.person_outline,
                                size: 16,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  customerName,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF0F1724),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (phone.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.phone_outlined,
                                  size: 14,
                                  color: Colors.grey.shade500,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  phone,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    Builder(
                      builder: (context) {
                        // Calculate grand total to match order detail screen
                        final userProfile = ref.watch(userProfileProvider).value;
                        final grandTotal = order.calculateGrandTotal(userProfile: userProfile);
                        
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₹${NumberFormat('#,##0').format(grandTotal)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            if (itemsCount > 0)
                              Text(
                                '$itemsCount ${itemsCount == 1 ? 'item' : 'items'}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Date Range Section
                if (!dateInfo.containsKey('error')) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'From',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    DateFormat(
                                      'dd MMM yyyy, hh:mm a',
                                    ).format(dateInfo['startDate'] as DateTime),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF0F1724),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'To',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    DateFormat(
                                      'dd MMM yyyy, hh:mm a',
                                    ).format(dateInfo['endDate'] as DateTime),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF0F1724),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Color(0xFF1F2A7A).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 14,
                                color: Color(0xFF1F2A7A),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                dateInfo['days'] > 0
                                    ? 'Duration: ${dateInfo['days']} day${dateInfo['days'] != 1 ? 's' : ''}'
                                    : 'Duration: ${dateInfo['hours']} hour${dateInfo['hours'] != 1 ? 's' : ''}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1F2A7A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                // Action Buttons
                if (canMarkReturned) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          context.push('/orders/${order.id}?scrollToItems=true'),
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text(
                        'Process Return',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
                if (canCancel) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isUpdating
                          ? null
                          : () => _handleCancelOrder(order),
                      icon: _isUpdating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.red,
                                ),
                              ),
                            )
                          : const Icon(Icons.cancel_outlined, size: 18),
                      label: Text(
                        _isUpdating ? 'Processing...' : 'Cancel Order',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade600,
                        side: BorderSide(
                          color: Colors.red.shade600,
                          width: 1.5,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyOrdersState extends StatelessWidget {
  final VoidCallback onNewOrder;

  const _EmptyOrdersState({required this.onNewOrder});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
              'No orders yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first order to get started',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onNewOrder,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('New Order'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1F2A7A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoResultsState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.search_off, size: 40, color: Colors.grey.shade400),
        ),
        const SizedBox(height: 12),
        Text(
          'No orders match your filters',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Try adjusting the search or filters to see more results.',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Failed to load orders',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(fontSize: 13, color: Colors.red.shade400),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
