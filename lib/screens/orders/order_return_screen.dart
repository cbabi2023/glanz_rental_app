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
  final Set<String> _unselectedReturnedItemIds = {}; // Item IDs that were returned but now unselected
  final Map<String, bool> _missingItems = {}; // Item ID -> is missing
  final Map<String, String> _missingNotes = {}; // Item ID -> missing note
  final Map<String, int> _returnedQuantities = {}; // Item ID -> quantity to return
  final Map<String, double> _damageCosts = {}; // Item ID -> damage cost
  final Map<String, String> _damageDescriptions = {}; // Item ID -> damage description
  final Map<String, TextEditingController> _quantityControllers = {}; // Item ID -> quantity controller
  double _lateFee = 0.0;
  bool _isProcessing = false;

  @override
  void dispose() {
    // Dispose all quantity controllers
    for (var controller in _quantityControllers.values) {
      controller.dispose();
    }
    _quantityControllers.clear();
    super.dispose();
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

          // Initialize selected items with already returned items on first build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_selectedItemIds.isEmpty && _unselectedReturnedItemIds.isEmpty) {
              setState(() {
                for (var item in items) {
                  if (item.id != null && item.isReturned) {
                    _selectedItemIds.add(item.id!);
                  }
                }
              });
            }
          });

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
                    final isUnselectedReturned = _unselectedReturnedItemIds.contains(item.id);
                    final isSelected = _selectedItemIds.contains(item.id) && !isUnselectedReturned;
                    final isMarkedMissing = _missingItems[item.id] == true;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 0,
                      color: isItemReturned && !isUnselectedReturned
                          ? Colors.green.shade50
                          : isItemMissing || isMarkedMissing
                              ? Colors.red.shade50
                              : isItemLate
                                  ? Colors.orange.shade50
                                  : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isItemReturned && !isUnselectedReturned
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
                              value: (isItemReturned && !isUnselectedReturned) || (isSelected && !isItemReturned),
                              onChanged: (value) {
                                setState(() {
                                  if (value == true) {
                                    // Selecting item
                                    if (isItemReturned) {
                                      // This is a returned item - just remove from unselected list
                                      _unselectedReturnedItemIds.remove(item.id!);
                                    } else {
                                      // This is a pending item - add to selected
                                      _selectedItemIds.add(item.id!);
                                      _missingItems[item.id!] = false;
                                      // Initialize returned quantity to pending quantity
                                      _returnedQuantities[item.id!] = item.pendingQuantity;
                                    }
                                  } else {
                                    // Unselecting item
                                    if (isItemReturned) {
                                      // This is a returned item being unselected (marked for unreturn)
                                      _unselectedReturnedItemIds.add(item.id!);
                                      _selectedItemIds.remove(item.id!);
                                    } else {
                                      // This is a pending item being unselected
                                      _selectedItemIds.remove(item.id!);
                                      _missingItems.remove(item.id!);
                                      _missingNotes.remove(item.id!);
                                      _returnedQuantities.remove(item.id!);
                                    }
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
                                    'Qty: ${item.quantity} × ₹${item.pricePerDay.toStringAsFixed(0)}/day × ${item.days} day${item.days != 1 ? 's' : ''}${item.returnedQuantity != null && item.returnedQuantity! > 0 ? ' (${item.returnedQuantity} returned)' : ''}',
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
                                    // Quantity selector for partial returns
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.blue.shade200,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Return Quantity:',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF0F1724),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              // Decrease button
                                              IconButton(
                                                icon: const Icon(Icons.remove_circle_outline),
                                                iconSize: 24,
                                                color: Colors.blue.shade700,
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                                onPressed: () {
                                                  setState(() {
                                                    final currentQty = _returnedQuantities[item.id!] ?? item.pendingQuantity;
                                                    if (currentQty > 1) {
                                                      _returnedQuantities[item.id!] = currentQty - 1;
                                                    }
                                                  });
                                                },
                                              ),
                                              const SizedBox(width: 4),
                                              // Quantity input field (editable)
                                              Expanded(
                                                child: _QuantityInputField(
                                                  key: ValueKey('qty_${item.id}'),
                                                  initialValue: _returnedQuantities[item.id!] ?? item.pendingQuantity,
                                                  maxValue: item.pendingQuantity,
                                                  onChanged: (value) {
                                                    // Update state without rebuilding immediately
                                                    _returnedQuantities[item.id!] = value;
                                                  },
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              // Increase button
                                              IconButton(
                                                icon: const Icon(Icons.add_circle_outline),
                                                iconSize: 24,
                                                color: Colors.blue.shade700,
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                                onPressed: () {
                                                  setState(() {
                                                    final currentQty = _returnedQuantities[item.id!] ?? item.pendingQuantity;
                                                    final pendingQty = item.pendingQuantity;
                                                    if (currentQty < pendingQty) {
                                                      _returnedQuantities[item.id!] = currentQty + 1;
                                                    }
                                                  });
                                                },
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Max: ${item.pendingQuantity}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Show missing quantity info if returned quantity < pending quantity
                                    Builder(
                                      builder: (context) {
                                        final returnedQty = _returnedQuantities[item.id!] ?? item.pendingQuantity;
                                        final missingQty = item.pendingQuantity - returnedQty;
                                        
                                        if (missingQty > 0 && returnedQty < item.pendingQuantity) {
                                          return Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
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
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Icon(
                                                          Icons.warning_amber_rounded,
                                                          size: 18,
                                                          color: Colors.orange.shade700,
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Expanded(
                                                          child: Text(
                                                            '$missingQty item${missingQty > 1 ? 's' : ''} will be marked as missing',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              fontWeight: FontWeight.w600,
                                                              color: Colors.orange.shade900,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 12),
                                                    // Damage Cost Input
                                                    _DamageCostField(
                                                      key: ValueKey('damage_cost_${item.id}'),
                                                      initialValue: _damageCosts[item.id!],
                                                      onChanged: (value) {
                                                        setState(() {
                                                          if (value == null) {
                                                            _damageCosts.remove(item.id!);
                                                          } else {
                                                            _damageCosts[item.id!] = value;
                                                          }
                                                        });
                                                      },
                                                    ),
                                                    const SizedBox(height: 8),
                                                    // Description Input
                                                    _DamageDescriptionField(
                                                      key: ValueKey('damage_desc_${item.id}'),
                                                      initialValue: _damageDescriptions[item.id!],
                                                      onChanged: (value) {
                                                        setState(() {
                                                          if (value.trim().isEmpty) {
                                                            _damageDescriptions.remove(item.id!);
                                                          } else {
                                                            _damageDescriptions[item.id!] = value;
                                                          }
                                                        });
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          );
                                        }
                                        return const SizedBox.shrink();
                                      },
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
                    if (_selectedItemIds.isNotEmpty || _unselectedReturnedItemIds.isNotEmpty)
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
                                : _buildProcessButtonLabel(),
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

  String _buildProcessButtonLabel() {
    final selectedCount = _selectedItemIds.length;
    final unselectedCount = _unselectedReturnedItemIds.length;
    
    if (selectedCount > 0 && unselectedCount > 0) {
      return 'Process Changes ($selectedCount to return, $unselectedCount to unreturn)';
    } else if (selectedCount > 0) {
      return 'Process Return ($selectedCount selected)';
    } else if (unselectedCount > 0) {
      return 'Unreturn Items ($unselectedCount selected)';
    }
    return 'Process Return';
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

    if (_selectedItemIds.isEmpty && _unselectedReturnedItemIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No changes to process'),
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

      // Build item returns list - only include items that need changes
      final List<ItemReturn> itemReturns = [];
      final items = order.items ?? [];
      
      // Add items to be returned or marked as missing (only if not already returned)
      for (final itemId in _selectedItemIds) {
        final item = items.firstWhere((i) => i.id == itemId, orElse: () => items.first);
        // Only process if item is not already returned
        if (!item.isReturned) {
          final isMissing = _missingItems[itemId] == true;
          final missingNote = _missingNotes[itemId];
          final returnedQty = _returnedQuantities[itemId] ?? item.pendingQuantity;
          final pendingQty = item.pendingQuantity;

          if (isMissing) {
            // Mark entire item as missing
            itemReturns.add(ItemReturn(
              itemId: itemId,
              returnStatus: 'missing',
              actualReturnDate: null,
              missingNote: missingNote?.isEmpty ?? true ? null : missingNote,
              returnedQuantity: null,
              damageCost: _damageCosts[itemId],
              description: _damageDescriptions[itemId]?.trim().isEmpty ?? true ? null : _damageDescriptions[itemId]?.trim(),
            ));
          } else {
            // Partial return - some returned, rest missing
            if (returnedQty < pendingQty && returnedQty > 0) {
              // Mark returned items - missing items will be processed separately
              itemReturns.add(ItemReturn(
                itemId: itemId,
                returnStatus: 'returned',
                actualReturnDate: DateTime.now(),
                missingNote: null,
                returnedQuantity: returnedQty,
              ));
            } else if (returnedQty == pendingQty) {
              // Full return
              itemReturns.add(ItemReturn(
                itemId: itemId,
                returnStatus: 'returned',
                actualReturnDate: DateTime.now(),
                missingNote: null,
                returnedQuantity: returnedQty,
              ));
            }
          }
        }
      }
      
      // Add items to be unreturned (reverted to not_yet_returned)
      for (final itemId in _unselectedReturnedItemIds) {
        itemReturns.add(ItemReturn(
          itemId: itemId,
          returnStatus: 'not_yet_returned',
          actualReturnDate: null,
          missingNote: null,
        ));
      }
      
      // If no actual changes, return early
      if (itemReturns.isEmpty) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No changes to process'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Process all returns in a single call
      await ordersService.processOrderReturn(
        orderId: widget.orderId,
        itemReturns: itemReturns,
        userId: userProfile!.id,
        lateFee: _lateFee,
      );
      
      // Process missing items separately for partial returns
      final List<ItemReturn> missingItemReturns = [];
      
      for (final itemId in _selectedItemIds) {
        final item = items.firstWhere((i) => i.id == itemId, orElse: () => items.first);
        if (!item.isReturned) {
          final returnedQty = _returnedQuantities[itemId] ?? item.pendingQuantity;
          final pendingQty = item.pendingQuantity;
          
          if (returnedQty < pendingQty && returnedQty > 0) {
            final missingQty = pendingQty - returnedQty;
            
            // Create missing entry with damage cost and description
            missingItemReturns.add(ItemReturn(
              itemId: itemId,
              returnStatus: 'missing',
              actualReturnDate: null,
              missingNote: _damageDescriptions[itemId]?.trim().isEmpty ?? true 
                  ? (_damageCosts[itemId] != null ? 'Missing item - Damage cost: ₹${_damageCosts[itemId]!.toInt()}' : 'Items not returned')
                  : _damageDescriptions[itemId]?.trim(),
              returnedQuantity: missingQty,
              damageCost: _damageCosts[itemId],
              description: _damageDescriptions[itemId]?.trim().isEmpty ?? true ? null : _damageDescriptions[itemId]?.trim(),
            ));
          }
        }
      }
      
      // Process missing items in a separate call
      if (missingItemReturns.isNotEmpty) {
        // Wait for return transaction to complete
        await Future.delayed(const Duration(milliseconds: 800));
        
        // Refresh order to get updated state
        ref.invalidate(orderProvider(widget.orderId));
        await Future.delayed(const Duration(milliseconds: 500));
        
        try {
          await ordersService.processOrderReturn(
            orderId: widget.orderId,
            itemReturns: missingItemReturns,
            userId: userProfile!.id,
            lateFee: 0.0, // Don't add late fee again
          );
        } catch (e) {
          print('Error processing missing items: $e');
          // Show user-friendly error message about database constraint
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'Return processed, but missing items failed. Please run the database migration to fix this. See DATABASE_FIX_REQUIRED.md',
                ),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 8),
                action: SnackBarAction(
                  label: 'Dismiss',
                  textColor: Colors.white,
                  onPressed: () {},
                ),
              ),
            );
          }
          // Continue - returned items were processed successfully
        }
      }

      // Refresh order data
      ref.invalidate(orderProvider(widget.orderId));
      if (userProfile!.branchId != null) {
        ref.invalidate(ordersProvider(OrdersParams(branchId: userProfile!.branchId!)));
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

/// Quantity Input Field Widget
/// 
/// A reusable widget for entering quantity with validation
class _QuantityInputField extends StatefulWidget {
  final int initialValue;
  final int maxValue;
  final ValueChanged<int> onChanged;

  const _QuantityInputField({
    super.key,
    required this.initialValue,
    required this.maxValue,
    required this.onChanged,
  });

  @override
  State<_QuantityInputField> createState() => _QuantityInputFieldState();
}

class _QuantityInputFieldState extends State<_QuantityInputField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  late int _currentValue;
  bool _isInternalUpdate = false;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.initialValue;
    _controller = TextEditingController(text: _currentValue.toString());
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(_QuantityInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only update if the value changed externally (from +/- buttons) and we're not focused
    if (widget.initialValue != oldWidget.initialValue && 
        widget.initialValue != _currentValue &&
        !_focusNode.hasFocus) {
      _isInternalUpdate = true;
      _currentValue = widget.initialValue;
      _controller.text = _currentValue.toString();
      _isInternalUpdate = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _updateValue(int newValue, {bool updateController = true}) {
    int finalValue = newValue;
    
    if (newValue > widget.maxValue) {
      finalValue = widget.maxValue;
    } else if (newValue < 1) {
      finalValue = 1;
    }

    if (finalValue != _currentValue) {
      _currentValue = finalValue;
      if (updateController) {
        _controller.text = finalValue.toString();
        // Move cursor to end
        _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: _controller.text.length),
        );
      }
      widget.onChanged(finalValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Color(0xFF0F1724),
      ),
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.blue.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.blue.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.blue.shade700, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      onChanged: (value) {
        // Don't update if this is an internal update
        if (_isInternalUpdate) return;
        
        // Allow empty string temporarily while user is typing
        if (value.isEmpty) {
          return;
        }
        
        // Parse and validate
        final intValue = int.tryParse(value);
        if (intValue != null) {
          _updateValue(intValue, updateController: false);
        }
      },
      onSubmitted: (value) {
        // When user presses enter/done, validate and set final value
        final intValue = int.tryParse(value);
        if (intValue != null) {
          _updateValue(intValue);
        } else if (value.isEmpty) {
          // If empty, restore to current value
          _controller.text = _currentValue.toString();
        } else {
          // Invalid input, restore to current value
          _controller.text = _currentValue.toString();
        }
        // Remove focus
        _focusNode.unfocus();
      },
      onTapOutside: (event) {
        // When user taps outside, validate and set final value
        final intValue = int.tryParse(_controller.text);
        if (intValue != null) {
          _updateValue(intValue);
        } else if (_controller.text.isEmpty) {
          _controller.text = _currentValue.toString();
        } else {
          _controller.text = _currentValue.toString();
        }
        _focusNode.unfocus();
      },
    );
  }
}

/// Damage Cost Input Field Widget
class _DamageCostField extends StatefulWidget {
  final double? initialValue;
  final ValueChanged<double?> onChanged;

  const _DamageCostField({
    super.key,
    this.initialValue,
    required this.onChanged,
  });

  @override
  State<_DamageCostField> createState() => _DamageCostFieldState();
}

class _DamageCostFieldState extends State<_DamageCostField> {
  late TextEditingController _controller;
  late double? _currentValue;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.initialValue;
    _controller = TextEditingController(
      text: _currentValue != null ? _currentValue!.toInt().toString() : '',
    );
  }

  @override
  void didUpdateWidget(_DamageCostField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue) {
      _currentValue = widget.initialValue;
      _controller.text = _currentValue != null ? _currentValue!.toInt().toString() : '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: 'Damage Cost (₹)',
        hintText: '0',
        prefixText: '₹ ',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      onChanged: (value) {
        if (value.isEmpty) {
          _currentValue = null;
          widget.onChanged(null);
        } else {
          final cost = int.tryParse(value);
          if (cost != null && cost >= 0) {
            _currentValue = cost.toDouble();
            widget.onChanged(cost.toDouble());
          }
        }
      },
      onSubmitted: (value) {
        if (value.isEmpty) {
          _currentValue = null;
          _controller.text = '';
          widget.onChanged(null);
        } else {
          final cost = int.tryParse(value);
          if (cost != null && cost >= 0) {
            _currentValue = cost.toDouble();
            _controller.text = cost.toString();
            widget.onChanged(cost.toDouble());
          } else {
            _controller.text = _currentValue != null ? _currentValue!.toInt().toString() : '';
          }
        }
      },
    );
  }
}

/// Damage Description Input Field Widget
class _DamageDescriptionField extends StatefulWidget {
  final String? initialValue;
  final ValueChanged<String> onChanged;

  const _DamageDescriptionField({
    super.key,
    this.initialValue,
    required this.onChanged,
  });

  @override
  State<_DamageDescriptionField> createState() => _DamageDescriptionFieldState();
}

class _DamageDescriptionFieldState extends State<_DamageDescriptionField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue ?? '');
  }

  @override
  void didUpdateWidget(_DamageDescriptionField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue) {
      _controller.text = widget.initialValue ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      maxLines: 3,
      decoration: InputDecoration(
        labelText: 'Description (Damage/Missing reason)',
        hintText: 'Enter description...',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      onChanged: (value) {
        widget.onChanged(value);
      },
    );
  }
}

