class BusinessModel {
  final int id;
  final String name;
  final String? address;
  final String? phone;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const BusinessModel({
    required this.id,
    required this.name,
    this.address,
    this.phone,
    this.createdAt,
    this.updatedAt,
  });

  factory BusinessModel.fromJson(Map<String, dynamic> json) {
    return BusinessModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name'] as String? ?? '',
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'phone': phone,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  BusinessModel copyWith({
    int? id,
    String? name,
    String? address,
    String? phone,
  }) {
    return BusinessModel(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class UserModel {
  final int id;
  final int? businessId;
  final String name;
  final String email;
  final String role;
  final bool isActive;
  final BusinessModel? business;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserModel({
    required this.id,
    this.businessId,
    required this.name,
    required this.email,
    required this.role,
    this.isActive = true,
    this.business,
    this.createdAt,
    this.updatedAt,
  });

  bool get isOwner => role == 'owner';
  bool get isCashier => role == 'cashier';
  bool get isPartner => role == 'partner';

  String get roleDisplayName {
    switch (role.toLowerCase()) {
      case 'owner':
        return 'Pemilik (Owner)';
      case 'cashier':
        return 'Kasir';
      case 'partner':
        return 'Partner';
      default:
        return role;
    }
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      businessId: json['business_id'] is int
          ? json['business_id']
          : int.tryParse(json['business_id']?.toString() ?? ''),
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'cashier',
      isActive: json['is_active'] == true || json['is_active'] == 1 || json['is_active'] == '1',
      business: json['business'] is Map<String, dynamic>
          ? BusinessModel.fromJson(json['business'] as Map<String, dynamic>)
          : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_id': businessId,
      'name': name,
      'email': email,
      'role': role,
      'is_active': isActive,
      if (business != null) 'business': business!.toJson(),
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  UserModel copyWith({
    int? id,
    int? businessId,
    String? name,
    String? email,
    String? role,
    bool? isActive,
    BusinessModel? business,
  }) {
    return UserModel(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      business: business ?? this.business,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class AuthResult {
  final bool success;
  final String message;
  final UserModel? user;
  final BusinessModel? business;
  final String? token;
  final Map<String, dynamic>? errors;

  const AuthResult({
    required this.success,
    required this.message,
    this.user,
    this.business,
    this.token,
    this.errors,
  });

  factory AuthResult.success({
    required String message,
    UserModel? user,
    BusinessModel? business,
    String? token,
  }) {
    return AuthResult(
      success: true,
      message: message,
      user: user,
      business: business,
      token: token,
    );
  }

  factory AuthResult.failure({
    required String message,
    Map<String, dynamic>? errors,
  }) {
    return AuthResult(
      success: false,
      message: message,
      errors: errors,
    );
  }
}
