class AppConstants {

  static const String roleAdmin = 'admin';
  static const String roleBusinessHub = 'business_hub';
  static const String roleLoadingStation = 'loading_station';
  static const String roleMerchant = 'merchant';
  static const String roleRider = 'rider';
  static const String roleCustomer = 'customer';


  // Database uses 'food' and 'parcel', but rider app displays as 'pabili' and 'padala'
  static const String deliveryTypeFood = 'food';    // Displayed as 'Pabili' in rider app
  static const String deliveryTypeParcel = 'parcel'; // Displayed as 'Padala' in rider app
  
  // Helper methods to convert database types to display labels
  static String getDeliveryTypeDisplayLabel(String type) {
    switch (type) {
      case deliveryTypeFood:
        return 'Pabili';
      case deliveryTypeParcel:
        return 'Padala';
      default:
        return type;
    }
  }
  
  static String getDeliveryTypeDisplayLabelLowercase(String type) {
    switch (type) {
      case deliveryTypeFood:
        return 'pabili';
      case deliveryTypeParcel:
        return 'padala';
      default:
        return type;
    }
  }
  
  // Legacy constants for backward compatibility (now point to food/parcel)
  static const String deliveryTypePabili = deliveryTypeFood;    // Alias for food (display only)
  static const String deliveryTypePadala = deliveryTypeParcel;   // Alias for parcel (display only)


  static const String deliveryStatusPending = 'pending';
  static const String deliveryStatusAccepted = 'accepted';
  static const String deliveryStatusPrepared = 'prepared';
  static const String deliveryStatusReady = 'ready';
  static const String deliveryStatusPickedUp = 'picked_up';
  static const String deliveryStatusInTransit = 'in_transit';
  static const String deliveryStatusCompleted = 'completed';
  static const String deliveryStatusCancelled = 'cancelled';


  static const String riderStatusAvailable = 'available';
  static const String riderStatusBusy = 'busy';
  static const String riderStatusOffline = 'offline';


  static const String accessStatusPending = 'pending';
  static const String accessStatusApproved = 'approved';
  static const String accessStatusRejected = 'rejected';
  static const String accessStatusSuspended = 'suspended';


  static const String tagRelationNone = 'none';
  static const String tagRelationFavorite = 'favorite';
  static const String tagRelationBlocked = 'blocked';
}

