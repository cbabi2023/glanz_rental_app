import 'package:flutter/material.dart';

/// Order Summary Widget
/// 
/// Displays order totals including subtotal, GST, and grand total
class OrderSummaryWidget extends StatelessWidget {
  final double subtotal;
  final double gstAmount;
  final double grandTotal;
  final bool? gstEnabled;
  final double? gstRate;
  final bool? gstIncluded;

  const OrderSummaryWidget({
    super.key,
    required this.subtotal,
    required this.gstAmount,
    required this.grandTotal,
    this.gstEnabled,
    this.gstRate,
    this.gstIncluded,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Order Summary',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Subtotal
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Subtotal'),
                Text(
                  '₹${subtotal.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            
            // GST (if enabled)
            if (gstEnabled == true && gstAmount > 0) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'GST ${gstRate != null ? '(${(gstRate ?? 0.0).toStringAsFixed(2)}%)' : ''} ${gstIncluded == true ? '(Included)' : ''}',
                  ),
                  Text(
                    '₹${gstAmount.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
            
            const Divider(height: 24),
            
            // Grand Total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Grand Total',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '₹${grandTotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
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

