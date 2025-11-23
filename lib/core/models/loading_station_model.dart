class LoadingStationModel {
  final String id;
  final String? businessHubId;
  final String name;
  final String lsCode;
  final String? address;
  final double balance;
  final double bonusRate;
  final DateTime createdAt;

  LoadingStationModel({
    required this.id,
    this.businessHubId,
    required this.name,
    required this.lsCode,
    this.address,
    required this.balance,
    required this.bonusRate,
    required this.createdAt,
  });

  factory LoadingStationModel.fromJson(Map<String, dynamic> json) {
    return LoadingStationModel(
      id: json['id'] as String,
      businessHubId: json['business_hub_id'] as String?,
      name: json['name'] as String,
      lsCode: json['ls_code'] as String,
      address: json['address'] as String?,
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      bonusRate: (json['bonus_rate'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_hub_id': businessHubId,
      'name': name,
      'ls_code': lsCode,
      'address': address,
      'balance': balance,
      'bonus_rate': bonusRate,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

