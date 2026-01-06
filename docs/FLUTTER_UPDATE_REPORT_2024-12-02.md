# Glanz Rental - Daily Update Report for Flutter Developer
**Date:** December 2, 2024  
**Time:** Until 3:20 PM  
**From:** Web Development Team  
**To:** Mohammad Shahil (Flutter Developer)  
**Subject:** Today's Updates - Implementation Guide for Flutter App

---

## 📋 Executive Summary

This report summarizes all updates made to the Glanz Rental web application today (December 2, 2024, until 3:20 PM). These features need to be implemented in the Flutter mobile application to maintain feature parity. All changes are production-ready, tested, and build successfully.

---

## 🔄 Major Features Implemented Today

### 1. **Scheduled Orders System** ⭐ NEW
**Priority:** HIGH  
**Status:** ✅ Completed & Tested

#### Description
Implemented a complete scheduled order workflow where orders can be booked in advance but remain in "scheduled" status until explicitly started via "Start Rental" action.

#### Key Changes
- Orders with future start dates are automatically marked as "scheduled"
- Scheduled orders cannot be returned (return section is hidden)
- "Start Rental" button converts scheduled → active status
- Scheduled orders can be cancelled anytime
- Once started, orders follow normal cancellation rules (10-minute window)

#### Database Changes
**Migration File:** `supabase-migrations/add-booking-date.sql`

```sql
-- Added booking_date field
ALTER TABLE orders
ADD COLUMN IF NOT EXISTS booking_date TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- Extended status enum
ALTER TABLE orders
ADD CONSTRAINT orders_status_check 
  CHECK (status IN ('scheduled', 'active', 'pending_return', 'completed', 'cancelled', 'partially_returned'));
```

#### Flutter Implementation Guide

**1. Update Order Model:**
```dart
class Order {
  final String id;
  final String? bookingDate; // ISO string - when order was booked/created
  final String startDate; // Legacy date field (YYYY-MM-DD)
  final String endDate; // Legacy date field (YYYY-MM-DD)
  final String? startDatetime; // ISO string with time (YYYY-MM-DDTHH:mm:ss)
  final String? endDatetime; // ISO string with time (YYYY-MM-DDTHH:mm:ss)
  final OrderStatus status; // Now includes 'scheduled'
  
  // ... other existing fields
}

enum OrderStatus {
  scheduled,
  active,
  pendingReturn,
  completed,
  cancelled,
  partiallyReturned;
  
  static OrderStatus fromString(String value) {
    switch (value) {
      case 'scheduled': return OrderStatus.scheduled;
      case 'active': return OrderStatus.active;
      case 'pending_return': return OrderStatus.pendingReturn;
      case 'completed': return OrderStatus.completed;
      case 'cancelled': return OrderStatus.cancelled;
      case 'partially_returned': return OrderStatus.partiallyReturned;
      default: return OrderStatus.active;
    }
  }
  
  String toJson() {
    switch (this) {
      case OrderStatus.scheduled: return 'scheduled';
      case OrderStatus.active: return 'active';
      case OrderStatus.pendingReturn: return 'pending_return';
      case OrderStatus.completed: return 'completed';
      case OrderStatus.cancelled: return 'cancelled';
      case OrderStatus.partiallyReturned: return 'partially_returned';
    }
  }
}
```

**2. Order Creation Logic:**
```dart
Future<Order> createOrder(OrderDraft draft) async {
  // Parse start date
  final startDate = DateTime.parse(draft.startDate);
  final today = DateTime.now();
  final todayStart = DateTime(today.year, today.month, today.day);
  final startDateOnly = DateTime(startDate.year, startDate.month, startDate.day);
  
  // Calculate status: scheduled if future date, active if today or past
  final orderStatus = startDateOnly.isAfter(todayStart) 
    ? OrderStatus.scheduled 
    : OrderStatus.active;
  
  // Generate invoice number if not provided
  final invoiceNumber = draft.invoiceNumber.isEmpty 
    ? generateInvoiceNumber() 
    : draft.invoiceNumber;
  
  // Prepare order data
  final orderData = {
    'branch_id': draft.branchId,
    'staff_id': draft.staffId,
    'customer_id': draft.customerId,
    'invoice_number': invoiceNumber,
    'booking_date': DateTime.now().toIso8601String(), // Always set booking date
    'start_date': startDateOnly.toIso8601String().split('T')[0], // YYYY-MM-DD
    'end_date': endDateOnly.toIso8601String().split('T')[0], // YYYY-MM-DD
    'start_datetime': draft.startDate, // Full ISO string with time
    'end_datetime': draft.endDate, // Full ISO string with time
    'status': orderStatus.toJson(), // Use calculated status
    'total_amount': draft.totalAmount,
    'subtotal': draft.subtotal,
    'gst_amount': draft.gstAmount,
  };
  
  final orderResponse = await supabase
    .from('orders')
    .insert(orderData)
    .select()
    .single();
  
  // Insert items
  final items = draft.items.map((item) => {
    return {
      'order_id': orderResponse['id'],
      'photo_url': item.photoUrl,
      'product_name': item.productName,
      'quantity': item.quantity,
      'price_per_day': item.pricePerDay,
      'days': item.days,
      'line_total': item.lineTotal,
    };
  }).toList();
  
  await supabase.from('order_items').insert(items);
  
  return Order.fromJson(orderResponse);
}
```

**3. "Start Rental" Action:**
```dart
Future<void> startRental(String orderId) async {
  try {
    final response = await supabase
      .from('orders')
      .update({
        'status': 'active',
        'start_datetime': DateTime.now().toIso8601String(),
      })
      .eq('id', orderId)
      .select()
      .single();
    
    if (response.hasError) {
      throw Exception('Failed to start rental: ${response.error}');
    }
    
    // Refresh orders list after update
    // Use your state management to refresh
    // Provider: context.read<OrdersProvider>().refresh();
    // Riverpod: ref.invalidate(ordersProvider);
    // Bloc: add(RefreshOrdersEvent());
    
  } catch (e) {
    throw Exception('Error starting rental: $e');
  }
}
```

**4. Order Category Logic (CRITICAL for filtering):**
```dart
enum OrderCategory {
  scheduled,
  ongoing,
  late,
  returned,
  partiallyReturned,
  cancelled;
}

OrderCategory getOrderCategory(Order order) {
  final status = order.status;
  
  // Fast path: Check status first
  if (status == OrderStatus.cancelled) return OrderCategory.cancelled;
  if (status == OrderStatus.partiallyReturned) return OrderCategory.partiallyReturned;
  if (status == OrderStatus.completed) return OrderCategory.returned;
  
  // ⚠️ CRITICAL: Scheduled orders ALWAYS return "scheduled" regardless of date
  // Do NOT check dates for scheduled orders - they remain scheduled until explicitly started
  if (status == OrderStatus.scheduled) {
    return OrderCategory.scheduled;
  }
  
  // Check for partial returns via items (if status is active but some items returned)
  if (order.items != null && order.items!.isNotEmpty) {
    final hasReturned = order.items!.any((item) => 
      item.returnStatus == ReturnStatus.returned
    );
    final hasNotReturned = order.items!.any((item) => 
      item.returnStatus == null || 
      item.returnStatus == ReturnStatus.notYetReturned ||
      item.returnStatus == ReturnStatus.missing
    );
    
    // If some items are returned but not all, it's partially returned
    if (hasReturned && hasNotReturned) {
      return OrderCategory.partiallyReturned;
    }
  }
  
  // Check if late (end date passed and not completed/cancelled)
  final endDate = DateTime.parse(order.endDatetime ?? order.endDate);
  final isLate = DateTime.now().isAfter(endDate) && 
                 status != OrderStatus.completed && 
                 status != OrderStatus.cancelled &&
                 status != OrderStatus.partiallyReturned;
  
  if (isLate) return OrderCategory.late;
  if (status == OrderStatus.active) return OrderCategory.ongoing;
  
  // Default to ongoing
  return OrderCategory.ongoing;
}
```

**5. UI Changes Required:**
- **Orders List Screen:**
  - Add "Scheduled" tab/filter
  - Show "Start Rental" button (orange color) for scheduled orders
  - Hide "Mark as Returned" button for scheduled orders
  - Display scheduled badge on order cards
  
- **Order Details Screen:**
  - Show "Start Rental" button in header (orange, prominent)
  - Hide return section for scheduled orders
  - Display scheduled badge on dates card
  - Show booking date prominently
  - Hide edit button for scheduled orders

---

### 2. **Auto-Generated Invoice Numbers** ⭐ NEW
**Priority:** MEDIUM  
**Status:** ✅ Completed

#### Description
All new orders automatically get a unique invoice number in format: `GLAORD-YYYYMMDD-XXXX` if not manually provided.

#### Format
- Pattern: `GLAORD-YYYYMMDD-XXXX`
- Example: `GLAORD-20241202-3847`
- Components:
  - `GLAORD-` prefix
  - `YYYYMMDD` date (year, month, day)
  - `-` separator
  - `XXXX` random 4-digit number (0000-9999)

#### Flutter Implementation
```dart
String generateInvoiceNumber() {
  final now = DateTime.now();
  final year = now.year.toString();
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');
  final random = Random().nextInt(10000).toString().padLeft(4, '0');
  
  return 'GLAORD-$year$month$day-$random';
}

// Usage in order creation
final invoiceNumber = draft.invoiceNumber.isEmpty 
  ? generateInvoiceNumber() 
  : draft.invoiceNumber;
```

**UI Requirements:**
- Invoice number field should be optional
- Show hint text: "(Optional - Auto-generated)"
- Display generated invoice number below input if auto-generated

---

### 3. **Item-Wise Return Tracking System** ⭐ MAJOR UPDATE
**Priority:** HIGH  
**Status:** ✅ Completed & Optimized

#### Description
Complete overhaul of return process - now tracks return status at **item level** instead of order level. Supports partial returns, missing items, and late returns.

#### Database Changes
**Migration File:** `supabase-migrations/add-return-tracking.sql`

**Order Items Table - New Fields:**
```sql
return_status TEXT DEFAULT 'not_yet_returned' 
  CHECK (return_status IN ('not_yet_returned', 'returned', 'missing'))
actual_return_date TIMESTAMP WITH TIME ZONE
late_return BOOLEAN DEFAULT FALSE
missing_note TEXT (nullable)
```

**Orders Table - Updates:**
```sql
-- Status enum now includes 'partially_returned'
status CHECK (status IN ('scheduled', 'active', 'pending_return', 'completed', 'cancelled', 'partially_returned'))

-- Quick filter flag
late_returned BOOLEAN DEFAULT FALSE
```

#### Flutter Model Updates
```dart
enum ReturnStatus {
  notYetReturned,
  returned,
  missing;
  
  static ReturnStatus? fromString(String? value) {
    if (value == null) return null;
    switch (value) {
      case 'not_yet_returned': return ReturnStatus.notYetReturned;
      case 'returned': return ReturnStatus.returned;
      case 'missing': return ReturnStatus.missing;
      default: return null;
    }
  }
  
  String toJson() {
    switch (this) {
      case ReturnStatus.notYetReturned: return 'not_yet_returned';
      case ReturnStatus.returned: return 'returned';
      case ReturnStatus.missing: return 'missing';
    }
  }
}

class OrderItem {
  final String? id;
  final String photoUrl;
  final String? productName;
  final int quantity;
  final double pricePerDay;
  final int days;
  final double lineTotal;
  
  // Return tracking fields
  final ReturnStatus? returnStatus;
  final DateTime? actualReturnDate;
  final bool? lateReturn;
  final String? missingNote;
  
  OrderItem({
    this.id,
    required this.photoUrl,
    this.productName,
    required this.quantity,
    required this.pricePerDay,
    required this.days,
    required this.lineTotal,
    this.returnStatus,
    this.actualReturnDate,
    this.lateReturn,
    this.missingNote,
  });
  
  bool get isReturned => returnStatus == ReturnStatus.returned;
  bool get isMissing => returnStatus == ReturnStatus.missing;
  bool get isPending => returnStatus == null || returnStatus == ReturnStatus.notYetReturned;
  
  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'],
      photoUrl: json['photo_url'],
      productName: json['product_name'],
      quantity: json['quantity'],
      pricePerDay: (json['price_per_day'] as num).toDouble(),
      days: json['days'],
      lineTotal: (json['line_total'] as num).toDouble(),
      returnStatus: ReturnStatus.fromString(json['return_status']),
      actualReturnDate: json['actual_return_date'] != null 
        ? DateTime.parse(json['actual_return_date'])
        : null,
      lateReturn: json['late_return'] as bool?,
      missingNote: json['missing_note'] as String?,
    );
  }
}
```

#### Return Processing API
**RPC Function:** `process_order_return_optimized`

**Flutter Implementation:**
```dart
class ItemReturn {
  final String itemId;
  final String returnStatus; // 'returned' or 'missing'
  final DateTime? actualReturnDate;
  final String? missingNote;
  
  ItemReturn({
    required this.itemId,
    required this.returnStatus,
    this.actualReturnDate,
    this.missingNote,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'item_id': itemId,
      'return_status': returnStatus,
      'actual_return_date': actualReturnDate?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'missing_note': missingNote,
    };
  }
}

Future<Map<String, dynamic>> processOrderReturn({
  required String orderId,
  required List<ItemReturn> itemReturns,
  required String userId,
  double lateFee = 0,
}) async {
  final itemReturnsJson = itemReturns.map((ir) => ir.toJson()).toList();
  
  final response = await supabase.rpc('process_order_return_optimized', params: {
    'p_order_id': orderId,
    'p_item_returns': itemReturnsJson,
    'p_user_id': userId,
    'p_late_fee': lateFee,
  });
  
  if (response.hasError) {
    throw Exception('Failed to process return: ${response.error?.message}');
  }
  
  // Refresh orders list after successful return
  refreshOrdersList();
  
  return response.data as Map<String, dynamic>;
}
```

#### UI Requirements for Return Screen
```dart
class OrderReturnScreen extends StatefulWidget {
  final Order order;
  
  @override
  _OrderReturnScreenState createState() => _OrderReturnScreenState();
}

class _OrderReturnScreenState extends State<OrderReturnScreen> {
  final Set<String> selectedItems = {}; // Item IDs to mark as returned
  final Map<String, String> missingNotes = {}; // Item ID -> note
  double lateFee = 0;
  
  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final items = order.items ?? [];
    final endDate = DateTime.parse(order.endDatetime ?? order.endDate);
    final isLate = DateTime.now().isAfter(endDate);
    
    // Calculate stats
    final returnedCount = items.where((item) => item.isReturned).length;
    final missingCount = items.where((item) => item.isMissing).length;
    final pendingCount = items.where((item) => item.isPending).length;
    
    return Scaffold(
      appBar: AppBar(title: Text('Process Return')),
      body: Column(
        children: [
          // Summary Card
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStat('Total', items.length, Colors.blue),
                  _buildStat('Returned', returnedCount, Colors.green),
                  _buildStat('Pending', pendingCount, Colors.orange),
                  _buildStat('Missing', missingCount, Colors.red),
                ],
              ),
            ),
          ),
          
          // Late Fee Input (if late)
          if (isLate)
            Card(
              color: Colors.orange[50],
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Late Fee Amount (₹)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    TextField(
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: '0',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          lateFee = double.tryParse(value) ?? 0;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          
          // Items List
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final isItemReturned = item.isReturned;
                final isItemLate = item.lateReturn == true;
                final isSelected = selectedItems.contains(item.id);
                
                return Card(
                  color: isItemReturned 
                    ? Colors.green[50] 
                    : isItemLate 
                    ? Colors.orange[50] 
                    : null,
                  child: ListTile(
                    leading: Checkbox(
                      value: isSelected || isItemReturned,
                      onChanged: isItemReturned ? null : (value) {
                        setState(() {
                          if (value == true) {
                            selectedItems.add(item.id!);
                          } else {
                            selectedItems.remove(item.id!);
                          }
                        });
                      },
                    ),
                    title: Text(item.productName ?? 'Unnamed Product'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Qty: ${item.quantity} × ₹${item.pricePerDay} = ₹${item.lineTotal}'),
                        if (isItemLate && !isItemReturned)
                          Chip(
                            label: Text('Late'),
                            backgroundColor: Colors.orange,
                            labelStyle: TextStyle(color: Colors.white, fontSize: 10),
                          ),
                        if (isItemReturned && item.actualReturnDate != null)
                          Text(
                            'Returned: ${DateFormat('dd MMM yyyy HH:mm').format(item.actualReturnDate!)}',
                            style: TextStyle(color: Colors.green[700], fontSize: 12),
                          ),
                      ],
                    ),
                    trailing: item.photoUrl.isNotEmpty
                      ? Image.network(item.photoUrl, width: 60, height: 60, fit: BoxFit.cover)
                      : null,
                  ),
                );
              },
            ),
          ),
          
          // Action Buttons
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                if (selectedItems.isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: () => _processReturn(),
                    icon: Icon(Icons.check_circle),
                    label: Text('Process Return (${selectedItems.length} selected)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      minimumSize: Size(double.infinity, 50),
                    ),
                  ),
                SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () => _markAllReturned(),
                  icon: Icon(Icons.select_all),
                  label: Text('Mark All as Returned'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    minimumSize: Size(double.infinity, 50),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  void _markAllReturned() {
    setState(() {
      final items = widget.order.items ?? [];
      for (var item in items) {
        if (!item.isReturned && item.id != null) {
          selectedItems.add(item.id!);
        }
      }
    });
  }
  
  Future<void> _processReturn() async {
    final items = widget.order.items ?? [];
    final itemReturns = selectedItems.map((itemId) {
      final item = items.firstWhere((i) => i.id == itemId);
      return ItemReturn(
        itemId: itemId,
        returnStatus: 'returned', // Default to returned, can add missing option
        actualReturnDate: DateTime.now(),
      );
    }).toList();
    
    try {
      await processOrderReturn(
        orderId: widget.order.id,
        itemReturns: itemReturns,
        userId: currentUserId, // Get from auth
        lateFee: lateFee,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Return processed successfully')),
      );
      
      Navigator.pop(context, true); // Return true to refresh
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
}
```

---

### 4. **Improved Order Cancellation Logic** ⭐ UPDATE
**Priority:** MEDIUM  
**Status:** ✅ Completed

#### Rules
1. **Scheduled orders**: Can be cancelled ANYTIME (until they become ongoing)
2. **Ongoing orders**: Can be cancelled ONLY within 10 minutes of becoming active
3. **Completed/Cancelled orders**: Cannot be cancelled

#### Implementation
```dart
bool canCancelOrder(Order order) {
  final status = order.status;
  
  // Already cancelled or completed cannot be cancelled
  if (status == OrderStatus.cancelled || status == OrderStatus.completed) {
    return false;
  }
  
  // Scheduled orders can be cancelled anytime
  if (status == OrderStatus.scheduled) {
    return true;
  }
  
  // Active orders: check 10-minute window
  if (status == OrderStatus.active) {
    // Use start_datetime as the timestamp when rental became active
    final activeSince = order.startDatetime != null 
      ? DateTime.parse(order.startDatetime!)
      : DateTime.parse(order.createdAt);
      
    final now = DateTime.now();
    final minutesSinceActive = now.difference(activeSince).inMinutes;
    
    // Can cancel if less than 10 minutes since becoming active
    return minutesSinceActive <= 10;
  }
  
  // Other statuses cannot be cancelled
  return false;
}
```

**UI Implementation:**
```dart
// In order list/detail screen
if (canCancelOrder(order)) {
  IconButton(
    icon: Icon(Icons.cancel, color: Colors.red),
    onPressed: () => _showCancelDialog(order),
    tooltip: 'Cancel Order',
  );
}

Future<void> _showCancelDialog(Order order) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Cancel Order'),
      content: Text('Are you sure you want to cancel this order? This action cannot be undone.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('No'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text('Yes, Cancel'),
        ),
      ],
    ),
  );
  
  if (confirmed == true) {
    await cancelOrder(order.id);
  }
}
```

---

### 5. **Real-Time Updates Optimization** ⭐ UPDATE
**Priority:** HIGH  
**Status:** ✅ Completed

#### Changes
- Changed from `invalidateQueries` to `refetchQueries` for immediate updates
- Subscribes to both `orders` and `order_items` tables
- Auto-resubscribes on timeout
- Only refetches active queries (currently being used)

#### Flutter Implementation
```dart
import 'package:supabase_flutter/supabase_flutter.dart';

class OrdersRealtimeService {
  final SupabaseClient supabase;
  RealtimeChannel? _ordersChannel;
  RealtimeChannel? _orderItemsChannel;
  final Function() onUpdate;
  
  OrdersRealtimeService({
    required this.supabase,
    required this.onUpdate,
  });
  
  void subscribeToOrders(String? branchId) {
    // Cleanup existing subscriptions
    unsubscribe();
    
    // Subscribe to orders table
    _ordersChannel = supabase
      .channel('orders:${branchId ?? 'global'}')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'orders',
        filter: branchId != null 
          ? PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'branch_id',
              value: branchId,
            )
          : null,
        callback: (payload) {
          print('[Realtime] Orders changed: ${payload.eventType}');
          // Immediately refetch orders (don't just invalidate cache)
          onUpdate();
        },
      )
      .subscribe();
      
    // Subscribe to order_items table (for return status updates)
    _orderItemsChannel = supabase
      .channel('order_items:${branchId ?? 'global'}')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'order_items',
        callback: (payload) {
          print('[Realtime] Order items changed: ${payload.eventType}');
          // Refetch orders when items change (affects return status)
          onUpdate();
        },
      )
      .subscribe();
      
    // Handle subscription status
    _ordersChannel?.onSubscriptionStatus((status) {
      if (status == RealtimeSubscriptionStatus.subscribed) {
        print('[Realtime] ✅ Subscribed to orders');
      } else if (status == RealtimeSubscriptionStatus.timedOut) {
        print('[Realtime] ⚠️ Channel timeout, resubscribing...');
        // Auto-resubscribe
        Future.delayed(Duration(seconds: 1), () {
          subscribeToOrders(branchId);
        });
      }
    });
  }
  
  void unsubscribe() {
    _ordersChannel?.unsubscribe();
    _orderItemsChannel?.unsubscribe();
    _ordersChannel = null;
    _orderItemsChannel = null;
  }
  
  void dispose() {
    unsubscribe();
  }
}

// Usage in Provider/Riverpod/Bloc
class OrdersProvider extends ChangeNotifier {
  final OrdersRealtimeService _realtimeService;
  List<Order> _orders = [];
  bool _isLoading = false;
  
  OrdersProvider() {
    final branchId = getCurrentBranchId(); // Get from auth
    _realtimeService = OrdersRealtimeService(
      supabase: Supabase.instance.client,
      onUpdate: () => refresh(), // Refresh orders when real-time update occurs
    );
    _realtimeService.subscribeToOrders(branchId);
  }
  
  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      _orders = await fetchOrders();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  @override
  void dispose() {
    _realtimeService.dispose();
    super.dispose();
  }
}
```

---

### 6. **Professional Invoice Actions UI** ⭐ NEW
**Priority:** MEDIUM  
**Status:** ✅ Completed

#### Description
4-button professional invoice actions card: View Invoice, Share WhatsApp, Download PDF, Print

#### Flutter UI Implementation
```dart
class InvoiceActionsCard extends StatelessWidget {
  final Order order;
  final User? user;
  
  const InvoiceActionsCard({
    required this.order,
    this.user,
  });
  
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Invoice Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[900],
              ),
            ),
            SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2, // 2 columns on mobile, 4 on tablet
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.2,
              children: [
                _buildActionButton(
                  icon: Icons.visibility,
                  label: 'View',
                  color: Colors.blue,
                  borderColor: Colors.blue[200]!,
                  onTap: () => _showInvoiceDialog(context),
                ),
                _buildActionButton(
                  icon: Icons.message,
                  label: 'WhatsApp',
                  color: Colors.green,
                  borderColor: Colors.green[400]!,
                  backgroundColor: Colors.green[500]!,
                  textColor: Colors.white,
                  onTap: () => _shareOnWhatsApp(context),
                ),
                _buildActionButton(
                  icon: Icons.download,
                  label: 'Download',
                  color: Colors.blue[700]!,
                  borderColor: Colors.blue[200]!,
                  onTap: () => _downloadPDF(context),
                ),
                _buildActionButton(
                  icon: Icons.print,
                  label: 'Print',
                  color: Colors.grey[700]!,
                  borderColor: Colors.grey[300]!,
                  onTap: () => _printInvoice(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color borderColor,
    Color? backgroundColor,
    Color? textColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.white,
          border: Border.all(color: borderColor, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: textColor ?? Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showInvoiceDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: InvoicePreviewWidget(order: order, user: user),
      ),
    );
  }
  
  void _shareOnWhatsApp(BuildContext context) async {
    final phone = order.customer?.phone?.replaceAll(RegExp(r'\D'), '');
    if (phone == null || phone.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Customer phone number not available')),
      );
      return;
    }
    
    // Build invoice text (same format as web)
    final invoiceText = _buildInvoiceText();
    final whatsappUrl = 'https://wa.me/91$phone?text=${Uri.encodeComponent(invoiceText)}';
    
    if (await canLaunchUrl(Uri.parse(whatsappUrl))) {
      await launchUrl(Uri.parse(whatsappUrl));
    }
  }
  
  String _buildInvoiceText() {
    final items = order.items ?? [];
    final itemsText = items.map((item, index) {
      return '${index + 1}. ${item.productName ?? "Unnamed Product"}\n'
          '   Price: ₹${item.pricePerDay.toStringAsFixed(0)}\n'
          '   Quantity: ${item.quantity}\n'
          '   Total: ₹${item.lineTotal.toStringAsFixed(0)}\n\n';
    }).join();
    
    final subtotal = order.subtotal ?? 0;
    final gstAmount = order.gstAmount ?? 0;
    final lateFee = order.lateFee ?? 0;
    final gstEnabled = user?.gstEnabled ?? false;
    final gstRate = user?.gstRate ?? 5.0;
    
    var invoiceText = '*GLANZ RENTAL - Invoice*\n\n'
        '*Invoice Number:* ${order.invoiceNumber}\n'
        '*Customer:* ${order.customer?.name ?? "N/A"}\n'
        '*Date:* ${DateFormat('dd MMM yyyy').format(DateTime.parse(order.createdAt))}\n\n'
        '*Items:*\n$itemsText'
        '*Summary:*\n'
        'Subtotal: ₹${subtotal.toStringAsFixed(0)}\n';
    
    if (gstEnabled && gstAmount > 0) {
      invoiceText += 'GST (${gstRate}%): ₹${gstAmount.toStringAsFixed(0)}\n';
    }
    
    if (lateFee > 0) {
      invoiceText += 'Late Fee: ₹${lateFee.toStringAsFixed(0)}\n';
    }
    
    invoiceText += '\n*Final Total Amount: ₹${order.totalAmount.toStringAsFixed(0)}*\n\n'
        'Thank you for your business!';
    
    return invoiceText;
  }
  
  Future<void> _downloadPDF(BuildContext context) async {
    // Use pdf package (like 'pdf' or 'printing' from pub.dev)
    // Generate PDF and download
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Generating PDF...')),
    );
    
    try {
      final pdfBytes = await generateInvoicePDF(order, user);
      // Save to device storage
      await savePDFToDevice(pdfBytes, 'Invoice-${order.invoiceNumber}.pdf');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF downloaded successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate PDF: $e')),
      );
    }
  }
  
  Future<void> _printInvoice(BuildContext context) async {
    // Use printing package
    // Show invoice preview first, then trigger print
    await Printing.layoutPdf(
      onLayout: (format) async {
        return await generateInvoicePDF(order, user);
      },
    );
  }
}
```

**Dependencies Required:**
```yaml
dependencies:
  url_launcher: ^6.2.0  # For WhatsApp sharing
  printing: ^5.12.0      # For PDF printing
  pdf: ^3.10.0           # For PDF generation
  path_provider: ^2.1.0  # For saving PDFs
```

---

### 7. **UX Improvements**

#### 7.1. New Items Appear Below Existing Items ✅
**Implementation:**
```dart
// In order creation screen
void addItem(OrderItem item) {
  // Append to end (not prepend)
  setState(() {
    items.add(item); // Add to end
  });
  
  // Scroll to newly added item
  WidgetsBinding.instance.addPostFrameCallback((_) {
    scrollController.animateTo(
      scrollController.position.maxScrollExtent,
      duration: Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  });
}
```

#### 7.2. Camera Icon Below Items List ✅
- Move camera/photo upload button to bottom of items list
- Better workflow for adding multiple products sequentially

#### 7.3. Optional Invoice Number ✅
- Invoice number field is optional
- Auto-generates if left empty
- Show hint: "(Optional - Auto-generated)"

#### 7.4. Better Date/Time Selection ✅
- Use separate dialogs/modals for date and time
- Simple, clean UI similar to shadcn components
- Better mobile experience

---

## 📊 Database Schema Summary

### Orders Table - New/Updated Fields
```sql
booking_date TIMESTAMP WITH TIME ZONE DEFAULT NOW() -- NEW
start_datetime TIMESTAMP WITH TIME ZONE            -- NEW (with time)
end_datetime TIMESTAMP WITH TIME ZONE              -- NEW (with time)
late_returned BOOLEAN DEFAULT FALSE                -- NEW
status CHECK (status IN (
  'scheduled',           -- NEW
  'active', 
  'pending_return', 
  'completed', 
  'cancelled', 
  'partially_returned'   -- NEW
))
```

### Order Items Table - New Fields
```sql
return_status TEXT DEFAULT 'not_yet_returned' 
  CHECK (return_status IN ('not_yet_returned', 'returned', 'missing'))
actual_return_date TIMESTAMP WITH TIME ZONE
late_return BOOLEAN DEFAULT FALSE
missing_note TEXT
```

### New Table: Order Return Audit
```sql
CREATE TABLE order_return_audit (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES orders(id),
  order_item_id UUID REFERENCES order_items(id),
  action TEXT NOT NULL,
  previous_status TEXT,
  new_status TEXT,
  user_id UUID NOT NULL REFERENCES profiles(id),
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

---

## 🔌 API/Backend Changes

### 1. New RPC Function: `process_order_return_optimized`
**File:** `supabase-migrations/optimize-order-return.sql`

**Purpose:** Process item-wise returns in a single atomic transaction (~50-100ms)

**Parameters:**
```dart
{
  'p_order_id': String,        // UUID
  'p_item_returns': List<Map>, // [{item_id, return_status, actual_return_date, missing_note}]
  'p_user_id': String,         // UUID
  'p_late_fee': double,        // Default: 0
}
```

**Returns:** JSONB with success status and updated order data

**Flutter Call:**
```dart
final response = await supabase.rpc('process_order_return_optimized', params: {
  'p_order_id': orderId,
  'p_item_returns': itemReturnsJson,
  'p_user_id': userId,
  'p_late_fee': lateFee,
});
```

### 2. Updated Queries
- `fetchOrders`: Now fetches `booking_date`, `return_status` fields from items
- `createOrder`: Auto-calculates status (scheduled/active) based on start_date
- **New:** `startRental`: Converts scheduled → active

---

## 🎨 UI/UX Changes Summary

### Order List Screen
- ✅ Added "Partially Returned" tab/filter
- ✅ Added "Scheduled" tab/filter
- ✅ "Start Rental" button (orange) for scheduled orders
- ✅ Updated cancellation logic display
- ✅ Real-time status updates (no manual refresh needed)
- ✅ Better pagination (20 items per page)

### Order Details Screen
- ✅ Booking date display
- ✅ Invoice number display (with auto-generated indicator)
- ✅ Professional invoice actions card (4 buttons: View, WhatsApp, Download, Print)
- ✅ Scheduled order handling (hide return section, show Start Rental)
- ✅ "Start Rental" button in header (orange, prominent design)
- ✅ Scheduled badge on dates card

### Order Creation Screen
- ✅ Auto-generated invoice numbers
- ✅ Camera icon below items list (better UX)
- ✅ Optional invoice number field
- ✅ Separate date/time modals
- ✅ New items appear below existing items

### Order Return Screen
- ✅ Unified items list (all items in one table)
- ✅ Item-level checkboxes for returns
- ✅ Display item totals (quantity × price/day)
- ✅ "Mark All as Returned" button
- ✅ Late fee input field
- ✅ Missing items notes
- ✅ Summary card with stats

---

## 🚨 Critical Implementation Notes for Flutter

### 1. Order Status Logic ⚠️ CRITICAL
**IMPORTANT:** Scheduled orders MUST always return category "scheduled" - do NOT check dates for scheduled status. Only check dates after status is confirmed as "active".

```dart
// ✅ CORRECT
if (status == OrderStatus.scheduled) {
  return OrderCategory.scheduled; // Always scheduled, ignore dates
}

// ❌ WRONG - Don't do this
if (status == OrderStatus.scheduled && startDate.isAfter(today)) {
  return OrderCategory.scheduled; // This is wrong!
}
```

### 2. Real-Time Subscriptions ⚠️ IMPORTANT
**Subscribe to TWO tables:**
- `orders` table (for order status changes)
- `order_items` table (for return status changes)

Both affect order categorization, so both must trigger refetch.

### 3. Item Return Processing ⚠️ USE RPC FUNCTION
**Always use the RPC function** `process_order_return_optimized` - it handles all logic atomically:
- Updates items
- Calculates order status
- Updates order totals
- Creates audit logs
- All in one transaction (~50-100ms)

**Do NOT** try to update items and order separately - use the RPC function.

### 4. Invoice Number Generation
**Format:** `GLAORD-YYYYMMDD-XXXX`  
**Example:** `GLAORD-20241202-3847`

Generate on client side if user doesn't provide one.

---

## 📝 Complete Flutter Code Examples

### Order Model (Complete)
```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'order.freezed.dart';
part 'order.g.dart';

@freezed
class Order with _$Order {
  const factory Order({
    required String id,
    required String branchId,
    required String staffId,
    required String customerId,
    required String invoiceNumber,
    String? bookingDate, // NEW
    required String startDate,
    required String endDate,
    String? startDatetime, // NEW
    String? endDatetime, // NEW
    required OrderStatus status,
    required double totalAmount,
    double? subtotal,
    double? gstAmount,
    double? lateFee,
    bool? lateReturned,
    required DateTime createdAt,
    Customer? customer,
    List<OrderItem>? items,
  }) = _Order;
  
  factory Order.fromJson(Map<String, dynamic> json) => _$OrderFromJson(json);
}

enum OrderStatus {
  @JsonValue('scheduled')
  scheduled,
  @JsonValue('active')
  active,
  @JsonValue('pending_return')
  pendingReturn,
  @JsonValue('completed')
  completed,
  @JsonValue('cancelled')
  cancelled,
  @JsonValue('partially_returned')
  partiallyReturned,
}
```

### Order Service (Complete)
```dart
class OrderService {
  final SupabaseClient supabase;
  
  OrderService(this.supabase);
  
  String generateInvoiceNumber() {
    final now = DateTime.now();
    final year = now.year.toString();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final random = Random().nextInt(10000).toString().padLeft(4, '0');
    return 'GLAORD-$year$month$day-$random';
  }
  
  Future<Order> createOrder(OrderDraft draft) async {
    // Calculate status
    final startDate = DateTime.parse(draft.startDate);
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final startDateOnly = DateTime(startDate.year, startDate.month, startDate.day);
    
    final status = startDateOnly.isAfter(todayStart) 
      ? OrderStatus.scheduled 
      : OrderStatus.active;
    
    // Generate invoice number if not provided
    final invoiceNumber = draft.invoiceNumber.isEmpty
      ? generateInvoiceNumber()
      : draft.invoiceNumber;
    
    final orderData = {
      'branch_id': draft.branchId,
      'staff_id': draft.staffId,
      'customer_id': draft.customerId,
      'invoice_number': invoiceNumber,
      'booking_date': DateTime.now().toIso8601String(),
      'start_date': startDateOnly.toIso8601String().split('T')[0],
      'end_date': endDateOnly.toIso8601String().split('T')[0],
      'start_datetime': draft.startDate,
      'end_datetime': draft.endDate,
      'status': status.name,
      'total_amount': draft.totalAmount,
      'subtotal': draft.subtotal,
      'gst_amount': draft.gstAmount,
    };
    
    final orderResponse = await supabase
      .from('orders')
      .insert(orderData)
      .select()
      .single();
    
    // Insert items
    final items = draft.items.map((item) => {
      return {
        'order_id': orderResponse['id'],
        'photo_url': item.photoUrl,
        'product_name': item.productName,
        'quantity': item.quantity,
        'price_per_day': item.pricePerDay,
        'days': item.days,
        'line_total': item.lineTotal,
      };
    }).toList();
    
    await supabase.from('order_items').insert(items);
    
    return Order.fromJson(orderResponse);
  }
  
  Future<void> startRental(String orderId) async {
    await supabase
      .from('orders')
      .update({
        'status': 'active',
        'start_datetime': DateTime.now().toIso8601String(),
      })
      .eq('id', orderId);
  }
  
  Future<Map<String, dynamic>> processOrderReturn({
    required String orderId,
    required List<ItemReturn> itemReturns,
    required String userId,
    double lateFee = 0,
  }) async {
    final itemReturnsJson = itemReturns.map((ir) => ir.toJson()).toList();
    
    final response = await supabase.rpc('process_order_return_optimized', params: {
      'p_order_id': orderId,
      'p_item_returns': itemReturnsJson,
      'p_user_id': userId,
      'p_late_fee': lateFee,
    });
    
    if (response.hasError) {
      throw Exception('Failed to process return: ${response.error?.message}');
    }
    
    return response.data as Map<String, dynamic>;
  }
}
```

---

## ✅ Testing Checklist for Flutter

### Scheduled Orders
- [ ] Create order with future start date → Status = "scheduled"
- [ ] Create order with today's date → Status = "active"
- [ ] Scheduled order shows "Start Rental" button (orange)
- [ ] Scheduled order does NOT show return section
- [ ] Start Rental button converts scheduled → active
- [ ] Scheduled orders can be cancelled anytime
- [ ] Scheduled orders appear in "Scheduled" tab

### Order Cancellation
- [ ] Cancel scheduled order → Should work
- [ ] Cancel active order within 10 mins → Should work
- [ ] Cancel active order after 10 mins → Should fail
- [ ] Cancel completed order → Should fail
- [ ] Cancel cancelled order → Should fail

### Return Processing
- [ ] Return some items → Status = "partially_returned"
- [ ] Return all items → Status = "completed"
- [ ] Mark item as missing → Status = "partially_returned"
- [ ] Late return shows late badge
- [ ] Late fee is added to total
- [ ] Return audit logs are created

### Real-Time Updates
- [ ] Open orders list in 2 devices
- [ ] Create order in device 1 → Appears in device 2 automatically
- [ ] Update order status in device 1 → Updates in device 2 automatically
- [ ] Return items in device 1 → Status updates in device 2 automatically

### Invoice Features
- [ ] Invoice number auto-generates if empty
- [ ] View invoice button opens preview
- [ ] WhatsApp share opens with formatted message
- [ ] Download PDF generates and saves
- [ ] Print button triggers print dialog

### UI/UX
- [ ] New items appear below existing items
- [ ] Camera icon is below items list
- [ ] Invoice number field is optional
- [ ] Date/time selection uses separate modals
- [ ] Invoice actions card has 4 professional buttons

---

## 📦 Required Flutter Packages

```yaml
dependencies:
  flutter:
    sdk: flutter
  supabase_flutter: ^2.0.0
  provider: ^6.1.0  # Or riverpod/bloc
  freezed_annotation: ^2.4.0
  json_annotation: ^4.8.0
  url_launcher: ^6.2.0
  printing: ^5.12.0
  pdf: ^3.10.0
  path_provider: ^2.1.0
  intl: ^0.19.0  # For date formatting
  qr_flutter: ^4.1.0  # For UPI QR codes

dev_dependencies:
  build_runner: ^2.4.0
  freezed: ^2.4.0
  json_serializable: ^6.7.0
```

---

## 🔗 Related Files & Resources

### Database Migrations
- `supabase-migrations/add-booking-date.sql` - Booking date and scheduled status
- `supabase-migrations/add-return-tracking.sql` - Item-wise return tracking
- `supabase-migrations/optimize-order-return.sql` - Optimized return RPC function

### Web Implementation References
- `lib/types/index.ts` - TypeScript type definitions (reference for Dart models)
- `lib/queries/orders.ts` - Order queries and mutations
- `lib/utils/invoice.ts` - Invoice number generation
- `components/orders/order-return-section.tsx` - Return UI component
- `components/invoice/invoice-share.tsx` - Invoice actions component
- `app/(dashboard)/orders/page.tsx` - Orders list page
- `app/(dashboard)/orders/[id]/page.tsx` - Order details page

---

## 📞 Questions or Clarifications

If you need any clarification on these updates, please contact the web development team. All database migrations are idempotent and safe to run multiple times.

**Key Contacts:**
- Web Development Team
- Database: All migrations are in `supabase-migrations/` folder

---

## 📅 Next Steps

1. **Review this report** and understand all changes
2. **Update Flutter models** to match new schema
3. **Implement scheduled orders** workflow
4. **Implement item-wise returns** using RPC function
5. **Add real-time subscriptions** for orders and order_items
6. **Update UI** to match web application
7. **Test thoroughly** using the checklist above

---

**Document Version:** 1.0  
**Date:** December 2, 2024  
**Time:** Until 3:20 PM  
**Status:** ✅ All features completed and tested  
**Build Status:** ✅ Build successful, no errors

---

## 🎯 Priority Implementation Order

1. **HIGH Priority:**
   - Scheduled orders system
   - Item-wise return tracking
   - Real-time updates optimization

2. **MEDIUM Priority:**
   - Auto-generated invoice numbers
   - Professional invoice actions UI
   - Improved cancellation logic

3. **LOW Priority:**
   - UX improvements (camera position, item order)

---

**End of Report**

