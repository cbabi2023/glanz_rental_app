import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Edit Order Screen
/// 
/// Allows editing an order before it's returned
class EditOrderScreen extends StatelessWidget {
  final String orderId;

  const EditOrderScreen({
    super.key,
    required this.orderId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Order'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.edit, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Edit Order Screen',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Coming soon...',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

