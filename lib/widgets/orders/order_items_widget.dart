import 'package:flutter/material.dart';
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

  OrderItem _handleUpdateItem(int index, String field, dynamic value) {
    final item = items[index];
    
    // Create updated item with new value
    final updatedQuantity = field == 'quantity' ? value : item.quantity;
    final updatedPrice = field == 'price_per_day' ? value : item.pricePerDay;
    
    // Calculate line total
    final updatedLineTotal = updatedQuantity * updatedPrice * item.days;
    
    return OrderItem(
      id: item.id,
      photoUrl: item.photoUrl,
      productName: field == 'product_name' ? value : item.productName,
      quantity: updatedQuantity,
      pricePerDay: updatedPrice,
      days: item.days,
      lineTotal: updatedLineTotal,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Items',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            CameraUploadWidget(
              onUploadComplete: _handleAddItem,
            ),
          ],
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
                'No items added. Tap the camera icon to add an item.',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          ...items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return _buildItemCard(context, index, item);
          }),
      ],
    );
  }

  Widget _buildItemCard(BuildContext context, int index, OrderItem item) {
    final productNameController = TextEditingController(text: item.productName);
    final quantityController =
        TextEditingController(text: item.quantity.toString());
    final priceController =
        TextEditingController(text: item.pricePerDay.toString());

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Photo
            Center(
              child: GestureDetector(
                onTap: () => onImageClick?.call(item.photoUrl),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: item.photoUrl.startsWith('http')
                      ? Image.network(
                          item.photoUrl,
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
                          File(item.photoUrl),
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
              controller: productNameController,
              decoration: const InputDecoration(
                labelText: 'Product Name',
                hintText: 'Optional',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                final updatedItem = _handleUpdateItem(index, 'product_name', value);
                onUpdateItem(index, updatedItem);
              },
            ),
            const SizedBox(height: 16),

            // Quantity & Price Row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: quantityController,
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      final quantity = int.tryParse(value) ?? 0;
                      if (quantity >= 0) {
                        final updatedItem =
                            _handleUpdateItem(index, 'quantity', quantity);
                        quantityController.text = quantity.toString();
                        onUpdateItem(index, updatedItem);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: priceController,
                    decoration: const InputDecoration(
                      labelText: 'Price per Day',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    onChanged: (value) {
                      final price = double.tryParse(value) ?? 0.0;
                      if (price >= 0) {
                        final updatedItem =
                            _handleUpdateItem(index, 'price_per_day', price);
                        priceController.text = price.toString();
                        onUpdateItem(index, updatedItem);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Line Total
            Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${item.quantity} × ₹${item.pricePerDay.toStringAsFixed(2)} × $days days',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      '₹${item.lineTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => onRemoveItem(index),
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

