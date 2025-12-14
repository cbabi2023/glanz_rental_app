import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/order_item.dart';
import 'camera_upload_widget.dart';
import 'dart:io';

/// Order Items Widget
/// 
/// Manages order items with photo upload, quantity, and pricing
class OrderItemsWidget extends StatelessWidget {
  final List<OrderItem> items;
  final Function(OrderItem) onAddItem;
  final Function(int, OrderItem) onUpdateItem;
  final Function(int) onRemoveItem;
  final Function(String)? onImageClick;
  final int days;

  const OrderItemsWidget({
    super.key,
    required this.items,
    required this.onAddItem,
    required this.onUpdateItem,
    required this.onRemoveItem,
    this.onImageClick,
    required this.days,
  });

  void _handleAddItem(String photoUrl) {
    if (photoUrl.isEmpty) return;

    final newItem = OrderItem(
      id: '',
      photoUrl: photoUrl,
      productName: '',
      quantity: 1,
      pricePerDay: 0,
      days: days,
      lineTotal: 0,
    );

    onAddItem(newItem);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Items',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),

        // Items List
        if (items.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text(
                'No items added. Use the camera button below to add an item.',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          // Reverse display order so newly added items stay below the previous ones
          ...items.asMap().entries.toList().reversed.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return _OrderItemCard(
              key: ValueKey(item.id?.isEmpty ?? true ? 'item_$index' : item.id!),
              item: item,
              index: index,
              days: days,
              onUpdateItem: onUpdateItem,
              onRemoveItem: onRemoveItem,
              onImageClick: onImageClick,
            );
          }),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: CameraUploadWidget(
            onUploadComplete: _handleAddItem,
          ),
        ),
      ],
    );
  }
}

/// Individual Order Item Card
/// 
/// Stateful widget to maintain text controllers across rebuilds
class _OrderItemCard extends StatefulWidget {
  final OrderItem item;
  final int index;
  final int days;
  final Function(int, OrderItem) onUpdateItem;
  final Function(int) onRemoveItem;
  final Function(String)? onImageClick;

  const _OrderItemCard({
    super.key,
    required this.item,
    required this.index,
    required this.days,
    required this.onUpdateItem,
    required this.onRemoveItem,
    this.onImageClick,
  });

  @override
  State<_OrderItemCard> createState() => _OrderItemCardState();
}

class _OrderItemCardState extends State<_OrderItemCard> {
  late TextEditingController _productNameController;
  late TextEditingController _quantityController;
  late TextEditingController _priceController;

  @override
  void initState() {
    super.initState();
    _productNameController = TextEditingController(text: widget.item.productName ?? '');
    _quantityController = TextEditingController(text: widget.item.quantity > 0 ? widget.item.quantity.toString() : '');
    // Don't show default 0 - leave empty if price is 0
    _priceController = TextEditingController(text: widget.item.pricePerDay > 0 ? _formatPrice(widget.item.pricePerDay) : '');
  }

  // Format price without unnecessary decimals
  String _formatPrice(double price) {
    if (price == price.truncateToDouble()) {
      return price.toInt().toString();
    }
    return price.toString();
  }

  @override
  void didUpdateWidget(_OrderItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // NEVER sync controller text from item value during typing
    // Only reset controllers if photo URL changed (completely new item)
    // This prevents dots and unwanted formatting from appearing automatically
    if (oldWidget.item.photoUrl != widget.item.photoUrl) {
      // Photo changed - this is a completely new item, reset controllers
      _productNameController.text = widget.item.productName ?? '';
      _quantityController.text = widget.item.quantity > 0 ? widget.item.quantity.toString() : '';
      // Don't show default 0 - leave empty if price is 0
      _priceController.text = widget.item.pricePerDay > 0 ? _formatPrice(widget.item.pricePerDay) : '';
    }
    // Otherwise, let the user type freely without any interference
  }

  @override
  void dispose() {
    _productNameController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  OrderItem _handleUpdateItem(String field, dynamic value) {
    final item = widget.item;
    
    // Create updated item with new value
    final updatedQuantity = field == 'quantity' ? value : item.quantity;
    final updatedPrice = field == 'price_per_day' ? value : item.pricePerDay;
    
    // Calculate line total (without multiplying by days)
    final updatedLineTotal = updatedQuantity * updatedPrice;
    
    return OrderItem(
      id: item.id,
      photoUrl: item.photoUrl,
      productName: field == 'product_name' ? value : item.productName,
      quantity: updatedQuantity,
      pricePerDay: updatedPrice,
      days: widget.days,
      lineTotal: updatedLineTotal,
    );
  }

  void _updateItem(String field, dynamic value) {
    final updatedItem = _handleUpdateItem(field, value);
    widget.onUpdateItem(widget.index, updatedItem);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Photo
            Center(
              child: GestureDetector(
                onTap: () => widget.onImageClick?.call(widget.item.photoUrl),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: widget.item.photoUrl.startsWith('http')
                      ? Image.network(
                          widget.item.photoUrl,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 80,
                              height: 80,
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.broken_image),
                            );
                          },
                        )
                      : Image.file(
                          File(widget.item.photoUrl),
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Product Name
            TextField(
              controller: _productNameController,
              decoration: const InputDecoration(
                labelText: 'Product Name',
                hintText: 'Optional',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                _updateItem('product_name', value);
              },
              onEditingComplete: () {
                // Dismiss keyboard
                FocusScope.of(context).unfocus();
              },
              onTapOutside: (_) {
                // Dismiss keyboard
                FocusScope.of(context).unfocus();
              },
            ),
            const SizedBox(height: 16),

            // Quantity & Price Row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _quantityController,
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      // Allow empty value during editing - don't reset immediately
                      if (value.isEmpty) {
                        // Don't update the item, just allow empty field
                        return;
                      }
                      final quantity = int.tryParse(value);
                      if (quantity != null && quantity >= 0) {
                        _updateItem('quantity', quantity);
                      }
                    },
                    onEditingComplete: () {
                      // When done editing, ensure field has a valid value
                      if (_quantityController.text.isEmpty || _quantityController.text.trim().isEmpty) {
                        _quantityController.text = '1';
                        _updateItem('quantity', 1);
                      }
                      // Dismiss keyboard
                      FocusScope.of(context).unfocus();
                    },
                    onTapOutside: (_) {
                      // When user taps outside, ensure field has a valid value
                      if (_quantityController.text.isEmpty || _quantityController.text.trim().isEmpty) {
                        _quantityController.text = '1';
                        _updateItem('quantity', 1);
                      }
                      // Dismiss keyboard
                      FocusScope.of(context).unfocus();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _priceController,
                    decoration: const InputDecoration(
                      labelText: 'Price',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      // Allow only numbers and one decimal point
                      // User must manually type the dot - it won't appear automatically
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    onChanged: (value) {
                      // Never update the controller text from here - let user type freely
                      // Allow empty value during editing - don't reset immediately
                      if (value.isEmpty) {
                        // Don't update the item, just allow empty field
                        return;
                      }
                      // Allow partial decimal input (like "0." or ".") - don't update yet
                      if (value == '.' || value == '0.') {
                        return;
                      }
                      // Only update the item value, but don't touch the controller text
                      final price = double.tryParse(value);
                      if (price != null && price >= 0) {
                        _updateItem('price_per_day', price);
                      }
                    },
                    onEditingComplete: () {
                      // When done editing, format if valid, otherwise leave empty
                      final text = _priceController.text.trim();
                      if (text.isEmpty || text == '.' || text == '0.') {
                        // Leave empty - don't set default 0
                        _priceController.text = '';
                        _updateItem('price_per_day', 0.0);
                      } else {
                        final price = double.tryParse(text);
                        if (price == null || price < 0) {
                          // Invalid input - leave empty
                          _priceController.text = '';
                          _updateItem('price_per_day', 0.0);
                        } else {
                          // Format without unnecessary decimals
                          _priceController.text = _formatPrice(price);
                        }
                      }
                      // Dismiss keyboard
                      FocusScope.of(context).unfocus();
                    },
                    onTapOutside: (_) {
                      // When user taps outside, format if valid, otherwise leave empty
                      final text = _priceController.text.trim();
                      if (text.isEmpty || text == '.' || text == '0.') {
                        // Leave empty - don't set default 0
                        _priceController.text = '';
                        _updateItem('price_per_day', 0.0);
                      } else {
                        final price = double.tryParse(text);
                        if (price == null || price < 0) {
                          // Invalid input - leave empty
                          _priceController.text = '';
                          _updateItem('price_per_day', 0.0);
                        } else {
                          // Format without unnecessary decimals
                          _priceController.text = _formatPrice(price);
                        }
                      }
                      // Dismiss keyboard
                      FocusScope.of(context).unfocus();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Line Total
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${widget.item.quantity} × ₹${widget.item.pricePerDay.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      '₹${widget.item.lineTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => widget.onRemoveItem(widget.index),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
