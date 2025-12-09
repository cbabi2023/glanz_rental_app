import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../models/user_profile.dart';

/// Edit Order Screen
///
/// Modern, attractive form for editing an existing rental order
class EditOrderScreen extends ConsumerStatefulWidget {
  final String orderId;

  const EditOrderScreen({super.key, required this.orderId});

  @override
  ConsumerState<EditOrderScreen> createState() => _EditOrderScreenState();
}

class _EditOrderScreenState extends ConsumerState<EditOrderScreen> {
  final _scrollController = ScrollController();
  final _invoiceNumberController = TextEditingController();
  Customer? _selectedCustomer;
  bool _isLoading = false;
  bool _isInitialized = false;

  @override
  void dispose() {
    _scrollController.dispose();
    _invoiceNumberController.dispose();
    super.dispose();
  }

  Future<void> _initializeFromOrder() async {
    if (_isInitialized) return;

    final orderAsync = ref.read(orderProvider(widget.orderId));

    await orderAsync.when(
      data: (order) async {
        if (order == null || !mounted) return;

        // Load order into draft
        ref.read(orderDraftProvider.notifier).loadOrder(order);

        // Set customer
        if (order.customer != null) {
          _selectedCustomer = order.customer;
        }

        // Set invoice number
        _invoiceNumberController.text = order.invoiceNumber;

        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
        }
      },
      loading: () {},
      error: (_, __) {},
    );
  }

  Future<void> _handleUpdateOrder() async {
    final draft = ref.read(orderDraftProvider);
    final userProfile = ref.read(userProfileProvider).value;
    final orderAsync = ref.read(orderProvider(widget.orderId));

    // Wait for order to load
    final order = orderAsync.when(
      data: (order) => order,
      loading: () => null,
      error: (_, __) => null,
    );

    if (order == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order not found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validation
    if (_selectedCustomer == null || _selectedCustomer!.id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a customer'),
          backgroundColor: Colors.red,
        ),
      );
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
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

    // Validate all items have required fields
    final invalidItems = draft.items.where(
      (item) =>
          item.photoUrl.isEmpty || item.quantity <= 0 || item.pricePerDay < 0,
    );
    if (invalidItems.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please check all items have valid photo, quantity, and price',
          ),
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

      // If staff or branch admin, use super admin GST settings (await to ensure we have it before submission)
      UserProfile? gstProfile = ref.read(userProfileProvider).value;
      if (gstProfile?.isStaff == true || gstProfile?.isBranchAdmin == true) {
        try {
          gstProfile = await ref.read(superAdminProfileProvider.future);
        } catch (_) {
          // fallback to user profile if super admin lookup fails
          gstProfile = ref.read(userProfileProvider).value;
        }
      }

      final gstAmount = calculateGstAmount(
        subtotal: subtotal,
        user: gstProfile,
      );
      final grandTotal = calculateGrandTotal(
        subtotal: subtotal,
        user: gstProfile,
      );

      // Prepare items for database
      final itemsForDb = draft.items.map((item) {
        // Update days for each item based on start/end dates
        final days = calculateDays(draft.startDate, draft.endDate);
        final lineTotal = item.quantity * item.pricePerDay;

        return {
          'photo_url': item.photoUrl,
          'product_name': item.productName,
          'quantity': item.quantity,
          'price_per_day': item.pricePerDay,
          'days': days,
          'line_total': lineTotal,
        };
      }).toList();

      // Update order
      await ordersService.updateOrder(
        orderId: widget.orderId,
        customerId: _selectedCustomer?.id,
        invoiceNumber: _invoiceNumberController.text.trim(),
        startDate: draft.startDate,
        endDate: draft.endDate,
        startDatetime: draft.startDate,
        endDatetime: draft.endDate,
        totalAmount: grandTotal,
        subtotal: subtotal,
        gstAmount: gstAmount,
        securityDeposit: draft.securityDeposit,
        items: itemsForDb,
      );

      // Invalidate order provider to refresh the order
      ref.invalidate(orderProvider(widget.orderId));

      // Invalidate orders list to refresh
      if (userProfile?.branchId != null) {
        ref.invalidate(
          ordersProvider(OrdersParams(branchId: userProfile!.branchId)),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update order: ${e.toString()}'),
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
    final orderAsync = ref.watch(orderProvider(widget.orderId));
    final draft = ref.watch(orderDraftProvider);
    final userProfile = ref.read(userProfileProvider).value;
    final subtotal = ref.watch(orderSubtotalProvider);
    final gstAmount = ref.watch(orderGstAmountProvider);
    final grandTotal = ref.watch(orderGrandTotalProvider);

    // Get branch admin's GST settings if user is staff
    // Get super admin's GST settings if user is staff or branch admin
    UserProfile? superAdmin;
    UserProfile? gstSettingsProfile = userProfile;

    if (userProfile?.isStaff == true || userProfile?.isBranchAdmin == true) {
      final superAdminAsync = ref.watch(superAdminProfileProvider);
      superAdmin =
          superAdminAsync.value; // Get the value (may be null if still loading)
      // Use super admin's GST settings for display if available, otherwise use user's own settings
      gstSettingsProfile = superAdmin ?? userProfile;
    }

    // Initialize from order when data is available
    orderAsync.whenData((order) {
      if (order != null && !_isInitialized) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _initializeFromOrder();
        });
      }
    });

    // Calculate days
    final days = draft.startDate.isNotEmpty && draft.endDate.isNotEmpty
        ? calculateDays(draft.startDate, draft.endDate)
        : 0;

    // Parse dates
    final startDate = draft.startDate.isNotEmpty
        ? DateTime.tryParse(draft.startDate)
        : null;
    final endDate = draft.endDate.isNotEmpty
        ? DateTime.tryParse(draft.endDate)
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
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

          if (!_isInitialized) {
            return const Center(child: CircularProgressIndicator());
          }

          return CustomScrollView(
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
                        colors: [Color(0xFF1F2A7A), Color(0xFF1F2A7A)],
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
                                    Icons.edit_outlined,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Edit Order',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        order.invoiceNumber,
                                        style: const TextStyle(
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
                            ref
                                .read(orderDraftProvider.notifier)
                                .setCustomer(
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
                              ref
                                  .read(orderDraftProvider.notifier)
                                  .setStartDate(date.toIso8601String());
                              // Auto-update end date to next day if not set
                              if (endDate == null) {
                                final nextDay = date.add(
                                  const Duration(days: 1),
                                );
                                ref
                                    .read(orderDraftProvider.notifier)
                                    .setEndDate(nextDay.toIso8601String());
                              }
                            }
                          },
                          onEndDateChanged: (date) {
                            if (date != null) {
                              ref
                                  .read(orderDraftProvider.notifier)
                                  .setEndDate(date.toIso8601String());
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
                              lineTotal: item.quantity * item.pricePerDay,
                            );
                            ref
                                .read(orderDraftProvider.notifier)
                                .addItem(updatedItem);
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
                              lineTotal:
                                  updatedItem.quantity *
                                  updatedItem.pricePerDay,
                            );
                            ref
                                .read(orderDraftProvider.notifier)
                                .updateItem(index, itemWithDays);
                          },
                          onRemoveItem: (index) {
                            ref
                                .read(orderDraftProvider.notifier)
                                .removeItem(index);
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

                      // Security Deposit Card
                      _SectionCard(
                        title: 'Security Deposit',
                        icon: Icons.security_outlined,
                        child: _SecurityDepositField(
                          value: draft.securityDeposit,
                          onChanged: (value) {
                            ref
                                .read(orderDraftProvider.notifier)
                                .setSecurityDeposit(value);
                          },
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
                          gstEnabled: gstSettingsProfile?.gstEnabled,
                          gstRate: gstSettingsProfile?.gstRate,
                          gstIncluded: gstSettingsProfile?.gstIncluded,
                          securityDeposit: draft.securityDeposit,
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
                            ref
                                .read(orderDraftProvider.notifier)
                                .setInvoiceNumber(value);
                          },
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Update Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleUpdateOrder,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1F2A7A),
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
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.save_outlined, size: 22),
                                    SizedBox(width: 8),
                                    Text(
                                      'Update Order',
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
          );
        },
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (error, stack) => Scaffold(
          appBar: AppBar(
            title: const Text('Edit Order'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                const SizedBox(height: 16),
                Text(
                  'Error loading order',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
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
                    backgroundColor: const Color(0xFF1F2A7A),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                    color: const Color(0xFF1F2A7A).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: const Color(0xFF1F2A7A), size: 20),
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
      style: const TextStyle(fontSize: 15, color: Color(0xFF0F1724)),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(prefixIcon, color: const Color(0xFF1F2A7A)),
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
          borderSide: const BorderSide(color: Color(0xFF1F2A7A), width: 2),
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

class _SecurityDepositField extends StatefulWidget {
  final double? value;
  final ValueChanged<double?> onChanged;

  const _SecurityDepositField({required this.value, required this.onChanged});

  @override
  State<_SecurityDepositField> createState() => _SecurityDepositFieldState();
}

class _SecurityDepositFieldState extends State<_SecurityDepositField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.value != null && widget.value! > 0
          ? widget.value!.toInt().toString()
          : '',
    );
  }

  @override
  void didUpdateWidget(_SecurityDepositField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _controller.text = widget.value != null && widget.value! > 0
          ? widget.value!.toInt().toString()
          : '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(fontSize: 15, color: Color(0xFF0F1724)),
      decoration: InputDecoration(
        labelText: 'Security Deposit Amount',
        hintText: 'Enter security deposit (optional)',
        prefixIcon: const Icon(
          Icons.security_outlined,
          color: Color(0xFF1F2A7A),
        ),
        prefixText: '₹ ',
        prefixStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Color(0xFF0F1724),
        ),
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
          borderSide: const BorderSide(color: Color(0xFF1F2A7A), width: 2),
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
      onChanged: (value) {
        if (value.isEmpty) {
          widget.onChanged(null);
          return;
        }
        final amount = int.tryParse(value);
        widget.onChanged(
          amount != null && amount > 0 ? amount.toDouble() : null,
        );
      },
    );
  }
}
