import '../models/notification_model.dart';
import 'supabase_service.dart';

class NotificationService {
  final _supabase = SupabaseService.instance;

  Future<List<NotificationModel>> getNotifications({
    required String riderId,
    bool? isRead,
  }) async {
    try {
      var query = _supabase
          .from('notifications')
          .select()
          .eq('rider_id', riderId);

      if (isRead != null) {
        query = query.eq('is_read', isRead);
      }

      final response = await query.order('created_at', ascending: false);
      return (response as List)
          .map((json) => NotificationModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to get notifications: $e');
    }
  }

  Future<int> getUnreadCount(String riderId) async {
    try {
      final response = await _supabase
          .from('notifications')
          .select('id')
          .eq('rider_id', riderId)
          .eq('is_read', false);

      return (response as List).length;
    } catch (e) {
      return 0;
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (e) {
      throw Exception('Failed to mark notification as read: $e');
    }
  }

  Future<void> markAllAsRead(String riderId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('rider_id', riderId)
          .eq('is_read', false);
    } catch (e) {
      throw Exception('Failed to mark all notifications as read: $e');
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .delete()
          .eq('id', notificationId);
    } catch (e) {
      throw Exception('Failed to delete notification: $e');
    }
  }
}

