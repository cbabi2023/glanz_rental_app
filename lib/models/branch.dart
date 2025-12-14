/// Branch Model
/// 
/// Represents a rental branch location
class Branch {
  final String id;
  final String name;
  final String address;
  final String? phone;
  final bool? isMain; // Whether this is the main/default branch
  final DateTime createdAt;

  Branch({
    required this.id,
    required this.name,
    required this.address,
    this.phone,
    this.isMain,
    required this.createdAt,
  });

  factory Branch.fromJson(Map<String, dynamic> json) {
    // Helper function to safely get string
    String safeString(dynamic value, [String defaultValue = '']) {
      if (value == null) return defaultValue;
      return value.toString();
    }

    // Helper function to parse datetime
    // Handles timezone correctly - Supabase returns datetimes in UTC
    // If no timezone info, assume UTC (common in databases)
    DateTime safeDateTime(dynamic value) {
      if (value == null) return DateTime.now();
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
        return DateTime.now();
      }
    }

    return Branch(
      id: safeString(json['id']),
      name: safeString(json['name']),
      address: safeString(json['address']),
      phone: json['phone']?.toString(),
      isMain: json['is_main'] as bool?,
      createdAt: safeDateTime(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'phone': phone,
      'is_main': isMain,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

