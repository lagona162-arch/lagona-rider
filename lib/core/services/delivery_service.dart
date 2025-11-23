import '../models/delivery_model.dart';
import 'supabase_service.dart';
import 'location_service.dart';
import '../constants/app_constants.dart';

/// Delivery service for riders
/// Handles delivery operations for riders (accepting, updating status, etc.)
class DeliveryService {
  final _supabase = SupabaseService.instance;

  /// Get deliveries for riders
  /// Riders can see deliveries assigned to them or available deliveries from their loading station
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

  /// Get deliveries within a radius (in km) from rider's location
  /// This filters deliveries client-side to avoid expensive database queries
  /// Returns deliveries within the specified radius from the rider's location
  Future<List<DeliveryModel>> getDeliveriesWithinRadius({
    required double riderLatitude,
    required double riderLongitude,
    required double radiusKm,
    String? loadingStationId,
    String? status,
  }) async {
    try {
      final locationService = LocationService();

      // Get all available deliveries (we'll filter by radius client-side)
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

      // Filter deliveries within radius
      final nearbyDeliveries = allDeliveries.where((delivery) {
        // Only include deliveries with pickup coordinates
        if (delivery.pickupLatitude == null || delivery.pickupLongitude == null) {
          return false;
        }

        // Calculate distance from rider to pickup location
        final distance = locationService.calculateDistance(
          riderLatitude,
          riderLongitude,
          delivery.pickupLatitude!,
          delivery.pickupLongitude!,
        );

        // Return deliveries within radius
        return distance <= radiusKm;
      }).toList();

      return nearbyDeliveries;
    } catch (e) {
      throw Exception('Failed to get deliveries within radius: $e');
    }
  }

  /// Get delivery by ID
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
    String status,
  ) async {
    try {
      final response = await _supabase
          .from('deliveries')
          .update({'status': status})
          .eq('id', deliveryId)
          .select()
          .single();

      return DeliveryModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update delivery status: $e');
    }
  }

  /// Check if rider has any active deliveries (not completed or cancelled)
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
      // If there's an error checking, assume they have an active delivery for safety
      return true;
    }
  }

  /// Get rider's active delivery (if any)
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
      // Check if rider already has an active delivery
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
      // Re-throw our custom exception
      if (e.toString().contains('already have an active delivery')) {
        rethrow;
      }
      throw Exception('Failed to assign rider: $e');
    }
  }
}

