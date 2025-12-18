import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../providers/customers_provider.dart';
import '../../models/customer.dart';

/// Customer Filter Type
enum _CustomerFilter {
  all,
  dues,
}

/// Customers List Screen
/// 
/// Modern, attractive customers list with search and stats
class CustomersListScreen extends ConsumerStatefulWidget {
  const CustomersListScreen({super.key});

  @override
  ConsumerState<CustomersListScreen> createState() =>
      _CustomersListScreenState();
}

class _CustomersListScreenState extends ConsumerState<CustomersListScreen> {
  final _searchController = TextEditingController();
  String? _searchQuery; // Used for provider (backend search)
  _CustomerFilter _selectedFilter = _CustomerFilter.all;
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounceTimer;
  final _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
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
          ref.read(customersInfiniteProvider(_searchQuery).notifier).refresh();
        }
      }
    });
  }

  void _onScroll() {
    // Load more when user scrolls to 80% of the list
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      ref.read(customersInfiniteProvider(_searchQuery).notifier).loadMore();
    }
  }

  List<Customer> _filterCustomers(List<Customer> customers) {
    // Apply filter chip (dues/all) - search is handled by backend
    if (_selectedFilter == _CustomerFilter.dues) {
      return customers.where((customer) {
        return customer.dueAmount != null && customer.dueAmount! > 0;
      }).toList();
    }
    return customers;
  }

  Widget _buildCustomersBody(CustomersInfiniteState customersState) {
    if (customersState.isLoading && customersState.customers.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1F2A7A)),
        ),
      );
    }

    if (customersState.error != null && customersState.customers.isEmpty) {
      return _ErrorState(
        message: 'Error loading customers: ${customersState.error}',
        onRetry: () {
          ref.read(customersInfiniteProvider(_searchQuery).notifier).refresh();
        },
      );
    }

    // Apply filter chip filtering (dues/all) - search is handled by backend
    final filteredCustomers = _filterCustomers(customersState.customers);

    // Only the list content rebuilds - search bar and filters are outside Consumer
    return _buildCustomerListBody(
      filteredCustomers,
      customersState.isLoading,
      customersState.isLoadingMore,
    );
  }

  Widget _buildCustomerListBody(List<Customer> filteredCustomers, bool isLoading, bool isLoadingMore) {
    if (filteredCustomers.isEmpty && _searchQuery == null) {
      return _EmptyCustomersState(
        onNewCustomer: () => context.push('/customers/new'),
        hasSearchQuery: false,
      );
    }

    if (filteredCustomers.isEmpty && (_searchQuery != null || _selectedFilter == _CustomerFilter.dues)) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _NoResultsState(),
        ),
      );
    }

    final stats = _calculateStats(filteredCustomers);

    // Only return the scrollable list content - search bar and filters are outside Consumer
    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(customersInfiniteProvider(_searchQuery).notifier).refresh();
      },
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: _CustomersStatsRow(stats: stats),
            ),
          ),
          SliverList.builder(
            itemCount: filteredCustomers.length + (isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= filteredCustomers.length) {
                // Show loading indicator at bottom
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final customer = filteredCustomers[index];
              return _CustomerCardItem(customer: customer);
            },
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 24),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Don't watch provider here - only watch it in the Consumer widget below
    // This prevents the entire screen from rebuilding when search changes
    
    return Scaffold(
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
          'Customers',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F1724),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'customers_fab',
        onPressed: () => context.push('/customers/new'),
        backgroundColor: const Color(0xFF1F2A7A),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text(
          'Add Customer',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      // Use Consumer to isolate provider watching to only the list content
      // Search bar and filters are outside Consumer so they don't rebuild
      body: Column(
        children: [
          // Search Bar (always visible, outside Consumer so it doesn't rebuild)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: _CustomersSearchBar(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: _onSearchChanged,
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          // Filter Chips (always visible, outside Consumer so they don't rebuild)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _CustomerFilterChip(
                  label: 'All',
                  icon: Icons.people_outline,
                  selected: _selectedFilter == _CustomerFilter.all,
                  onTap: () {
                    setState(() {
                      _selectedFilter = _CustomerFilter.all;
                    });
                  },
                ),
                const SizedBox(width: 8),
                _CustomerFilterChip(
                  label: 'Dues',
                  icon: Icons.account_balance_wallet_outlined,
                  selected: _selectedFilter == _CustomerFilter.dues,
                  onTap: () {
                    setState(() {
                      _selectedFilter = _CustomerFilter.dues;
                    });
                  },
                  isWarning: true,
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          // Only this part watches the provider and rebuilds when data changes
          Expanded(
            child: Consumer(
              builder: (context, ref, child) {
                final customersState = ref.watch(customersInfiniteProvider(_searchQuery));
                return _buildCustomersBody(customersState);
              },
            ),
          ),
        ],
      ),
    );
  }

  _CustomersStats _calculateStats(List<Customer> customers) {
    int total = customers.length;
    int withDues = 0;
    double totalDues = 0.0;

    for (final customer in customers) {
      if (customer.dueAmount != null && customer.dueAmount! > 0) {
        withDues++;
        totalDues += customer.dueAmount!;
      }
    }

    return _CustomersStats(
      total: total,
      withDues: withDues,
      totalDues: totalDues,
    );
  }
}

class _CustomersStats {
  final int total;
  final int withDues;
  final double totalDues;

  const _CustomersStats({
    required this.total,
    required this.withDues,
    required this.totalDues,
  });
}

class _CustomerFilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final bool isWarning;

  const _CustomerFilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.isWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    final warningColor = Colors.orange.shade600;
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
              : (isWarning ? warningColor.withValues(alpha: 0.5) : Colors.grey.shade300),
        ),
      ),
    );
  }
}

class _CustomersSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final FocusNode? focusNode;

  const _CustomersSearchBar({
    required this.controller,
    required this.onChanged,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const ValueKey('customer_search_field'),
      controller: controller,
      focusNode: focusNode,
      decoration: InputDecoration(
        hintText: 'Search by name, phone, or customer number',
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

class _CustomersStatsRow extends StatelessWidget {
  final _CustomersStats stats;

  const _CustomersStatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _StatPill(
            label: 'Total',
            value: stats.total,
            icon: Icons.people_outline,
          ),
          const SizedBox(width: 8),
          _StatPill(
            label: 'With Dues',
            value: stats.withDues,
            icon: Icons.account_balance_wallet_outlined,
            color: Colors.orange.shade600,
          ),
          const SizedBox(width: 8),
          _StatPill(
            label: 'Total Dues',
            value: stats.totalDues,
            icon: Icons.currency_rupee,
            color: Colors.red.shade600,
            isAmount: true,
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final dynamic value;
  final IconData icon;
  final Color? color;
  final bool isAmount;

  const _StatPill({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
    this.isAmount = false,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = color ?? Colors.grey.shade700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: baseColor),
          const SizedBox(width: 8),
          Text(
            isAmount
                ? '₹${NumberFormat('#,##0').format(value)}'
                : '$value',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: baseColor,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerCardItem extends StatelessWidget {
  final Customer customer;

  const _CustomerCardItem({required this.customer});

  @override
  Widget build(BuildContext context) {
    final hasDues = customer.dueAmount != null && customer.dueAmount! > 0;
    final initials = customer.name.isNotEmpty
        ? customer.name.split(' ').map((n) => n[0]).take(2).join().toUpperCase()
        : 'CU';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: hasDues ? Colors.orange.shade200 : Colors.grey.shade200,
            width: hasDues ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/customers/${customer.id}'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF1F2A7A),
                        Color(0xFF1F2A7A),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Customer Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  customer.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F1724),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (customer.customerNumber != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    customer.customerNumber!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (hasDues)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.orange.shade200,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    size: 14,
                                    color: Colors.orange.shade700,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '₹${NumberFormat('#,##0').format(customer.dueAmount)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.phone_outlined,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              customer.phone,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                          // Dialer Icon
                          InkWell(
                            onTap: () => _launchDialer(context, customer.phone),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.phone,
                                size: 18,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // WhatsApp Icon
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _launchWhatsApp(context, customer.phone),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF25D366).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const FaIcon(
                                  FontAwesomeIcons.whatsapp,
                                  size: 18,
                                  color: Color(0xFF25D366),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (customer.email != null && customer.email!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.email_outlined,
                              size: 14,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                customer.email!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (customer.idProofType != null) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Color(0xFF1F2A7A).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.verified_outlined,
                                size: 12,
                                color: Color(0xFF1F2A7A),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _getProofTypeLabel(customer.idProofType!),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1F2A7A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: Colors.grey.shade400,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getProofTypeLabel(IdProofType type) {
    switch (type) {
      case IdProofType.aadhar:
        return 'Aadhar';
      case IdProofType.passport:
        return 'Passport';
      case IdProofType.voter:
        return 'Voter ID';
      case IdProofType.others:
        return 'Other ID';
    }
  }

  Future<void> _launchDialer(BuildContext context, String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot launch dialer. Please check your device settings.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error launching dialer: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _launchWhatsApp(BuildContext context, String phoneNumber) async {
    try {
      // Remove any spaces, dashes, or special characters from phone number
      String cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
      
      // Remove + if present (WhatsApp URL doesn't use +)
      if (cleanPhone.startsWith('+')) {
        cleanPhone = cleanPhone.substring(1);
      }
      
      // If phone number doesn't have country code, assume it's an Indian number and add 91
      if (cleanPhone.length == 10) {
        cleanPhone = '91$cleanPhone';
      } else if (cleanPhone.length == 11 && cleanPhone.startsWith('0')) {
        // Handle 0 followed by 10 digits (like 09876543210)
        cleanPhone = '91${cleanPhone.substring(1)}';
      } else if (cleanPhone.length < 10) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid phone number format'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // WhatsApp URL format: https://wa.me/919876543210 (just numbers, no +)
      final Uri whatsappUri = Uri.parse('https://wa.me/$cleanPhone');
      
      // Try to launch WhatsApp directly
      // Using externalApplication mode to ensure it opens in WhatsApp app
      final launched = await launchUrl(
        whatsappUri,
        mode: LaunchMode.externalApplication,
      );
      
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot launch WhatsApp. Please ensure WhatsApp is installed.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error launching WhatsApp: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _EmptyCustomersState extends StatelessWidget {
  final VoidCallback onNewCustomer;
  final bool hasSearchQuery;

  const _EmptyCustomersState({
    required this.onNewCustomer,
    required this.hasSearchQuery,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasSearchQuery ? Icons.search_off : Icons.people_outline,
                size: 56,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              hasSearchQuery ? 'No customers found' : 'No customers yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasSearchQuery
                  ? 'Try adjusting your search to find customers'
                  : 'Create your first customer to get started',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
            if (!hasSearchQuery) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onNewCustomer,
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('New Customer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1F2A7A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
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
          child: Icon(
            Icons.search_off,
            size: 40,
            color: Colors.grey.shade400,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'No customers match your search',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Try adjusting the search query to see more results.',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Failed to load customers',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: Colors.red.shade400,
              ),
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

