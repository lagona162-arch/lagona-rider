import '../models/delivery_model.dart';
import 'supabase_service.dart';
import 'location_service.dart';
import '../constants/app_constants.dart';



class DeliveryService {
  final _supabase = SupabaseService.instance;
  final _locationService = LocationService();



  Future<List<DeliveryModel>> getDeliveries({
    String? riderId,
    String? status,
    String? loadingStationId,
    bool filterRiderTypes = false, // If true, only return pabili and padala
  }) async {
    try {
      var query = _supabase.from('deliveries').select();

      if (riderId != null) {
        query = query.eq('rider_id', riderId);
      }
      if (loadingStationId != null) {
        query = query.eq('loading_station_id', loadingStationId);
      }
      if (status != null) {
        query = query.eq('status', status);
      }

      // Filter to only food (pabili) and parcel (padala) types for riders
      if (filterRiderTypes) {
        query = query.inFilter('type', [
          AppConstants.deliveryTypeFood,
          AppConstants.deliveryTypeParcel,
        ]);
      }

      final response = await query.order('created_at', ascending: false);
      return (response as List)
          .map((json) => DeliveryModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to get deliveries: $e');
    }
  }




  Future<List<DeliveryModel>> getDeliveriesWithinRadius({
    required double riderLatitude,
    required double riderLongitude,
    required double radiusKm,
    String? loadingStationId,
    String? status,
  }) async {
    try {
      final locationService = LocationService();


      var query = _supabase.from('deliveries').select();

      if (loadingStationId != null) {
        query = query.eq('loading_station_id', loadingStationId);
      }
      if (status != null) {
        query = query.eq('status', status);
      }

      // Filter to only food (pabili) and parcel (padala) types for riders
      query = query.inFilter('type', [
        AppConstants.deliveryTypeFood,
        AppConstants.deliveryTypeParcel,
      ]);

      final response = await query.order('created_at', ascending: false);
      final allDeliveries = (response as List)
          .map((json) => DeliveryModel.fromJson(json as Map<String, dynamic>))
          .toList();


      final nearbyDeliveries = allDeliveries.where((delivery) {

        if (delivery.pickupLatitude == null || delivery.pickupLongitude == null) {
          return false;
        }


        final distance = locationService.calculateDistance(
          riderLatitude,
          riderLongitude,
          delivery.pickupLatitude!,
          delivery.pickupLongitude!,
        );


        return distance <= radiusKm;
      }).toList();

      return nearbyDeliveries;
    } catch (e) {
      throw Exception('Failed to get deliveries within radius: $e');
    }
  }


  Future<DeliveryModel?> getDeliveryById(String deliveryId) async {
    try {
      final response = await _supabase
          .from('deliveries')
          .select()
          .eq('id', deliveryId)
          .maybeSingle();
      
      if (response == null) {
        return null;
      }
      
      return DeliveryModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to get delivery: $e');
    }
  }

  Future<DeliveryModel> updateDeliveryStatus(
    String deliveryId,
    String status, {
    String? pickupPhotoUrl,
    String? dropoffPhotoUrl,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'status': status,
      };


      if (pickupPhotoUrl != null) {
        updateData['pickup_photo_url'] = pickupPhotoUrl;
      }
      if (dropoffPhotoUrl != null) {
        updateData['dropoff_photo_url'] = dropoffPhotoUrl;
      }

      final response = await _supabase
          .from('deliveries')
          .update(updateData)
          .eq('id', deliveryId)
          .select()
          .single();

      return DeliveryModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update delivery status: $e');
    }
  }


  Future<bool> hasActiveDelivery(String riderId) async {
    try {
      final activeStatuses = [
        AppConstants.deliveryStatusPending,
        AppConstants.deliveryStatusAccepted,
        AppConstants.deliveryStatusPrepared,
        AppConstants.deliveryStatusReady,
        AppConstants.deliveryStatusPickedUp,
        AppConstants.deliveryStatusInTransit,
      ];

      final response = await _supabase
          .from('deliveries')
          .select('id')
          .eq('rider_id', riderId)
          .inFilter('status', activeStatuses)
          .limit(1)
          .maybeSingle();

      return response != null;
    } catch (e) {

      return true;
    }
  }


  Future<DeliveryModel?> getActiveDelivery(String riderId) async {
    try {
      final activeStatuses = [
        AppConstants.deliveryStatusPending,
        AppConstants.deliveryStatusAccepted,
        AppConstants.deliveryStatusPrepared,
        AppConstants.deliveryStatusReady,
        AppConstants.deliveryStatusPickedUp,
        AppConstants.deliveryStatusInTransit,
      ];

      final response = await _supabase
          .from('deliveries')
          .select()
          .eq('rider_id', riderId)
          .inFilter('status', activeStatuses)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return DeliveryModel.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  Future<DeliveryModel> assignRider(String deliveryId, String riderId) async {
    try {
      // First, get the delivery to check its type
      final delivery = await getDeliveryById(deliveryId);
      if (delivery == null) {
        throw Exception('Delivery not found');
      }

      // Validate delivery type - riders can only accept food (pabili) or parcel (padala)
      if (delivery.type != AppConstants.deliveryTypeFood &&
          delivery.type != AppConstants.deliveryTypeParcel) {
        throw Exception(
            'Riders can only be assigned to Pabili (food) or Padala (parcel) deliveries. This delivery type is not supported.');
      }

      final hasActive = await hasActiveDelivery(riderId);
      if (hasActive) {
        throw Exception(
            'You already have an active delivery. Please complete your current delivery before accepting a new one.');
      }

      final response = await _supabase
          .from('deliveries')
          .update({
            'rider_id': riderId,
            'status': AppConstants.deliveryStatusAccepted,
          })
          .eq('id', deliveryId)
          .select()
          .single();

      return DeliveryModel.fromJson(response);
    } catch (e) {
      if (e.toString().contains('already have an active delivery') ||
          e.toString().contains('can only be assigned to')) {
        rethrow;
      }
      throw Exception('Failed to assign rider: $e');
    }
  }

  /// Calculates delivery fee based on distance between merchant (pickup) and buyer (dropoff) locations
  /// 
  /// Fee structure:
  /// - Base fee: ₱20.00 for first 2 km
  /// - Additional fee: ₱5.00 per km after 2 km
  /// - Minimum fee: ₱20.00
  /// 
  /// Example:
  /// - 1 km: ₱20.00
  /// - 3 km: ₱20.00 + (1 km × ₱5.00) = ₱25.00
  /// - 5 km: ₱20.00 + (3 km × ₱5.00) = ₱35.00
  double calculateDeliveryFee({
    required double? pickupLatitude,
    required double? pickupLongitude,
    required double? dropoffLatitude,
    required double? dropoffLongitude,
  }) {
    // Validate coordinates
    if (pickupLatitude == null ||
        pickupLongitude == null ||
        dropoffLatitude == null ||
        dropoffLongitude == null) {
      throw Exception('Pickup and dropoff coordinates are required to calculate delivery fee');
    }

    final locationService = LocationService();
    
    // Calculate distance in kilometers
    final distanceKm = locationService.calculateDistance(
      pickupLatitude,
      pickupLongitude,
      dropoffLatitude,
      dropoffLongitude,
    );

    // Fee calculation
    const double baseFee = 20.0; // Base fee for first 2 km
    const double baseDistanceKm = 2.0; // Base distance covered by base fee
    const double additionalFeePerKm = 5.0; // Additional fee per km after base distance

    if (distanceKm <= baseDistanceKm) {
      // Within base distance, charge base fee
      return baseFee;
    } else {
      // Beyond base distance, charge base fee + additional fee
      final additionalKm = distanceKm - baseDistanceKm;
      final additionalFee = additionalKm * additionalFeePerKm;
      return baseFee + additionalFee;
    }
  }

  /// Calculates and updates delivery fee and distance for a delivery
  Future<DeliveryModel> calculateAndUpdateDeliveryFee(String deliveryId) async {
    try {
      final delivery = await getDeliveryById(deliveryId);
      if (delivery == null) {
        throw Exception('Delivery not found');
      }

      // Calculate distance and fee
      final distanceKm = delivery.pickupLatitude != null &&
              delivery.pickupLongitude != null &&
              delivery.dropoffLatitude != null &&
              delivery.dropoffLongitude != null
          ? _locationService.calculateDistance(
              delivery.pickupLatitude!,
              delivery.pickupLongitude!,
              delivery.dropoffLatitude!,
              delivery.dropoffLongitude!,
            )
          : null;

      final deliveryFee = delivery.pickupLatitude != null &&
              delivery.pickupLongitude != null &&
              delivery.dropoffLatitude != null &&
              delivery.dropoffLongitude != null
          ? calculateDeliveryFee(
              pickupLatitude: delivery.pickupLatitude,
              pickupLongitude: delivery.pickupLongitude,
              dropoffLatitude: delivery.dropoffLatitude,
              dropoffLongitude: delivery.dropoffLongitude,
            )
          : null;

      // Update delivery with calculated distance and fee
      final updateData = <String, dynamic>{};
      if (distanceKm != null) {
        updateData['distance_km'] = distanceKm;
      }
      if (deliveryFee != null) {
        updateData['delivery_fee'] = deliveryFee;
      }

      if (updateData.isEmpty) {
        return delivery; // No updates needed
      }

      final response = await _supabase
          .from('deliveries')
          .update(updateData)
          .eq('id', deliveryId)
          .select()
          .single();

      return DeliveryModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to calculate and update delivery fee: $e');
    }
  }
}

