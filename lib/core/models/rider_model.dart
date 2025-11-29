class RiderModel {
  final String id;
  final String? loadingStationId;
  final String? plateNumber;
  final String? vehicleType;
  final String? profilePictureUrl;
  final String? driversLicenseUrl;
  final String? officialReceiptUrl;
  final String? certificateOfRegistrationUrl;
  final String? vehicleFrontPictureUrl;
  final String? vehicleSidePictureUrl;
  final String? vehicleBackPictureUrl;
  final double balance;
  final double commissionRate;
  final String status;
  final String? currentAddress;
  final double? latitude;
  final double? longitude;
  final DateTime? lastActive;
  final DateTime createdAt;

  RiderModel({
    required this.id,
    this.loadingStationId,
    this.plateNumber,
    this.vehicleType,
    this.profilePictureUrl,
    this.driversLicenseUrl,
    this.officialReceiptUrl,
    this.certificateOfRegistrationUrl,
    this.vehicleFrontPictureUrl,
    this.vehicleSidePictureUrl,
    this.vehicleBackPictureUrl,
    required this.balance,
    required this.commissionRate,
    required this.status,
    this.currentAddress,
    this.latitude,
    this.longitude,
    this.lastActive,
    required this.createdAt,
  });

  factory RiderModel.fromJson(Map<String, dynamic> json) {

    String? sanitizeUrl(dynamic value) {
      if (value == null) return null;
      if (value is String) {
        final trimmed = value.trim();
        return trimmed.isEmpty ? null : trimmed;
      }
      return null;
    }

    return RiderModel(
      id: json['id'] as String,
      loadingStationId: json['loading_station_id'] as String?,
      plateNumber: json['plate_number'] as String?,
      vehicleType: json['vehicle_type'] as String?,
      profilePictureUrl: sanitizeUrl(json['profile_picture_url']),
      driversLicenseUrl: sanitizeUrl(json['drivers_license_url']),
      officialReceiptUrl: sanitizeUrl(json['official_receipt_url']),
      certificateOfRegistrationUrl: sanitizeUrl(json['certificate_of_registration_url']),
      vehicleFrontPictureUrl: sanitizeUrl(json['vehicle_front_picture_url']),
      vehicleSidePictureUrl: sanitizeUrl(json['vehicle_side_picture_url']),
      vehicleBackPictureUrl: sanitizeUrl(json['vehicle_back_picture_url']),
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      commissionRate: (json['commission_rate'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'available',
      currentAddress: json['current_address'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      lastActive: json['last_active'] != null
          ? DateTime.parse(json['last_active'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'loading_station_id': loadingStationId,
      'plate_number': plateNumber,
      'vehicle_type': vehicleType,
      'profile_picture_url': profilePictureUrl,
      'drivers_license_url': driversLicenseUrl,
      'official_receipt_url': officialReceiptUrl,
      'certificate_of_registration_url': certificateOfRegistrationUrl,
      'vehicle_front_picture_url': vehicleFrontPictureUrl,
      'vehicle_side_picture_url': vehicleSidePictureUrl,
      'vehicle_back_picture_url': vehicleBackPictureUrl,
      'balance': balance,
      'commission_rate': commissionRate,
      'status': status,
      'current_address': currentAddress,
      'latitude': latitude,
      'longitude': longitude,
      'last_active': lastActive?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}

