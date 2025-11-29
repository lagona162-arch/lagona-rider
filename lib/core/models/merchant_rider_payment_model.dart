class MerchantRiderPaymentModel {
  final String id;
  final String deliveryId;
  final String merchantId;
  final String riderId;
  final double amount;
  final String riderGcashNumber;
  final String? referenceNumber;
  final String? senderName;
  final String? proofPhotoUrl;
  final String status;
  final DateTime createdAt;
  final DateTime? updatedAt;

  MerchantRiderPaymentModel({
    required this.id,
    required this.deliveryId,
    required this.merchantId,
    required this.riderId,
    required this.amount,
    required this.riderGcashNumber,
    this.referenceNumber,
    this.senderName,
    this.proofPhotoUrl,
    required this.status,
    required this.createdAt,
    this.updatedAt,
  });

  factory MerchantRiderPaymentModel.fromJson(Map<String, dynamic> json) {
    return MerchantRiderPaymentModel(
      id: json['id'] as String,
      deliveryId: json['delivery_id'] as String,
      merchantId: json['merchant_id'] as String,
      riderId: json['rider_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      riderGcashNumber: json['rider_gcash_number'] as String,
      referenceNumber: json['reference_number'] as String?,
      senderName: json['sender_name'] as String?,
      proofPhotoUrl: json['proof_photo_url'] as String?,
      status: json['status'] as String? ?? 'pending_confirmation',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'delivery_id': deliveryId,
      'merchant_id': merchantId,
      'rider_id': riderId,
      'amount': amount,
      'rider_gcash_number': riderGcashNumber,
      'reference_number': referenceNumber,
      'sender_name': senderName,
      'proof_photo_url': proofPhotoUrl,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  bool get isPending => status == 'pending_confirmation';
  bool get isConfirmed => status == 'confirmed';
  bool get isRejected => status == 'rejected';
}

