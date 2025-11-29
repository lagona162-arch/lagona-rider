import '../models/delivery_model.dart';
import 'supabase_service.dart';
import 'location_service.dart';
import '../constants/app_constants.dart';



class DeliveryService {
  final _supabase = SupabaseService.instance;



  Future<List<DeliveryModel>> getDeliveries({
    String? riderId,
    String? status,
    String? loadingStationId,
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

      if (e.toString().contains('already have an active delivery')) {
        rethrow;
      }
      throw Exception('Failed to assign rider: $e');
    }
  }
}

