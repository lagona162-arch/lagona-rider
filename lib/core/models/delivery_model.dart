class DeliveryModel {
  final String id;
  final String type;
  final String? customerId;
  final String? merchantId;
  final String? riderId;
  final String? loadingStationId;
  final String? businessHubId;
  final String? pickupAddress;
  final String? dropoffAddress;
  final double? pickupLatitude;
  final double? pickupLongitude;
  final double? dropoffLatitude;
  final double? dropoffLongitude;
  final double? distanceKm;
  final double? deliveryFee;
  final double? commissionRider;
  final double? commissionLoading;
  final double? commissionHub;
  final String status;
  final String? pickupPhotoUrl;
  final String? dropoffPhotoUrl;
  final DateTime createdAt;

  DeliveryModel({
    required this.id,
    required this.type,
    this.customerId,
    this.merchantId,
    this.riderId,
    this.loadingStationId,
    this.businessHubId,
    this.pickupAddress,
    this.dropoffAddress,
    this.pickupLatitude,
    this.pickupLongitude,
    this.dropoffLatitude,
    this.dropoffLongitude,
    this.distanceKm,
    this.deliveryFee,
    this.commissionRider,
    this.commissionLoading,
    this.commissionHub,
    required this.status,
    this.pickupPhotoUrl,
    this.dropoffPhotoUrl,
    required this.createdAt,
  });

  factory DeliveryModel.fromJson(Map<String, dynamic> json) {
    return DeliveryModel(
      id: json['id'] as String,
      type: json['type'] as String,
      customerId: json['customer_id'] as String?,
      merchantId: json['merchant_id'] as String?,
      riderId: json['rider_id'] as String?,
      loadingStationId: json['loading_station_id'] as String?,
      businessHubId: json['business_hub_id'] as String?,
      pickupAddress: json['pickup_address'] as String?,
      dropoffAddress: json['dropoff_address'] as String?,
      pickupLatitude: (json['pickup_latitude'] as num?)?.toDouble(),
      pickupLongitude: (json['pickup_longitude'] as num?)?.toDouble(),
      dropoffLatitude: (json['dropoff_latitude'] as num?)?.toDouble(),
      dropoffLongitude: (json['dropoff_longitude'] as num?)?.toDouble(),
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      deliveryFee: (json['delivery_fee'] as num?)?.toDouble(),
      commissionRider: (json['commission_rider'] as num?)?.toDouble(),
      commissionLoading: (json['commission_loading'] as num?)?.toDouble(),
      commissionHub: (json['commission_hub'] as num?)?.toDouble(),
      status: json['status'] as String? ?? 'pending',
      pickupPhotoUrl: json['pickup_photo_url'] as String?,
      dropoffPhotoUrl: json['dropoff_photo_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'customer_id': customerId,
      'merchant_id': merchantId,
      'rider_id': riderId,
      'loading_station_id': loadingStationId,
      'business_hub_id': businessHubId,
      'pickup_address': pickupAddress,
      'dropoff_address': dropoffAddress,
      'pickup_latitude': pickupLatitude,
      'pickup_longitude': pickupLongitude,
      'dropoff_latitude': dropoffLatitude,
      'dropoff_longitude': dropoffLongitude,
      'distance_km': distanceKm,
      'delivery_fee': deliveryFee,
      'commission_rider': commissionRider,
      'commission_loading': commissionLoading,
      'commission_hub': commissionHub,
      'status': status,
      'pickup_photo_url': pickupPhotoUrl,
      'dropoff_photo_url': dropoffPhotoUrl,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

