class NotificationModel {
  final String id;
  final String riderId;
  final String? deliveryId;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.riderId,
    this.deliveryId,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final createdAtString = json['created_at'] as String;
    DateTime createdAt;
    
    try {
      createdAt = DateTime.parse(createdAtString);
      if (createdAtString.endsWith('Z') || createdAtString.contains('+') || createdAtString.contains('-', 10)) {
        createdAt = createdAt.toLocal();
      }
    } catch (e) {
      createdAt = DateTime.now();
    }
    
    return NotificationModel(
      id: json['id'] as String,
      riderId: json['rider_id'] as String,
      deliveryId: json['delivery_id'] as String?,
      title: json['title'] as String,
      message: json['message'] as String,
      type: json['type'] as String,
      isRead: (json['is_read'] as bool?) ?? false,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'rider_id': riderId,
      'delivery_id': deliveryId,
      'title': title,
      'message': message,
      'type': type,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

