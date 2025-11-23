class TopUpModel {
  final String id;
  final String? initiatedBy;
  final String? loadingStationId;
  final String? businessHubId;
  final String? riderId;
  final double amount;
  final double? bonusAmount;
  final double? totalCredited;
  final DateTime createdAt;

  TopUpModel({
    required this.id,
    this.initiatedBy,
    this.loadingStationId,
    this.businessHubId,
    this.riderId,
    required this.amount,
    this.bonusAmount,
    this.totalCredited,
    required this.createdAt,
  });

  factory TopUpModel.fromJson(Map<String, dynamic> json) {
    return TopUpModel(
      id: json['id'] as String,
      initiatedBy: json['initiated_by'] as String?,
      loadingStationId: json['loading_station_id'] as String?,
      businessHubId: json['business_hub_id'] as String?,
      riderId: json['rider_id'] as String?,
      amount: (json['amount'] as num).toDouble(),
      bonusAmount: (json['bonus_amount'] as num?)?.toDouble(),
      totalCredited: (json['total_credited'] as num?)?.toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'initiated_by': initiatedBy,
      'loading_station_id': loadingStationId,
      'business_hub_id': businessHubId,
      'rider_id': riderId,
      'amount': amount,
      'bonus_amount': bonusAmount,
      'total_credited': totalCredited,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

