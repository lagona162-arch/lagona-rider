import 'supabase_service.dart';



class RegistrationService {
  final _supabase = SupabaseService.instance;


  Future<bool> validateLSCode(String lsCode) async {
    try {
      final response = await _supabase
          .from('loading_stations')
          .select('id')
          .eq('ls_code', lsCode)
          .maybeSingle();
      return response != null;
    } catch (e) {
      return false;
    }
  }


  Future<String?> getLoadingStationIdByLSCode(String lsCode) async {
    try {
      final response = await _supabase
          .from('loading_stations')
          .select('id')
          .eq('ls_code', lsCode)
          .maybeSingle();
      return response?['id'] as String?;
    } catch (e) {
      return null;
    }
  }


  Future<void> linkRiderToLoadingStation(
    String riderId,
    String lsCode,
  ) async {
    try {
      final loadingStationId = await getLoadingStationIdByLSCode(lsCode);
      if (loadingStationId == null) {
        throw Exception('Invalid Loading Station Code');
      }

      await _supabase
          .from('riders')
          .update({'loading_station_id': loadingStationId})
          .eq('id', riderId);
    } catch (e) {
      throw Exception('Failed to link rider to loading station: $e');
    }
  }


  Future<void> updateRiderDetails(
    String riderId, {
    String? plateNumber,
    String? vehicleType,
    String? profilePictureUrl,
    String? driversLicenseUrl,
    String? officialReceiptUrl,
    String? certificateOfRegistrationUrl,
    String? vehicleFrontPictureUrl,
    String? vehicleSidePictureUrl,
    String? vehicleBackPictureUrl,
  }) async {
    try {
      final updateData = <String, dynamic>{};
      
      if (plateNumber != null) {
        updateData['plate_number'] = plateNumber;
      }
      if (vehicleType != null) {
        updateData['vehicle_type'] = vehicleType;
      }
      if (profilePictureUrl != null) {
        updateData['profile_picture_url'] = profilePictureUrl;
      }
      if (driversLicenseUrl != null) {
        updateData['drivers_license_url'] = driversLicenseUrl;
      }
      if (officialReceiptUrl != null) {
        updateData['official_receipt_url'] = officialReceiptUrl;
      }
      if (certificateOfRegistrationUrl != null) {
        updateData['certificate_of_registration_url'] = certificateOfRegistrationUrl;
      }
      if (vehicleFrontPictureUrl != null) {
        updateData['vehicle_front_picture_url'] = vehicleFrontPictureUrl;
      }
      if (vehicleSidePictureUrl != null) {
        updateData['vehicle_side_picture_url'] = vehicleSidePictureUrl;
      }
      if (vehicleBackPictureUrl != null) {
        updateData['vehicle_back_picture_url'] = vehicleBackPictureUrl;
      }

      if (updateData.isNotEmpty) {
        await _supabase
            .from('riders')
            .update(updateData)
            .eq('id', riderId);
      }
    } catch (e) {
      throw Exception('Failed to update rider details: $e');
    }
  }
}

