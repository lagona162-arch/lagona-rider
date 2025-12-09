import '../models/topup_model.dart';
import '../models/topup_request_model.dart';
import 'supabase_service.dart';



class TopUpService {
  final _supabase = SupabaseService.instance;

  /// Creates a top-up request in the topup_requests table
  /// This is used when riders request top-up from their Loading Station
  Future<TopUpRequestModel> createTopUpRequest({
    required String requestedBy,
    required String? loadingStationId,
    required double requestedAmount,
  }) async {
    try {
      final response = await _supabase.from('topup_requests').insert({
        'requested_by': requestedBy,
        'loading_station_id': loadingStationId,
        'requested_amount': requestedAmount,
        'status': 'pending',
      }).select().single();

      return TopUpRequestModel.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to create top-up request: $e');
    }
  }

  /// Creates a completed top-up transaction in the topups table
  /// This is typically used after a top-up request is approved
  Future<TopUpModel> createTopUp({
    required String initiatedBy,
    required String? loadingStationId,
    required String? riderId,
    required double amount,
    double? bonusAmount,
    double? totalCredited,
  }) async {
    try {
      final response = await _supabase.from('topups').insert({
        'initiated_by': initiatedBy,
        'loading_station_id': loadingStationId,
        'rider_id': riderId,
        'amount': amount,
        'bonus_amount': bonusAmount,
        'total_credited': totalCredited ?? (amount + (bonusAmount ?? 0)),
      }).select().single();

      return TopUpModel.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to create top-up: $e');
    }
  }


  Future<List<TopUpModel>> getTopUps({
    required String riderId,
  }) async {
    try {
      final response = await _supabase
          .from('topups')
          .select()
          .eq('rider_id', riderId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => TopUpModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to get top-ups: $e');
    }
  }

}

