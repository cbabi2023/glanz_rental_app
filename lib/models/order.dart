import 'customer.dart';
import 'user_profile.dart';
import 'branch.dart';
import 'order_item.dart';

/// Order Status Enum
enum OrderStatus {
  scheduled('scheduled'),
  active('active'),
  pendingReturn('pending_return'),
  completed('completed'),
  completedWithIssues('completed_with_issues'),
  cancelled('cancelled'),
  partiallyReturned('partially_returned'),
  flagged('flagged');

  final String value;
  const OrderStatus(this.value);

  static OrderStatus fromString(String value) {
    switch (value) {
      case 'scheduled':
        return OrderStatus.scheduled;
      case 'active':
        return OrderStatus.active;
      case 'pending_return':
        return OrderStatus.pendingReturn;
      case 'completed':
        return OrderStatus.completed;
      case 'completed_with_issues':
        return OrderStatus.completedWithIssues;
      case 'cancelled':
        return OrderStatus.cancelled;
      case 'partially_returned':
        return OrderStatus.partiallyReturned;
      case 'flagged':
        return OrderStatus.flagged;
      default:
        throw ArgumentError('Unknown order status: $value');
    }
  }
}

/// Order Model
/// 
/// Represents a rental order with customer, items, and billing information
class Order {
  final String id;
  final String branchId;
  final String staffId;
  final String customerId;
  final String invoiceNumber;
  
  // Booking date - when order was booked/created
  final String? bookingDate;
  
  // Legacy date fields (for backward compatibility)
  final String startDate;
  final String endDate;
  
  // New datetime fields with time
  final String? startDatetime;
  final String? endDatetime;
  
  final OrderStatus status;
  final double totalAmount;
  final double? subtotal; // Subtotal before GST
  final double? gstAmount; // GST amount
  final double? lateFee; // Late fee amount
  final double? damageFeeTotal; // Total damage fee for the order
  final double? securityDepositAmount; // Security deposit amount
  final bool? securityDepositCollected; // Security deposit collected flag (boolean - indicates if collected)
  final bool? securityDepositRefunded; // Security deposit refunded flag (boolean)
  final double? securityDepositRefundedAmount; // Security deposit refunded amount
  final DateTime? securityDepositRefundDate; // Security deposit refund date
  final double? additionalAmountCollected; // Additional amount collected beyond security deposit (for outstanding amounts)
  final DateTime createdAt;
  
  // Computed property for backward compatibility
  // Returns the security deposit amount (not the boolean flags)
  double? get securityDeposit => securityDepositAmount;
  
  // Relations
  final Customer? customer;
  final UserProfile? staff;
  final Branch? branch;
  final List<OrderItem>? items;

  Order({
    required this.id,
    required this.branchId,
    required this.staffId,
    required this.customerId,
    required this.invoiceNumber,
    this.bookingDate,
    required this.startDate,
    required this.endDate,
    this.startDatetime,
    this.endDatetime,
    required this.status,
    required this.totalAmount,
    this.subtotal,
    this.gstAmount,
    this.lateFee,
    this.damageFeeTotal,
    this.securityDepositAmount,
    this.securityDepositCollected, // Boolean flag (indicates if collected)
    this.securityDepositRefunded, // Boolean flag (indicates if refunded)
    this.securityDepositRefundedAmount,
    this.securityDepositRefundDate,
    this.additionalAmountCollected, // Additional amount collected beyond security deposit
    required this.createdAt,
    this.customer,
    this.staff,
    this.branch,
    this.items,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    // Helper function to safely get string or return empty string
    String safeString(dynamic value, [String defaultValue = '']) {
      if (value == null) return defaultValue;
      return value.toString();
    }

    // Helper function to parse datetime string
    // Handles timezone correctly - if string is UTC (ends with Z) or has timezone, 
    // it will be converted to local time. If no timezone, treats as local.
    DateTime safeDateTime(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is DateTime) return value;
      try {
        final dateString = value.toString();
        // Parse the datetime string
        DateTime parsed = DateTime.parse(dateString);
        // DateTime.parse already handles timezone conversion correctly
        return parsed;
      } catch (e) {
        return DateTime.now();
      }
    }
    
    // Helper function to parse datetime string and preserve timezone info
    // This ensures datetimes from database are correctly handled
    // If the string doesn't have timezone info, we assume it's UTC (common in databases)
    String? safeDateTimeString(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value.toIso8601String();
      try {
        final dateString = value.toString().trim();
        
        // Check if string has timezone info (ends with Z or has timezone offset like +05:30, -05:00)
        final hasTimezone = dateString.endsWith('Z') || 
                           RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(dateString);
        
        if (!hasTimezone) {
          // No timezone info - assume it's UTC from database
          // Parse the components and create as UTC, then convert to local for consistency
          final parsed = DateTime.parse(dateString);
          // Create as UTC datetime
          final utcDate = DateTime.utc(
            parsed.year, parsed.month, parsed.day,
            parsed.hour, parsed.minute, parsed.second, 
            parsed.millisecond, parsed.microsecond
          );
          // Return in ISO format - this will be converted to local when parsed later
          return utcDate.toIso8601String();
        }
        
        // Has timezone info, return as-is (DateTime.parse will handle conversion correctly)
        return dateString;
      } catch (e) {
        return null;
      }
    }

    // Helper function to safely convert to double (handles num, string, bool, null)
    double? safeToDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      if (value is bool) return null; // Skip boolean values
      if (value is String) {
        final parsed = double.tryParse(value);
        return parsed;
      }
      return null;
    }

    // Handle customer relation - might be a list, object, or null
    Customer? customer;
    if (json['customer'] != null) {
      if (json['customer'] is List && (json['customer'] as List).isNotEmpty) {
        customer = Customer.fromJson((json['customer'] as List).first as Map<String, dynamic>);
      } else if (json['customer'] is Map) {
        customer = Customer.fromJson(json['customer'] as Map<String, dynamic>);
      }
    }

    // Handle staff relation
    UserProfile? staff;
    if (json['staff'] != null) {
      if (json['staff'] is List && (json['staff'] as List).isNotEmpty) {
        staff = UserProfile.fromJson((json['staff'] as List).first as Map<String, dynamic>);
      } else if (json['staff'] is Map) {
        staff = UserProfile.fromJson(json['staff'] as Map<String, dynamic>);
      }
    }

    // Handle branch relation
    Branch? branch;
    if (json['branch'] != null) {
      if (json['branch'] is List && (json['branch'] as List).isNotEmpty) {
        branch = Branch.fromJson((json['branch'] as List).first as Map<String, dynamic>);
      } else if (json['branch'] is Map) {
        branch = Branch.fromJson(json['branch'] as Map<String, dynamic>);
      }
    }

    // Handle items - might be a list or null
    List<OrderItem>? items;
    if (json['items'] != null && json['items'] is List) {
      items = (json['items'] as List)
          .where((item) => item != null)
          .map((item) => OrderItem.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    return Order(
      id: safeString(json['id']),
      branchId: safeString(json['branch_id']),
      staffId: safeString(json['staff_id']),
      customerId: safeString(json['customer_id']),
      invoiceNumber: safeString(json['invoice_number']),
      bookingDate: json['booking_date']?.toString(),
      startDate: safeString(json['start_date']),
      endDate: safeString(json['end_date']),
      startDatetime: safeDateTimeString(json['start_datetime']),
      endDatetime: safeDateTimeString(json['end_datetime']),
      status: OrderStatus.fromString(safeString(json['status'], 'active')),
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      subtotal: (json['subtotal'] as num?)?.toDouble(),
      gstAmount: (json['gst_amount'] as num?)?.toDouble(),
      lateFee: (json['late_fee'] as num?)?.toDouble(),
      damageFeeTotal: (json['damage_fee_total'] as num?)?.toDouble(),
      securityDepositAmount: safeToDouble(json['security_deposit_amount']),
      securityDepositCollected: json['security_deposit_collected'] is bool 
          ? json['security_deposit_collected'] as bool?
          : (json['security_deposit_collected'] == true || json['security_deposit_collected'] == 'true' || json['security_deposit_collected'] == 1),
      securityDepositRefunded: json['security_deposit_refunded'] is bool 
          ? json['security_deposit_refunded'] as bool?
          : (json['security_deposit_refunded'] == true || json['security_deposit_refunded'] == 'true' || json['security_deposit_refunded'] == 1),
      securityDepositRefundedAmount: safeToDouble(json['security_deposit_refunded_amount']),
      securityDepositRefundDate: json['security_deposit_refund_date'] != null 
          ? safeDateTime(json['security_deposit_refund_date'])
          : null,
      additionalAmountCollected: safeToDouble(json['additional_amount_collected']),
      createdAt: safeDateTime(json['created_at']),
      customer: customer,
      staff: staff,
      branch: branch,
      items: items,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'branch_id': branchId,
      'staff_id': staffId,
      'customer_id': customerId,
      'invoice_number': invoiceNumber,
      'booking_date': bookingDate,
      'start_date': startDate,
      'end_date': endDate,
      'start_datetime': startDatetime,
      'end_datetime': endDatetime,
      'status': status.value,
      'total_amount': totalAmount,
      'subtotal': subtotal,
      'gst_amount': gstAmount,
      'late_fee': lateFee,
      'security_deposit_amount': securityDepositAmount,
      'security_deposit_collected': securityDepositCollected,
      'security_deposit_refunded': securityDepositRefunded, // Boolean flag
      'security_deposit_refunded_amount': securityDepositRefundedAmount,
      'security_deposit_refund_date': securityDepositRefundDate?.toIso8601String(),
      'additional_amount_collected': additionalAmountCollected,
      'created_at': createdAt.toIso8601String(),
      if (customer != null) 'customer': customer!.toJson(),
      if (staff != null) 'staff': staff!.toJson(),
      if (branch != null) 'branch': branch!.toJson(),
      if (items != null)
        'items': items!.map((item) => item.toJson()).toList(),
    };
  }

  // Helper methods
  bool get isScheduled => status == OrderStatus.scheduled;
  bool get isActive => status == OrderStatus.active;
  bool get isPendingReturn => status == OrderStatus.pendingReturn;
  bool get isCompleted => status == OrderStatus.completed;
  bool get isCompletedWithIssues => status == OrderStatus.completedWithIssues;
  bool get isCancelled => status == OrderStatus.cancelled;
  bool get isPartiallyReturned => status == OrderStatus.partiallyReturned;
  bool get isFlagged => status == OrderStatus.flagged;
  
  // Check if order is in any completed state (completed or completed_with_issues)
  bool get isAnyCompleted => isCompleted || isCompletedWithIssues;

  bool get canEdit => isActive || isPendingReturn;
  bool get canMarkReturned {
    // Can return if active, pending return, or partially returned
    if (isActive || isPendingReturn || isPartiallyReturned) {
      return true;
    }
    return false;
  }
  
  /// Check if there are items that still need to be returned
  bool get hasPendingReturnItems {
    if (items == null || items!.isEmpty) {
      return false;
    }
    return items!.any((item) => item.isPending);
  }
  
  bool get canStartRental => isScheduled;
  
  /// Check if order can be cancelled based on status and time rules
  /// - Scheduled orders: can be cancelled anytime
  /// - Active orders: can be cancelled only within 10 minutes of becoming active
  /// - Completed/Cancelled orders: cannot be cancelled
  bool canCancel() {
    // Already cancelled or completed cannot be cancelled
    if (isCancelled || isAnyCompleted) {
      return false;
    }
    
    // Scheduled orders can be cancelled anytime
    if (isScheduled) {
      return true;
    }
    
    // Active orders: check 10-minute window
    if (isActive) {
      // Use start_datetime as the timestamp when rental became active
      final activeSince = startDatetime != null 
        ? DateTime.parse(startDatetime!)
        : createdAt;
        
      final now = DateTime.now();
      final minutesSinceActive = now.difference(activeSince).inMinutes;
      
      // Can cancel if less than 10 minutes since becoming active
      return minutesSinceActive <= 10;
    }
    
    // Other statuses cannot be cancelled
    return false;
  }
}

/// Order Draft Model
/// 
/// Used for creating new orders (before saving to database)
class OrderDraft {
  String? customerId;
  String? customerName;
  String? customerPhone;
  String startDate;
  String endDate;
  String invoiceNumber;
  List<OrderItem> items;
  double grandTotal;

  OrderDraft({
    this.customerId,
    this.customerName,
    this.customerPhone,
    required this.startDate,
    required this.endDate,
    required this.invoiceNumber,
    required this.items,
    required this.grandTotal,
  });

  void clear() {
    customerId = null;
    customerName = null;
    customerPhone = null;
    items.clear();
    grandTotal = 0.0;
  }
}

