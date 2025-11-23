class BusinessHubModel {
  final String id;
  final String name;
  final String bhCode;
  final String? municipality;
  final double balance;
  final double bonusRate;
  final DateTime createdAt;

  BusinessHubModel({
    required this.id,
    required this.name,
    required this.bhCode,
    this.municipality,
    required this.balance,
    required this.bonusRate,
    required this.createdAt,
  });

  factory BusinessHubModel.fromJson(Map<String, dynamic> json) {
    return BusinessHubModel(
      id: json['id'] as String,
      name: json['name'] as String,
      bhCode: json['bh_code'] as String,
      municipality: json['municipality'] as String?,
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      bonusRate: (json['bonus_rate'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'bh_code': bhCode,
      'municipality': municipality,
      'balance': balance,
      'bonus_rate': bonusRate,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

