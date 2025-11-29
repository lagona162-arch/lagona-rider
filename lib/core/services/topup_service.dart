import '../models/topup_model.dart';
import 'supabase_service.dart';



class TopUpService {
  final _supabase = SupabaseService.instance;



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




      return TopUpModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create top-up request: $e');
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

