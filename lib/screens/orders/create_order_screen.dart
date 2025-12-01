import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/customer.dart';
import '../../models/order_item.dart';
import '../../providers/order_draft_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/orders_provider.dart';
import '../../widgets/orders/customer_search_widget.dart';
import '../../widgets/orders/order_datetime_widget.dart';
import '../../widgets/orders/order_items_widget.dart';
import '../../widgets/orders/order_summary_widget.dart';

/// Create Order Screen
/// 
/// Multi-step form for creating a new rental order
class CreateOrderScreen extends ConsumerStatefulWidget {
  const CreateOrderScreen({super.key});

  @override
  ConsumerState<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends ConsumerState<CreateOrderScreen> {
  final _invoiceNumberController = TextEditingController();
  Customer? _selectedCustomer;
  bool _isLoading = false;

  @override
  void dispose() {
    _invoiceNumberController.dispose();
    super.dispose();
  }

  Future<void> _handleSaveOrder() async {
    final draft = ref.read(orderDraftProvider);
    final userProfile = ref.read(userProfileProvider).value;

    // Validation
    if (_selectedCustomer == null || _selectedCustomer!.id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a customer'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (draft.endDate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an end date'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (draft.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one item'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_invoiceNumberController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an invoice number'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (userProfile?.branchId == null || userProfile?.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User information missing'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate all items have required fields
    final invalidItems = draft.items.where(
      (item) => item.photoUrl.isEmpty ||
          item.quantity <= 0 ||
          item.pricePerDay < 0,
    );
    if (invalidItems.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please check all items have valid photo, quantity, and price'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final ordersService = ref.read(ordersServiceProvider);
      final subtotal = ref.read(orderSubtotalProvider);
      final gstAmount = ref.read(orderGstAmountProvider);
      final grandTotal = ref.read(orderGrandTotalProvider);

      // Prepare items for database
      final itemsForDb = draft.items.map((item) {
        // Update days for each item based on start/end dates
        final days = calculateDays(draft.startDate, draft.endDate);
        final lineTotal = item.quantity * item.pricePerDay * days;
        
        return {
          'photo_url': item.photoUrl,
          'product_name': item.productName,
          'quantity': item.quantity,
          'price_per_day': item.pricePerDay,
          'days': days,
          'line_total': lineTotal,
        };
      }).toList();

      // Create order
      await ordersService.createOrder(
        branchId: userProfile!.branchId!,
        staffId: userProfile.id,
        customerId: _selectedCustomer!.id,
        invoiceNumber: _invoiceNumberController.text.trim(),
        startDate: draft.startDate,
        endDate: draft.endDate,
        startDatetime: draft.startDate,
        endDatetime: draft.endDate,
        totalAmount: grandTotal,
        subtotal: subtotal,
        gstAmount: userProfile.gstEnabled == true ? gstAmount : 0,
        items: itemsForDb,
      );

      // Clear draft
      ref.read(orderDraftProvider.notifier).clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/orders');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create order: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(orderDraftProvider);
    final userProfile = ref.read(userProfileProvider).value;
    final subtotal = ref.watch(orderSubtotalProvider);
    final gstAmount = ref.watch(orderGstAmountProvider);
    final grandTotal = ref.watch(orderGrandTotalProvider);

    // Calculate days
    final days = draft.startDate.isNotEmpty && draft.endDate.isNotEmpty
        ? calculateDays(draft.startDate, draft.endDate)
        : 0;

    // Parse dates
    final startDate = draft.startDate.isNotEmpty
        ? DateTime.tryParse(draft.startDate)
        : null;
    final endDate =
        draft.endDate.isNotEmpty ? DateTime.tryParse(draft.endDate) : null;

    // Update invoice number in draft when controller changes
    if (_invoiceNumberController.text != draft.invoiceNumber) {
      _invoiceNumberController.text = draft.invoiceNumber;
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('New Order'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Customer Section
            CustomerSearchWidget(
              selectedCustomer: _selectedCustomer,
              onSelectCustomer: (customer) {
                setState(() {
                  _selectedCustomer = customer;
                });
                ref.read(orderDraftProvider.notifier).setCustomer(
                      customerId: customer.id,
                      customerName: customer.name,
                      customerPhone: customer.phone,
                    );
              },
            ),

            const SizedBox(height: 24),

            // Rental Dates & Times
            OrderDateTimeWidget(
              startDate: startDate,
              endDate: endDate,
              onStartDateChanged: (date) {
                if (date != null) {
                  ref.read(orderDraftProvider.notifier).setStartDate(
                        date.toIso8601String(),
                      );
                  // Auto-update end date to next day if not set
                  if (endDate == null) {
                    final nextDay = date.add(const Duration(days: 1));
                    ref.read(orderDraftProvider.notifier).setEndDate(
                          nextDay.toIso8601String(),
                        );
                  }
                }
              },
              onEndDateChanged: (date) {
                if (date != null) {
                  ref.read(orderDraftProvider.notifier).setEndDate(
                        date.toIso8601String(),
                      );
                }
              },
            ),

            const SizedBox(height: 24),

            // Items Section
            OrderItemsWidget(
              items: draft.items,
              onAddItem: (item) {
                // Update item with correct days
                final updatedItem = OrderItem(
                  id: item.id,
                  photoUrl: item.photoUrl,
                  productName: item.productName,
                  quantity: item.quantity,
                  pricePerDay: item.pricePerDay,
                  days: days,
                  lineTotal: item.quantity * item.pricePerDay * days,
                );
                ref.read(orderDraftProvider.notifier).addItem(updatedItem);
              },
              onUpdateItem: (index, updatedItem) {
                // Update item with correct days
                final itemWithDays = OrderItem(
                  id: updatedItem.id,
                  photoUrl: updatedItem.photoUrl,
                  productName: updatedItem.productName,
                  quantity: updatedItem.quantity,
                  pricePerDay: updatedItem.pricePerDay,
                  days: days,
                  lineTotal: updatedItem.quantity * updatedItem.pricePerDay * days,
                );
                ref.read(orderDraftProvider.notifier).updateItem(index, itemWithDays);
              },
              onRemoveItem: (index) {
                ref.read(orderDraftProvider.notifier).removeItem(index);
              },
              onImageClick: (imageUrl) {
                // Show image in dialog
                showDialog(
                  context: context,
                  builder: (context) => Dialog(
                    child: Stack(
                      children: [
                        Image.network(imageUrl),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              days: days,
            ),

            const SizedBox(height: 24),

            // Order Summary
            OrderSummaryWidget(
              subtotal: subtotal,
              gstAmount: gstAmount,
              grandTotal: grandTotal,
              gstEnabled: userProfile?.gstEnabled,
              gstRate: userProfile?.gstRate,
              gstIncluded: userProfile?.gstIncluded,
            ),

            const SizedBox(height: 24),

            // Invoice Number
            const Text(
              'Invoice Number *',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _invoiceNumberController,
              decoration: const InputDecoration(
                hintText: 'Enter invoice number',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                ref.read(orderDraftProvider.notifier).setInvoiceNumber(value);
              },
            ),

            const SizedBox(height: 24),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleSaveOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0B63FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Save Order',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
