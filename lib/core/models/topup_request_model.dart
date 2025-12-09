class TopUpRequestModel {
  final String id;
  final String requestedBy;
  final String? businessHubId;
  final String? loadingStationId;
  final double requestedAmount;
  final String status;
  final DateTime createdAt;
  final DateTime? processedAt;
  final String? processedBy;
  final String? rejectionReason;
  final double? bonusRate;
  final double? bonusAmount;
  final double? totalCredited;

  TopUpRequestModel({
    required this.id,
    required this.requestedBy,
    this.businessHubId,
    this.loadingStationId,
    required this.requestedAmount,
    required this.status,
    required this.createdAt,
    this.processedAt,
    this.processedBy,
    this.rejectionReason,
    this.bonusRate,
    this.bonusAmount,
    this.totalCredited,
  });

  factory TopUpRequestModel.fromJson(Map<String, dynamic> json) {
    return TopUpRequestModel(
      id: json['id'] as String,
      requestedBy: json['requested_by'] as String,
      businessHubId: json['business_hub_id'] as String?,
      loadingStationId: json['loading_station_id'] as String?,
      requestedAmount: (json['requested_amount'] as num).toDouble(),
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      processedAt: json['processed_at'] != null
          ? DateTime.parse(json['processed_at'] as String)
          : null,
      processedBy: json['processed_by'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
      bonusRate: (json['bonus_rate'] as num?)?.toDouble(),
      bonusAmount: (json['bonus_amount'] as num?)?.toDouble(),
      totalCredited: (json['total_credited'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'requested_by': requestedBy,
      'business_hub_id': businessHubId,
      'loading_station_id': loadingStationId,
      'requested_amount': requestedAmount,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'processed_at': processedAt?.toIso8601String(),
      'processed_by': processedBy,
      'rejection_reason': rejectionReason,
      'bonus_rate': bonusRate,
      'bonus_amount': bonusAmount,
      'total_credited': totalCredited,
    };
  }

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
}

