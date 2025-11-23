import '../models/topup_model.dart';
import 'supabase_service.dart';

/// Top-up service for riders
/// Handles top-up requests from riders to their Loading Station
class TopUpService {
  final _supabase = SupabaseService.instance;

  /// Create a top-up request for a rider
  /// The top-up will be pending approval from the Loading Station
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

      // Note: Balance update should be handled by the Loading Station after approval
      // This creates a top-up request that needs to be approved

      return TopUpModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create top-up request: $e');
    }
  }

  /// Get top-up requests for a rider
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

