import '../models/rider_model.dart';
import 'supabase_service.dart';

class RiderService {
  final _supabase = SupabaseService.instance;

  Future<bool> isUserActive(String userId) async {
    try {
      final response = await _supabase
          .from('users')
          .select('access_status, is_active')
          .eq('id', userId)
          .single();
      
      final access = response['access_status'] as String?;
      if (access != null) {
        return access.toLowerCase() == 'approved';
      }
      return response['is_active'] as bool? ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<RiderModel> updateRiderStatus(
    String riderId,
    String status, {
    double? latitude,
    double? longitude,
    String? address,
  }) async {
    try {
      final isActive = await isUserActive(riderId);
      if (!isActive) {
        throw Exception('Your account is pending admin approval. You cannot change your status until your account is approved.');
      }

      // Check balance requirement when setting status to "available"
      if (status == 'available') {
        const double minimumBalance = 20.0;
        final riderResponse = await _supabase
            .from('riders')
            .select('balance')
            .eq('id', riderId)
            .single();
        
        final balance = (riderResponse['balance'] as num?)?.toDouble() ?? 0.0;
        if (balance < minimumBalance) {
          throw Exception('You need at least ₱${minimumBalance.toStringAsFixed(2)} in your balance to go Available. Your current balance is ₱${balance.toStringAsFixed(2)}.');
        }
      }

      final updateData = <String, dynamic>{
        'status': status,
        'last_active': DateTime.now().toIso8601String(),
      };

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

