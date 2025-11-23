class CustomerModel {
  final String id;
  final String? address;
  final double? latitude;
  final double? longitude;
  final DateTime? locationUpdatedAt;
  final DateTime createdAt;

  CustomerModel({
    required this.id,
    this.address,
    this.latitude,
    this.longitude,
    this.locationUpdatedAt,
    required this.createdAt,
  });

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    return CustomerModel(
      id: json['id'] as String,
      address: json['address'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      locationUpdatedAt: json['location_updated_at'] != null
          ? DateTime.parse(json['location_updated_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'location_updated_at': locationUpdatedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}

