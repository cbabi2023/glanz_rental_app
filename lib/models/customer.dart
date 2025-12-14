/// Customer Model
/// 
/// Represents a customer with ID proof information
class Customer {
  final String id;
  final String? customerNumber; // Format: GLA-00001
  final String name;
  final String phone;
  final String? email;
  final String? address;
  final IdProofType? idProofType;
  final String? idProofNumber;
  final String? idProofFrontUrl;
  final String? idProofBackUrl;
  final DateTime? createdAt;
  final double? dueAmount; // Calculated field for pending orders

  Customer({
    required this.id,
    this.customerNumber,
    required this.name,
    required this.phone,
    this.email,
    this.address,
    this.idProofType,
    this.idProofNumber,
    this.idProofFrontUrl,
    this.idProofBackUrl,
    this.createdAt,
    this.dueAmount,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
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

    return Customer(
      id: safeString(json['id']),
      customerNumber: json['customer_number']?.toString(),
      name: safeString(json['name']),
      phone: safeString(json['phone']),
      email: json['email']?.toString(),
      address: json['address']?.toString(),
      idProofType: json['id_proof_type'] != null
          ? IdProofType.fromString(json['id_proof_type'].toString())
          : null,
      idProofNumber: json['id_proof_number']?.toString(),
      idProofFrontUrl: json['id_proof_front_url']?.toString(),
      idProofBackUrl: json['id_proof_back_url']?.toString(),
      createdAt: safeDateTime(json['created_at']),
      dueAmount: (json['due_amount'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer_number': customerNumber,
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'id_proof_type': idProofType?.value,
      'id_proof_number': idProofNumber,
      'id_proof_front_url': idProofFrontUrl,
      'id_proof_back_url': idProofBackUrl,
      'created_at': createdAt?.toIso8601String(),
      'due_amount': dueAmount,
    };
  }
}

/// ID Proof Type Enum
enum IdProofType {
  aadhar('aadhar'),
  passport('passport'),
  voter('voter'),
  others('others');

  final String value;
  const IdProofType(this.value);

  static IdProofType fromString(String value) {
    switch (value) {
      case 'aadhar':
        return IdProofType.aadhar;
      case 'passport':
        return IdProofType.passport;
      case 'voter':
        return IdProofType.voter;
      case 'others':
        return IdProofType.others;
      default:
        throw ArgumentError('Unknown ID proof type: $value');
    }
  }

  static List<String> get allValues => 
      IdProofType.values.map((e) => e.value).toList();
}

