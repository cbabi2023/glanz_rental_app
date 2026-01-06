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
  bool _isInitializing = false; // Prevent concurrent initialization
  String?
  _lastLoadedOrderId; // Track which order was last loaded to prevent reloading

  @override
  void initState() {
    super.initState();
    // Initialize once when screen is created
    // Use addPostFrameCallback to ensure widget is fully built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isInitialized && !_isInitializing) {
        // Wait a frame to ensure providers are ready
        Future.microtask(() {
          if (mounted && !_isInitialized && !_isInitializing) {
            _initializeFromOrder();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _invoiceNumberController.dispose();
    // Reset flags - don't use ref here as widget may be disposed
    _isInitialized = false;
    _isInitializing = false;
    super.dispose();
  }

  /// Helper function to parse datetime string with timezone conversion
  /// Converts UTC times from database to local time for display
  DateTime? _parseDateTimeWithTimezone(String dateString) {
    try {
      final trimmed = dateString.trim();

      // Check if string has timezone info (ends with Z or has timezone offset like +05:30, -05:00)
      final hasTimezone =
          trimmed.endsWith('Z') ||
          RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(trimmed);

      if (hasTimezone) {
        // Has timezone info - DateTime.parse will handle conversion to local time
        return DateTime.parse(trimmed).toLocal();
      } else {
        // No timezone info - assume it's UTC from database
        // Parse the components and create as UTC, then convert to local
        final parsed = DateTime.parse(trimmed);
        final utcDate = DateTime.utc(
          parsed.year,
          parsed.month,
          parsed.day,
          parsed.hour,
          parsed.minute,
          parsed.second,
          parsed.millisecond,
          parsed.microsecond,
        );
        return utcDate.toLocal(); // Convert UTC to local time
      }
    } catch (e) {
      return null;
    }
  }

  Future<void> _initializeFromOrder() async {
    print('🟣 _initializeFromOrder called for order: ${widget.orderId}');
    print(
      '🟣 _isInitialized: $_isInitialized, _isInitializing: $_isInitializing',
    );
    print('🟣 _lastLoadedOrderId: $_lastLoadedOrderId');

    // CRITICAL: Prevent multiple calls with multiple checks
    if (_isInitialized || _isInitializing) {
      print(
        '🔴 _initializeFromOrder BLOCKED - already initialized or initializing',
      );
      return;
    }

    // Check if we've already loaded this order
    if (_lastLoadedOrderId == widget.orderId && _isInitialized) {
      print('🔴 _initializeFromOrder BLOCKED - order already loaded');
      return;
    }

    // Set flag immediately to prevent concurrent calls
    _isInitializing = true;
    print('🟣 _initializeFromOrder proceeding...');

    // CRITICAL: Clear draft FIRST to ensure completely clean state
    // This prevents any items from previous sessions or partial loads
    ref.read(orderDraftProvider.notifier).clear();

    // Wait to ensure clear() has completed
    await Future.microtask(() {});

    // CRITICAL: Use read, not watch, to prevent rebuilds from triggering re-initialization
    final orderAsync = ref.read(orderProvider(widget.orderId));

    await orderAsync.when(
      data: (order) async {
        // DEBUG: Check if order from database has duplicates
        if (order != null && order.items != null) {
          final itemIds = <String>{};
          final duplicateIds = <String>[];
          for (final item in order.items!) {
            if (item.id != null && item.id!.isNotEmpty) {
              if (itemIds.contains(item.id)) {
                duplicateIds.add(item.id!);
              } else {
                itemIds.add(item.id!);
              }
            }
          }
          // If duplicateIds is not empty, backend has duplicates
        }
        // Check again after async operation - prevent race conditions
        if (_isInitialized && _lastLoadedOrderId == widget.orderId) {
          if (mounted) {
            setState(() {
              _isInitializing = false;
            });
          }
          return;
        }

        if (!mounted) {
          if (mounted) {
            setState(() {
              _isInitializing = false;
            });
          }
          return;
        }

        if (order == null) {
          if (mounted) {
            setState(() {
              _isInitializing = false;
            });
          }
          return;
        }

        // CRITICAL: Clear draft AGAIN before loading to ensure no leftover items
        // This is a double-safety measure
        ref.read(orderDraftProvider.notifier).clear();
        await Future.microtask(() {});

        // VERIFY: Draft should be empty before loading
        final draftCheckBeforeLoad = ref.read(orderDraftProvider);
        if (draftCheckBeforeLoad.items.isNotEmpty) {
          // Draft still has items - clear again
          print('🟡 Draft still has items before load, clearing again...');
          ref.read(orderDraftProvider.notifier).clear();
          await Future.microtask(() {});
        }

        // CRITICAL: Load order into draft (this REPLACES items, not adds to them)
        // The loadOrder method now clears state first, then loads items
        // Track that we're about to load this order BEFORE calling loadOrder
        // This prevents loadOrder from being called multiple times
        _lastLoadedOrderId = widget.orderId;

        print(
          '🟣 About to call loadOrder. Order items count: ${order.items?.length ?? 0}',
        );
        final draftStateBeforeLoad = ref.read(orderDraftProvider);
        print(
          '🟣 Draft items count before loadOrder: ${draftStateBeforeLoad.items.length}',
        );

        // Load order - this will replace all items
        ref.read(orderDraftProvider.notifier).loadOrder(order);

        // VERIFY: After loading, ensure state is consistent
        await Future.microtask(() {});

        final draftAfterLoad = ref.read(orderDraftProvider);
        print(
          '🟣 Draft items count after loadOrder: ${draftAfterLoad.items.length}',
        );
        print('🟣 Order items from DB: ${order.items?.length ?? 0}');

        if (draftAfterLoad.items.length > (order.items?.length ?? 0)) {
          print(
            '🔴 WARNING: Draft has MORE items than order! This indicates a problem.',
          );
        } else if (draftAfterLoad.items.length < (order.items?.length ?? 0)) {
          print(
            '🟡 INFO: Draft has fewer items than order (duplicates were removed)',
          );
        } else {
          print('🟢 SUCCESS: Draft items count matches order items count');
        }

        // Set customer
        if (order.customer != null) {
          _selectedCustomer = order.customer;
        }

        // Set invoice number
        _invoiceNumberController.text = order.invoiceNumber;

        if (mounted) {
          setState(() {
            _isInitialized = true;
            _isInitializing = false;
          });
        }
      },
      loading: () {},
      error: (_, __) {
        if (mounted) {
          setState(() {
            _isInitializing = false;
          });
        }
      },
    );
  }

  Future<void> _handleUpdateOrder() async {
    print('🟠 _handleUpdateOrder called for order: ${widget.orderId}');

    // CRITICAL: Get a snapshot of the draft IMMEDIATELY to prevent any changes during update
    // This ensures we're working with a fixed set of items
    final draft = ref.read(orderDraftProvider);
    print('🟠 Draft items count: ${draft.items.length}');

    // CRITICAL: First, remove any duplicates that might already exist in the draft
    // This is a safety measure in case duplicates somehow got into the draft
    final draftItemsBeforeDedup = draft.items;
    print('🟠 Draft items before dedup: ${draftItemsBeforeDedup.length}');

    // Use comprehensive key that matches what we use in loadOrder and updateOrder
    final deduplicatedDraftItems = <String, OrderItem>{};
    final foundDuplicates = <String>[];

    for (final item in draftItemsBeforeDedup) {
      String key;
      if (item.id != null && item.id!.isNotEmpty) {
        // Use ID as key for items with ID
        key = 'id_${item.id}';
      } else {
        // For items without ID, use comprehensive composite key
        // Include ALL fields to ensure uniqueness
        key =
            'key_${item.photoUrl}_${item.productName ?? ''}_${item.quantity}_${item.pricePerDay}_${item.days}_${item.lineTotal}';
      }

      if (!deduplicatedDraftItems.containsKey(key)) {
        deduplicatedDraftItems[key] = item;
      } else {
        foundDuplicates.add(key);
        print('🔴 DUPLICATE FOUND in draft: $key');
      }
    }

    // Use the deduplicated items as our starting point
    final cleanDraftItems = List<OrderItem>.from(deduplicatedDraftItems.values);
    print('🟠 Draft items after dedup: ${cleanDraftItems.length}');
    print('🟠 Duplicates found in draft: ${foundDuplicates.length}');
    if (draftItemsBeforeDedup.length != cleanDraftItems.length) {
      print(
        '🔴 DUPLICATES FOUND in draft before update! Removed ${draftItemsBeforeDedup.length - cleanDraftItems.length} duplicates',
      );
    }

    // Use the clean deduplicated items as our snapshot
    final draftItemsSnapshot = cleanDraftItems
        .map(
          (item) => OrderItem(
            id: item.id,
            orderId: item.orderId,
            photoUrl: item.photoUrl,
            productName: item.productName,
            quantity: item.quantity,
            pricePerDay: item.pricePerDay,
            days: item.days,
            lineTotal: item.lineTotal,
            returnStatus: item.returnStatus,
            actualReturnDate: item.actualReturnDate,
            lateReturn: item.lateReturn,
            missingNote: item.missingNote,
            returnedQuantity: item.returnedQuantity,
            damageCost: item.damageCost,
            damageDescription: item.damageDescription,
          ),
        )
        .toList();
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

    if (draftItemsSnapshot.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one item'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate all items have required fields
    final invalidItems = draftItemsSnapshot.where(
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

      // CRITICAL: Prepare items for database - ensure NO duplicates
      // Use the snapshot we created at the start to prevent any changes during update
      // Remove duplicates using a Map - this is the final safeguard
      final uniqueItemsMap = <String, OrderItem>{};

      for (final item in draftItemsSnapshot) {
        String key;

        // Use item ID if available (most reliable for existing items)
        if (item.id != null && item.id!.isNotEmpty) {
          key = 'id_${item.id}';
        } else {
          // For items without ID (new items), create a comprehensive composite key
          // Include ALL identifying fields to ensure uniqueness
          key =
              'key_${item.photoUrl}_${item.productName ?? ''}_${item.quantity}_${item.pricePerDay}_${item.days}_${item.lineTotal}';
        }

        // Only add if we haven't seen this key before
        // This ensures each item appears exactly once
        if (!uniqueItemsMap.containsKey(key)) {
          uniqueItemsMap[key] = item;
        }
      }

      // Convert map values to list - this guarantees unique items only
      final uniqueItems = List<OrderItem>.from(uniqueItemsMap.values);

      // FINAL VERIFICATION: Ensure we have unique items
      // Double-check by creating another map to catch any edge cases
      print(
        '🟠 First deduplication: ${draftItemsSnapshot.length} -> ${uniqueItems.length}',
      );
      final finalUniqueItemsMap = <String, OrderItem>{};
      final verificationDuplicates = <String>[];
      for (final item in uniqueItems) {
        String key;
        if (item.id != null && item.id!.isNotEmpty) {
          key = 'id_${item.id}';
        } else {
          key =
              'key_${item.photoUrl}_${item.productName ?? ''}_${item.quantity}_${item.pricePerDay}_${item.days}_${item.lineTotal}';
        }
        if (!finalUniqueItemsMap.containsKey(key)) {
          finalUniqueItemsMap[key] = item;
        } else {
          verificationDuplicates.add(key);
          print('🔴 VERIFICATION DUPLICATE in update: $key');
        }
      }
      final finalUniqueItems = List<OrderItem>.from(finalUniqueItemsMap.values);
      print(
        '🟠 Final unique items after verification: ${finalUniqueItems.length}',
      );
      print('🟠 Verification duplicates: ${verificationDuplicates.length}');

      final itemsForDb = finalUniqueItems.map((item) {
        // Update days for each item based on start/end dates
        final days = calculateDays(draft.startDate, draft.endDate);
        // Calculate line total: quantity × price per item (not per day, so no days multiplier)
        final lineTotal = item.quantity * item.pricePerDay;

        final itemData = {
          'photo_url': item.photoUrl,
          'product_name': item.productName,
          'quantity': item.quantity,
          'price_per_day': item.pricePerDay,
          'days': days,
          'line_total': lineTotal,
        };

        // CRITICAL: Include item ID if available - this allows matching by ID for updates
        // When price/quantity changes, we can still match by ID and update instead of inserting new
        if (item.id != null && item.id!.isNotEmpty) {
          itemData['id'] = item.id;
        }

        return itemData;
      }).toList();

      // CRITICAL FIX: Calculate subtotal from the actual items being sent to database
      // This ensures the subtotal matches the items, especially after item removal
      // Calculate line total: quantity × price per item (not per day, so no days multiplier)
      final subtotal = itemsForDb.fold<double>(0.0, (sum, item) {
        return sum + (item['line_total'] as double);
      });
      print(
        '🟠 Calculated subtotal from ${finalUniqueItems.length} items: $subtotal',
      );

      final gstAmount = calculateGstAmount(
        subtotal: subtotal,
        user: gstProfile,
      );
      final grandTotal = calculateGrandTotal(
        subtotal: subtotal,
        user: gstProfile,
      );
      print('🟠 GST: $gstAmount, Grand Total: $grandTotal');

      // Update order
      print('🟠 Sending ${itemsForDb.length} items to updateOrder service');
      print(
        '🟠 Items for DB: ${itemsForDb.map((i) => '${i['photo_url']}_${i['product_name']}_${i['quantity']}_${i['price_per_day']}_${i['days']}').join(", ")}',
      );

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

      print('🟢 updateOrder service call completed');

      // CRITICAL: Clear draft IMMEDIATELY after successful update
      // This prevents any chance of items being reused or duplicated
      ref.read(orderDraftProvider.notifier).clear();
      _isInitialized = false;
      _isInitializing = false;

      if (mounted) {
        // Unfocus any text fields to prevent keyboard state issues
        FocusScope.of(context).unfocus();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Pop IMMEDIATELY to close the edit screen
        // This prevents any order reload from affecting the draft
        context.pop();

        // Invalidate order provider AFTER popping to refresh the order
        // This happens after the screen is closed, so it won't affect the draft
        Future.microtask(() {
          if (mounted) {
            ref.invalidate(orderProvider(widget.orderId));

            // Invalidate orders list to refresh
            if (userProfile?.branchId != null) {
              ref.invalidate(
                ordersProvider(OrdersParams(branchId: userProfile!.branchId)),
              );
            }
          }
        });
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

    // Don't initialize here - we do it in initState to prevent multiple calls
    // This callback was causing items to be loaded multiple times

    // Calculate days
    final days = draft.startDate.isNotEmpty && draft.endDate.isNotEmpty
        ? calculateDays(draft.startDate, draft.endDate)
        : 0;

    // Parse dates with timezone conversion
    // This ensures UTC times from database are converted to local time for display
    final startDate = draft.startDate.isNotEmpty
        ? _parseDateTimeWithTimezone(draft.startDate)
        : null;
    final endDate = draft.endDate.isNotEmpty
        ? _parseDateTimeWithTimezone(draft.endDate)
        : null;

    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        if (didPop) {
          // Unfocus when popping to prevent keyboard state issues
          FocusScope.of(context).unfocus();
        }
      },
      child: Scaffold(
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
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey.shade700,
                      ),
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
                    onPressed: () {
                      FocusScope.of(context).unfocus();
                      context.pop();
                    },
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
                                      color: Colors.white.withValues(
                                        alpha: 0.2,
                                      ),
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
                                          onPressed: () =>
                                              Navigator.pop(context),
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
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  context.pop();
                },
              ),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red.shade300,
                  ),
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
                    color: const Color(0xFF1F2A7A).withValues(alpha: 0.1),
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
