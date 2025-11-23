class UserModel {
  final String id;
  final String fullName;
  final String email;
  final String password;
  final String role;
  final String? phone;
  final String? lastname;
  final String? firstname;
  final String? middleInitial;
  final DateTime? birthdate;
  final String? address;
  final bool isActive;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.password,
    required this.role,
    this.phone,
    this.lastname,
    this.firstname,
    this.middleInitial,
    this.birthdate,
    this.address,
    required this.isActive,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // Determine active status: prefer access_status == 'approved' if present,
    // otherwise fallback to legacy is_active boolean.
    final dynamic accessStatus = json['access_status'];
    final bool resolvedIsActive = accessStatus is String
        ? accessStatus.toLowerCase() == 'approved'
        : (json['is_active'] as bool? ?? false);

    return UserModel(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      email: json['email'] as String,
      password: json['password'] as String,
      role: json['role'] as String,
      phone: json['phone'] as String?,
      lastname: json['lastname'] as String?,
      firstname: json['firstname'] as String?,
      middleInitial: json['middle_initial'] as String?,
      birthdate: json['birthdate'] != null
          ? DateTime.parse(json['birthdate'] as String)
          : null,
      address: json['address'] as String?,
      isActive: resolvedIsActive,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'email': email,
      'password': password,
      'role': role,
      'phone': phone,
      'lastname': lastname,
      'firstname': firstname,
      'middle_initial': middleInitial,
      'birthdate': birthdate?.toIso8601String().split('T')[0], // Store as date only (YYYY-MM-DD)
      'address': address,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? id,
    String? fullName,
    String? email,
    String? password,
    String? role,
    String? phone,
    String? lastname,
    String? firstname,
    String? middleInitial,
    DateTime? birthdate,
    String? address,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      password: password ?? this.password,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      lastname: lastname ?? this.lastname,
      firstname: firstname ?? this.firstname,
      middleInitial: middleInitial ?? this.middleInitial,
      birthdate: birthdate ?? this.birthdate,
      address: address ?? this.address,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Calculate age from birthdate
  int? get age {
    if (birthdate == null) return null;
    final today = DateTime.now();
    int age = today.year - birthdate!.year;
    if (today.month < birthdate!.month ||
        (today.month == birthdate!.month && today.day < birthdate!.day)) {
      age--;
    }
    return age;
  }

  /// Check if user is 18 years or older
  bool get is18OrOlder {
    final userAge = age;
    return userAge != null && userAge >= 18;
  }
}

