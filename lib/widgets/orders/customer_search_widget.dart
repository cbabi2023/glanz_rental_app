import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/customers_provider.dart';
import '../../models/customer.dart';

/// Customer Search Widget
/// 
/// Allows searching and selecting a customer for an order
class CustomerSearchWidget extends ConsumerStatefulWidget {
  final Customer? selectedCustomer;
  final Function(Customer) onSelectCustomer;

  const CustomerSearchWidget({
    super.key,
    this.selectedCustomer,
    required this.onSelectCustomer,
  });

  @override
  ConsumerState<CustomerSearchWidget> createState() =>
      _CustomerSearchWidgetState();
}

class _CustomerSearchWidgetState
    extends ConsumerState<CustomerSearchWidget> {
  final _searchController = TextEditingController();
  bool _showDropdown = false;
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool _isCustomerVerified(Customer customer) {
    return customer.idProofNumber != null ||
        customer.idProofFrontUrl != null ||
        customer.idProofBackUrl != null;
  }

  @override
  Widget build(BuildContext context) {
    final searchQuery = _searchController.text.trim();
    final customersAsync = ref.watch(
      customersProvider(CustomersParams(searchQuery: searchQuery.isEmpty ? null : searchQuery)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Customer *',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        
        // Search Input with Add Button
        Row(
          children: [
            Expanded(
              child: Stack(
                children: [
                  TextField(
                    controller: _searchController,
                    focusNode: _focusNode,
                    decoration: InputDecoration(
                      hintText: 'Search customer by name or phone',
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                      suffixIcon: widget.selectedCustomer != null
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                widget.onSelectCustomer(Customer(
                                  id: '',
                                  name: '',
                                  phone: '',
                                ));
                              },
                            )
                          : null,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _showDropdown = value.trim().isNotEmpty;
                      });
                    },
                    onTap: () {
                      if (_searchController.text.trim().isNotEmpty) {
                        setState(() {
                          _showDropdown = true;
                        });
                      }
                    },
                  ),
                  
                  // Dropdown with Customer List
                  if (_showDropdown)
                    Positioned(
                      top: 56,
                      left: 0,
                      right: 0,
                      child: Material(
                        elevation: 8,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          constraints: const BoxConstraints(maxHeight: 300),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: customersAsync.when(
                            data: (data) {
                              final customers = (data['data'] as List).cast<Customer>();
                              if (customers.isEmpty) {
                                return Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('No customers found'),
                                      const SizedBox(height: 8),
                                      TextButton.icon(
                                        onPressed: () {
                                          context.push('/customers/new');
                                        },
                                        icon: const Icon(Icons.add),
                                        label: const Text('Add New Customer'),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              return ListView.builder(
                                shrinkWrap: true,
                                itemCount: customers.length,
                                itemBuilder: (context, index) {
                                  final customer = customers[index];
                                  final isVerified = _isCustomerVerified(customer);
                                  
                                  return ListTile(
                                    leading: isVerified
                                        ? const Icon(
                                            Icons.check_circle,
                                            color: Colors.green,
                                          )
                                        : const SizedBox(width: 24),
                                    title: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            customer.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        if (isVerified)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.green.shade50,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              '✓ KYC',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.green,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    subtitle: Text(customer.phone),
                                    onTap: () {
                                      widget.onSelectCustomer(customer);
                                      _searchController.text = customer.name;
                                      setState(() {
                                        _showDropdown = false;
                                      });
                                      _focusNode.unfocus();
                                    },
                                  );
                                },
                              );
                            },
                            loading: () => const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            ),
                            error: (error, stack) => Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text('Error: $error'),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.add),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF0EA5E9),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
              onPressed: () => context.push('/customers/new'),
            ),
          ],
        ),

        // Selected Customer Display
        if (widget.selectedCustomer != null &&
            widget.selectedCustomer!.id.isNotEmpty &&
            !_showDropdown)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                if (_isCustomerVerified(widget.selectedCustomer!))
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.selectedCustomer!.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.selectedCustomer!.phone,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    _searchController.clear();
                    widget.onSelectCustomer(Customer(
                      id: '',
                      name: '',
                      phone: '',
                    ));
                  },
                  child: const Text('Change'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

