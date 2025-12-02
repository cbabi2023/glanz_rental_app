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
/// Modern, attractive multi-step form for creating a new rental order
class CreateOrderScreen extends ConsumerStatefulWidget {
  const CreateOrderScreen({super.key});

  @override
  ConsumerState<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends ConsumerState<CreateOrderScreen> {
  final _scrollController = ScrollController();
  final _invoiceNumberController = TextEditingController();
  Customer? _selectedCustomer;
  bool _isLoading = false;

  @override
  void dispose() {
    _scrollController.dispose();
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
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
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
      final branchId = userProfile!.branchId!;
      await ordersService.createOrder(
        branchId: branchId,
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

      // Invalidate orders provider to refresh the orders list
      ref.invalidate(ordersProvider(OrdersParams(branchId: branchId)));

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
      backgroundColor: const Color(0xFFF7F9FB),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Modern Header
          SliverAppBar(
            expandedHeight: 140,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF0B63FF),
                      Color(0xFF0052D4),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.add_shopping_cart,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'New Order',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Create a new rental order',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Form Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Customer Selection Card
                  _SectionCard(
                    title: 'Customer Information',
                    icon: Icons.person_outline,
                    child: CustomerSearchWidget(
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
                  ),

                  const SizedBox(height: 20),

                  // Rental Period Card
                  _SectionCard(
                    title: 'Rental Period',
                    icon: Icons.calendar_today_outlined,
                    child: OrderDateTimeWidget(
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
                  ),

                  const SizedBox(height: 20),

                  // Order Items Card
                  _SectionCard(
                    title: 'Order Items',
                    icon: Icons.inventory_2_outlined,
                    child: OrderItemsWidget(
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
                  ),

                  const SizedBox(height: 20),

                  // Order Summary Card
                  _SectionCard(
                    title: 'Order Summary',
                    icon: Icons.receipt_long_outlined,
                    child: OrderSummaryWidget(
                      subtotal: subtotal,
                      gstAmount: gstAmount,
                      grandTotal: grandTotal,
                      gstEnabled: userProfile?.gstEnabled,
                      gstRate: userProfile?.gstRate,
                      gstIncluded: userProfile?.gstIncluded,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Invoice Number Card
                  _SectionCard(
                    title: 'Invoice Details',
                    icon: Icons.description_outlined,
                    child: _ModernTextField(
                      controller: _invoiceNumberController,
                      label: 'Invoice Number',
                      hint: 'Enter invoice number',
                      prefixIcon: Icons.receipt_outlined,
                      onChanged: (value) {
                        ref.read(orderDraftProvider.notifier).setInvoiceNumber(value);
                      },
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleSaveOrder,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0B63FF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_outline, size: 22),
                                SizedBox(width: 8),
                                Text(
                                  'Create Order',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B63FF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: const Color(0xFF0B63FF),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F1724),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}

class _ModernTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData prefixIcon;
  final ValueChanged<String>? onChanged;

  const _ModernTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.prefixIcon,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(
        fontSize: 15,
        color: Color(0xFF0F1724),
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(prefixIcon, color: const Color(0xFF0B63FF)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0B63FF), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade300),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade500, width: 2),
        ),
      ),
    );
  }
}
