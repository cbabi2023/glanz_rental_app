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

  OrderItem({
    this.id,
    this.orderId,
    required this.photoUrl,
    this.productName,
    required this.quantity,
    required this.pricePerDay,
    required this.days,
    required this.lineTotal,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    // Helper function to safely get string
    String safeString(dynamic value, [String defaultValue = '']) {
      if (value == null) return defaultValue;
      return value.toString();
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
    };
  }

  /// Calculate line total (quantity * price_per_day * days)
  static double calculateLineTotal({
    required int quantity,
    required double pricePerDay,
    required int days,
  }) {
    return quantity * pricePerDay * days;
  }
}

