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
    DateTime? safeDateTime(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      try {
        return DateTime.parse(value.toString());
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

