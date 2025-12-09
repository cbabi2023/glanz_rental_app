import 'package:flutter/material.dart';

/// Order Summary Widget
/// 
/// Displays order totals including subtotal, GST, grand total, and security deposit
class OrderSummaryWidget extends StatelessWidget {
  final double subtotal;
  final double gstAmount;
  final double grandTotal;
  final bool? gstEnabled;
  final double? gstRate;
  final bool? gstIncluded;
  final double? securityDeposit;

  const OrderSummaryWidget({
    super.key,
    required this.subtotal,
    required this.gstAmount,
    required this.grandTotal,
    this.gstEnabled,
    this.gstRate,
    this.gstIncluded,
    this.securityDeposit,
  });

  @override
  Widget build(BuildContext context) {
    // Always show GST if amount > 0 (regardless of flags)
    // This ensures GST shows for staff using branch admin settings
    final shouldShowGst = gstAmount > 0;
    
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
            
            // GST (show if amount > 0)
            // This handles cases where staff uses branch admin's GST settings
            if (shouldShowGst) ...[
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
            
            // Security Deposit (if provided)
            if (securityDeposit != null && securityDeposit! > 0) ...[
              const SizedBox(height: 16),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Security Deposit',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2A7A),
                    ),
                  ),
                  Text(
                    '₹${securityDeposit!.toInt()}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2A7A),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

