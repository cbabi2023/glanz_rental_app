import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/customers_provider.dart';
import '../../models/customer.dart';

/// Customer Search Widget
/// 
/// Modern, attractive customer search widget for order creation
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
  void initState() {
    super.initState();
    // If customer is already selected, set the search text
    if (widget.selectedCustomer != null && widget.selectedCustomer!.id.isNotEmpty) {
      _searchController.text = widget.selectedCustomer!.name;
    }
  }

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
      customersProvider(
        CustomersParams(
          searchQuery: searchQuery.isNotEmpty ? searchQuery : null,
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search Input
        TextFormField(
          controller: _searchController,
          focusNode: _focusNode,
          style: const TextStyle(
            fontSize: 15,
            color: Color(0xFF0F1724),
          ),
          decoration: InputDecoration(
            labelText: 'Customer',
            hintText: 'Search by name or phone',
            prefixIcon: const Icon(Icons.search, color: Color(0xFF0B63FF)),
            suffixIcon: widget.selectedCustomer != null && widget.selectedCustomer!.id.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      widget.onSelectCustomer(Customer(
                        id: '',
                        name: '',
                        phone: '',
                      ));
                      setState(() {
                        _showDropdown = false;
                      });
                    },
                  )
                : null,
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
          ),
          onChanged: (value) {
            setState(() {
              _showDropdown = value.trim().isNotEmpty && _focusNode.hasFocus;
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

        // Dropdown Results
        if (_showDropdown && !(widget.selectedCustomer != null && widget.selectedCustomer!.id.isNotEmpty))
          Container(
            margin: const EdgeInsets.only(top: 8),
            constraints: const BoxConstraints(maxHeight: 300),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
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
                        Icon(
                          Icons.search_off,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No customers found',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _showDropdown = false;
                            });
                            context.push('/customers/new');
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Add New Customer'),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF0B63FF),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: customers.length,
                  itemBuilder: (context, index) {
                    final customer = customers[index];
                    final isVerified = _isCustomerVerified(customer);
                    
                    return InkWell(
                      onTap: () {
                        widget.onSelectCustomer(customer);
                        _searchController.text = customer.name;
                        _focusNode.unfocus();
                        setState(() {
                          _showDropdown = false;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.grey.shade200,
                              width: index < customers.length - 1 ? 1 : 0,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: isVerified
                                    ? Colors.green.shade50
                                    : Colors.grey.shade200,
                                shape: BoxShape.circle,
                              ),
                              child: isVerified
                                  ? Icon(
                                      Icons.check_circle,
                                      size: 24,
                                      color: Colors.green.shade700,
                                    )
                                  : Center(
                                      child: Text(
                                        customer.name.isNotEmpty
                                            ? customer.name[0].toUpperCase()
                                            : '?',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          customer.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                            color: Color(0xFF0F1724),
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
                                          child: Text(
                                            'KYC',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.green.shade700,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.phone,
                                        size: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        customer.phone,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0B63FF)),
                  ),
                ),
              ),
              error: (error, stack) => Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red.shade400,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Error loading customers',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      error.toString(),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Selected Customer Display
        if (widget.selectedCustomer != null &&
            widget.selectedCustomer!.id.isNotEmpty &&
            !_showDropdown)
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0B63FF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF0B63FF).withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B63FF),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      widget.selectedCustomer!.name.isNotEmpty
                          ? widget.selectedCustomer!.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.selectedCustomer!.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: Color(0xFF0F1724),
                              ),
                            ),
                          ),
                          if (_isCustomerVerified(widget.selectedCustomer!))
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'KYC',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.phone,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.selectedCustomer!.phone,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
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
                    setState(() {
                      _showDropdown = false;
                    });
                  },
                  child: const Text(
                    'Change',
                    style: TextStyle(
                      color: Color(0xFF0B63FF),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Add Customer Button (only if no customer selected)
        if ((widget.selectedCustomer == null || widget.selectedCustomer!.id.isEmpty) && !_showDropdown)
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _showDropdown = false;
                });
                context.push('/customers/new');
              },
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Add New Customer'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0B63FF),
                side: const BorderSide(color: Color(0xFF0B63FF)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
