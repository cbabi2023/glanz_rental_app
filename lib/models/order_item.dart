/// Return Status Enum
enum ReturnStatus {
  notYetReturned('not_yet_returned'),
  returned('returned'),
  missing('missing');

  final String value;
  const ReturnStatus(this.value);

  static ReturnStatus? fromString(String? value) {
    if (value == null) return null;
    switch (value) {
      case 'not_yet_returned':
        return ReturnStatus.notYetReturned;
      case 'returned':
        return ReturnStatus.returned;
      case 'missing':
        return ReturnStatus.missing;
      default:
        return null;
    }
  }
}

/// Order Item Model
/// 
/// Represents an item within an order
class OrderItem {
  final String? id;
  final String? orderId;
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
  final int? returnedQuantity; // Number of items returned (for partial returns)
  final double? damageCost; // Cost for damaged/missing items
  final String? damageDescription; // Description of damage or issues (separate from missing_note)

  OrderItem({
    this.id,
    this.orderId,
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
    this.returnedQuantity,
    this.damageCost,
    this.damageDescription,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    // Helper function to safely get string
    String safeString(dynamic value, [String defaultValue = '']) {
      if (value == null) return defaultValue;
      return value.toString();
    }
    
    // Helper function to parse datetime
    // Handles timezone correctly - Supabase returns datetimes in UTC
    // If no timezone info, assume UTC (common in databases)
    DateTime? safeDateTime(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value.toLocal(); // Convert to local time
      try {
        final dateString = value.toString().trim();
        
        // Check if string has timezone info (ends with Z or has timezone offset)
        final hasTimezone = dateString.endsWith('Z') || 
                           RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(dateString);
        
        if (hasTimezone) {
          // Has timezone info - DateTime.parse will handle conversion to local time
          return DateTime.parse(dateString).toLocal();
        } else {
          // No timezone info - assume it's UTC from database
          final parsed = DateTime.parse(dateString);
          final utcDate = DateTime.utc(
            parsed.year, parsed.month, parsed.day,
            parsed.hour, parsed.minute, parsed.second, 
            parsed.millisecond, parsed.microsecond
          );
          return utcDate.toLocal(); // Convert UTC to local time
        }
      } catch (e) {
        return null;
      }
    }

    return OrderItem(
      id: json['id']?.toString(),
      orderId: json['order_id']?.toString(),
      photoUrl: safeString(json['photo_url']),
      productName: json['product_name']?.toString(),
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      pricePerDay: (json['price_per_day'] as num?)?.toDouble() ?? 0.0,
      days: (json['days'] as num?)?.toInt() ?? 0,
      lineTotal: (json['line_total'] as num?)?.toDouble() ?? 0.0,
      returnStatus: ReturnStatus.fromString(json['return_status']?.toString()),
      actualReturnDate: safeDateTime(json['actual_return_date']),
      lateReturn: json['late_return'] as bool?,
      missingNote: json['missing_note']?.toString(),
      returnedQuantity: (json['returned_quantity'] as num?)?.toInt(),
      damageCost: (json['damage_fee'] as num?)?.toDouble(),
      damageDescription: json['damage_description']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (orderId != null) 'order_id': orderId,
      'photo_url': photoUrl,
      'product_name': productName,
      'quantity': quantity,
      'price_per_day': pricePerDay,
      'days': days,
      'line_total': lineTotal,
      if (returnStatus != null) 'return_status': returnStatus!.value,
      if (actualReturnDate != null) 'actual_return_date': actualReturnDate!.toIso8601String(),
      if (lateReturn != null) 'late_return': lateReturn,
      if (missingNote != null) 'missing_note': missingNote,
      if (returnedQuantity != null) 'returned_quantity': returnedQuantity,
      if (damageCost != null) 'damage_fee': damageCost,
      if (damageDescription != null) 'damage_description': damageDescription,
    };
  }
  
  // Helper methods
  bool get isReturned => returnStatus == ReturnStatus.returned;
  bool get isMissing => returnStatus == ReturnStatus.missing;
  bool get isPending => returnStatus == null || returnStatus == ReturnStatus.notYetReturned;
  
  /// Get the quantity that is still pending return
  int get pendingQuantity {
    if (returnStatus == ReturnStatus.returned) {
      // If fully returned, no pending quantity
      final returned = returnedQuantity ?? quantity;
      return (quantity - returned).clamp(0, quantity);
    }
    // If not returned or partially returned, calculate pending
    final alreadyReturned = returnedQuantity ?? 0;
    return (quantity - alreadyReturned).clamp(0, quantity);
  }
  
  /// Get the quantity that has been returned
  int get alreadyReturnedQuantity => returnedQuantity ?? (isReturned ? quantity : 0);

  /// Calculate line total (quantity * price_per_day, without multiplying by days)
  static double calculateLineTotal({
    required int quantity,
    required double pricePerDay,
    required int days,
  }) {
    return quantity * pricePerDay;
  }
}

