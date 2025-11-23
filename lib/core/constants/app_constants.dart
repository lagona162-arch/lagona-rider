class AppConstants {
  // User Roles
  static const String roleAdmin = 'admin';
  static const String roleBusinessHub = 'business_hub';
  static const String roleLoadingStation = 'loading_station';
  static const String roleMerchant = 'merchant';
  static const String roleRider = 'rider';
  static const String roleCustomer = 'customer';

  // Delivery Types
  static const String deliveryTypePabili = 'pabili';
  static const String deliveryTypePadala = 'padala';

  // Delivery Status
  static const String deliveryStatusPending = 'pending';
  static const String deliveryStatusAccepted = 'accepted';
  static const String deliveryStatusPrepared = 'prepared';
  static const String deliveryStatusReady = 'ready';
  static const String deliveryStatusPickedUp = 'picked_up';
  static const String deliveryStatusInTransit = 'in_transit';
  static const String deliveryStatusCompleted = 'completed';
  static const String deliveryStatusCancelled = 'cancelled';

  // Rider Status
  static const String riderStatusAvailable = 'available';
  static const String riderStatusBusy = 'busy';
  static const String riderStatusOffline = 'offline';

  // Access Status
  static const String accessStatusPending = 'pending';
  static const String accessStatusApproved = 'approved';
  static const String accessStatusRejected = 'rejected';
  static const String accessStatusSuspended = 'suspended';

  // Tag Relation Type
  static const String tagRelationNone = 'none';
  static const String tagRelationFavorite = 'favorite';
  static const String tagRelationBlocked = 'blocked';
}

