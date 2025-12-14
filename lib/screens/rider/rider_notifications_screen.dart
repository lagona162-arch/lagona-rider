import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/models/notification_model.dart';
import '../../core/models/merchant_rider_payment_model.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/merchant_rider_payment_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/error_dialog.dart';
import '../delivery/delivery_detail_screen.dart';

class RiderNotificationsScreen extends StatefulWidget {
  const RiderNotificationsScreen({super.key});

  @override
  State<RiderNotificationsScreen> createState() => _RiderNotificationsScreenState();
}

class _RiderNotificationsScreenState extends State<RiderNotificationsScreen>
    with WidgetsBindingObserver {
  final NotificationService _notificationService = NotificationService();
  final MerchantRiderPaymentService _paymentService = MerchantRiderPaymentService();
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  bool _isScreenVisible = true;
  RealtimeChannel? _notificationsChannel;
  Map<String, bool> _processingPayments = {};
  Map<String, MerchantRiderPaymentModel?> _paymentCache = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadNotifications();
    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationsChannel?.unsubscribe();
    super.dispose();
  }

  void _setupRealtimeSubscription() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user == null) return;

    final supabase = SupabaseService.instance;
    _notificationsChannel?.unsubscribe();

    _notificationsChannel = supabase
        .channel('notifications_${authProvider.user!.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'rider_id',
            value: authProvider.user!.id,
          ),
          callback: (payload) {
            if (mounted && _isScreenVisible) {
              _loadNotifications();
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'rider_id',
            value: authProvider.user!.id,
          ),
          callback: (payload) {
            if (mounted && _isScreenVisible) {
              _loadNotifications();
            }
          },
        )
        .subscribe();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _isScreenVisible = false;
    } else if (state == AppLifecycleState.resumed) {
      _isScreenVisible = true;
      _loadNotifications();
    }
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.user == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final notifications = await _notificationService.getNotifications(
        riderId: authProvider.user!.id,
      );

      // Load payment status only for payment confirmation notifications
      for (final notification in notifications) {
        if (_isPaymentConfirmationNotification(notification) && notification.deliveryId != null) {
          try {
            final payment = await _paymentService.getPaymentByRiderIdAndDeliveryId(
              riderId: authProvider.user!.id,
              deliveryId: notification.deliveryId!,
            );
            _paymentCache[notification.id] = payment;
          } catch (e) {
            // Ignore errors when loading payment status
            _paymentCache[notification.id] = null;
          }
        }
      }

      if (mounted) {
        setState(() {
          _notifications = notifications;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _markAsRead(NotificationModel notification) async {
    if (notification.isRead) return;

    try {
      await _notificationService.markAsRead(notification.id);
      if (mounted) {
        setState(() {
          final index = _notifications.indexWhere((n) => n.id == notification.id);
          if (index != -1) {
            _notifications[index] = NotificationModel(
              id: notification.id,
              riderId: notification.riderId,
              deliveryId: notification.deliveryId,
              title: notification.title,
              message: notification.message,
              type: notification.type,
              isRead: true,
              createdAt: notification.createdAt,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ErrorDialog.show(context, message: e);
      }
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.user == null) return;

      await _notificationService.markAllAsRead(authProvider.user!.id);
      await _loadNotifications();
    } catch (e) {
      if (mounted) {
        ErrorDialog.show(context, message: e);
      }
    }
  }

  bool _isPaymentNotification(NotificationModel notification) {
    return notification.title.toLowerCase().contains('payment') ||
        notification.type == 'payment_received';
  }

  bool _isPaymentConfirmationNotification(NotificationModel notification) {
    // Only show buttons for "Payment Received - Please Confirm" notifications
    final titleLower = notification.title.toLowerCase();
    return (titleLower.contains('payment received') && 
            titleLower.contains('please confirm')) ||
           notification.type == 'payment_received';
  }

  Future<void> _confirmPayment(NotificationModel notification) async {
    if (notification.deliveryId == null) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user == null) return;

    setState(() {
      _processingPayments[notification.id] = true;
    });

    try {
      // Get the payment by delivery ID - use cached version if available to avoid race conditions
      MerchantRiderPaymentModel? payment = _paymentCache[notification.id];
      
      if (payment == null) {
        payment = await _paymentService.getPaymentByRiderIdAndDeliveryId(
          riderId: authProvider.user!.id,
          deliveryId: notification.deliveryId!,
        );
      }

      if (payment == null) {
        throw Exception('Payment not found');
      }

      // Double-check that payment is still pending before confirming
      if (!payment.isPending) {
        // Payment was already processed, update cache and return
        _paymentCache[notification.id] = payment;
        if (mounted) {
          setState(() {});
        }
        return;
      }

      // Confirm ONLY this specific payment
      final confirmedPayment = await _paymentService.confirmPayment(
        paymentId: payment.id,
        riderId: authProvider.user!.id,
      );

      // Update payment cache ONLY for this specific notification
      _paymentCache[notification.id] = confirmedPayment;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment confirmed successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        // Reload notifications to update the UI
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ErrorDialog.show(
          context,
          message: e,
          title: 'Payment Confirmation Error',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _processingPayments[notification.id] = false;
        });
      }
    }
  }

  Future<void> _rejectPayment(NotificationModel notification) async {
    if (notification.deliveryId == null) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user == null) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Payment'),
        content: const Text('Are you sure you want to reject this payment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _processingPayments[notification.id] = true;
    });

    try {
      // Get the payment by delivery ID - use cached version if available to avoid race conditions
      MerchantRiderPaymentModel? payment = _paymentCache[notification.id];
      
      if (payment == null) {
        payment = await _paymentService.getPaymentByRiderIdAndDeliveryId(
          riderId: authProvider.user!.id,
          deliveryId: notification.deliveryId!,
        );
      }

      if (payment == null) {
        throw Exception('Payment not found');
      }

      // Double-check that payment is still pending before rejecting
      if (!payment.isPending) {
        // Payment was already processed, update cache and return
        _paymentCache[notification.id] = payment;
        if (mounted) {
          setState(() {});
        }
        return;
      }

      // Reject ONLY this specific payment
      final rejectedPayment = await _paymentService.rejectPayment(
        paymentId: payment.id,
        riderId: authProvider.user!.id,
      );

      // Update payment cache ONLY for this specific notification
      _paymentCache[notification.id] = rejectedPayment;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment rejected'),
            backgroundColor: AppColors.error,
          ),
        );
        // Reload notifications to update the UI
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ErrorDialog.show(
          context,
          message: e,
          title: 'Payment Rejection Error',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _processingPayments[notification.id] = false;
        });
      }
    }
  }

  void _handleNotificationTap(NotificationModel notification) {
    // Don't navigate if it's a payment confirmation notification with pending confirmation
    if (_isPaymentConfirmationNotification(notification) && notification.deliveryId != null) {
      final payment = _paymentCache[notification.id];
      // Only block navigation if payment is pending
      if (payment != null && payment.isPending) {
        return;
      }
    }

    _markAsRead(notification);

    if (notification.deliveryId != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DeliveryDetailScreen(
            deliveryId: notification.deliveryId!,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (_notifications.any((n) => !n.isRead))
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text('Mark all as read'),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_none,
                        size: 64,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No notifications',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final notification = _notifications[index];
                      final isPayment = _isPaymentNotification(notification);
                      final isConfirmationNotification = _isPaymentConfirmationNotification(notification);
                      final isProcessing = _processingPayments[notification.id] ?? false;
                      final payment = _paymentCache[notification.id];
                      final showPaymentButtons = isConfirmationNotification && 
                          notification.deliveryId != null && 
                          payment != null && 
                          payment.isPending;
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        elevation: notification.isRead ? 1 : 3,
                        color: notification.isRead
                            ? null
                            : AppColors.primary.withOpacity(0.05),
                        child: Column(
                          children: [
                            ListTile(
                              leading: CircleAvatar(
                                backgroundColor: notification.isRead
                                    ? AppColors.textSecondary
                                    : AppColors.primary,
                                child: Icon(
                                  notification.type == 'delivery_ready'
                                      ? Icons.restaurant
                                      : isPayment
                                          ? Icons.payment
                                          : Icons.notifications,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(
                                notification.title,
                                style: TextStyle(
                                  fontWeight: notification.isRead
                                      ? FontWeight.normal
                                      : FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(notification.message),
                                  if (isConfirmationNotification && payment != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        payment.isConfirmed
                                            ? 'Payment confirmed'
                                            : payment.isRejected
                                                ? 'Payment rejected'
                                                : 'Awaiting your confirmation',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: payment.isConfirmed
                                              ? AppColors.success
                                              : payment.isRejected
                                                  ? AppColors.error
                                                  : AppColors.statusPending,
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatDate(notification.createdAt),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: notification.isRead && !isPayment
                                  ? null
                                  : isPayment && !showPaymentButtons
                                      ? null
                                      : !isPayment
                                          ? Container(
                                              width: 8,
                                              height: 8,
                                              decoration: const BoxDecoration(
                                                color: AppColors.primary,
                                                shape: BoxShape.circle,
                                              ),
                                            )
                                          : null,
                              onTap: isPayment && showPaymentButtons 
                                  ? null 
                                  : () => _handleNotificationTap(notification),
                            ),
                            if (showPaymentButtons)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton(
                                      onPressed: isProcessing
                                          ? null
                                          : () => _rejectPayment(notification),
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppColors.error,
                                      ),
                                      child: const Text('Reject'),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: isProcessing
                                          ? null
                                          : () => _confirmPayment(notification),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.success,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: isProcessing
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                              ),
                                            )
                                          : const Text('Confirm'),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final dateLocal = date.isUtc ? date.toLocal() : date;
    final difference = now.difference(dateLocal);

    if (difference.isNegative) {
      return 'Just now';
    }

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateLocal.day}/${dateLocal.month}/${dateLocal.year}';
    }
  }
}

