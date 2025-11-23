import '../models/rider_model.dart';
import 'supabase_service.dart';

/// Rider service for managing rider data and operations
class RiderService {
  final _supabase = SupabaseService.instance;

  /// Check if user is active (approved by admin)
  Future<bool> isUserActive(String userId) async {
    try {
      final response = await _supabase
          .from('users')
          .select('access_status, is_active')
          .eq('id', userId)
          .single();
      
      // Prefer access_status when present
      final access = response['access_status'] as String?;
      if (access != null) {
        return access.toLowerCase() == 'approved';
      }
      return response['is_active'] as bool? ?? false;
    } catch (e) {
      // If we can't check, assume inactive for safety
      return false;
    }
  }

  /// Update rider status and optionally update location
  /// If status is 'available', location should be provided to enable delivery detection
  /// Requires user to be active (is_active = true) before allowing status changes
  Future<RiderModel> updateRiderStatus(
    String riderId,
    String status, {
    double? latitude,
    double? longitude,
    String? address,
  }) async {
    try {
      // Check if user is active before allowing status change
      final isActive = await isUserActive(riderId);
      if (!isActive) {
        throw Exception('Your account is pending admin approval. You cannot change your status until your account is approved.');
      }

      final updateData = <String, dynamic>{
        'status': status,
        'last_active': DateTime.now().toIso8601String(),
      };

      // Update location if provided (usually when setting status to available)
      if (latitude != null && longitude != null) {
        updateData['latitude'] = latitude;
        updateData['longitude'] = longitude;
        if (address != null) {
          updateData['current_address'] = address;
        }
      }

      final response = await _supabase
          .from('riders')
          .update(updateData)
          .eq('id', riderId)
          .select()
          .single();

      return RiderModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update rider status: $e');
    }
  }

  Future<RiderModel> updateRiderLocation(
    String riderId,
    double latitude,
    double longitude,
    String? address,
  ) async {
    try {
      final response = await _supabase
          .from('riders')
          .update({
            'latitude': latitude,
            'longitude': longitude,
            'current_address': address,
            'last_active': DateTime.now().toIso8601String(),
          })
          .eq('id', riderId)
          .select()
          .single();

      return RiderModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update rider location: $e');
    }
  }

  Future<RiderModel> getRider(String riderId) async {
    try {
      // Explicitly select all required fields to ensure they're included in the response
      // Sometimes .select() without parameters might not return all fields due to RLS policies
      final response = await _supabase
          .from('riders')
          .select('id, loading_station_id, plate_number, vehicle_type, drivers_license_url, profile_picture_url, official_receipt_url, certificate_of_registration_url, vehicle_front_picture_url, vehicle_side_picture_url, vehicle_back_picture_url, balance, commission_rate, status, current_address, latitude, longitude, last_active, created_at')
          .eq('id', riderId)
          .single();
      
      return RiderModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to get rider: $e');
    }
  }
}

