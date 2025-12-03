import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/order.dart';
import '../../models/order_item.dart';
import '../../services/orders_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/orders_provider.dart';

/// Order Return Screen
///
/// Allows users to select individual items and return them (partial returns)
class OrderReturnScreen extends ConsumerStatefulWidget {
  final String orderId;

  const OrderReturnScreen({
    super.key,
    required this.orderId,
  });

  @override
  ConsumerState<OrderReturnScreen> createState() => _OrderReturnScreenState();
}

class _OrderReturnScreenState extends ConsumerState<OrderReturnScreen> {
  final Set<String> _selectedItemIds = {}; // Item IDs to mark as returned
  final Map<String, bool> _missingItems = {}; // Item ID -> is missing
  final Map<String, String> _missingNotes = {}; // Item ID -> missing note
  double _lateFee = 0.0;
  bool _isProcessing = false;

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
          'Process Return',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F1724),
          ),
        ),
      ),
      body: orderAsync.when(
        data: (order) {
          if (order == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Order not found',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            );
          }

          final items = order.items ?? [];
          if (items.isEmpty) {
            return Center(
              child: Text(
                'No items found in this order',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            );
          }

          // Calculate stats
          final returnedCount = items.where((item) => item.isReturned).length;
          final missingCount = items.where((item) => item.isMissing).length;
          final pendingCount = items.where((item) => item.isPending).length;

          // Check if order is late
          final endDateStr = order.endDatetime ?? order.endDate;
          DateTime? endDate;
          bool isLate = false;
          try {
            endDate = DateTime.parse(endDateStr);
            isLate = DateTime.now().isAfter(endDate);
          } catch (e) {
            // Ignore parsing errors
          }

          return Column(
            children: [
              // Summary Card
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem('Total', items.length, Colors.blue),
                    _buildStatItem('Returned', returnedCount, Colors.green),
                    _buildStatItem('Pending', pendingCount, Colors.orange),
                    _buildStatItem('Missing', missingCount, Colors.red),
                  ],
                ),
              ),

              // Late Fee Input (if late)
              if (isLate)
                Container(
                  color: Colors.orange.shade50,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Late Fee Amount (₹)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: '0',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixText: '₹ ',
                        ),
                        onChanged: (value) {
                          setState(() {
                            _lateFee = double.tryParse(value) ?? 0.0;
                          });
                        },
                      ),
                    ],
                  ),
                ),

              // Items List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    if (item.id == null) return const SizedBox.shrink();

                    final isItemReturned = item.isReturned;
                    final isItemMissing = item.isMissing;
                    final isItemLate = item.lateReturn == true;
                    final isSelected = _selectedItemIds.contains(item.id);
                    final isMarkedMissing = _missingItems[item.id] == true;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 0,
                      color: isItemReturned
                          ? Colors.green.shade50
                          : isItemMissing || isMarkedMissing
                              ? Colors.red.shade50
                              : isItemLate
                                  ? Colors.orange.shade50
                                  : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isItemReturned
                              ? Colors.green.shade200
                              : isItemMissing || isMarkedMissing
                                  ? Colors.red.shade200
                                  : Colors.grey.shade200,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            // Checkbox
                            Checkbox(
                              value: isSelected || isItemReturned,
                              onChanged: isItemReturned
                                  ? null
                                  : (value) {
                                      setState(() {
                                        if (value == true) {
                                          _selectedItemIds.add(item.id!);
                                          _missingItems[item.id!] = false;
                                        } else {
                                          _selectedItemIds.remove(item.id!);
                                          _missingItems.remove(item.id!);
                                          _missingNotes.remove(item.id!);
                                        }
                                      });
                                    },
                            ),

                            const SizedBox(width: 8),

                            // Item Image
                            if (item.photoUrl.isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  imageUrl: item.photoUrl,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    width: 60,
                                    height: 60,
                                    color: Colors.grey.shade200,
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      Container(
                                    width: 60,
                                    height: 60,
                                    color: Colors.grey.shade200,
                                    child: const Icon(Icons.image_not_supported),
                                  ),
                                ),
                              ),

                            const SizedBox(width: 12),

                            // Item Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.productName ?? 'Unnamed Product',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F1724),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Qty: ${item.quantity} × ₹${item.pricePerDay.toStringAsFixed(0)}/day × ${item.days} day${item.days != 1 ? 's' : ''}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  Text(
                                    'Total: ₹${item.lineTotal.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF0F1724),
                                    ),
                                  ),
                                  if (isItemLate && !isItemReturned) ...[
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade200,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Late',
                                        style: TextStyle(
                                          color: Colors.orange.shade900,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (isItemReturned &&
                                      item.actualReturnDate != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Returned: ${DateFormat('dd MMM yyyy HH:mm').format(item.actualReturnDate!)}',
                                      style: TextStyle(
                                        color: Colors.green.shade700,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                  // Missing note input (if selected and not returned)
                                  if (isSelected &&
                                      !isItemReturned &&
                                      !isItemMissing) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () {
                                              setState(() {
                                                _missingItems[item.id!] = true;
                                              });
                                              _showMissingNoteDialog(item.id!);
                                            },
                                            icon: const Icon(
                                              Icons.warning_amber_rounded,
                                              size: 16,
                                            ),
                                            label: const Text('Mark Missing'),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.red,
                                              side: const BorderSide(
                                                color: Colors.red,
                                              ),
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (_missingNotes[item.id!] != null) ...[
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade50,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: Colors.red.shade200,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.note,
                                              size: 14,
                                              color: Colors.red.shade700,
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                _missingNotes[item.id!]!,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.red.shade900,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Action Buttons
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (_selectedItemIds.isNotEmpty)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isProcessing ? null : _processReturn,
                          icon: _isProcessing
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Icon(Icons.check_circle),
                          label: Text(
                            _isProcessing
                                ? 'Processing...'
                                : 'Process Return (${_selectedItemIds.length} selected)',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isProcessing ? null : _markAllReturned,
                        icon: const Icon(Icons.select_all),
                        label: const Text('Mark All as Returned'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue.shade600,
                          side: BorderSide(color: Colors.blue.shade600),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Error loading order',
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: TextStyle(color: Colors.red.shade400, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          '$value',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  void _markAllReturned() {
    final order = ref.read(orderProvider(widget.orderId)).value;
    if (order == null) return;

    setState(() {
      final items = order.items ?? [];
      for (var item in items) {
        if (!item.isReturned && item.id != null) {
          _selectedItemIds.add(item.id!);
        }
      }
    });
  }

  void _showMissingNoteDialog(String itemId) {
    final noteController = TextEditingController(
      text: _missingNotes[itemId] ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Missing Item Note'),
        content: TextField(
          controller: noteController,
          decoration: const InputDecoration(
            hintText: 'Enter reason why item is missing...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _missingItems[itemId] = false;
                _missingNotes.remove(itemId);
              });
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _missingNotes[itemId] = noteController.text.trim();
              });
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _processReturn() async {
    final order = ref.read(orderProvider(widget.orderId)).value;
    final userProfile = ref.read(userProfileProvider).value;

    if (order == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order not found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (userProfile?.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User information missing'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedItemIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one item to return'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final ordersService = ref.read(ordersServiceProvider);

      // Build item returns list
      final itemReturns = _selectedItemIds.map((itemId) {
        final isMissing = _missingItems[itemId] == true;
        final missingNote = _missingNotes[itemId];

        return ItemReturn(
          itemId: itemId,
          returnStatus: isMissing ? 'missing' : 'returned',
          actualReturnDate: isMissing ? null : DateTime.now(),
          missingNote: missingNote?.isEmpty ?? true ? null : missingNote,
        );
      }).toList();

      await ordersService.processOrderReturn(
        orderId: widget.orderId,
        itemReturns: itemReturns,
        userId: userProfile!.id,
        lateFee: _lateFee,
      );

      // Refresh order data
      ref.invalidate(orderProvider(widget.orderId));
      final branchId = userProfile.branchId;
      if (branchId != null) {
        ref.invalidate(ordersProvider(OrdersParams(branchId: branchId)));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Return processed successfully'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
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
          _isProcessing = false;
        });
      }
    }
  }
}

