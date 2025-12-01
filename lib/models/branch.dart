/// Branch Model
/// 
/// Represents a rental branch location
class Branch {
  final String id;
  final String name;
  final String address;
  final String? phone;
  final DateTime createdAt;

  Branch({
    required this.id,
    required this.name,
    required this.address,
    this.phone,
    required this.createdAt,
  });

  factory Branch.fromJson(Map<String, dynamic> json) {
    // Helper function to safely get string
    String safeString(dynamic value, [String defaultValue = '']) {
      if (value == null) return defaultValue;
      return value.toString();
    }

    // Helper function to parse datetime
    DateTime safeDateTime(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is DateTime) return value;
      try {
        return DateTime.parse(value.toString());
      } catch (e) {
        return DateTime.now();
      }
    }

    return Branch(
      id: safeString(json['id']),
      name: safeString(json['name']),
      address: safeString(json['address']),
      phone: json['phone']?.toString(),
      createdAt: safeDateTime(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'phone': phone,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

