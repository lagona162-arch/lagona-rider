import '../models/merchant_rider_payment_model.dart';
import 'supabase_service.dart';

class MerchantRiderPaymentService {
  final _supabase = SupabaseService.instance;

  Future<MerchantRiderPaymentModel?> getPaymentByDeliveryId(
    String deliveryId,
  ) async {
    try {
      final response = await _supabase
          .from('merchant_rider_payments')
          .select()
          .eq('delivery_id', deliveryId)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return MerchantRiderPaymentModel.fromJson(
        response as Map<String, dynamic>,
      );
    } catch (e) {
      throw Exception('Failed to get payment: $e');
    }
  }

  Future<MerchantRiderPaymentModel?> getPaymentByRiderIdAndDeliveryId({
    required String riderId,
    required String deliveryId,
  }) async {
    try {
      final response = await _supabase
          .from('merchant_rider_payments')
          .select()
          .eq('delivery_id', deliveryId)
          .eq('rider_id', riderId)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return MerchantRiderPaymentModel.fromJson(
        response as Map<String, dynamic>,
      );
    } catch (e) {
      throw Exception('Failed to get payment: $e');
    }
  }

  Future<MerchantRiderPaymentModel> confirmPayment({
    required String paymentId,
    required String riderId,
  }) async {
    try {
      // First, fetch the payment to get the amount
      final paymentResponse = await _supabase
          .from('merchant_rider_payments')
          .select()
          .eq('id', paymentId)
          .eq('rider_id', riderId)
          .single();

      if (paymentResponse == null) {
        throw Exception('Payment not found');
      }

      final payment = MerchantRiderPaymentModel.fromJson(
        paymentResponse as Map<String, dynamic>,
      );

      // Check if payment is already confirmed to avoid double crediting
      if (payment.isConfirmed) {
        return payment;
      }

      // Update payment status
      final response = await _supabase
          .from('merchant_rider_payments')
          .update({
            'status': 'confirmed',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', paymentId)
          .eq('rider_id', riderId)
          .select()
          .single();

      final confirmedPayment = MerchantRiderPaymentModel.fromJson(
        response as Map<String, dynamic>,
      );

      // Credit the rider's balance by adding the payment amount
      final riderResponse = await _supabase
          .from('riders')
          .select('balance')
          .eq('id', riderId)
          .single();

      final currentBalance = (riderResponse['balance'] as num?)?.toDouble() ?? 0.0;
      final newBalance = currentBalance + payment.amount;

      await _supabase
          .from('riders')
          .update({
            'balance': newBalance,
          })
          .eq('id', riderId);

      return confirmedPayment;
    } catch (e) {
      throw Exception('Failed to confirm payment: $e');
    }
  }

  Future<MerchantRiderPaymentModel> rejectPayment({
    required String paymentId,
    required String riderId,
  }) async {
    try {
      final response = await _supabase
          .from('merchant_rider_payments')
          .update({
            'status': 'rejected',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', paymentId)
          .eq('rider_id', riderId)
          .select()
          .single();

      return MerchantRiderPaymentModel.fromJson(
        response as Map<String, dynamic>,
      );
    } catch (e) {
      throw Exception('Failed to reject payment: $e');
    }
  }

  Future<bool> hasPendingPayment(String deliveryId) async {
    try {
      final response = await _supabase
          .from('merchant_rider_payments')
          .select('id')
          .eq('delivery_id', deliveryId)
          .eq('status', 'pending_confirmation')
          .maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }
}

