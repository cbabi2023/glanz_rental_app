/// User Profile Model
/// 
/// Represents a user profile with role-based access control
class UserProfile {
  final String id;
  final String username;
  final String fullName;
  final String phone;
  final UserRole role;
  final String? branchId;
  final String? gstNumber;
  final bool? gstEnabled;
  final double? gstRate;
  final bool? gstIncluded;
  final String? upiId;
  final String? companyName;
  final String? companyAddress;
  final String? companyLogoUrl;
  final bool? showInvoiceTerms; // Show terms & conditions in invoice PDF
  final bool? showInvoiceQr; // Show QR code in invoice PDF

  UserProfile({
    required this.id,
    required this.username,
    required this.fullName,
    required this.phone,
    required this.role,
    this.branchId,
    this.gstNumber,
    this.gstEnabled,
    this.gstRate,
    this.gstIncluded,
    this.upiId,
    this.companyName,
    this.companyAddress,
    this.companyLogoUrl,
    this.showInvoiceTerms,
    this.showInvoiceQr,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    // Helper function to safely get string
    String safeString(dynamic value, [String defaultValue = '']) {
      if (value == null) return defaultValue;
      return value.toString();
    }

    return UserProfile(
      id: safeString(json['id']),
      username: safeString(json['username']),
      fullName: safeString(json['full_name']),
      phone: safeString(json['phone']),
      role: UserRole.fromString(safeString(json['role'], 'staff')),
      branchId: json['branch_id']?.toString(),
      gstNumber: json['gst_number']?.toString(),
      gstEnabled: json['gst_enabled'] as bool?,
      gstRate: (json['gst_rate'] as num?)?.toDouble(),
      gstIncluded: json['gst_included'] as bool?,
      upiId: json['upi_id']?.toString(),
      companyName: json['company_name']?.toString(),
      companyAddress: json['company_address']?.toString(),
      companyLogoUrl: json['company_logo_url']?.toString(),
      // Support both new column names (show_terms/show_qr_code) and old ones for backward compatibility
      showInvoiceTerms: (json['show_terms'] as bool?) ?? json['show_invoice_terms'] as bool?, // Read actual value (null if not set)
      showInvoiceQr: (json['show_qr_code'] as bool?) ?? json['show_invoice_qr'] as bool?, // Read actual value (null if not set)
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'full_name': fullName,
      'phone': phone,
      'role': role.value,
      'branch_id': branchId,
      'gst_number': gstNumber,
      'gst_enabled': gstEnabled,
      'gst_rate': gstRate,
      'gst_included': gstIncluded,
      'upi_id': upiId,
      'company_name': companyName,
      'company_address': companyAddress,
      'company_logo_url': companyLogoUrl,
      // Write both keys for compatibility; backend will store matching columns
      'show_terms': showInvoiceTerms,
      'show_qr_code': showInvoiceQr,
      'show_invoice_terms': showInvoiceTerms,
      'show_invoice_qr': showInvoiceQr,
    };
  }

  // Role checks
  bool get isSuperAdmin => role == UserRole.superAdmin;
  bool get isBranchAdmin => role == UserRole.branchAdmin;
  bool get isStaff => role == UserRole.staff;

  // Check if user can manage branches
  bool get canManageBranches => isSuperAdmin;

  // Check if user can manage staff
  bool get canManageStaff => isSuperAdmin || isBranchAdmin;

  // Check if user can view reports
  bool get canViewReports => isSuperAdmin || isBranchAdmin;
}

/// User Role Enum
enum UserRole {
  superAdmin('super_admin'),
  branchAdmin('branch_admin'),
  staff('staff');

  final String value;
  const UserRole(this.value);

  static UserRole fromString(String value) {
    switch (value) {
      case 'super_admin':
        return UserRole.superAdmin;
      case 'branch_admin':
        return UserRole.branchAdmin;
      case 'staff':
        return UserRole.staff;
      default:
        throw ArgumentError('Unknown role: $value');
    }
  }
}

