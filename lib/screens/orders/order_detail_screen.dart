import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final bool scrollToItems;

  const OrderDetailScreen({
    super.key,
    required this.orderId,
    this.scrollToItems = false,
  });

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  bool _isUpdating = false;
  bool _isViewingInvoice = false;
  bool _isSharingInvoice = false;
  bool _isDownloadingInvoice = false;
  bool _isPrintingInvoice = false;

  // Scroll controller for scrolling to items section
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _itemsSectionKey = GlobalKey();

  // State for item return management
  final Map<String, bool> _itemCheckboxes = {}; // itemId -> isChecked
  final Map<String, int> _returnedQuantities =
      {}; // itemId -> returned quantity
  final Map<String, double> _damageCosts = {}; // itemId -> damage cost
  final Map<String, String> _damageDescriptions =
      {}; // itemId -> damage description

  // Late fee controller
  final TextEditingController _lateFeeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Force refresh order data when screen opens to get latest from database
    // This ensures we get the latest data, including any changes made on the website
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Invalidate to clear cache and force fresh fetch
        ref.invalidate(orderProvider(widget.orderId));
      }
    });
  }

  /// Manually refresh order data from database
  Future<void> _refreshOrder() async {
    ref.invalidate(orderProvider(widget.orderId));
    // Wait a bit for the fetch to complete
    await Future.delayed(const Duration(milliseconds: 500));
  }

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
                    backgroundColor: const Color(0xFF1F2A7A),
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
                backgroundColor: const Color(0xFF1F2A7A),
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

    // Normalize to date only (midnight) to ensure accurate day calculation
    final startDateOnly = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    );
    final endDateOnly = DateTime(endDate.year, endDate.month, endDate.day);

    final duration = endDateOnly.difference(startDateOnly);
    // For rental: same day = 1 day, next day = 1 day (overnight), etc.
    final daysDifference = duration.inDays;
    final days = daysDifference < 1 ? 1 : daysDifference;
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
      endDate = DateTime.parse(endStr);
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

  @override
  void dispose() {
    _lateFeeController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToItemsSection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_itemsSectionKey.currentContext != null) {
        Scrollable.ensureVisible(
          _itemsSectionKey.currentContext!,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
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
        return const Color(0xFF1F2A7A);
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
            child: Text('No', style: TextStyle(color: Colors.grey.shade700)),
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

  Future<void> _handleSaveChanges() async {
    final order = ref.read(orderProvider(widget.orderId)).value;
    final userProfile = ref.read(userProfileProvider).value;

    if (order == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order not found'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (userProfile?.id == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User information missing'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Check if there are any changes
    bool hasChanges = false;
    final items = order.items ?? [];

    for (final item in items) {
      if (item.id == null) continue;

      final isChecked = _itemCheckboxes[item.id!] ?? false;
      final returnedQty = _returnedQuantities[item.id!];
      final damageCost = _damageCosts[item.id!];
      final damageDesc = _damageDescriptions[item.id!];

      // Check if item state differs from current state
      if (isChecked) {
        final currentReturnedQty = item.returnedQuantity ?? 0;
        final currentDamageCost = item.damageCost;
        final currentDamageDesc = item.missingNote;

        if (returnedQty != null && returnedQty != currentReturnedQty) {
          hasChanges = true;
          break;
        }
        if (damageCost != null && damageCost != (currentDamageCost ?? 0)) {
          hasChanges = true;
          break;
        }
        if (damageDesc != null && damageDesc != (currentDamageDesc ?? '')) {
          hasChanges = true;
          break;
        }
      } else if (item.isReturned || (item.returnedQuantity ?? 0) > 0) {
        // Item was returned but now unchecked (unreturn)
        hasChanges = true;
        break;
      }
    }

    if (!hasChanges) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No changes to save'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      final ordersService = ref.read(ordersServiceProvider);
      final List<ItemReturn> itemReturns = [];

      // Process checked items (returns)
      for (final item in items) {
        if (item.id == null) continue;

        final isChecked = _itemCheckboxes[item.id!] ?? false;
        final returnedQty = _returnedQuantities[item.id!];
        final damageCost = _damageCosts[item.id!];
        final damageDesc = _damageDescriptions[item.id!];

        if (isChecked && returnedQty != null && returnedQty > 0) {
          // Item is being returned
          final currentReturnedQty = item.returnedQuantity ?? 0;
          final pendingQty = item.quantity - currentReturnedQty;

          if (returnedQty <= pendingQty) {
            // Valid return quantity
            itemReturns.add(
              ItemReturn(
                itemId: item.id!,
                returnStatus: returnedQty >= item.quantity
                    ? 'returned'
                    : 'returned',
                actualReturnDate: DateTime.now(),
                returnedQuantity: returnedQty,
                damageCost: damageCost,
                description: damageDesc?.trim().isEmpty ?? true
                    ? null
                    : damageDesc?.trim(),
              ),
            );
          }
        } else if (!isChecked &&
            (item.isReturned || (item.returnedQuantity ?? 0) > 0)) {
          // Item was returned but now unchecked (unreturn)
          itemReturns.add(
            ItemReturn(
              itemId: item.id!,
              returnStatus: 'not_yet_returned',
              actualReturnDate: null,
              missingNote: null,
            ),
          );
        }
      }

      // Also update damage for items that have damage but may not be returned
      for (final item in items) {
        if (item.id == null) continue;

        final damageCost = _damageCosts[item.id!];
        final damageDesc = _damageDescriptions[item.id!];
        final currentDamageCost = item.damageCost;
        final currentDamageDesc = item.missingNote;

        // Update damage if changed
        if ((damageCost != null && damageCost != (currentDamageCost ?? 0)) ||
            (damageDesc != null && damageDesc != (currentDamageDesc ?? ''))) {
          await ordersService.updateItemDamage(
            itemId: item.id!,
            damageCost: damageCost,
            damageDescription: damageDesc,
          );
        }
      }

      // Update late fee if order is late or has late fee set
      if (_isOrderLate(order) ||
          (order.lateFee != null && order.lateFee! > 0)) {
        final lateFeeText = _lateFeeController.text.trim();
        if (lateFeeText.isNotEmpty) {
          try {
            final lateFee = double.parse(lateFeeText);
            if (lateFee >= 0 && lateFee != (order.lateFee ?? 0)) {
              await ordersService.updateLateFee(
                orderId: widget.orderId,
                lateFee: lateFee,
              );
            }
          } catch (e) {
            print('Error parsing late fee: $e');
            // Continue with other updates even if late fee parsing fails
          }
        } else if ((order.lateFee ?? 0) > 0) {
          // Clear late fee if field is empty but order has late fee
          await ordersService.updateLateFee(
            orderId: widget.orderId,
            lateFee: 0.0,
          );
        }
      }

      if (itemReturns.isNotEmpty) {
        await ordersService.processOrderReturn(
          orderId: widget.orderId,
          itemReturns: itemReturns,
          userId: userProfile!.id,
          lateFee: 0.0, // Late fee is handled separately above
        );
      }

      // Refresh order data
      final branchId = ref.read(userProfileProvider).value?.branchId;
      ref.invalidate(orderProvider(widget.orderId));
      if (branchId != null) {
        ref.invalidate(ordersProvider(OrdersParams(branchId: branchId)));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Changes saved successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving changes: ${e.toString()}'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
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
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
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

    // Initialize late fee controller when order data is available
    orderAsync.whenData((order) {
      if (order != null) {
        if (order.lateFee != null && order.lateFee! > 0) {
          if (_lateFeeController.text.isEmpty ||
              _lateFeeController.text != order.lateFee!.toStringAsFixed(2)) {
            _lateFeeController.text = order.lateFee!.toStringAsFixed(2);
          }
        } else if (_isOrderLate(order)) {
          // If order is late but no late fee set, keep controller empty
          if (_lateFeeController.text.isNotEmpty &&
              (order.lateFee == null || order.lateFee! == 0)) {
            // Don't clear if user has entered a value
          }
        }
      }
    });

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
          // Refresh button to manually refresh order data
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF0F1724)),
            onPressed: () async {
              // Force refresh order data from database
              await _refreshOrder();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Order data refreshed'),
                    duration: Duration(seconds: 1),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            tooltip: 'Refresh Order',
          ),
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
                        onPressed: _isUpdating
                            ? null
                            : () => _handleStartRental(order),
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
          final canMarkReturned =
              !order.isScheduled &&
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
              ? (buttonCount * 56.0) +
                    ((buttonCount - 1) * 8.0) +
                    32.0 +
                    34.0 +
                    20.0
              : 16.0;

          // Scroll to items section if requested
          if (widget.scrollToItems) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollToItemsSection();
            });
          }

          return Stack(
            children: [
              SingleChildScrollView(
                controller: _scrollController,
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
                          width:
                              (category == _OrderCategory.late ||
                                  category == _OrderCategory.flagged)
                              ? 1.5
                              : 1,
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
                                    color: const Color(0xFF1F2A7A),
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
                                  color: const Color(
                                    0xFF1F2A7A,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      size: 18,
                                      color: const Color(0xFF1F2A7A),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Duration: ${dateInfo['days']} day${dateInfo['days'] != 1 ? 's' : ''} ${dateInfo['hours']} hour${dateInfo['hours'] != 1 ? 's' : ''}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF1F2A7A),
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

                    // Return Status Section (only show if order has items, is not scheduled, and is not cancelled)
                    if (order.items != null &&
                        order.items!.isNotEmpty &&
                        !order.isScheduled &&
                        !order.isCancelled) ...[
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
                                  final returnedQuantity = items.fold<int>(0, (
                                    sum,
                                    item,
                                  ) {
                                    int returnedQty;
                                    if (item.isReturned) {
                                      // Item is marked as returned: use returnedQuantity if available, otherwise item.quantity
                                      returnedQty =
                                          item.returnedQuantity ??
                                          item.quantity;
                                    } else {
                                      // Item is not marked as returned: use returnedQuantity (could be partial return)
                                      returnedQty = item.returnedQuantity ?? 0;
                                    }
                                    return sum + returnedQty;
                                  });

                                  // Get items that are marked as returned (returnStatus = 'returned') for full/partial count
                                  final returnedItems = items
                                      .where((item) => item.isReturned)
                                      .toList();

                                  // Count items with full returns (returned quantity >= item quantity) among returned items
                                  final fullReturns = returnedItems.where((
                                    item,
                                  ) {
                                    // If returnedQuantity is null and status is returned, it's fully returned
                                    final returnedQty =
                                        item.returnedQuantity ?? item.quantity;
                                    return returnedQty >= item.quantity;
                                  }).length;

                                  // Count items with partial returns (returned quantity > 0 but < item quantity) among returned items
                                  final partialReturns = returnedItems.where((
                                    item,
                                  ) {
                                    // Partial if returnedQuantity exists, is > 0, and is less than quantity
                                    final returnedQty = item.returnedQuantity;
                                    if (returnedQty == null)
                                      return false; // null means full return
                                    return returnedQty > 0 &&
                                        returnedQty < item.quantity;
                                  }).length;

                                  // Calculate pending items - Website logic:
                                  // PENDING count = items where returnStatus != 'returned' (not marked as returned)
                                  // PENDING quantity = sum of remaining quantity for ALL items where returnedQuantity < quantity
                                  final pendingItems = items
                                      .where((item) => !item.isReturned)
                                      .toList();
                                  final pendingCount = pendingItems.length;

                                  // Calculate total pending quantity from ALL items (not just pending items)
                                  // This includes items that are marked as returned but have partial returns
                                  final pendingQuantity = items.fold<int>(0, (
                                    sum,
                                    item,
                                  ) {
                                    final returnedQty =
                                        item.returnedQuantity ?? 0;
                                    // If item is marked as returned and returnedQuantity is null, assume fully returned
                                    if (item.isReturned &&
                                        item.returnedQuantity == null) {
                                      return sum; // Fully returned, no pending quantity
                                    }
                                    // Calculate remaining quantity
                                    final remaining =
                                        item.quantity - returnedQty;
                                    // Only add if there's remaining quantity
                                    return sum +
                                        (remaining > 0 ? remaining : 0);
                                  });

                                  // Get total damage cost from order (damage_fee_total)
                                  final totalDamage =
                                      order.damageFeeTotal ?? 0.0;

                                  // Debug: Check damage fee total value
                                  print(
                                    '🔍 Order Damage Fee Total: ${order.damageFeeTotal}',
                                  );
                                  print('🔍 Total Damage: $totalDamage');

                                  // Determine overall status
                                  String overallStatus;
                                  Color statusBgColor;
                                  Color statusValueColor;
                                  String statusDetail = '';
                                  Color statusDetailColor =
                                      Colors.grey.shade600;

                                  // Determine status based on website logic
                                  // Check if all items are fully returned (returnedQuantity >= item quantity for all)
                                  final allItemsReturned = items.every((item) {
                                    // If item is marked as returned and returnedQuantity is null, it's fully returned
                                    // Otherwise check if returnedQuantity >= quantity
                                    final returnedQty =
                                        item.isReturned &&
                                            item.returnedQuantity == null
                                        ? item.quantity
                                        : (item.returnedQuantity ?? 0);
                                    return returnedQty >= item.quantity;
                                  });

                                  // Check if some items have returns but not all are fully returned
                                  final hasSomeReturns = returnedQuantity > 0;
                                  final hasPendingQuantity =
                                      pendingQuantity >
                                      0; // Check pending quantity, not just count

                                  // Website logic: Show "Partial" if there's pending quantity, even if all items are marked as returned
                                  if (allItemsReturned &&
                                      !hasPendingQuantity &&
                                      returnedQuantity > 0) {
                                    // All items fully returned with no pending quantity
                                    overallStatus = 'Returned';
                                    statusBgColor = Colors.green.shade50;
                                    statusValueColor = Colors.green.shade700;
                                  } else if (hasSomeReturns &&
                                      hasPendingQuantity) {
                                    // Partial: Some items returned but there's still pending quantity
                                    overallStatus = 'Partial';
                                    statusBgColor = const Color(
                                      0xFF1F2A7A,
                                    ).withOpacity(0.1);
                                    statusValueColor = const Color(0xFF1F2A7A);
                                  } else if (hasSomeReturns &&
                                      !hasPendingQuantity) {
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
                                  if (order.damageFeeTotal != null &&
                                      order.damageFeeTotal! > 0) {
                                    statusDetail =
                                        'Damage: ₹${order.damageFeeTotal!.toStringAsFixed(2)}';
                                    statusDetailColor = Colors.red.shade700;
                                    print(
                                      '✅ Setting damage detail: $statusDetail',
                                    );
                                  } else {
                                    print(
                                      '⚠️ Damage not shown - damageFeeTotal: ${order.damageFeeTotal}, totalDamage: $totalDamage',
                                    );
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
                                              detail:
                                                  '$fullReturns full, $partialReturns partial',
                                              backgroundColor:
                                                  Colors.green.shade50,
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
                                              detail: '$pendingCount items',
                                              backgroundColor:
                                                  Colors.orange.shade50,
                                              valueColor:
                                                  Colors.orange.shade700,
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

                    // Items Card (hide for cancelled orders)
                    if (order.items != null &&
                        order.items!.isNotEmpty &&
                        !order.isCancelled) ...[
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
                                key: _itemsSectionKey,
                                children: [
                                  Icon(
                                    Icons.inventory_2_outlined,
                                    size: 20,
                                    color: Colors.indigo.shade600,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      'Items & Return Details',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0F1724),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Mark All as Returned button (only for non-scheduled, non-cancelled orders)
                                  if (!order.isScheduled &&
                                      !order.isCancelled &&
                                      canMarkReturned)
                                    Flexible(
                                      child: OutlinedButton(
                                        onPressed: () {
                                          setState(() {
                                            for (final item in order.items!) {
                                              if (item.id != null) {
                                                _itemCheckboxes[item.id!] =
                                                    true;
                                                _returnedQuantities[item.id!] =
                                                    item.quantity;
                                              }
                                            }
                                          });
                                        },
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          side: BorderSide(
                                            color: Colors.grey.shade300,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        child: const Text(
                                          'Mark All as Returned',
                                          style: TextStyle(fontSize: 12),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              ...order.items!.asMap().entries.map((entry) {
                                final index = entry.key;
                                final item = entry.value;
                                // Auto-check if item is already returned
                                final isItemReturned =
                                    item.isReturned ||
                                    (item.returnedQuantity != null &&
                                        item.returnedQuantity! > 0);
                                final shouldBeChecked =
                                    _itemCheckboxes[item.id] ?? isItemReturned;

                                // Initialize returned quantity if item is returned but not in state
                                if (isItemReturned &&
                                    item.id != null &&
                                    !_itemCheckboxes.containsKey(item.id)) {
                                  _returnedQuantities[item.id!] =
                                      item.returnedQuantity ?? item.quantity;
                                  _itemCheckboxes[item.id!] = true;
                                }

                                return _OrderItemCard(
                                  item: item,
                                  index: index + 1,
                                  isLast: index == order.items!.length - 1,
                                  orderId: order.id,
                                  isChecked: shouldBeChecked,
                                  returnedQuantity:
                                      _returnedQuantities[item.id] ??
                                      item.returnedQuantity,
                                  damageCost:
                                      _damageCosts[item.id] ?? item.damageCost,
                                  damageDescription:
                                      _damageDescriptions[item.id] ??
                                      item.missingNote,
                                  onCheckboxChanged: (checked) {
                                    setState(() {
                                      if (item.id != null) {
                                        _itemCheckboxes[item.id!] = checked;
                                        if (checked) {
                                          _returnedQuantities[item.id!] =
                                              item.returnedQuantity ?? 0;
                                        } else {
                                          _returnedQuantities.remove(item.id!);
                                          _damageCosts.remove(item.id!);
                                          _damageDescriptions.remove(item.id!);
                                        }
                                      }
                                    });
                                  },
                                  onReturnedQuantityChanged: (quantity) {
                                    setState(() {
                                      if (item.id != null) {
                                        _returnedQuantities[item.id!] =
                                            quantity;
                                      }
                                    });
                                  },
                                  onDamageCostChanged: (cost) {
                                    setState(() {
                                      if (item.id != null) {
                                        if (cost != null && cost > 0) {
                                          _damageCosts[item.id!] = cost;
                                        } else {
                                          _damageCosts.remove(item.id!);
                                        }
                                      }
                                    });
                                  },
                                  onDamageDescriptionChanged: (description) {
                                    setState(() {
                                      if (item.id != null) {
                                        if (description != null &&
                                            description.isNotEmpty) {
                                          _damageDescriptions[item.id!] =
                                              description;
                                        } else {
                                          _damageDescriptions.remove(item.id!);
                                        }
                                      }
                                    });
                                  },
                                  onUpdated: () {
                                    // Refresh order data
                                    ref.invalidate(orderProvider(order.id));
                                  },
                                );
                              }),
                              // Save Changes Button (only show when at least one checkbox is checked)
                              Builder(
                                builder: (context) {
                                  // Check if any checkbox is checked
                                  final hasCheckedItems = _itemCheckboxes.values
                                      .any((checked) => checked);

                                  if (!order.isScheduled &&
                                      !order.isCancelled &&
                                      canMarkReturned &&
                                      hasCheckedItems) {
                                    return Column(
                                      children: [
                                        const SizedBox(height: 20),
                                        Divider(
                                          color: Colors.grey.shade200,
                                          height: 1,
                                        ),
                                        const SizedBox(height: 16),
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton.icon(
                                            onPressed: _isUpdating
                                                ? null
                                                : _handleSaveChanges,
                                            icon: _isUpdating
                                                ? const SizedBox(
                                                    width: 20,
                                                    height: 20,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      valueColor:
                                                          AlwaysStoppedAnimation<
                                                            Color
                                                          >(Colors.white),
                                                    ),
                                                  )
                                                : const Icon(
                                                    Icons.save_outlined,
                                                    size: 20,
                                                  ),
                                            label: Text(
                                              _isUpdating
                                                  ? 'Saving Changes...'
                                                  : 'Save Changes',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 16,
                                                  ),
                                              backgroundColor:
                                                  Colors.green.shade600,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              elevation: 0,
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Order Timeline Card (placed after Return Status)
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

                    // Late Fee Section Card (hide for flagged orders)
                    if (!order.isFlagged &&
                        (_isOrderLate(order) ||
                            (order.lateFee != null && order.lateFee! > 0)))
                      Card(
                        elevation: 0,
                        color: Colors.red.shade50,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: Colors.red.shade200,
                            width: 1.5,
                          ),
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
                              // Late Fee Input Field (when order is late or has late fee)
                              if (_isOrderLate(order) ||
                                  (order.lateFee != null &&
                                      order.lateFee! > 0)) ...[
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Enter Late Fee Amount',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: _lateFeeController,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      decoration: InputDecoration(
                                        hintText: '0.00',
                                        prefixText: '₹ ',
                                        prefixStyle: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade700,
                                        ),
                                        filled: true,
                                        fillColor: Colors.white,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.grey.shade300,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.grey.shade300,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.red.shade600,
                                            width: 2,
                                          ),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 14,
                                            ),
                                      ),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade900,
                                      ),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                // Display late fee if already set
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      order.lateFee != null &&
                                              order.lateFee! > 0
                                          ? 'Late Fee Amount'
                                          : 'No Late Fee Applied',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                    if (order.lateFee != null &&
                                        order.lateFee! > 0)
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
                              ],
                              if (_isOrderLate(order) &&
                                  (order.lateFee == null ||
                                      order.lateFee! == 0)) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.orange.shade200,
                                    ),
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
                                          'Please enter the late fee amount',
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
                    if (_isOrderLate(order) ||
                        (order.lateFee != null && order.lateFee! > 0))
                      const SizedBox(height: 16),

                    // Summary Card (matching website design)
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
                                  Icons.description_outlined,
                                  size: 20,
                                  color: Colors.indigo.shade600,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Summary',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F1724),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            // Subtotal
                            if (order.subtotal != null) ...[
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Subtotal',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    '₹${NumberFormat('#,##0.00').format(order.subtotal!)}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade900,
                                    ),
                                  ),
                                ],
                              ),
                              Divider(color: Colors.grey.shade200, height: 24),
                            ],
                            // GST
                            if (order.gstAmount != null &&
                                order.gstAmount! > 0) ...[
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'GST (5%)',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    '₹${NumberFormat('#,##0.00').format(order.gstAmount!)}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade900,
                                    ),
                                  ),
                                ],
                              ),
                              Divider(color: Colors.grey.shade200, height: 24),
                            ],
                            // Damage Fees (itemized breakdown)
                            Builder(
                              builder: (context) {
                                final itemsWithDamage =
                                    order.items
                                        ?.where(
                                          (item) =>
                                              item.damageCost != null &&
                                              item.damageCost! > 0,
                                        )
                                        .toList() ??
                                    [];

                                if (itemsWithDamage.isNotEmpty) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Damage Fees',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey.shade700,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      ...itemsWithDamage.map((item) {
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            left: 16,
                                            bottom: 6,
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  '- ${item.productName ?? 'Item'} (${item.quantity} qty)${item.missingNote != null && item.missingNote!.isNotEmpty ? ' - ${item.missingNote}' : ''}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                '₹${NumberFormat('#,##0.00').format(item.damageCost!)}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.grey.shade900,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Total Damage Fee',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey.shade700,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            '₹${NumberFormat('#,##0.00').format(order.damageFeeTotal ?? 0.0)}',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.red.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Divider(
                                        color: Colors.grey.shade200,
                                        height: 24,
                                      ),
                                    ],
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                            // Return Status Section
                            if (order.items != null &&
                                order.items!.isNotEmpty &&
                                !order.isScheduled &&
                                !order.isCancelled) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'RETURN STATUS',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey.shade700,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Builder(
                                      builder: (context) {
                                        final totalQuantity = order.items!
                                            .fold<int>(
                                              0,
                                              (sum, item) =>
                                                  sum + item.quantity,
                                            );
                                        final returnedQuantity = order.items!
                                            .fold<int>(0, (sum, item) {
                                              int returnedQty;
                                              if (item.isReturned) {
                                                returnedQty =
                                                    item.returnedQuantity ??
                                                    item.quantity;
                                              } else {
                                                returnedQty =
                                                    item.returnedQuantity ?? 0;
                                              }
                                              return sum + returnedQty;
                                            });
                                        final missingQuantity =
                                            totalQuantity - returnedQuantity;

                                        return Column(
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  'Total Quantity',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade600,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                Text(
                                                  '$totalQuantity',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.grey.shade700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  'Returned',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color:
                                                        Colors.green.shade700,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                Text(
                                                  '$returnedQuantity',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        Colors.green.shade700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (missingQuantity > 0) ...[
                                              const SizedBox(height: 8),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    'Missing',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color:
                                                          Colors.red.shade700,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                  Text(
                                                    '$missingQuantity',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color:
                                                          Colors.red.shade700,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ],
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            // Security Deposit (if provided)
                            if (order.securityDeposit != null &&
                                order.securityDeposit! > 0) ...[
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Security Deposit',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF1F2A7A),
                                    ),
                                  ),
                                  Text(
                                    '₹${NumberFormat('#,##0').format(order.securityDeposit!.toInt())}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF1F2A7A),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                            ],
                            // Total
                            Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.grey.shade50,
                                    Colors.grey.shade100,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Total',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade900,
                                    ),
                                  ),
                                  Text(
                                    '₹${NumberFormat('#,##0.00').format(order.totalAmount)}',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF1F2A7A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Security Deposit Refund Section (only show if security deposit exists)
                    if (order.securityDeposit != null &&
                        order.securityDeposit! > 0) ...[
                      const SizedBox(height: 16),
                      _SecurityDepositRefundSection(
                        order: order,
                        localDamageCosts:
                            _damageCosts, // Pass local damage costs for real-time calculation
                      ),
                    ],
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
                                onPressed: _isUpdating
                                    ? null
                                    : () => _handleStartRental(order),
                                icon: _isUpdating
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                    : const Icon(Icons.play_arrow, size: 20),
                                label: Text(
                                  _isUpdating
                                      ? 'Processing...'
                                      : 'Start Rental',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  backgroundColor: Colors.orange.shade600,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          if (canEdit) ...[
                            if (canMarkReturned || canStartRental)
                              const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _isUpdating
                                    ? null
                                    : () => context.push(
                                        '/orders/${order.id}/edit',
                                      ),
                                icon: const Icon(Icons.edit_outlined, size: 20),
                                label: const Text(
                                  'Edit Order',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
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
                            if (canMarkReturned || canStartRental || canEdit)
                              const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _isUpdating
                                    ? null
                                    : () => _handleCancelOrder(order),
                                icon: _isUpdating
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.red,
                                              ),
                                        ),
                                      )
                                    : const Icon(
                                        Icons.cancel_outlined,
                                        size: 20,
                                      ),
                                label: Text(
                                  _isUpdating
                                      ? 'Processing...'
                                      : 'Cancel Order',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.red.shade600,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
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
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1F2A7A)),
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

enum _OrderCategory {
  scheduled,
  ongoing,
  late,
  returned,
  partiallyReturned,
  cancelled,
  flagged,
}

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

class _OrderItemCard extends StatefulWidget {
  final OrderItem item;
  final int index;
  final bool isLast;
  final String orderId;
  final bool isChecked;
  final int? returnedQuantity;
  final double? damageCost;
  final String? damageDescription;
  final ValueChanged<bool>? onCheckboxChanged;
  final ValueChanged<int>? onReturnedQuantityChanged;
  final ValueChanged<double?>? onDamageCostChanged;
  final ValueChanged<String?>? onDamageDescriptionChanged;
  final VoidCallback? onUpdated;

  const _OrderItemCard({
    required this.item,
    required this.index,
    required this.isLast,
    required this.orderId,
    this.isChecked = false,
    this.returnedQuantity,
    this.damageCost,
    this.damageDescription,
    this.onCheckboxChanged,
    this.onReturnedQuantityChanged,
    this.onDamageCostChanged,
    this.onDamageDescriptionChanged,
    this.onUpdated,
  });

  @override
  State<_OrderItemCard> createState() => _OrderItemCardState();
}

class _OrderItemCardState extends State<_OrderItemCard> {
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
          productName: productName ?? 'Item ${widget.index}',
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
    // Use state values if checkbox is checked, otherwise use item values
    final currentReturnedQty = widget.isChecked
        ? (widget.returnedQuantity ?? widget.item.returnedQuantity ?? 0)
        : (widget.item.returnedQuantity ?? 0);
    final currentDamageCost = widget.isChecked && widget.damageCost != null
        ? widget.damageCost
        : widget.item.damageCost;
    final currentDamageDescription =
        widget.isChecked && widget.damageDescription != null
        ? widget.damageDescription
        : widget.item.missingNote;

    final isReturned = widget.item.isReturned;
    final isFullyReturned = currentReturnedQty >= widget.item.quantity;
    final isPartiallyReturned =
        currentReturnedQty > 0 && currentReturnedQty < widget.item.quantity;
    final isLate = widget.item.lateReturn == true;
    final hasDamage = currentDamageCost != null && currentDamageCost > 0;
    final pendingQty = widget.item.quantity - currentReturnedQty;

    // Determine card background color based on status
    Color cardBgColor = Colors.white;
    Color borderColor = Colors.grey.shade200;
    if (isFullyReturned) {
      cardBgColor = Colors.green.shade50;
      borderColor = Colors.green.shade200;
    } else if (isPartiallyReturned) {
      cardBgColor = Colors.yellow.shade50;
      borderColor = Colors.yellow.shade200;
    } else if (isLate && !isReturned) {
      cardBgColor = Colors.orange.shade50;
      borderColor = Colors.orange.shade200;
    } else if (hasDamage) {
      cardBgColor = Colors.red.shade50;
      borderColor = Colors.red.shade200;
    }

    // Check if order is scheduled or cancelled (disable editing)
    return Container(
      margin: EdgeInsets.only(bottom: widget.isLast ? 0 : 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Checkbox
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Checkbox(
              value: widget.isChecked,
              onChanged: widget.onCheckboxChanged != null
                  ? (value) => widget.onCheckboxChanged!(value ?? false)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          // Product Image
          InkWell(
            onTap: widget.item.photoUrl.isNotEmpty
                ? () => _showImagePreview(
                    context,
                    widget.item.photoUrl,
                    widget.item.productName,
                  )
                : null,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: widget.item.photoUrl.isNotEmpty
                      ? Colors.grey.shade300
                      : Colors.grey.shade200,
                  width: 2,
                ),
                color: Colors.grey.shade50,
              ),
              child: widget.item.photoUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        widget.item.photoUrl,
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.image_outlined,
                            size: 24,
                            color: Colors.grey.shade400,
                          );
                        },
                      ),
                    )
                  : Icon(
                      Icons.image_outlined,
                      size: 24,
                      color: Colors.grey.shade400,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          // Product Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product name with status badges
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: Text(
                        widget.item.productName ?? 'Item ${widget.index}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F1724),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                    // Status badges only show when checkbox is checked
                    if (widget.isChecked) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (isFullyReturned)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade500,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      size: 11,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 2),
                                    Flexible(
                                      child: Text(
                                        'Fully Returned',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (isPartiallyReturned)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.yellow.shade500,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.inventory_2,
                                      size: 11,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 2),
                                    Flexible(
                                      child: Text(
                                        'Partial Return',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (isLate && !isReturned)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade500,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      size: 11,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 2),
                                    Flexible(
                                      child: Text(
                                        'Late',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (hasDamage)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade500,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.warning,
                                      size: 11,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 2),
                                    Flexible(
                                      child: Text(
                                        'Damage',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                // Qty, Price, Total
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text(
                      'Qty: ${widget.item.quantity}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    Text(
                      'Price: ₹${widget.item.pricePerDay.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    Text(
                      'Total: ₹${widget.item.lineTotal.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
                // Returned Quantity Section (shown when checkbox is checked)
                if (widget.isChecked) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Returned Quantity *',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            SizedBox(
                              width: 100,
                              child: TextField(
                                controller:
                                    TextEditingController(
                                        text: currentReturnedQty.toString(),
                                      )
                                      ..selection = TextSelection.collapsed(
                                        offset: currentReturnedQty
                                            .toString()
                                            .length,
                                      ),
                                keyboardType: TextInputType.number,
                                enabled: true,
                                onChanged: (value) {
                                  final qty = int.tryParse(value);
                                  if (qty != null &&
                                      qty >= 0 &&
                                      qty <= widget.item.quantity) {
                                    widget.onReturnedQuantityChanged?.call(qty);
                                  }
                                },
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 8,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                              ),
                            ),
                            Text(
                              'of ${widget.item.quantity}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            if (isFullyReturned)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade500,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      'Fully Returned',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (isPartiallyReturned)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.yellow.shade700,
                                  border: Border.all(
                                    color: Colors.yellow.shade300,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '$pendingQty missing',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.yellow.shade900,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        // Damage Fee & Description (show when item is checked/returned - allows damage even for full returns)
                        if (widget.isChecked ||
                            isPartiallyReturned ||
                            isFullyReturned) ...[
                          const SizedBox(height: 16),
                          Text(
                            'Damage Fee (₹)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: TextEditingController(
                              text:
                                  currentDamageCost != null &&
                                      currentDamageCost > 0
                                  ? currentDamageCost.toStringAsFixed(0)
                                  : '',
                            ),
                            keyboardType: TextInputType.number,
                            enabled: true,
                            onChanged: (value) {
                              final cost = value.isEmpty
                                  ? null
                                  : double.tryParse(value);
                              widget.onDamageCostChanged?.call(cost);
                            },
                            decoration: InputDecoration(
                              hintText: '0.00',
                              prefixText: '₹ ',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Damage Description / Issues',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: TextEditingController(
                              text: currentDamageDescription ?? '',
                            ),
                            maxLines: 3,
                            enabled: true,
                            onChanged: (value) {
                              widget.onDamageDescriptionChanged?.call(
                                value.isEmpty ? null : value,
                              );
                            },
                            decoration: InputDecoration(
                              hintText:
                                  'Describe any damage, missing parts, or issues...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
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
        border: Border.all(color: Colors.grey.shade200, width: 1),
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
                fontWeight: detailColor != null
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            )
          else
            const SizedBox(
              height: 16,
            ), // Spacer to maintain symmetry when no detail
        ],
      ),
    );
  }
}

/// Security Deposit Refund Section Widget
///
/// Displays security deposit refund details matching website design
class _SecurityDepositRefundSection extends ConsumerStatefulWidget {
  final Order order;
  final Map<String, double>?
  localDamageCosts; // Local damage costs (before saving)

  const _SecurityDepositRefundSection({
    required this.order,
    this.localDamageCosts,
  });

  @override
  ConsumerState<_SecurityDepositRefundSection> createState() =>
      _SecurityDepositRefundSectionState();
}

class _SecurityDepositRefundSectionState
    extends ConsumerState<_SecurityDepositRefundSection> {
  bool _isRefunding = false;

  // Helper function to calculate refundable amount (matches website's calculateRefundableAmount)
  double _calculateRefundableAmount(Order order) {
    // Use deposit_balance from backend if available, otherwise calculate it
    final depositBalance =
        (order.depositBalance ??
                ((order.securityDepositAmount ?? 0.0) -
                    (order.securityDepositRefundedAmount ?? 0.0)))
            .clamp(0.0, double.infinity);

    // Per user request: always refund full remaining deposit balance (no deductions)
    return depositBalance;
  }

  bool _shouldShowRefundButton(Order order) {
    // Must have collected deposit and not fully refunded (matches website logic)
    if (!(order.securityDepositCollected == true) ||
        order.securityDepositRefunded == true) {
      return false;
    }

    // Must have some items returned or order completed/cancelled (matches website logic)
    // Website checks: item.return_status === 'returned' || item.return_status === 'partial' || (item.returned_quantity && item.returned_quantity > 0)
    final hasReturns =
        order.items != null &&
        order.items!.any(
          (item) =>
              item.returnStatus == ReturnStatus.returned ||
              (item.returnedQuantity != null && item.returnedQuantity! > 0),
        );
    final isOrderCompleted =
        order.status == OrderStatus.completed ||
        order.status == OrderStatus.completedWithIssues ||
        order.status == OrderStatus.cancelled;

    if (!hasReturns && !isOrderCompleted) {
      return false;
    }

    // Calculate remaining deposit to refund (deposit - already refunded)
    // This matches the website's simple calculation for button visibility
    final depositAmount = order.securityDepositAmount ?? 0.0;
    final alreadyRefunded = order.securityDepositRefundedAmount ?? 0.0;
    final remainingDeposit = (depositAmount - alreadyRefunded).clamp(
      0.0,
      double.infinity,
    );

    // Show button if there's remaining deposit to refund
    return remainingDeposit > 0.01;
  }

  Future<void> _handleRefundDeposit(Order order) async {
    if (_isRefunding) return;

    // Calculate remaining deposit to refund (deposit - already refunded)
    // This matches the website's simple calculation
    final depositAmount = order.securityDepositAmount ?? 0.0;
    final alreadyRefunded = order.securityDepositRefundedAmount ?? 0.0;
    final remainingDeposit = (depositAmount - alreadyRefunded).clamp(
      0.0,
      double.infinity,
    );

    if (remainingDeposit <= 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No amount available to refund'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Amount to refund = full remaining deposit balance (per user request)
    final amountToRefund = remainingDeposit;

    setState(() {
      _isRefunding = true;
    });

    try {
      final ordersService = ref.read(ordersServiceProvider);
      await ordersService.refundSecurityDeposit(
        orderId: order.id,
        amount: amountToRefund,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully refunded ₹${NumberFormat('#,##0.00').format(amountToRefund)}',
            ),
            backgroundColor: Colors.green,
          ),
        );

        // Refresh the order to get updated data
        ref.invalidate(orderProvider(order.id));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error refunding deposit: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefunding = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch the order provider to get the latest data from database
    final orderAsync = ref.watch(orderProvider(widget.order.id));

    return orderAsync.when(
      data: (updatedOrder) {
        if (updatedOrder == null) {
          return const SizedBox.shrink();
        }

        // Use the latest order data from database
        final order = updatedOrder;

        // Calculate refundable amount using website's formula
        final refundableAmount = _calculateRefundableAmount(order);

        // Use deposit_balance from backend if available
        final depositBalance =
            order.depositBalance ??
            ((order.securityDepositAmount ?? 0.0) -
                (order.securityDepositRefundedAmount ?? 0.0));

        final securityDeposit = order.securityDepositAmount ?? 0.0;
        final refunded = order.securityDepositRefundedAmount ?? 0.0;

        // Amount to show in refund button
        final amountToRefund = refundableAmount.clamp(0.0, depositBalance);

        // Status mapping to mirror website (matches website logic from order details page)
        String statusLabel;
        Color statusColor;
        if (order.securityDepositRefunded == true ||
            (refunded >= securityDeposit && securityDeposit > 0)) {
          statusLabel = 'Fully Refunded';
          statusColor = Colors.green;
        } else if (refunded > 0) {
          statusLabel = 'Partially Refunded';
          statusColor = Colors.orange;
        } else if (order.securityDepositCollected == true) {
          statusLabel = 'Collected';
          statusColor = Colors.blue;
        } else {
          statusLabel = 'Pending Collection';
          statusColor = Colors.orange;
        }

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
                      Icons.security_outlined,
                      size: 20,
                      color: Colors.indigo.shade600,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Security Deposit',
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Deposit Amount',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '₹${NumberFormat('#,##0.00').format(securityDeposit)}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Status',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: statusColor.withOpacity(0.2)),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_shouldShowRefundButton(order)) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isRefunding
                          ? null
                          : () => _handleRefundDeposit(order),
                      icon: _isRefunding
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
                          : const Icon(Icons.account_balance_wallet, size: 20),
                      label: Text(
                        _isRefunding
                            ? 'Processing Refund...'
                            : 'Refund Deposit ₹${NumberFormat('#,##0.00').format(amountToRefund)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                if (order.securityDepositRefundDate != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Last Refund',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        DateFormat(
                          'dd MMM yyyy, hh:mm a',
                        ).format(order.securityDepositRefundDate!),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade900,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

/// Collect Outstanding Amount Section Widget
///
/// Displays input field and button to collect outstanding amount
class _CollectOutstandingAmountSection extends ConsumerStatefulWidget {
  final Order order;
  final double outstandingAmount;

  const _CollectOutstandingAmountSection({
    required this.order,
    required this.outstandingAmount,
  });

  @override
  ConsumerState<_CollectOutstandingAmountSection> createState() =>
      _CollectOutstandingAmountSectionState();
}

class _CollectOutstandingAmountSectionState
    extends ConsumerState<_CollectOutstandingAmountSection> {
  final TextEditingController _amountController = TextEditingController();
  bool _isCollecting = false;
  double _remainingToCollect = 0.0;

  @override
  void initState() {
    super.initState();
    _remainingToCollect = widget.outstandingAmount;
    _amountController.text =
        '₹${NumberFormat('#,##0.00').format(widget.outstandingAmount)} (Remaining)';
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _handleCollect() async {
    if (_isCollecting) return;

    // Parse amount from input field (remove ₹ and extract number)
    String amountText = _amountController.text
        .replaceAll('₹', '')
        .replaceAll(',', '')
        .replaceAll(' (Remaining)', '')
        .trim();

    double? amountToCollect;
    try {
      amountToCollect = double.tryParse(amountText);
    } catch (e) {
      // If parsing fails, use remaining amount
      amountToCollect = _remainingToCollect;
    }

    // Validate amount
    if (amountToCollect == null || amountToCollect <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount to collect'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Don't allow collecting more than remaining (with small tolerance for floating-point precision)
    // Round to 2 decimal places to avoid floating-point precision issues
    final roundedAmount = (amountToCollect * 100).round() / 100;
    final roundedRemaining = (_remainingToCollect * 100).round() / 100;

    if (roundedAmount > roundedRemaining + 0.01) {
      // Allow 0.01 tolerance
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cannot collect more than ₹${NumberFormat('#,##0.00').format(_remainingToCollect)}',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Use rounded amount for collection
    final finalAmount = roundedAmount.clamp(0.0, roundedRemaining);

    setState(() {
      _isCollecting = true;
    });

    try {
      // Collect the outstanding amount using the service
      // Use the final rounded amount to avoid precision issues
      final ordersService = ref.read(ordersServiceProvider);
      await ordersService.collectOutstandingAmount(
        orderId: widget.order.id,
        amount: finalAmount,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully collected ₹${NumberFormat('#,##0.00').format(finalAmount)}',
            ),
            backgroundColor: Colors.green,
          ),
        );

        // Refresh the order to get updated data from database
        ref.invalidate(orderProvider(widget.order.id));

        // Wait for order to refresh, then recalculate remaining amount
        // This ensures we get the updated security_deposit_amount from database
        await Future.delayed(const Duration(milliseconds: 300));

        // Get updated order to recalculate outstanding amount
        final updatedOrderAsync = ref.read(orderProvider(widget.order.id));
        updatedOrderAsync.whenData((updatedOrder) {
          if (updatedOrder != null && mounted) {
            // Recalculate outstanding amount with updated data
            // Include all charges: rental, GST, damage fees, and late fees
            // Subtract both security deposit and additional amount collected
            final updatedSecurityDeposit =
                updatedOrder.securityDepositAmount ?? 0.0;
            final updatedAdditionalCollected =
                updatedOrder.additionalAmountCollected ?? 0.0;
            final rentalAmount = updatedOrder.subtotal ?? 0.0;
            final gstAmount = updatedOrder.gstAmount ?? 0.0;
            final damageFees = updatedOrder.damageFeeTotal ?? 0.0;
            final lateFee = updatedOrder.lateFee ?? 0.0;
            final totalCharges =
                rentalAmount + gstAmount + damageFees + lateFee;
            final newOutstanding =
                (totalCharges -
                        updatedSecurityDeposit -
                        updatedAdditionalCollected)
                    .clamp(0.0, double.infinity);

            setState(() {
              _remainingToCollect = newOutstanding;
              if (_remainingToCollect > 0) {
                _amountController.text =
                    '₹${NumberFormat('#,##0.00').format(_remainingToCollect)} (Remaining)';
              } else {
                _amountController.text = '₹0.00 (Remaining)';
              }
            });
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error collecting amount: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCollecting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch the order to get the latest data and recalculate outstanding amount
    final orderAsync = ref.watch(orderProvider(widget.order.id));

    return orderAsync.when(
      data: (updatedOrder) {
        if (updatedOrder == null) {
          return const SizedBox.shrink();
        }

        // Recalculate outstanding amount with latest order data
        final securityDeposit = updatedOrder.securityDepositAmount ?? 0.0;
        final additionalCollected =
            updatedOrder.additionalAmountCollected ?? 0.0;
        final rentalAmount = updatedOrder.subtotal ?? 0.0;
        final gstAmount = updatedOrder.gstAmount ?? 0.0;
        final damageFees = updatedOrder.damageFeeTotal ?? 0.0;
        final lateFee = updatedOrder.lateFee ?? 0.0;
        final totalCharges = rentalAmount + gstAmount + damageFees + lateFee;
        final currentOutstanding =
            (totalCharges - securityDeposit - additionalCollected).clamp(
              0.0,
              double.infinity,
            );

        // Hide the section if outstanding amount is 0 or less
        if (currentOutstanding <= 0) {
          return const SizedBox.shrink();
        }

        // Update remaining amount if it changed
        if (currentOutstanding != _remainingToCollect) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _remainingToCollect = currentOutstanding;
                _amountController.text =
                    '₹${NumberFormat('#,##0.00').format(_remainingToCollect)} (Remaining)';
              });
            }
          });
        }

        return Card(
          elevation: 0,
          color: Colors.pink.shade50,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.red.shade200, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 20,
                      color: Colors.red.shade700,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Collect Outstanding Amount',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Enter Amount to Collect',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _amountController,
                        readOnly: _remainingToCollect <= 0,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          // Allow only numbers and decimal point
                          FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                        ],
                        decoration: InputDecoration(
                          hintText: 'Enter amount',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Colors.red.shade400,
                              width: 2,
                            ),
                          ),
                          suffixIcon: _remainingToCollect > 0
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        Icons.arrow_drop_up,
                                        color: Colors.grey.shade600,
                                      ),
                                      onPressed: () {
                                        // Set to full remaining amount
                                        setState(() {
                                          _amountController.text =
                                              '₹${NumberFormat('#,##0.00').format(_remainingToCollect)} (Remaining)';
                                        });
                                      },
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.arrow_drop_down,
                                        color: Colors.grey.shade600,
                                      ),
                                      onPressed: () {
                                        // Set to zero
                                        setState(() {
                                          _amountController.text =
                                              '₹0.00 (Remaining)';
                                        });
                                      },
                                    ),
                                  ],
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.orange.shade400, Colors.red.shade600],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ElevatedButton(
                        onPressed: _remainingToCollect > 0 && !_isCollecting
                            ? _handleCollect
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isCollecting
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
                            : const Text(
                                'Collect',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
                if (_remainingToCollect > 0) ...[
                  const SizedBox(height: 8),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                      children: [
                        const TextSpan(text: 'Remaining to collect: '),
                        TextSpan(
                          text:
                              '₹${NumberFormat('#,##0.00').format(_remainingToCollect)}',
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

/// Refund Row Widget for displaying refund line items
/// Item Return Status Row Widget
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
                          color: const Color(0xFF1F2A7A).withOpacity(0.5),
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
                                            const AlwaysStoppedAnimation<Color>(
                                              Color(0xFF1F2A7A),
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
                    colors: [
                      const Color(0xFF1F2A7A).withOpacity(0.7),
                      const Color(0xFF1F2A7A),
                    ],
                  )
                : null,
            color: isActive ? null : Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isActive
                  ? const Color(0xFF1F2A7A).withOpacity(0.5)
                  : Colors.white.withOpacity(0.2),
              width: isActive ? 1.5 : 1,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Color(0xFF1F2A7A).withOpacity(0.3),
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

  // Build simplified timeline steps matching website logic
  List<_TimelineStep> _buildTimelineSteps() {
    final steps = <_TimelineStep>[];
    final order = widget.order;
    final events = _timelineEvents ?? [];

    // Helper to get staff name with fallbacks
    String getStaffName(Map<String, dynamic>? event) {
      if (event != null &&
          event['user_name'] != null &&
          event['user_name'] != 'Unknown') {
        return event['user_name'] as String;
      }
      if (order.staff != null) {
        return order.staff!.fullName.isNotEmpty
            ? order.staff!.fullName
            : order.staff!.username;
      }
      return 'Unknown';
    }

    // 1. Order Created (always show)
    final createdEvent = events.firstWhere(
      (e) => e['action'] == 'order_created',
      orElse: () => <String, dynamic>{},
    );
    steps.add(
      _TimelineStep(
        id: 'created',
        label: 'Order Created',
        icon: Icons.description_outlined,
        color: const Color(0xFF1F2A7A),
        timestamp:
            createdEvent['created_at'] ?? order.createdAt.toIso8601String(),
        staffName: getStaffName(createdEvent.isEmpty ? null : createdEvent),
      ),
    );

    // 2. Scheduled (if status is scheduled)
    if (order.status == OrderStatus.scheduled) {
      final scheduledEvent = events.firstWhere(
        (e) =>
            e['action'] == 'order_scheduled' ||
            (e['action'] == 'status_changed' && e['new_status'] == 'scheduled'),
        orElse: () => <String, dynamic>{},
      );
      steps.add(
        _TimelineStep(
          id: 'scheduled',
          label: 'Scheduled',
          icon: Icons.calendar_today_outlined,
          color: Colors.indigo,
          timestamp:
              scheduledEvent['created_at'] ?? order.createdAt.toIso8601String(),
          staffName: getStaffName(
            scheduledEvent.isEmpty ? null : scheduledEvent,
          ),
        ),
      );
    }

    // 3. Ongoing (if status is active)
    if (order.status == OrderStatus.active) {
      final startedEvent = events.firstWhere(
        (e) =>
            e['action'] == 'rental_started' ||
            (e['action'] == 'status_changed' && e['new_status'] == 'active'),
        orElse: () => <String, dynamic>{},
      );
      steps.add(
        _TimelineStep(
          id: 'ongoing',
          label: 'Ongoing',
          icon: Icons.play_circle_outlined,
          color: Colors.green,
          timestamp:
              startedEvent['created_at'] ??
              order.startDatetime ??
              order.startDate ??
              order.createdAt.toIso8601String(),
          staffName: getStaffName(startedEvent.isEmpty ? null : startedEvent),
        ),
      );
    }

    // 4. Returned (if items have been returned)
    final hasReturns =
        order.items?.any(
          (item) =>
              item.isReturned ||
              (item.returnedQuantity != null && item.returnedQuantity! > 0),
        ) ??
        false;
    if (hasReturns) {
      final returnEvent = events.firstWhere(
        (e) =>
            e['action'] == 'marked_returned' ||
            e['action'] == 'item_returned' ||
            e['action'] == 'all_items_returned' ||
            (e['action'] == 'status_changed' &&
                (e['new_status'] == 'completed' ||
                    e['new_status'] == 'partially_returned')),
        orElse: () => <String, dynamic>{},
      );
      final returnDate =
          returnEvent['created_at'] ??
          order.items
              ?.firstWhere(
                (item) => item.actualReturnDate != null,
                orElse: () => OrderItem(
                  id: '',
                  photoUrl: '',
                  productName: '',
                  quantity: 0,
                  pricePerDay: 0,
                  days: 0,
                  lineTotal: 0,
                ),
              )
              .actualReturnDate
              ?.toIso8601String() ??
          order.createdAt.toIso8601String();
      steps.add(
        _TimelineStep(
          id: 'returned',
          label: 'Returned',
          icon: Icons.check_circle_outlined,
          color: Colors.green,
          timestamp: returnDate,
          staffName: getStaffName(returnEvent.isEmpty ? null : returnEvent),
        ),
      );
    }

    // 5. Partially Returned (if status is partially_returned)
    if (order.status == OrderStatus.partiallyReturned) {
      final partialEvent = events.firstWhere(
        (e) =>
            e['action'] == 'partial_return' ||
            (e['action'] == 'status_changed' &&
                e['new_status'] == 'partially_returned'),
        orElse: () => <String, dynamic>{},
      );
      steps.add(
        _TimelineStep(
          id: 'partially_returned',
          label: 'Partially Returned',
          icon: Icons.check_circle_outline,
          color: Colors.yellow,
          timestamp:
              partialEvent['created_at'] ?? order.createdAt.toIso8601String(),
          staffName: getStaffName(partialEvent.isEmpty ? null : partialEvent),
        ),
      );
    }

    // 6. Flagged/Damaged (if flagged or has damage fees)
    final hasDamage = (order.damageFeeTotal ?? 0) > 0;
    if (order.status == OrderStatus.flagged || hasDamage) {
      final flaggedEvent = events.firstWhere(
        (e) => e['action'] == 'status_changed' && e['new_status'] == 'flagged',
        orElse: () => <String, dynamic>{},
      );
      steps.add(
        _TimelineStep(
          id: 'flagged',
          label: hasDamage ? 'Damaged' : 'Flagged',
          icon: Icons.flag_outlined,
          color: Colors.red,
          timestamp:
              flaggedEvent['created_at'] ?? order.createdAt.toIso8601String(),
          staffName: getStaffName(flaggedEvent.isEmpty ? null : flaggedEvent),
        ),
      );
    }

    // 7. Refunded (if security deposit was refunded)
    if ((order.securityDepositRefunded == true) ||
        ((order.securityDepositRefundedAmount ?? 0) > 0)) {
      final refundEvent = events.firstWhere(
        (e) => (e['action'] as String?)?.contains('refund') ?? false,
        orElse: () => <String, dynamic>{},
      );
      steps.add(
        _TimelineStep(
          id: 'refunded',
          label: 'Refunded',
          icon: Icons.rotate_left_outlined,
          color: Colors.purple,
          timestamp:
              refundEvent['created_at'] ??
              order.securityDepositRefundDate?.toIso8601String() ??
              order.createdAt.toIso8601String(),
          staffName: getStaffName(refundEvent.isEmpty ? null : refundEvent),
        ),
      );
    }

    // 8. Completed (if status is completed)
    if (order.status == OrderStatus.completed ||
        order.status == OrderStatus.completedWithIssues) {
      final completedEvent = events.firstWhere(
        (e) =>
            e['action'] == 'order_completed' ||
            (e['action'] == 'status_changed' && e['new_status'] == 'completed'),
        orElse: () => <String, dynamic>{},
      );
      steps.add(
        _TimelineStep(
          id: 'completed',
          label: 'Completed',
          icon: Icons.check_circle_outlined,
          color: const Color(0xFF1F2A7A),
          timestamp:
              completedEvent['created_at'] ?? order.createdAt.toIso8601String(),
          staffName: getStaffName(
            completedEvent.isEmpty ? null : completedEvent,
          ),
        ),
      );
    }

    // Sort by timestamp (oldest first)
    steps.sort(
      (a, b) =>
          DateTime.parse(a.timestamp).compareTo(DateTime.parse(b.timestamp)),
    );

    return steps;
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Card(
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_error != null) {
      return Card(
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                'Failed to load timeline',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    final timelineSteps = _buildTimelineSteps();

    if (timelineSteps.isEmpty) {
      return Card(
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.description_outlined,
                size: 48,
                color: Colors.grey.shade300,
              ),
              const SizedBox(height: 12),
              Text(
                'No timeline events yet',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Order Timeline',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Key order milestones',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            // Timeline container with line
            Stack(
              children: [
                // Vertical line (positioned at left: 20px to align with center of 32px circle)
                Positioned(
                  left: 20,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 0.5,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.grey.shade300,
                          Colors.grey.shade200,
                          Colors.grey.shade300,
                        ],
                      ),
                    ),
                  ),
                ),
                // Timeline steps
                Column(
                  children: timelineSteps.asMap().entries.map((entry) {
                    final index = entry.key;
                    final step = entry.value;
                    final isLast = index == timelineSteps.length - 1;

                    return _TimelineItemWidget(
                      event: _TimelineEvent(
                        icon: step.icon,
                        title: step.label,
                        description: '',
                        date: DateTime.parse(step.timestamp),
                        color: step.color,
                        isCompleted: true,
                        userName: step.staffName,
                      ),
                      isLast: isLast,
                      formatDateTime: _formatDateTime12Hour,
                    );
                  }).toList(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineStep {
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  final String timestamp;
  final String staffName;

  _TimelineStep({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    required this.timestamp,
    required this.staffName,
  });
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
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline dot with icon
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: isLast ? const Color(0xFF1F2A7A) : Colors.grey.shade300,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: event.color,
                  shape: BoxShape.circle,
                ),
                child: Icon(event.icon, color: Colors.white, size: 14),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Timeline content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badge with label
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: event.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: event.color.withOpacity(0.3),
                        width: 1,
                      ),
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
                  const SizedBox(height: 6),
                  // Timestamp and staff name
                  Row(
                    children: [
                      Text(
                        formatDateTime(event.date.toIso8601String()),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          '•',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ),
                      Text(
                        event.userName ?? 'Unknown',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
