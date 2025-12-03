import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/customers_provider.dart';
import '../../providers/orders_provider.dart';
import '../../models/customer.dart';
import '../../models/order.dart';

/// Customer Detail Screen
/// 
/// Modern, attractive customer detail screen with information and order history
class CustomerDetailScreen extends ConsumerWidget {
  final String customerId;

  const CustomerDetailScreen({
    super.key,
    required this.customerId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customerAsync = ref.watch(customerProvider(customerId));
    final ordersAsync = ref.watch(customerOrdersProvider(customerId));

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      body: customerAsync.when(
        data: (customer) {
          if (customer == null) {
            return const Center(
              child: Text('Customer not found'),
            );
          }

          return CustomScrollView(
            slivers: [
              // Modern Header
              SliverAppBar(
                expandedHeight: 200,
                floating: false,
                pinned: true,
                elevation: 0,
                backgroundColor: Colors.white,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => context.pop(),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.white),
                    onPressed: () => context.push('/customers/${customer.id}/edit'),
                    tooltip: 'Edit Customer',
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF0B63FF),
                          const Color(0xFF0052D4),
                        ],
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                // Customer Avatar
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 4,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      customer.name.isNotEmpty
                                          ? customer.name
                                              .split(' ')
                                              .map((n) => n[0])
                                              .take(2)
                                              .join()
                                              .toUpperCase()
                                          : 'CU',
                                      style: const TextStyle(
                                        color: Color(0xFF0B63FF),
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        customer.name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (customer.customerNumber != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          customer.customerNumber!,
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.9),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Content
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Quick Actions (Call & WhatsApp)
                      _QuickActionsCard(
                        phoneNumber: customer.phone,
                      ),
                      const SizedBox(height: 16),

                      // Quick Stats Card
                      ordersAsync.when(
                        data: (orders) {
                          if (orders.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Column(
                            children: [
                              _CustomerStatsCard(orders: orders),
                              const SizedBox(height: 16),
                            ],
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),

                      // Due Amount Card (if applicable)
                      if (customer.dueAmount != null && customer.dueAmount! > 0)
                        _DueAmountCard(
                          amount: customer.dueAmount!,
                        ),
                      if (customer.dueAmount != null && customer.dueAmount! > 0)
                        const SizedBox(height: 16),

                      // Contact Information Card
                      _ContactInfoCard(customer: customer),
                      const SizedBox(height: 16),

                      // ID Proof Card (if available)
                      if (customer.idProofType != null)
                        _IdProofCard(customer: customer),
                      if (customer.idProofType != null) const SizedBox(height: 16),

                      // Order History Section
                      Row(
                        children: [
                          Icon(
                            Icons.history,
                            color: Colors.grey.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Order History',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F1724),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Orders List
                      ordersAsync.when(
                        data: (orders) {
                          if (orders.isEmpty) {
                            return _EmptyOrdersState();
                          }
                          return Column(
                            children: orders.map((order) {
                              return _OrderCard(order: order);
                            }).toList(),
                          );
                        },
                        loading: () => const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF0B63FF),
                              ),
                            ),
                          ),
                        ),
                        error: (error, stack) => _ErrorCard(
                          message: 'Error loading orders: $error',
                          onRetry: () {
                            ref.invalidate(customerOrdersProvider(customerId));
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0B63FF)),
          ),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Error loading customer',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.red.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: TextStyle(color: Colors.red.shade400),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionsCard extends StatelessWidget {
  final String phoneNumber;

  const _QuickActionsCard({required this.phoneNumber});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: Icons.phone,
                label: 'Call',
                color: Colors.green,
                onTap: () => _launchDialer(context, phoneNumber),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionButton(
                icon: FontAwesomeIcons.whatsapp,
                label: 'WhatsApp',
                color: const Color(0xFF25D366),
                isFaIcon: true,
                onTap: () => _launchWhatsApp(context, phoneNumber),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchDialer(BuildContext context, String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      await launchUrl(phoneUri);
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
      String cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
      if (cleanPhone.startsWith('+')) {
        cleanPhone = cleanPhone.substring(1);
      }
      if (cleanPhone.length == 10) {
        cleanPhone = '91$cleanPhone';
      } else if (cleanPhone.length == 11 && cleanPhone.startsWith('0')) {
        cleanPhone = '91${cleanPhone.substring(1)}';
      }

      final Uri whatsappUri = Uri.parse('https://wa.me/$cleanPhone');
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
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

class _ActionButton extends StatelessWidget {
  final dynamic icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isFaIcon;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isFaIcon = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.3),
          ),
        ),
        child: Column(
          children: [
            isFaIcon
                ? FaIcon(
                    icon,
                    size: 24,
                    color: color,
                  )
                : Icon(
                    icon,
                    size: 24,
                    color: color,
                  ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DueAmountCard extends StatelessWidget {
  final double amount;

  const _DueAmountCard({required this.amount});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.orange.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.orange.shade200,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.account_balance_wallet,
                color: Colors.orange.shade700,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Outstanding Balance',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${NumberFormat('#,##0').format(amount)}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange.shade700,
              size: 28,
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactInfoCard extends StatelessWidget {
  final Customer customer;

  const _ContactInfoCard({required this.customer});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.contact_phone,
                  color: Colors.blue.shade600,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Contact Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F1724),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _InfoRow(
              icon: Icons.phone_outlined,
              label: 'Phone',
              value: customer.phone,
              color: Colors.green,
            ),
            if (customer.email != null && customer.email!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _InfoRow(
                icon: Icons.email_outlined,
                label: 'Email',
                value: customer.email!,
                color: Colors.blue,
              ),
            ],
            if (customer.address != null && customer.address!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _InfoRow(
                icon: Icons.location_on_outlined,
                label: 'Address',
                value: customer.address!,
                color: Colors.red,
              ),
            ],
            if (customer.createdAt != null) ...[
              const SizedBox(height: 12),
              _InfoRow(
                icon: Icons.calendar_today_outlined,
                label: 'Member Since',
                value: DateFormat('dd MMM yyyy').format(customer.createdAt!),
                color: const Color(0xFF0B63FF),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: color,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F1724),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _IdProofCard extends StatelessWidget {
  final Customer customer;

  const _IdProofCard({required this.customer});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.verified_outlined,
                  color: Colors.blue.shade600,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'ID Proof',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F1724),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.badge_outlined,
                    color: Colors.blue.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getProofTypeLabel(customer.idProofType!),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        if (customer.idProofNumber != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            customer.idProofNumber!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (customer.idProofFrontUrl != null ||
                customer.idProofBackUrl != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  if (customer.idProofFrontUrl != null)
                    _IdProofImage(
                      url: customer.idProofFrontUrl!,
                      label: 'Front',
                    ),
                  if (customer.idProofBackUrl != null)
                    _IdProofImage(
                      url: customer.idProofBackUrl!,
                      label: 'Back',
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getProofTypeLabel(IdProofType type) {
    switch (type) {
      case IdProofType.aadhar:
        return 'Aadhar Card';
      case IdProofType.passport:
        return 'Passport';
      case IdProofType.voter:
        return 'Voter ID';
      case IdProofType.others:
        return 'Other ID';
    }
  }
}

class _IdProofImage extends StatelessWidget {
  final String url;
  final String label;

  const _IdProofImage({
    required this.url,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        // Show full screen image
        showDialog(
          context: context,
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: Stack(
              children: [
                Center(
                  child: InteractiveViewer(
                    child: CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.contain,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(),
                      ),
                      errorWidget: (context, url, error) => const Icon(
                        Icons.error,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 40,
                  right: 20,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: url,
                width: 100,
                height: 100,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey.shade200,
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.error),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;

  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(order.status);
    final statusIcon = _getStatusIcon(order.status);

    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.grey.shade200,
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.receipt_long,
                      color: Colors.blue.shade700,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.invoiceNumber,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F1724),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatOrderDate(order),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
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
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          statusIcon,
                          size: 14,
                          color: statusColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatStatus(order.status),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Amount',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₹${NumberFormat('#,##0.00').format(order.totalAmount)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F1724),
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.scheduled:
        return Colors.grey;
      case OrderStatus.active:
        return Colors.green;
      case OrderStatus.pendingReturn:
        return Colors.orange;
      case OrderStatus.completed:
        return Colors.blue;
      case OrderStatus.cancelled:
        return Colors.red;
      case OrderStatus.partiallyReturned:
        return Colors.blue;
    }
  }

  IconData _getStatusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.scheduled:
        return Icons.calendar_today;
      case OrderStatus.active:
        return Icons.check_circle;
      case OrderStatus.pendingReturn:
        return Icons.schedule;
      case OrderStatus.completed:
        return Icons.done_all;
      case OrderStatus.cancelled:
        return Icons.cancel;
      case OrderStatus.partiallyReturned:
        return Icons.history;
    }
  }

  String _formatStatus(OrderStatus status) {
    switch (status) {
      case OrderStatus.scheduled:
        return 'Scheduled';
      case OrderStatus.active:
        return 'Active';
      case OrderStatus.pendingReturn:
        return 'Pending Return';
      case OrderStatus.completed:
        return 'Completed';
      case OrderStatus.cancelled:
        return 'Cancelled';
      case OrderStatus.partiallyReturned:
        return 'Partially Returned';
    }
  }

  String _formatOrderDate(Order order) {
    try {
      final date = DateTime.parse(order.createdAt.toString());
      return DateFormat('dd MMM yyyy, hh:mm a').format(date);
    } catch (e) {
      return 'N/A';
    }
  }
}

class _EmptyOrdersState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(
              Icons.shopping_bag_outlined,
              size: 64,
              color: Colors.grey.shade400,
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
              'This customer hasn\'t placed any orders',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.red.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.red.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red.shade700,
            ),
            const SizedBox(height: 12),
            Text(
              'Failed to load orders',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: Colors.red.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
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

/// Customer Stats Card
/// 
/// Displays quick statistics: Total Orders, Total Spent, Active Rentals
class _CustomerStatsCard extends StatelessWidget {
  final List<Order> orders;

  const _CustomerStatsCard({required this.orders});

  int get totalOrders => orders.length;

  double get totalSpent {
    return orders.fold(0.0, (sum, order) => sum + order.totalAmount);
  }

  int get activeRentals {
    return orders.where((order) {
      return order.isActive || 
             order.isPendingReturn || 
             order.isPartiallyReturned ||
             order.isScheduled;
    }).length;
  }

  /// Format number with simplified notation (1k, 20.8k, 1.5M, etc.)
  String _formatSimplifiedAmount(double amount) {
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
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.bar_chart_outlined,
                  size: 20,
                  color: Colors.indigo.shade600,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Quick Stats',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F1724),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                // Total Orders
                Expanded(
                  child: _StatItem(
                    icon: Icons.receipt_long_outlined,
                    label: 'Total Orders',
                    value: totalOrders.toString(),
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                // Total Spent
                Expanded(
                  child: _StatItem(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Total Spent',
                    value: _formatSimplifiedAmount(totalSpent),
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                // Active Rentals
                Expanded(
                  child: _StatItem(
                    icon: Icons.local_activity_outlined,
                    label: 'Active Rental',
                    value: activeRentals.toString(),
                    color: Colors.orange,
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

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 24,
            color: color,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
