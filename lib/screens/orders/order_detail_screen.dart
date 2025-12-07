import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../providers/orders_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/order.dart';
import '../../models/order_item.dart';
import '../../services/invoice_service.dart';
import '../../services/orders_service.dart';

/// Order Detail Screen
///
/// Displays detailed information about a specific order with modern design
class OrderDetailScreen extends ConsumerStatefulWidget {
  final String orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  bool _isUpdating = false;
  bool _isViewingInvoice = false;
  bool _isSharingInvoice = false;
  bool _isDownloadingInvoice = false;
  bool _isPrintingInvoice = false;

  Future<void> _handleInvoiceAction(String action, Order order) async {
    // Set loading state for specific action
    switch (action) {
      case 'view':
        setState(() {
          _isViewingInvoice = true;
        });
        break;
      case 'share':
        setState(() {
          _isSharingInvoice = true;
        });
        break;
        case 'download':
          setState(() {
            _isDownloadingInvoice = true;
          });
          break;
        case 'print':
          setState(() {
            _isPrintingInvoice = true;
          });
          break;
    }

    try {
      switch (action) {
        case 'view':
          await InvoiceService.viewInvoice(order);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Invoice opened'),
                backgroundColor: Colors.green.shade600,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            );
          }
          break;

        case 'share':
          await InvoiceService.shareOnWhatsApp(order);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Share Invoice on WhatsApp',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Select WhatsApp from the share dialog and choose the customer contact',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                backgroundColor: Colors.green.shade600,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                duration: const Duration(seconds: 3),
              ),
            );
          }
          break;

        case 'download':
          await InvoiceService.downloadInvoice(order);
          if (mounted) {
            // Show message after a short delay to allow dialog to appear first
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Save Invoice to Downloads',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'In the share dialog, select "Save to Downloads" or "Save to Files"',
                          style: TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Look for "Downloads" folder option in the dialog to save the file',
                          style: TextStyle(fontSize: 11, color: Colors.white70),
                        ),
                      ],
                    ),
                    backgroundColor: Colors.blue.shade700,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    duration: const Duration(seconds: 6),
                    margin: const EdgeInsets.all(16),
                  ),
                );
              }
            });
          }
          break;

        case 'print':
          await InvoiceService.printInvoice(order);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Print dialog opened'),
                backgroundColor: Colors.blue.shade600,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            );
          }
          break;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          switch (action) {
            case 'view':
              _isViewingInvoice = false;
              break;
            case 'share':
              _isSharingInvoice = false;
              break;
            case 'download':
              _isDownloadingInvoice = false;
              break;
            case 'print':
              _isPrintingInvoice = false;
              break;
          }
        });
      }
    }
  }


  Map<String, dynamic> _getDateInfo(Order order) {
    DateTime? startDate;
    DateTime? endDate;

    try {
      final startStr = order.startDatetime ?? order.startDate;
      startDate = DateTime.parse(startStr);
    } catch (e) {
      return {'error': 'Invalid start date'};
    }

    try {
      final endStr = order.endDatetime ?? order.endDate;
      endDate = DateTime.parse(endStr);
    } catch (e) {
      return {'error': 'Invalid end date'};
    }

    final duration = endDate.difference(startDate);
    final days = duration.inDays;
    final hours = duration.inHours % 24;

    return {
      'startDate': startDate,
      'endDate': endDate,
      'days': days,
      'hours': hours,
    };
  }

  _OrderCategory _getOrderCategory(Order order) {
    final status = order.status;
    
    // Fast path: Check status first
    if (status == OrderStatus.cancelled) return _OrderCategory.cancelled;
    if (status == OrderStatus.flagged) return _OrderCategory.flagged;
    if (status == OrderStatus.partiallyReturned) return _OrderCategory.partiallyReturned;
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
      endDate = DateTime.parse(endStr);
    } catch (e) {
      // If parsing fails, treat as ongoing
      return _OrderCategory.ongoing;
    }
    
    // Check if late (end date passed and not completed/cancelled)
    final isLate = DateTime.now().isAfter(endDate) && 
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

  /// Check if order is currently late
  bool _isOrderLate(Order order) {
    if (order.isCompleted || order.isCancelled || order.isScheduled) {
      return false;
    }

    try {
      final endStr = order.endDatetime ?? order.endDate;
      final endDate = DateTime.parse(endStr);
      return DateTime.now().isAfter(endDate);
    } catch (e) {
      return false;
    }
  }

  /// Calculate days overdue for a late order
  int _getDaysOverdue(Order order) {
    try {
      final endStr = order.endDatetime ?? order.endDate;
      final endDate = DateTime.parse(endStr);
      final now = DateTime.now();
      if (now.isAfter(endDate)) {
        return now.difference(endDate).inDays;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  Color _getCategoryColor(_OrderCategory category) {
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
        return Colors.blue.shade600;
      case _OrderCategory.cancelled:
        return Colors.grey.shade500;
      case _OrderCategory.flagged:
        return Colors.purple.shade600;
    }
  }

  String _getCategoryText(_OrderCategory category) {
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
        return 'Partially Returned';
      case _OrderCategory.cancelled:
        return 'Cancelled';
      case _OrderCategory.flagged:
        return 'Flagged';
    }
  }
  
  Future<void> _handleCancelOrder(Order order) async {
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Cancel Order',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        content: Text(
          'Are you sure you want to cancel order ${order.invoiceNumber}? This action cannot be undone.',
          style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'No',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
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

      final branchId = ref.read(userProfileProvider).value?.branchId;
      ref.invalidate(orderProvider(widget.orderId));
      ref.invalidate(ordersProvider(OrdersParams(branchId: branchId)));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Order cancelled successfully'),
            backgroundColor: Colors.orange.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
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

  Future<void> _handleStartRental(Order order) async {
    final shouldStart = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start Rental'),
        content: Text(
          'Are you sure you want to start rental for order ${order.invoiceNumber}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.orange,
            ),
            child: const Text('Start Rental'),
          ),
        ],
      ),
    );

    if (shouldStart != true) {
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      final ordersService = ref.read(ordersServiceProvider);
      await ordersService.startRental(order.id);

      // Invalidate order queries to refresh
      ref.invalidate(orderProvider(widget.orderId));
      final branchId = ref.read(userProfileProvider).value?.branchId;
      if (branchId != null) {
        ref.invalidate(ordersProvider(OrdersParams(branchId: branchId)));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rental started successfully'),
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

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(orderProvider(widget.orderId));

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F1724)),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Order Details',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F1724),
          ),
        ),
        actions: [
          orderAsync.when(
            data: (order) {
              if (order != null) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Start Rental button for scheduled orders
                    if (order.isScheduled)
                      IconButton(
                        icon: const Icon(
                          Icons.play_arrow,
                          color: Colors.orange,
                        ),
                        onPressed: _isUpdating ? null : () => _handleStartRental(order),
                        tooltip: 'Start Rental',
                      ),
                    // Invoice Actions Menu
                    PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_vert,
                        color: Color(0xFF0F1724),
                      ),
                      onSelected: (value) => _handleInvoiceAction(value, order),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'view',
                          child: Row(
                            children: [
                              Icon(
                                Icons.visibility_outlined,
                                size: 20,
                                color: Color(0xFF0F1724),
                              ),
                              SizedBox(width: 12),
                              Text('View Invoice'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'share',
                          child: Row(
                            children: [
                              FaIcon(
                                FontAwesomeIcons.whatsapp,
                                size: 18,
                                color: Colors.green,
                              ),
                              SizedBox(width: 12),
                              Text('Share on WhatsApp'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'download',
                          child: Row(
                            children: [
                              Icon(
                                Icons.download_outlined,
                                size: 20,
                                color: Color(0xFF0F1724),
                              ),
                              SizedBox(width: 12),
                              Text('Download PDF'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: orderAsync.when(
        data: (order) {
          if (order == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Order not found',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade700),
                  ),
                ],
              ),
            );
          }

          final category = _getOrderCategory(order);
          final categoryColor = _getCategoryColor(category);
          final categoryText = _getCategoryText(category);
          final dateInfo = _getDateInfo(order);
          // Show return button if order has pending items to return (not scheduled, completed, cancelled, or flagged)
          final canMarkReturned = !order.isScheduled && 
                                  !order.isCompleted && 
                                  !order.isCancelled &&
                                  !order.isFlagged &&
                                  order.hasPendingReturnItems;
          final canStartRental = order.isScheduled;
          final canCancel = order.canCancel();
          final canEdit = order.canEdit;

          // Calculate bottom padding based on number of buttons
          int buttonCount = 0;
          if (canStartRental) buttonCount++;
          if (canMarkReturned) buttonCount++;
          if (canEdit) buttonCount++;
          if (canCancel) buttonCount++;
          
          // Calculate bottom padding to ensure pricing breakdown is fully visible
          // Button height: ~56px each, spacing: 8px between buttons, container padding: 32px (16 top + 16 bottom)
          // SafeArea bottom padding: ~34px, plus extra buffer: 20px
          final bottomPadding = buttonCount > 0
              ? (buttonCount * 56.0) + ((buttonCount - 1) * 8.0) + 32.0 + 34.0 + 20.0
              : 16.0;

          return Stack(
            children: [
              SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: bottomPadding,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Card with Status and Invoice
                    Card(
                      elevation: 0,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: category == _OrderCategory.late
                              ? Colors.red.shade200
                              : category == _OrderCategory.flagged
                                  ? Colors.purple.shade200
                                  : Colors.grey.shade200,
                          width: (category == _OrderCategory.late || category == _OrderCategory.flagged) ? 1.5 : 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: categoryColor.withOpacity(
                                            0.12,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: categoryColor.withOpacity(
                                              0.3,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.circle,
                                              size: 8,
                                              color: categoryColor,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              categoryText,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: categoryColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Invoice #${order.invoiceNumber}',
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0F1724),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      if (order.bookingDate != null) ...[
                                        Text(
                                          'Booking Date: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(order.bookingDate!))}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                      ],
                                      Text(
                                        'Created ${DateFormat('dd MMM yyyy, hh:mm a').format(order.createdAt)}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Total Amount',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '₹${NumberFormat('#,##0.00').format(order.totalAmount)}',
                                      style: const TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Customer Card (moved to top)
                    Card(
                      elevation: 0,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: order.customer != null
                            ? () => context.push(
                                '/customers/${order.customer!.id}',
                              )
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: Colors.purple.shade100,
                                child: Icon(
                                  Icons.person,
                                  color: Colors.purple.shade600,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.person_outline,
                                          size: 16,
                                          color: Colors.purple.shade600,
                                        ),
                                        const SizedBox(width: 6),
                                        const Text(
                                          'Customer',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF0F1724),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      order.customer?.name ?? 'Unknown',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0F1724),
                                      ),
                                    ),
                                    if (order.customer?.phone != null) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.phone_outlined,
                                            size: 14,
                                            color: Colors.grey.shade600,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            order.customer?.phone ?? '',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (order.customer != null)
                                Icon(
                                  Icons.arrow_forward_ios,
                                  size: 18,
                                  color: Colors.grey.shade400,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Invoice Actions Card
                    Card(
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
                                  Icons.receipt_long_outlined,
                                  size: 20,
                                  color: Colors.teal.shade600,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Invoice Actions',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F1724),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 48,
                                    child: OutlinedButton.icon(
                                      onPressed:
                                          (_isViewingInvoice ||
                                              _isSharingInvoice ||
                                              _isDownloadingInvoice ||
                                              _isPrintingInvoice)
                                          ? null
                                          : () => _handleInvoiceAction(
                                              'view',
                                              order,
                                            ),
                                      icon: _isViewingInvoice
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.visibility_outlined,
                                              size: 18,
                                            ),
                                      label: const Text(
                                        'View',
                                        style: TextStyle(fontSize: 13),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(
                                          0xFF0F1724,
                                        ),
                                        side: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: SizedBox(
                                    height: 48,
                                    child: OutlinedButton.icon(
                                      onPressed:
                                          (_isViewingInvoice ||
                                              _isSharingInvoice ||
                                              _isDownloadingInvoice ||
                                              _isPrintingInvoice)
                                          ? null
                                          : () => _handleInvoiceAction(
                                              'share',
                                              order,
                                            ),
                                      icon: _isSharingInvoice
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const FaIcon(
                                              FontAwesomeIcons.whatsapp,
                                              size: 18,
                                              color: Colors.green,
                                            ),
                                      label: const Text(
                                        'WhatsApp',
                                        style: TextStyle(fontSize: 13),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.green.shade700,
                                        side: BorderSide(
                                          color: Colors.green.shade300,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 48,
                                    child: OutlinedButton.icon(
                                      onPressed:
                                          (_isViewingInvoice ||
                                              _isSharingInvoice ||
                                              _isDownloadingInvoice ||
                                              _isPrintingInvoice)
                                          ? null
                                          : () => _handleInvoiceAction(
                                              'download',
                                              order,
                                            ),
                                      icon: _isDownloadingInvoice
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.download_outlined,
                                              size: 18,
                                            ),
                                      label: const Text(
                                        'Download',
                                        style: TextStyle(fontSize: 13),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(
                                          0xFF0F1724,
                                        ),
                                        side: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: SizedBox(
                                    height: 48,
                                    child: OutlinedButton.icon(
                                      onPressed:
                                          (_isViewingInvoice ||
                                              _isSharingInvoice ||
                                              _isDownloadingInvoice ||
                                              _isPrintingInvoice)
                                          ? null
                                          : () => _handleInvoiceAction(
                                              'print',
                                              order,
                                            ),
                                      icon: _isPrintingInvoice
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.print_outlined,
                                              size: 18,
                                            ),
                                      label: const Text(
                                        'Print',
                                        style: TextStyle(fontSize: 13),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(
                                          0xFF0F1724,
                                        ),
                                        side: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Rental Period Card
                    if (!dateInfo.containsKey('error')) ...[
                      Card(
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
                                    Icons.calendar_today,
                                    size: 20,
                                    color: Colors.blue.shade600,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Rental Period',
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
                                  Expanded(
                                    child: _DateInfoWidget(
                                      label: 'From',
                                      date: dateInfo['startDate'] as DateTime,
                                    ),
                                  ),
                                  Container(
                                    width: 1,
                                    height: 60,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    color: Colors.grey.shade300,
                                  ),
                                  Expanded(
                                    child: _DateInfoWidget(
                                      label: 'To',
                                      date: dateInfo['endDate'] as DateTime,
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
                                      Icons.access_time,
                                      size: 18,
                                      color: Colors.blue.shade700,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Duration: ${dateInfo['days']} day${dateInfo['days'] != 1 ? 's' : ''} ${dateInfo['hours']} hour${dateInfo['hours'] != 1 ? 's' : ''}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.blue.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Order Timeline Card
                    Card(
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
                                  Icons.timeline_outlined,
                                  size: 20,
                                  color: Colors.indigo.shade600,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Order Timeline',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F1724),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            _OrderTimelineWidget(order: order),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Items Card
                    if (order.items != null && order.items!.isNotEmpty) ...[
                      Card(
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
                                    Icons.inventory_2_outlined,
                                    size: 20,
                                    color: Colors.indigo.shade600,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Order Items',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F1724),
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.indigo.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${order.items!.length} ${order.items!.length == 1 ? 'item' : 'items'}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.indigo.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              ...order.items!.asMap().entries.map((entry) {
                                final index = entry.key;
                                final item = entry.value;
                                return _OrderItemCard(
                                  item: item,
                                  index: index + 1,
                                  isLast: index == order.items!.length - 1,
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Return Status Section (only show if order has items and is not scheduled)
                    if (order.items != null && 
                        order.items!.isNotEmpty && 
                        !order.isScheduled) ...[
                      Card(
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
                              // Header with icon
                              Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: Colors.indigo.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.assignment_return_outlined,
                                      size: 18,
                                      color: Colors.indigo.shade700,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Return Status',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F1724),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Divider(color: Colors.grey.shade200, height: 1),
                              const SizedBox(height: 16),
                              
                              // Calculate return statistics
                              Builder(
                                builder: (context) {
                                  final items = order.items!;
                                  final totalItems = items.length;
                                  final totalQuantity = items.fold<int>(
                                    0, 
                                    (sum, item) => sum + item.quantity,
                                  );
                                  
                                  // Website logic (matching exact behavior):
                                  // - RETURNED quantity: Sum of returnedQuantity from ALL items
                                  //   For items with returnStatus = 'returned', if returnedQuantity is null, use item.quantity
                                  //   For items without returnStatus = 'returned', use returnedQuantity (for partial returns)
                                  // - Full/Partial: Count items with returnStatus = 'returned', then check if full or partial
                                  // - PENDING: Items that are not marked as returned (returnStatus != 'returned')
                                  
                                  // Calculate total returned quantity from ALL items
                                  final returnedQuantity = items.fold<int>(
                                    0,
                                    (sum, item) {
                                      int returnedQty;
                                      if (item.isReturned) {
                                        // Item is marked as returned: use returnedQuantity if available, otherwise item.quantity
                                        returnedQty = item.returnedQuantity ?? item.quantity;
                                      } else {
                                        // Item is not marked as returned: use returnedQuantity (could be partial return)
                                        returnedQty = item.returnedQuantity ?? 0;
                                      }
                                      return sum + returnedQty;
                                    },
                                  );
                                  
                                  // Get items that are marked as returned (returnStatus = 'returned') for full/partial count
                                  final returnedItems = items.where((item) => item.isReturned).toList();
                                  
                                  // Count items with full returns (returned quantity >= item quantity) among returned items
                                  final fullReturns = returnedItems.where((item) {
                                    // If returnedQuantity is null and status is returned, it's fully returned
                                    final returnedQty = item.returnedQuantity ?? item.quantity;
                                    return returnedQty >= item.quantity;
                                  }).length;
                                  
                                  // Count items with partial returns (returned quantity > 0 but < item quantity) among returned items
                                  final partialReturns = returnedItems.where((item) {
                                    // Partial if returnedQuantity exists, is > 0, and is less than quantity
                                    final returnedQty = item.returnedQuantity;
                                    if (returnedQty == null) return false; // null means full return
                                    return returnedQty > 0 && returnedQty < item.quantity;
                                  }).length;
                                  
                                  // Calculate pending items - Website logic:
                                  // PENDING count = items where returnStatus != 'returned' (not marked as returned)
                                  // PENDING quantity = sum of remaining quantity for ALL items where returnedQuantity < quantity
                                  final pendingItems = items.where((item) => !item.isReturned).toList();
                                  final pendingCount = pendingItems.length;
                                  
                                  // Calculate total pending quantity from ALL items (not just pending items)
                                  // This includes items that are marked as returned but have partial returns
                                  final pendingQuantity = items.fold<int>(
                                    0,
                                    (sum, item) {
                                      final returnedQty = item.returnedQuantity ?? 0;
                                      // If item is marked as returned and returnedQuantity is null, assume fully returned
                                      if (item.isReturned && item.returnedQuantity == null) {
                                        return sum; // Fully returned, no pending quantity
                                      }
                                      // Calculate remaining quantity
                                      final remaining = item.quantity - returnedQty;
                                      // Only add if there's remaining quantity
                                      return sum + (remaining > 0 ? remaining : 0);
                                    },
                                  );
                                  
                                  // Get total damage cost from order (damage_fee_total)
                                  final totalDamage = order.damageFeeTotal ?? 0.0;
                                  
                                  // Debug: Check damage fee total value
                                  print('🔍 Order Damage Fee Total: ${order.damageFeeTotal}');
                                  print('🔍 Total Damage: $totalDamage');
                                  
                                  // Determine overall status
                                  String overallStatus;
                                  Color statusBgColor;
                                  Color statusValueColor;
                                  String statusDetail = '';
                                  Color statusDetailColor = Colors.grey.shade600;
                                  
                                  // Determine status based on website logic
                                  // Check if all items are fully returned (returnedQuantity >= item quantity for all)
                                  final allItemsReturned = items.every((item) {
                                    // If item is marked as returned and returnedQuantity is null, it's fully returned
                                    // Otherwise check if returnedQuantity >= quantity
                                    final returnedQty = item.isReturned && item.returnedQuantity == null
                                        ? item.quantity
                                        : (item.returnedQuantity ?? 0);
                                    return returnedQty >= item.quantity;
                                  });
                                  
                                  // Check if some items have returns but not all are fully returned
                                  final hasSomeReturns = returnedQuantity > 0;
                                  final hasPendingQuantity = pendingQuantity > 0; // Check pending quantity, not just count
                                  
                                  // Website logic: Show "Partial" if there's pending quantity, even if all items are marked as returned
                                  if (allItemsReturned && !hasPendingQuantity && returnedQuantity > 0) {
                                    // All items fully returned with no pending quantity
                                    overallStatus = 'Returned';
                                    statusBgColor = Colors.green.shade50;
                                    statusValueColor = Colors.green.shade700;
                                  } else if (hasSomeReturns && hasPendingQuantity) {
                                    // Partial: Some items returned but there's still pending quantity
                                    overallStatus = 'Partial';
                                    statusBgColor = Colors.blue.shade50;
                                    statusValueColor = Colors.blue.shade700;
                                  } else if (hasSomeReturns && !hasPendingQuantity) {
                                    // All items fully returned (no pending quantity)
                                    overallStatus = 'Returned';
                                    statusBgColor = Colors.green.shade50;
                                    statusValueColor = Colors.green.shade700;
                                  } else {
                                    // No returns yet
                                    overallStatus = 'Pending';
                                    // Use indigo/purple for STATUS to differentiate from orange PENDING box
                                    statusBgColor = Colors.indigo.shade50;
                                    statusValueColor = Colors.indigo.shade700;
                                  }
                                  
                                  // Add damage information to status detail if there's damage
                                  // Always show damage if damage_fee_total exists and is greater than 0
                                  if (order.damageFeeTotal != null && order.damageFeeTotal! > 0) {
                                    statusDetail = 'Damage: ₹${order.damageFeeTotal!.toStringAsFixed(2)}';
                                    statusDetailColor = Colors.red.shade700;
                                    print('✅ Setting damage detail: $statusDetail');
                                  } else {
                                    print('⚠️ Damage not shown - damageFeeTotal: ${order.damageFeeTotal}, totalDamage: $totalDamage');
                                  }
                                  
                                  // 2x2 Grid Layout for symmetric design
                                  return Column(
                                    children: [
                                      // First Row: TOTAL ITEMS and RETURNED
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _ReturnStatusBox(
                                              label: 'TOTAL ITEMS',
                                              value: '$totalItems',
                                              detail: '($totalQuantity qty)',
                                              backgroundColor: Colors.white,
                                              valueColor: Colors.black,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: _ReturnStatusBox(
                                              label: 'RETURNED',
                                              value: '$returnedQuantity',
                                              detail: '$fullReturns full, $partialReturns partial',
                                              backgroundColor: Colors.green.shade50,
                                              valueColor: Colors.green.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      // Second Row: PENDING and STATUS
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _ReturnStatusBox(
                                              label: 'PENDING',
                                              value: '$pendingQuantity',
                                              detail: '$pendingCount ${pendingCount == 1 ? 'item' : 'items'}',
                                              backgroundColor: Colors.orange.shade50,
                                              valueColor: Colors.orange.shade700,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: _ReturnStatusBox(
                                              label: 'STATUS',
                                              value: overallStatus,
                                              detail: statusDetail,
                                              backgroundColor: statusBgColor,
                                              valueColor: statusValueColor,
                                              detailColor: statusDetailColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Late Fee Section Card (hide for flagged orders)
                    if (!order.isFlagged && (_isOrderLate(order) || (order.lateFee != null && order.lateFee! > 0)))
                      Card(
                        elevation: 0,
                        color: Colors.red.shade50,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.red.shade200, width: 1.5),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.warning_amber_rounded,
                                      size: 20,
                                      color: Colors.red.shade700,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Text(
                                      'Late Fee',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0F1724),
                                      ),
                                    ),
                                  ),
                                  if (_isOrderLate(order))
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade600,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'LATE',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              if (_isOrderLate(order)) ...[
                                Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today_outlined,
                                      size: 16,
                                      color: Colors.red.shade700,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Days Overdue: ${_getDaysOverdue(order)}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.red.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                              ],
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    order.lateFee != null && order.lateFee! > 0
                                        ? 'Late Fee Amount'
                                        : 'No Late Fee Applied',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  if (order.lateFee != null && order.lateFee! > 0)
                                    Text(
                                      '₹${NumberFormat('#,##0.00').format(order.lateFee!)}',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red.shade700,
                                      ),
                                    )
                                  else
                                    Text(
                                      '₹0.00',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                ],
                              ),
                              if (_isOrderLate(order) && (order.lateFee == null || order.lateFee! == 0)) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.orange.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        size: 16,
                                        color: Colors.orange.shade700,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Late fee will be applied when processing return',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.orange.shade700,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    if (_isOrderLate(order) || (order.lateFee != null && order.lateFee! > 0))
                      const SizedBox(height: 16),

                    // Pricing Breakdown Card
                    Card(
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
                                  Icons.receipt_long_outlined,
                                  size: 20,
                                  color: Colors.teal.shade600,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Pricing Breakdown',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F1724),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            if (order.subtotal != null) ...[
                              _PricingRow(
                                label: 'Subtotal',
                                amount: order.subtotal!,
                                isTotal: false,
                              ),
                              const SizedBox(height: 12),
                            ],
                            if (order.gstAmount != null &&
                                order.gstAmount! > 0) ...[
                              _PricingRow(
                                label: 'GST',
                                amount: order.gstAmount!,
                                isTotal: false,
                              ),
                              const SizedBox(height: 12),
                            ],
                            if (order.lateFee != null &&
                                order.lateFee! > 0) ...[
                              _PricingRow(
                                label: 'Late Fee',
                                amount: order.lateFee!,
                                isTotal: false,
                                isLateFee: true,
                              ),
                              const SizedBox(height: 12),
                            ],
                            Divider(color: Colors.grey.shade300, height: 24),
                            _PricingRow(
                              label: 'Total Amount',
                              amount: order.totalAmount,
                              isTotal: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Action Buttons
              if (canMarkReturned || canStartRental || canCancel || canEdit)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (canStartRental)
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _isUpdating ? null : () => _handleStartRental(order),
                                icon: _isUpdating
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            Colors.white,
                                          ),
                                        ),
                                      )
                                    : const Icon(
                                        Icons.play_arrow,
                                        size: 20,
                                      ),
                                label: Text(
                                  _isUpdating ? 'Processing...' : 'Start Rental',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  backgroundColor: Colors.orange.shade600,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          if (canMarkReturned) ...[
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => context.push('/orders/${order.id}/return'),
                                icon: const Icon(
                                  Icons.check_circle_outline,
                                  size: 20,
                                ),
                                label: const Text(
                                  'Process Return',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  backgroundColor: Colors.green.shade600,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ],
                          if (canEdit) ...[
                            if (canMarkReturned || canStartRental) const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _isUpdating ? null : () => context.push('/orders/${order.id}/edit'),
                                icon: const Icon(Icons.edit_outlined, size: 20),
                                label: const Text(
                                  'Edit Order',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  foregroundColor: const Color(0xFF0F1724),
                                  side: BorderSide(color: Colors.grey.shade300),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                          if (canCancel) ...[
                            if (canMarkReturned || canStartRental || canEdit) const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _isUpdating ? null : () => _handleCancelOrder(order),
                                icon: _isUpdating
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            Colors.red,
                                          ),
                                        ),
                                      )
                                    : const Icon(Icons.cancel_outlined, size: 20),
                                label: Text(
                                  _isUpdating ? 'Processing...' : 'Cancel Order',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.red.shade600,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  foregroundColor: Colors.red.shade600,
                                  side: BorderSide(
                                    color: Colors.red.shade600,
                                    width: 1.5,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
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
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0B63FF)),
          ),
        ),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
                const SizedBox(height: 16),
                Text(
                  'Failed to load order',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  style: TextStyle(fontSize: 13, color: Colors.red.shade400),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    ref.invalidate(orderProvider(widget.orderId));
                  },
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
        ),
      ),
    );
  }
}

enum _OrderCategory { scheduled, ongoing, late, returned, partiallyReturned, cancelled, flagged }

class _DateInfoWidget extends StatelessWidget {
  final String label;
  final DateTime date;

  const _DateInfoWidget({required this.label, required this.date});

  String _formatDateTime12Hour(DateTime date) {
    final hour = date.hour;
    final minute = date.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    // Convert 24-hour to 12-hour format
    final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final minuteStr = minute.toString().padLeft(2, '0');
    
    final dateStr = DateFormat('dd MMM yyyy').format(date);
    return '$dateStr, $hour12:$minuteStr $period';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
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
        const SizedBox(height: 6),
        Text(
          _formatDateTime12Hour(date),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F1724),
          ),
        ),
      ],
    );
  }
}

class _OrderItemCard extends StatelessWidget {
  final OrderItem item;
  final int index;
  final bool isLast;

  const _OrderItemCard({
    required this.item,
    required this.index,
    required this.isLast,
  });

  void _showImagePreview(
    BuildContext context,
    String imageUrl,
    String? productName,
  ) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withOpacity(0.85),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _ImagePreviewModal(
          imageUrl: imageUrl,
          productName: productName ?? 'Item ${index + 1}',
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(0, 0.1),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Item Image
            InkWell(
              onTap: item.photoUrl.isNotEmpty
                  ? () => _showImagePreview(
                      context,
                      item.photoUrl,
                      item.productName,
                    )
                  : null,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: item.photoUrl.isNotEmpty
                        ? Colors.blue.shade200
                        : Colors.grey.shade200,
                    width: item.photoUrl.isNotEmpty ? 1.5 : 1,
                  ),
                  color: Colors.grey.shade50,
                ),
                child: item.photoUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          item.photoUrl,
                          width: 70,
                          height: 70,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.image_outlined,
                              size: 32,
                              color: Colors.grey.shade400,
                            );
                          },
                        ),
                      )
                    : Icon(
                        Icons.image_outlined,
                        size: 32,
                        color: Colors.grey.shade400,
                      ),
              ),
            ),
            const SizedBox(width: 16),
            // Item Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.productName ?? 'Item $index',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F1724),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Qty: ${item.quantity}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${item.days} day${item.days != 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '₹${item.pricePerDay.toStringAsFixed(2)}/day',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            // Item Total
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${item.lineTotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F1724),
                  ),
                ),
              ],
            ),
          ],
        ),
        if (!isLast) ...[
          const SizedBox(height: 16),
          Divider(color: Colors.grey.shade200, height: 1),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

/// Return Status Box Widget (symmetric design)
class _ReturnStatusBox extends StatelessWidget {
  final String label;
  final String value;
  final String detail;
  final Color backgroundColor;
  final Color valueColor;
  final Color? detailColor;

  const _ReturnStatusBox({
    required this.label,
    required this.value,
    required this.detail,
    required this.backgroundColor,
    required this.valueColor,
    this.detailColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 110, // Fixed height for symmetry
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: valueColor,
              height: 1.2,
            ),
          ),
          const Spacer(),
          if (detail.isNotEmpty)
            Text(
              detail,
              style: TextStyle(
                fontSize: 11,
                color: detailColor ?? Colors.grey.shade600,
                height: 1.3,
                fontWeight: detailColor != null ? FontWeight.w600 : FontWeight.normal,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            )
          else
            const SizedBox(height: 16), // Spacer to maintain symmetry when no detail
        ],
      ),
    );
  }
}

/// Item Return Status Row Widget
class _PricingRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool isTotal;
  final bool isLateFee;

  const _PricingRow({
    required this.label,
    required this.amount,
    required this.isTotal,
    this.isLateFee = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            if (isLateFee)
              Icon(
                Icons.warning_amber_rounded,
                size: 16,
                color: Colors.red.shade600,
              ),
            if (isLateFee) const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: isTotal ? 16 : 14,
                fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
                color: isLateFee
                    ? Colors.red.shade700
                    : isTotal
                    ? const Color(0xFF0F1724)
                    : Colors.grey.shade700,
              ),
            ),
          ],
        ),
        Text(
          '₹${NumberFormat('#,##0.00').format(amount)}',
          style: TextStyle(
            fontSize: isTotal ? 18 : 14,
            fontWeight: FontWeight.bold,
            color: isLateFee
                ? Colors.red.shade600
                : isTotal
                ? Colors.green.shade600
                : const Color(0xFF0F1724),
          ),
        ),
      ],
    );
  }
}

class _ImagePreviewModal extends StatefulWidget {
  final String imageUrl;
  final String productName;

  const _ImagePreviewModal({required this.imageUrl, required this.productName});

  @override
  State<_ImagePreviewModal> createState() => _ImagePreviewModalState();
}

class _ImagePreviewModalState extends State<_ImagePreviewModal> {
  final TransformationController _transformationController =
      TransformationController();
  bool _isZoomed = false;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _transformationController.addListener(() {
      final isZoomed =
          _transformationController.value.getMaxScaleOnAxis() > 1.0;
      if (_isZoomed != isZoomed) {
        setState(() {
          _isZoomed = isZoomed;
        });
      }
    });
  }

  void _showFullScreenImage(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _FullScreenImageViewer(
          imageUrl: widget.imageUrl,
          productName: widget.productName,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenHeight = screenSize.height;
    final modalHeight = screenHeight * 0.75;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: Container(
            height: modalHeight,
            width: screenSize.width,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              children: [
                // Header with Gradient
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF2C2C2C),
                        const Color(0xFF1A1A1A),
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        child: Icon(
                          Icons.image_outlined,
                          color: Colors.blue.shade300,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.productName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.zoom_in_outlined,
                                  size: 14,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _isZoomed
                                      ? 'Pinch to zoom'
                                      : 'Pinch to zoom in',
                                  style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                          onPressed: () => Navigator.pop(context),
                          tooltip: 'Close',
                        ),
                      ),
                    ],
                  ),
                ),
                // Image Viewer with Zoom
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(24),
                        bottomRight: Radius.circular(24),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(24),
                        bottomRight: Radius.circular(24),
                      ),
                      child: InteractiveViewer(
                        transformationController: _transformationController,
                        minScale: 0.8,
                        maxScale: 4.0,
                        panEnabled: true,
                        scaleEnabled: true,
                        child: Center(
                          child: Container(
                            width: double.infinity,
                            constraints: BoxConstraints(
                              maxHeight: modalHeight - 120,
                            ),
                            child: Image.network(
                              widget.imageUrl,
                              fit: BoxFit.contain,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CircularProgressIndicator(
                                        value:
                                            loadingProgress
                                                    .expectedTotalBytes !=
                                                null
                                            ? loadingProgress
                                                      .cumulativeBytesLoaded /
                                                  loadingProgress
                                                      .expectedTotalBytes!
                                            : null,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.blue.shade400,
                                            ),
                                        strokeWidth: 3,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Loading image...',
                                        style: TextStyle(
                                          color: Colors.grey.shade400,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.broken_image_outlined,
                                          size: 48,
                                          color: Colors.grey.shade400,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Failed to load image',
                                        style: TextStyle(
                                          color: Colors.grey.shade400,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Please check your connection',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Bottom Actions Bar
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF1A1A1A),
                        const Color(0xFF2C2C2C),
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ModernActionButton(
                        icon: Icons.refresh_rounded,
                        label: 'Reset View',
                        onPressed: () {
                          setState(() {
                            _transformationController.value =
                                Matrix4.identity();
                          });
                        },
                        isActive: _isZoomed,
                      ),
                      const SizedBox(width: 12),
                      _ModernActionButton(
                        icon: Icons.fullscreen_rounded,
                        label: 'Full Screen',
                        onPressed: () {
                          Navigator.pop(context); // Close current modal
                          // Show full screen viewer
                          Future.delayed(const Duration(milliseconds: 100), () {
                            _showFullScreenImage(context);
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModernActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isActive;

  const _ModernActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            gradient: isActive
                ? LinearGradient(
                    colors: [Colors.blue.shade400, Colors.blue.shade600],
                  )
                : null,
            color: isActive ? null : Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isActive
                  ? Colors.blue.shade300
                  : Colors.white.withOpacity(0.2),
              width: isActive ? 1.5 : 1,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FullScreenImageViewer extends StatefulWidget {
  final String imageUrl;
  final String productName;

  const _FullScreenImageViewer({
    required this.imageUrl,
    required this.productName,
  });

  @override
  State<_FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<_FullScreenImageViewer> {
  final TransformationController _transformationController =
      TransformationController();
  bool _showControls = true;
  bool _isZoomed = false;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _transformationController.addListener(() {
      final isZoomed =
          _transformationController.value.getMaxScaleOnAxis() > 1.0;
      if (_isZoomed != isZoomed) {
        setState(() {
          _isZoomed = isZoomed;
        });
      }
    });

    // Hide controls after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && !_isZoomed) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            // Full Screen Image
            InteractiveViewer(
              transformationController: _transformationController,
              minScale: 0.5,
              maxScale: 5.0,
              panEnabled: true,
              scaleEnabled: true,
              child: Center(
                child: Image.network(
                  widget.imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                : null,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                            strokeWidth: 3,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Loading image...',
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.broken_image_outlined,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Failed to load image',
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

            // Top Controls
            AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                            ),
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.productName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tap to show/hide controls',
                                style: TextStyle(
                                  color: Colors.grey.shade300,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                            ),
                          ),
                          child: IconButton(
                            icon: Icon(
                              _isZoomed
                                  ? Icons.refresh_rounded
                                  : Icons.close_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            onPressed: _isZoomed
                                ? () {
                                    setState(() {
                                      _transformationController.value =
                                          Matrix4.identity();
                                    });
                                  }
                                : () => Navigator.pop(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Bottom Controls
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              bottom: _showControls ? 0 : -100,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom + 16,
                  top: 16,
                  left: 16,
                  right: 16,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.zoom_in_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isZoomed
                                ? 'Zoomed - Tap to reset'
                                : 'Pinch to zoom',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Order Timeline Widget
/// 
/// Displays the order's journey from creation to completion
/// Uses real audit log data from order_return_audit table (matching website)
class _OrderTimelineWidget extends StatefulWidget {
  final Order order;

  const _OrderTimelineWidget({required this.order});

  @override
  State<_OrderTimelineWidget> createState() => _OrderTimelineWidgetState();
}

class _OrderTimelineWidgetState extends State<_OrderTimelineWidget> {
  List<Map<String, dynamic>>? _timelineEvents;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTimeline();
  }

  Future<void> _loadTimeline() async {
    try {
      final events = await OrdersService().getOrderTimeline(widget.order.id);
      if (mounted) {
        setState(() {
          _timelineEvents = events;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  String _formatDateTime12Hour(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final hour = date.hour;
      final minute = date.minute;
      final period = hour >= 12 ? 'PM' : 'AM';
      final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      final minuteStr = minute.toString().padLeft(2, '0');
      
      final dateStr = DateFormat('dd MMM yyyy').format(date);
      return '$dateStr, $hour12:$minuteStr $period';
    } catch (e) {
      return dateString;
    }
  }

  IconData _getActionIcon(String action) {
    switch (action) {
      case 'order_created':
        return Icons.description_outlined;
      case 'order_scheduled':
        return Icons.calendar_today_outlined;
      case 'rental_started':
        return Icons.play_circle_outlined;
      case 'order_edited':
        return Icons.edit_outlined;
      case 'billing_updated':
        return Icons.attach_money_outlined;
      case 'status_changed':
        return Icons.arrow_forward_outlined;
      case 'marked_returned':
      case 'item_returned':
      case 'all_items_returned':
        return Icons.check_circle_outlined;
      case 'item_reverted':
        return Icons.rotate_left_outlined;
      case 'marked_missing':
        return Icons.cancel_outlined;
      case 'partial_return':
        return Icons.check_circle_outline;
      case 'order_completed':
        return Icons.check_circle_outlined;
      case 'order_cancelled':
        return Icons.block_outlined;
      case 'order_pending_return':
        return Icons.schedule_outlined;
      case 'updated_return_date':
        return Icons.access_time_outlined;
      case 'flagged':
        return Icons.flag_outlined;
      default:
        return Icons.access_time_outlined;
    }
  }

  String _getActionLabel(String action, Map<String, dynamic> event) {
    switch (action) {
      case 'order_created':
        return 'Order Created';
      case 'order_scheduled':
        return 'Scheduled';
      case 'rental_started':
        return 'Rental Started';
      case 'order_edited':
        return 'Order Updated';
      case 'billing_updated':
        return 'Billing Updated';
      case 'status_changed':
        final newStatus = event['new_status'] as String?;
        if (newStatus == 'completed') {
          return 'Completed';
        } else if (newStatus == 'cancelled') {
          return 'Cancelled';
        } else if (newStatus == 'partially_returned') {
          return 'Partial Return';
        } else if (newStatus == 'flagged') {
          return 'Flagged';
        }
        return 'Status Changed';
      case 'marked_returned':
      case 'item_returned':
      case 'all_items_returned':
        return 'Items Returned';
      case 'partial_return':
        return 'Partial Return';
      case 'order_completed':
        return 'Completed';
      case 'items_reverted':
        return 'Items Reverted';
      case 'items_marked_missing':
        return 'Items Missing';
      case 'items_updated':
        return 'Items Updated';
      case 'order_cancelled':
        return 'Cancelled';
      case 'order_pending_return':
        return 'Pending Return';
      case 'updated_return_date':
        return 'Return Date Updated';
      default:
        return action.replaceAll('_', ' ').split(' ').map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1);
        }).join(' ');
    }
  }

  Color _getActionColor(String action) {
    switch (action) {
      case 'order_created':
        return Colors.blue;
      case 'order_scheduled':
        return Colors.indigo;
      case 'rental_started':
        return Colors.green;
      case 'order_edited':
        return Colors.amber;
      case 'billing_updated':
        return Colors.purple;
      case 'status_changed':
        return Colors.purple;
      case 'marked_returned':
      case 'item_returned':
        return Colors.green;
      case 'item_reverted':
        return Colors.orange;
      case 'marked_missing':
        return Colors.red;
      case 'partial_return':
        return Colors.yellow;
      case 'order_completed':
        return Colors.green;
      case 'order_cancelled':
        return Colors.red;
      case 'order_pending_return':
        return Colors.yellow;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'Failed to load timeline: $_error',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    if (_timelineEvents == null || _timelineEvents!.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'No timeline data available',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Column(
      children: _timelineEvents!.asMap().entries.map((entry) {
        final index = entry.key;
        final event = entry.value;
        final isLast = index == _timelineEvents!.length - 1;
        final action = event['action'] as String;
        final color = _getActionColor(action);
        final icon = _getActionIcon(action);
        final label = _getActionLabel(action, event);
        final userName = event['user_name'] as String? ?? 'Unknown';
        final notes = event['notes'] as String?;
        final createdAt = event['created_at'] as String;

        return _TimelineItemWidget(
          event: _TimelineEvent(
            icon: icon,
            title: label,
            description: notes ?? '',
            date: DateTime.parse(createdAt),
            color: color,
            isCompleted: true,
            userName: userName,
          ),
          isLast: isLast,
          formatDateTime: _formatDateTime12Hour,
        );
      }).toList(),
    );
  }
}

class _TimelineEvent {
  final IconData icon;
  final String title;
  final String description;
  final DateTime date;
  final Color color;
  final bool isCompleted;
  final String? userName;

  _TimelineEvent({
    required this.icon,
    required this.title,
    required this.description,
    required this.date,
    required this.color,
    this.isCompleted = false,
    this.userName,
  });
}

class _TimelineItemWidget extends StatelessWidget {
  final _TimelineEvent event;
  final bool isLast;
  final String Function(String) formatDateTime;

  const _TimelineItemWidget({
    required this.event,
    required this.isLast,
    required this.formatDateTime,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline indicator
        Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: event.isCompleted 
                    ? event.color 
                    : Colors.grey.shade300,
                shape: BoxShape.circle,
                border: Border.all(
                  color: event.isCompleted 
                      ? event.color 
                      : Colors.grey.shade400,
                  width: 2,
                ),
              ),
              child: Icon(
                event.icon,
                color: event.isCompleted 
                    ? Colors.white 
                    : Colors.grey.shade600,
                size: 20,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 60,
                color: event.isCompleted 
                    ? event.color.withOpacity(0.3)
                    : Colors.grey.shade300,
              ),
          ],
        ),
        const SizedBox(width: 16),
        // Timeline content
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badge with title
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: event.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: event.color.withOpacity(0.3)),
                      ),
                      child: Text(
                        event.title,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: event.color,
                        ),
                      ),
                    ),
                    if (event.description.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          event.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                // User name and date
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 14,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      event.userName ?? 'Unknown',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '•',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatDateTime(event.date.toIso8601String()),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
