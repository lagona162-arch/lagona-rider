import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/models/delivery_model.dart';
import '../../core/models/merchant_rider_payment_model.dart';
import '../../core/models/user_model.dart';
import '../../core/services/delivery_service.dart';
import '../../core/services/rider_service.dart';
import '../../core/services/location_service.dart';
import '../../core/services/google_maps_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/merchant_rider_payment_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/providers/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_colors.dart';
import 'delivery_in_transit_screen.dart';

class DeliveryDetailScreen extends StatefulWidget {
  final String deliveryId;

  const DeliveryDetailScreen({
    super.key,
    required this.deliveryId,
  });

  @override
  State<DeliveryDetailScreen> createState() => _DeliveryDetailScreenState();
}

class _DeliveryDetailScreenState extends State<DeliveryDetailScreen> {
  final DeliveryService _deliveryService = DeliveryService();
  final LocationService _locationService = LocationService();
  final GoogleMapsService _mapsService = GoogleMapsService();
  final StorageService _storageService = StorageService();
  final MerchantRiderPaymentService _paymentService = MerchantRiderPaymentService();
  final ImagePicker _imagePicker = ImagePicker();
  final SupabaseClient _supabase = SupabaseService.instance;
  DeliveryModel? _delivery;
  MerchantRiderPaymentModel? _payment;
  UserModel? _senderUser;
  UserModel? _recipientUser;
  bool _isLoading = true;
  bool _isUpdating = false;
  bool _isLoadingPayment = false;
  bool _isLoadingUserDetails = false;
  GoogleMapController? _mapController;
  Position? _currentPosition;

  Timer? _locationUpdateTimer;

  @override
  void initState() {
    super.initState();
    _loadDelivery();
    _getCurrentLocation();

    _locationUpdateTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _getCurrentLocation(),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _locationUpdateTimer?.cancel();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await _locationService.getCurrentPosition();
      if (mounted) {
        setState(() {
          _currentPosition = position;
          // Trigger rebuild to update proximity status for completion button
        });
      }
    } catch (e) {
      // Silently handle location errors
    }
  }


  Duration? _calculateETAToPickup() {
    if (_currentPosition == null ||
        _delivery?.pickupLatitude == null ||
        _delivery?.pickupLongitude == null) {
      return null;
    }

    final distance = _locationService.calculateDistance(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      _delivery!.pickupLatitude!,
      _delivery!.pickupLongitude!,
    );

    return _locationService.calculateETA(distance);
  }


  Duration? _calculateETAToDropoff() {
    if (_currentPosition == null ||
        _delivery?.dropoffLatitude == null ||
        _delivery?.dropoffLongitude == null) {
      return null;
    }

    final distance = _locationService.calculateDistance(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      _delivery!.dropoffLatitude!,
      _delivery!.dropoffLongitude!,
    );

    return _locationService.calculateETA(distance);
  }

  Future<void> _loadDelivery() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final delivery = await _deliveryService.getDeliveryById(widget.deliveryId);
      

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (delivery != null && 
          authProvider.user != null &&
          delivery.riderId == authProvider.user!.id &&
          delivery.status == AppConstants.deliveryStatusPending) {

        try {
          await _deliveryService.updateDeliveryStatus(
            widget.deliveryId,
            AppConstants.deliveryStatusAccepted,
          );

          final riderService = RiderService();
          await riderService.updateRiderStatus(
            authProvider.user!.id,
            AppConstants.riderStatusBusy,
          );

          final updatedDelivery = await _deliveryService.getDeliveryById(widget.deliveryId);
          if (mounted) {
            setState(() {
              _delivery = updatedDelivery;
              _isLoading = false;
            });
          }
          return;
        } catch (e) {

        }
      }
      
      if (mounted) {
      setState(() {
        _delivery = delivery;
        _isLoading = false;
      });
        
        if (delivery != null) {
          _loadPayment();
          _loadSenderAndRecipientDetails();
        }
      }
    } catch (e) {
      if (mounted) {
      setState(() {
        _isLoading = false;
      });
      }
    }
  }

  Future<void> _loadPayment() async {
    if (_delivery == null) return;
    
    setState(() {
      _isLoadingPayment = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.user == null) return;

      final payment = await _paymentService.getPaymentByRiderIdAndDeliveryId(
        riderId: authProvider.user!.id,
        deliveryId: widget.deliveryId,
      );

      if (mounted) {
        setState(() {
          _payment = payment;
          _isLoadingPayment = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingPayment = false;
        });
      }
    }
  }

  Future<void> _loadSenderAndRecipientDetails() async {
    if (_delivery == null) return;
    
    setState(() {
      _isLoadingUserDetails = true;
    });

    try {
      // For Padala deliveries, sender is typically the customer (pickup) and recipient is at dropoff
      // Load sender (customer) details if available
      if (_delivery!.customerId != null) {
        try {
          final senderResponse = await _supabase
              .from('users')
              .select()
              .eq('id', _delivery!.customerId!)
              .maybeSingle();
          
          if (senderResponse != null) {
            _senderUser = UserModel.fromJson(senderResponse as Map<String, dynamic>);
          }
        } catch (e) {
          // Ignore errors for sender
        }
      }

      // For Padala (parcel), recipient might be stored differently or we might need to check merchant
      // For now, if there's a merchant, they might be the sender, and customer is recipient
      if (_delivery!.merchantId != null && _delivery!.type == AppConstants.deliveryTypeParcel) {
        try {
          final recipientResponse = await _supabase
              .from('users')
              .select()
              .eq('id', _delivery!.merchantId!)
              .maybeSingle();
          
          if (recipientResponse != null) {
            _recipientUser = UserModel.fromJson(recipientResponse as Map<String, dynamic>);
          }
        } catch (e) {
          // Ignore errors for recipient
        }
      }

      if (mounted) {
        setState(() {
          _isLoadingUserDetails = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingUserDetails = false;
        });
      }
    }
  }

  bool _isNearDropoffLocation() {
    if (_currentPosition == null ||
        _delivery?.dropoffLatitude == null ||
        _delivery?.dropoffLongitude == null) {
      return false;
    }

    final distance = _locationService.calculateDistance(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      _delivery!.dropoffLatitude!,
      _delivery!.dropoffLongitude!,
    );

    // Consider "near" if within 100 meters
    return distance <= 0.1; // 100 meters in kilometers
  }



  Future<File?> _showPhotoCaptureDialog(String title) async {
    return showDialog<File?>(
      context: context,
      barrierDismissible: false, 
      builder: (BuildContext context) {
        return PopScope(
          canPop: false, 
          child: AlertDialog(
            title: Row(
              children: [
                Icon(Icons.camera_alt, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(title)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Photo is required to proceed',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Please take or select a photo for verification',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          try {
                            final XFile? image = await _imagePicker.pickImage(
                              source: ImageSource.camera,
                              maxWidth: 1920,
                              maxHeight: 1080,
                              imageQuality: 85,
                            );
                            if (image != null && mounted) {
                              Navigator.of(context).pop(File(image.path));
                            } else if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please take a photo to continue'),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error taking photo: $e'),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Camera'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          try {
                            final XFile? image = await _imagePicker.pickImage(
                              source: ImageSource.gallery,
                              maxWidth: 1920,
                              maxHeight: 1080,
                              imageQuality: 85,
                            );
                            if (image != null && mounted) {
                              Navigator.of(context).pop(File(image.path));
                            } else if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please select a photo to continue'),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error picking photo: $e'),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Gallery'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

          ),
        );
      },
    );
  }

  Future<bool?> _showPaymentConfirmationDialog() async {
    if (_payment == null) return false;

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.payment, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text('Confirm Payment Receipt'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payment Details',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildPaymentDetailRow('Amount', '₱${_payment!.amount.toStringAsFixed(2)}'),
                      _buildPaymentDetailRow('GCash Number', _payment!.riderGcashNumber),
                      if (_payment!.referenceNumber != null)
                        _buildPaymentDetailRow('Reference Number', _payment!.referenceNumber!),
                      if (_payment!.senderName != null)
                        _buildPaymentDetailRow('Sender Name', _payment!.senderName!),
                    ],
                  ),
                ),
                if (_payment!.proofPhotoUrl != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Payment Proof',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: _payment!.proofPhotoUrl!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        height: 200,
                        color: Colors.grey[300],
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: 200,
                        color: Colors.grey[300],
                        child: const Icon(Icons.error),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Please verify that you have received the payment in your GCash account before confirming.',
                          style: TextStyle(
                            color: Colors.orange[900],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop(true);
                await _confirmPayment();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
              ),
              child: const Text('Confirm Received'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop(false);
                await _rejectPayment();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
              ),
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPaymentDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentStatusCard() {
    if (_payment == null) return const SizedBox.shrink();

    final isConfirmed = _payment!.isConfirmed;
    final isPending = _payment!.isPending;
    final isRejected = _payment!.isRejected;

    Color cardColor;
    Color borderColor;
    IconData icon;
    String statusText;
    String statusMessage;

    if (isConfirmed) {
      cardColor = AppColors.success.withValues(alpha: 0.1);
      borderColor = AppColors.success;
      icon = Icons.check_circle;
      statusText = 'Payment Confirmed';
      statusMessage = 'You have confirmed receipt of payment. You can now proceed to pick up the delivery.';
    } else if (isRejected) {
      cardColor = AppColors.error.withValues(alpha: 0.1);
      borderColor = AppColors.error;
      icon = Icons.cancel;
      statusText = 'Payment Rejected';
      statusMessage = 'Payment has been rejected. Please contact the merchant.';
    } else {
      cardColor = Colors.orange.withValues(alpha: 0.1);
      borderColor = Colors.orange;
      icon = Icons.payment;
      statusText = 'Payment Pending Confirmation';
      statusMessage = 'Please confirm that you have received payment of ₱${_payment!.amount.toStringAsFixed(2)} before proceeding.';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: borderColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusText,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: borderColor,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Amount: ₱${_payment!.amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            statusMessage,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          if (isPending) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showPaymentConfirmationDialog(),
                icon: const Icon(Icons.visibility, size: 18),
                label: const Text('View Payment Details'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmPayment() async {
    if (_payment == null) return;
    
    setState(() {
      _isUpdating = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.user == null) {
        throw Exception('User not authenticated');
      }

      await _paymentService.confirmPayment(
        paymentId: _payment!.id,
        riderId: authProvider.user!.id,
      );

      await _loadPayment();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Payment confirmed successfully'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error confirming payment: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  Future<void> _rejectPayment() async {
    if (_payment == null) return;

    setState(() {
      _isUpdating = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.user == null) {
        throw Exception('User not authenticated');
      }

      await _paymentService.rejectPayment(
        paymentId: _payment!.id,
        riderId: authProvider.user!.id,
      );

      await _loadPayment();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Payment rejected'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error rejecting payment: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  Future<void> _updateStatus(String status, {String? pickupPhotoUrl, String? dropoffPhotoUrl, bool skipLoadingState = false}) async {
    if (!skipLoadingState && _isUpdating) return;
    
    if (!skipLoadingState) {
    setState(() {
      _isUpdating = true;
    });
    }

    try {
      await _deliveryService.updateDeliveryStatus(
        widget.deliveryId,
        status,
        pickupPhotoUrl: pickupPhotoUrl,
        dropoffPhotoUrl: dropoffPhotoUrl,
      );
      await _loadDelivery();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Status updated successfully'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (!skipLoadingState && mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  Future<void> _markAsPickedUp() async {
    if (_isUpdating) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user == null) return;

    if (_delivery?.merchantId != null) {
      await _loadPayment();
      
      if (_payment == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment confirmation required. Please wait for merchant to make payment.'),
              backgroundColor: AppColors.error,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      if (_payment!.isPending) {
        final confirmed = await _showPaymentConfirmationDialog();
        if (confirmed != true) {
          return;
        }
        await _loadPayment();
        
        if (_payment == null || !_payment!.isConfirmed) {
          return;
        }
      } else if (!_payment!.isConfirmed) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment must be confirmed before proceeding.'),
              backgroundColor: AppColors.error,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }
    }

    final photoFile = await _showPhotoCaptureDialog('Pickup Photo Required');
    if (photoFile == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo is required to mark as picked up'),
            backgroundColor: AppColors.error,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.user == null) {
        throw Exception('User not authenticated');
      }

      final photoUrl = await _storageService.uploadDeliveryPhoto(
        deliveryId: widget.deliveryId,
        imageFile: photoFile,
        photoType: 'pickup',
        riderId: authProvider.user!.id,
      );

      await _updateStatus(
        AppConstants.deliveryStatusPickedUp,
        pickupPhotoUrl: photoUrl,
        skipLoadingState: true,
      );

      await Future.delayed(const Duration(milliseconds: 500));

      await _updateStatus(
        AppConstants.deliveryStatusInTransit,
        skipLoadingState: true,
      );

      if (mounted) {
        await _loadDelivery();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Delivery marked as picked up and in transit'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  Future<void> _markAsCompleted() async {
    if (_isUpdating) return;


    final photoFile = await _showPhotoCaptureDialog('Dropoff Photo Required');
    if (photoFile == null) {


      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo is required to complete delivery'),
            backgroundColor: AppColors.error,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.user == null) {
        throw Exception('User not authenticated');
      }

      final photoUrl = await _storageService.uploadDeliveryPhoto(
        deliveryId: widget.deliveryId,
        imageFile: photoFile,
        photoType: 'dropoff',
        riderId: authProvider.user!.id,
      );


      await _updateStatus(
        AppConstants.deliveryStatusCompleted,
        dropoffPhotoUrl: photoUrl,
        skipLoadingState: true,
      );

      if (authProvider.user != null) {
        final riderService = RiderService();
        await riderService.updateRiderStatus(
          authProvider.user!.id,
          AppConstants.riderStatusAvailable,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case AppConstants.deliveryStatusPending:
        return AppColors.statusPending;
      case AppConstants.deliveryStatusAccepted:
        return AppColors.statusAccepted;
      case AppConstants.deliveryStatusPrepared:
        return AppColors.statusPrepared;
      case AppConstants.deliveryStatusReady:
        return AppColors.statusReady;
      case AppConstants.deliveryStatusPickedUp:
        return Colors.blue;
      case AppConstants.deliveryStatusInTransit:
        return Colors.orange;
      case AppConstants.deliveryStatusCompleted:
        return AppColors.statusCompleted;
      case AppConstants.deliveryStatusCancelled:
        return AppColors.statusCancelled;
      default:
        return AppColors.textSecondary;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case AppConstants.deliveryStatusPending:
        return 'Pending';
      case AppConstants.deliveryStatusAccepted:
        return 'Accepted';
      case AppConstants.deliveryStatusPrepared:
        return 'Prepared';
      case AppConstants.deliveryStatusReady:
        return 'Ready';
      case AppConstants.deliveryStatusPickedUp:
        return 'Picked Up';
      case AppConstants.deliveryStatusInTransit:
        return 'In Transit';
      case AppConstants.deliveryStatusCompleted:
        return 'Completed';
      case AppConstants.deliveryStatusCancelled:
        return 'Cancelled';
      default:
        return status;
    }
  }

  Widget _buildStatusStepper() {
    // Different status flows based on delivery type
    final List<String> statuses;
    final bool isPadala = _delivery!.type == AppConstants.deliveryTypeParcel;
    
    if (isPadala) {
      // Padala (Parcel) flow: picked_up → in_transit → completed
      statuses = [
        AppConstants.deliveryStatusPickedUp,
        AppConstants.deliveryStatusInTransit,
        AppConstants.deliveryStatusCompleted,
      ];
    } else {
      // Pabili (Food) flow: pending → accepted → prepared → ready → picked_up → in_transit → completed
      statuses = [
      AppConstants.deliveryStatusPending,
      AppConstants.deliveryStatusAccepted,
        AppConstants.deliveryStatusPrepared,
        AppConstants.deliveryStatusReady,
      AppConstants.deliveryStatusPickedUp,
      AppConstants.deliveryStatusInTransit,
      AppConstants.deliveryStatusCompleted,
    ];
    }

    final currentIndex = statuses.indexOf(_delivery!.status);
    final isValidStatus = currentIndex >= 0;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timeline, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text(
                  'Delivery Status',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (!isValidStatus) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.error.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.error, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Current Status: ${_getStatusLabel(_delivery!.status)}',
                        style: TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            ...statuses.asMap().entries.map((entry) {
              final index = entry.key;
              final status = entry.value;
              final isCompleted = isValidStatus && currentIndex > index;
              final isCurrent = isValidStatus && currentIndex == index;
              final isPending = isValidStatus && currentIndex < index;

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [

                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCompleted || isCurrent
                            ? _getStatusColor(status)
                            : Colors.grey[300],
                        border: Border.all(
                          color: isCurrent ? _getStatusColor(status) : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: isCompleted
                          ? const Icon(Icons.check, color: Colors.white, size: 20)
                          : isCurrent
                              ? Icon(
                                  Icons.radio_button_checked,
                                  color: Colors.white,
                                  size: 20,
                                )
                              : null,
                    ),
                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getStatusLabel(status),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                              color: isPending ? Colors.grey : Colors.black87,
                            ),
                          ),
                          if (isCurrent)
                            Text(
                              'Current status',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSenderRecipientSection() {
    if (_delivery!.type != AppConstants.deliveryTypeParcel) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.person,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Sender & Recipient Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoadingUserDetails)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else ...[
              // Sender Information
              if (_senderUser != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.send, color: Colors.blue[700], size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Sender',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[900],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildDetailRow('Name', _senderUser!.fullName),
                      if (_senderUser!.phone != null)
                        _buildDetailRow('Phone', _senderUser!.phone!),
                      if (_senderUser!.email.isNotEmpty)
                        _buildDetailRow('Email', _senderUser!.email),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              // Recipient Information - Always show for Padala
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.purple.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person_pin, color: Colors.purple[700], size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Recipient',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple[900],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_isLoadingUserDetails)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else if (_recipientUser != null) ...[
                      _buildDetailRow('Name', _recipientUser!.fullName),
                      if (_recipientUser!.phone != null)
                        _buildDetailRow('Phone', _recipientUser!.phone!),
                      if (_recipientUser!.email.isNotEmpty)
                        _buildDetailRow('Email', _recipientUser!.email),
                    ] else ...[
                      // Show dropoff address as recipient location
                      _buildDetailRow('Location', _delivery!.dropoffAddress ?? 'Address not provided'),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Contact recipient upon arrival at dropoff location',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required VoidCallback onPressed,
    required Color color,
    required IconData icon,
    bool isPrimary = false,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      child: ElevatedButton.icon(
        onPressed: _isUpdating ? null : onPressed,
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: isPrimary ? 4 : 2,
        ),
      ),
    );
  }

  Future<void> _openNavigation({
    required double? destinationLat,
    required double? destinationLng,
    String? destinationLabel,
  }) async {
    if (destinationLat == null || destinationLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Destination coordinates not available'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    String url;
    if (_currentPosition != null) {
      // Include origin (rider's current location) to preserve custom pin
      // Use proper URL encoding for coordinates
      final origin = '${_currentPosition!.latitude},${_currentPosition!.longitude}';
      final destination = '$destinationLat,$destinationLng';
      
      // Build URL with origin and destination
      url = 'https://www.google.com/maps/dir/?api=1'
          '&origin=$origin'
          '&destination=$destination';
      
      // Only add destination_place_id if it's a valid non-empty string
      if (destinationLabel != null && destinationLabel.trim().isNotEmpty) {
        // Note: destination_place_id should be a Google Place ID, not an address
        // If destinationLabel is an address, we'll skip this parameter
        // to avoid issues with invalid place IDs
      }
    } else {
      // If no current position, just search for the destination
      url = 'https://www.google.com/maps/search/?api=1&query=$destinationLat,$destinationLng';
    }

    try {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not open navigation'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening navigation: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Set<Marker> _buildMapMarkers() {
    final markers = <Marker>{};
    

    if (_delivery!.pickupLatitude != null && _delivery!.pickupLongitude != null) {
      markers.add(
        GoogleMapsService.createMarker(
          markerId: 'pickup',
          position: LatLng(_delivery!.pickupLatitude!, _delivery!.pickupLongitude!),
          title: 'Pickup Location',
          snippet: _delivery!.pickupAddress ?? 'Pickup point',
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      );
    }
    

    if (_delivery!.dropoffLatitude != null && _delivery!.dropoffLongitude != null) {
      markers.add(
        GoogleMapsService.createMarker(
          markerId: 'dropoff',
          position: LatLng(_delivery!.dropoffLatitude!, _delivery!.dropoffLongitude!),
          title: 'Dropoff Location',
          snippet: _delivery!.dropoffAddress ?? 'Dropoff point',
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }
    

    if (_currentPosition != null) {
      markers.add(
        GoogleMapsService.createMarker(
          markerId: 'current',
          position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          title: 'Your Location',
          snippet: 'Current position',
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }
    
    return markers;
  }

  CameraPosition _getInitialCameraPosition() {

    if (_delivery!.pickupLatitude != null &&
        _delivery!.pickupLongitude != null &&
        _delivery!.dropoffLatitude != null &&
        _delivery!.dropoffLongitude != null) {
      final centerLat = (_delivery!.pickupLatitude! + _delivery!.dropoffLatitude!) / 2;
      final centerLng = (_delivery!.pickupLongitude! + _delivery!.dropoffLongitude!) / 2;
      return GoogleMapsService.createCameraPosition(
        target: LatLng(centerLat, centerLng),
        zoom: 12.0,
      );
    }
    

    if (_delivery!.pickupLatitude != null && _delivery!.pickupLongitude != null) {
      return GoogleMapsService.createCameraPosition(
        target: LatLng(_delivery!.pickupLatitude!, _delivery!.pickupLongitude!),
        zoom: 14.0,
      );
    }
    
    if (_delivery!.dropoffLatitude != null && _delivery!.dropoffLongitude != null) {
      return GoogleMapsService.createCameraPosition(
        target: LatLng(_delivery!.dropoffLatitude!, _delivery!.dropoffLongitude!),
        zoom: 14.0,
      );
    }
    

    return GoogleMapsService.createCameraPosition(
      target: const LatLng(14.5995, 120.9842),
      zoom: 12.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Details'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _delivery == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'Delivery not found',
                        style: TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Go Back'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadDelivery,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        Card(
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primary.withOpacity(0.1),
                                  AppColors.primary.withOpacity(0.05),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                            'Delivery #${_delivery!.id.substring(0, 8).toUpperCase()}',
                                style: const TextStyle(
                                              fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                              letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _getStatusColor(_delivery!.status),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              _getStatusLabel(_delivery!.status).toUpperCase(),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        _delivery!.type == AppConstants.deliveryTypeFood
                                            ? Icons.shopping_bag
                                            : Icons.local_shipping,
                                        color: AppColors.primary,
                                        size: 28,
                                      ),
                                  ),
                                ],
                              ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Icon(Icons.category, size: 18, color: Colors.grey[700]),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${AppConstants.getDeliveryTypeDisplayLabel(_delivery!.type)} Delivery',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey[700],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                if (_delivery!.deliveryFee != null) ...[
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Icon(Icons.payments, size: 18, color: Colors.grey[700]),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Delivery Fee: ₱${_delivery!.deliveryFee!.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey[700],
                                          fontWeight: FontWeight.w500,
                          ),
                        ),
                                    ],
                                  ),
                                ],
                                if (_delivery!.distanceKm != null) ...[
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Icon(Icons.straighten, size: 18, color: Colors.grey[700]),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Distance: ${_delivery!.distanceKm!.toStringAsFixed(2)} km',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey[700],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        if (_delivery!.type == AppConstants.deliveryTypePadala)
                          _buildSenderRecipientSection(),
                        _buildStatusStepper(),
                      const SizedBox(height: 16),

                      Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        child: Padding(
                            padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.location_on,
                                        color: Colors.green,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                              const Text(
                                'Pickup Location',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _delivery!.pickupAddress ?? 'Address not available',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.grey[700],
                                    height: 1.5,
                                  ),
                                ),
                                if (_delivery!.pickupLatitude != null &&
                                    _delivery!.pickupLongitude != null) ...[
                              const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${_delivery!.pickupLatitude}, ${_delivery!.pickupLongitude}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.navigation, size: 20),
                                        color: Colors.green,
                                        onPressed: () => _openNavigation(
                                          destinationLat: _delivery!.pickupLatitude,
                                          destinationLng: _delivery!.pickupLongitude,
                                          destinationLabel: _delivery!.pickupAddress,
                                        ),
                                        tooltip: 'Navigate to pickup',
                                      ),
                                    ],
                                  ),

                                  if (_currentPosition != null &&
                                      _delivery!.status != AppConstants.deliveryStatusPickedUp &&
                                      _delivery!.status != AppConstants.deliveryStatusInTransit &&
                                      _delivery!.status != AppConstants.deliveryStatusCompleted) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.green.withOpacity(0.3),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.access_time,
                                            size: 16,
                                            color: Colors.green[700],
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'ETA: ${_locationService.formatETA(_calculateETAToPickup() ?? Duration.zero)}',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.green[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        child: Padding(
                            padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.location_on,
                                        color: Colors.red,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                              const Text(
                                'Dropoff Location',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                                const SizedBox(height: 12),
                                Text(
                                  _delivery!.dropoffAddress ?? 'Address not available',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.grey[700],
                                    height: 1.5,
                                  ),
                                ),
                                if (_delivery!.dropoffLatitude != null &&
                                    _delivery!.dropoffLongitude != null) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${_delivery!.dropoffLatitude}, ${_delivery!.dropoffLongitude}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.navigation, size: 20),
                                        color: Colors.red,
                                        onPressed: () => _openNavigation(
                                          destinationLat: _delivery!.dropoffLatitude,
                                          destinationLng: _delivery!.dropoffLongitude,
                                          destinationLabel: _delivery!.dropoffAddress,
                                        ),
                                        tooltip: 'Navigate to dropoff',
                                ),
                                    ],
                                  ),

                                  if (_currentPosition != null &&
                                      (_delivery!.status == AppConstants.deliveryStatusPickedUp ||
                                       _delivery!.status == AppConstants.deliveryStatusInTransit)) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.red.withOpacity(0.3),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.access_time,
                                            size: 16,
                                            color: Colors.red[700],
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'ETA: ${_locationService.formatETA(_calculateETAToDropoff() ?? Duration.zero)}',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.red[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        if (_delivery!.pickupPhotoUrl != null || _delivery!.dropoffPhotoUrl != null)
                          Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.photo_library, color: AppColors.primary),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Delivery Photos',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  if (_delivery!.pickupPhotoUrl != null) ...[
                                    const Text(
                                      'Pickup Photo',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) => _PhotoViewScreen(
                                              imageUrl: _delivery!.pickupPhotoUrl!,
                                              title: 'Pickup Photo',
                                            ),
                                          ),
                                        );
                                      },
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: CachedNetworkImage(
                                          imageUrl: _delivery!.pickupPhotoUrl!,
                                          width: double.infinity,
                                          height: 200,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) => Container(
                                            height: 200,
                                            color: Colors.grey[200],
                                            child: const Center(
                                              child: CircularProgressIndicator(),
                                            ),
                                          ),
                                          errorWidget: (context, url, error) => Container(
                                            height: 200,
                                            color: Colors.grey[200],
                                            child: const Icon(Icons.error),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                  if (_delivery!.dropoffPhotoUrl != null) ...[
                                    const Text(
                                      'Dropoff Photo',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) => _PhotoViewScreen(
                                              imageUrl: _delivery!.dropoffPhotoUrl!,
                                              title: 'Dropoff Photo',
                                            ),
                                          ),
                                        );
                                      },
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: CachedNetworkImage(
                                          imageUrl: _delivery!.dropoffPhotoUrl!,
                                          width: double.infinity,
                                          height: 200,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) => Container(
                                            height: 200,
                                            color: Colors.grey[200],
                                            child: const Center(
                                              child: CircularProgressIndicator(),
                                            ),
                                          ),
                                          errorWidget: (context, url, error) => Container(
                                            height: 200,
                                            color: Colors.grey[200],
                                            child: const Icon(Icons.error),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        Consumer<AuthProvider>(
                          builder: (context, authProvider, _) {
                            if (authProvider.user == null) {
                              return const SizedBox.shrink();
                            }


                            final isAssignedToMe = authProvider.user != null &&
                                _delivery!.riderId == authProvider.user!.id;

                            return Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.touch_app, color: AppColors.primary),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'Actions',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                                    ),
                        const SizedBox(height: 16),
                                    

                                    if (_delivery!.status == AppConstants.deliveryStatusPending &&
                                        _delivery!.riderId == null)
                                      FutureBuilder<bool>(
                                        future: _checkIfCanAccept(),
                                        builder: (context, snapshot) {
                                          if (snapshot.connectionState == ConnectionState.waiting) {
                                            return const Center(
                                              child: Padding(
                                                padding: EdgeInsets.all(16.0),
                                                child: CircularProgressIndicator(),
                                              ),
                                            );
                                          }
                                          
                                          final canAccept = snapshot.data ?? false;
                                          
                                          if (!canAccept) {
                                            return Container(
                                              padding: const EdgeInsets.all(16),
                                              decoration: BoxDecoration(
                                                color: Colors.orange.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: Colors.orange),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(Icons.info_outline, color: Colors.orange),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Text(
                                                      'You already have an active delivery. Complete it first to accept new deliveries.',
                                                      style: TextStyle(
                                                        color: Colors.orange[900],
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }
                                          
                                          // Different accept methods for Pabili vs Padala
                                          final isPadala = _delivery!.type == AppConstants.deliveryTypeParcel;
                                          
                                          return _buildActionButton(
                                            label: isPadala ? 'Accept Padala (with photo)' : 'Accept Delivery',
                                            onPressed: () => isPadala ? _acceptPadalaDelivery() : _acceptDelivery(),
                                            color: AppColors.statusAccepted,
                                            icon: isPadala ? Icons.photo_camera : Icons.check_circle,
                                            isPrimary: true,
                                          );
                                        },
                                      ),

                                    if (isAssignedToMe &&
                                        _delivery!.status == AppConstants.deliveryStatusPending)
                                      _buildActionButton(
                                        label: 'Accept Pabili',
                                        onPressed: () => _updateStatus(AppConstants.deliveryStatusAccepted),
                                        color: AppColors.statusAccepted,
                                        icon: Icons.check_circle,
                                        isPrimary: true,
                                      ),

                                    if (isAssignedToMe &&
                                        _delivery!.status == AppConstants.deliveryStatusReady) ...[
                                      if (_delivery!.merchantId != null) ...[
                                        if (_isLoadingPayment)
                                          const Padding(
                                            padding: EdgeInsets.all(16.0),
                                            child: Center(
                                              child: CircularProgressIndicator(),
                                            ),
                                          )
                                        else if (_payment != null)
                                          _buildPaymentStatusCard()
                                        else
                                          Container(
                                            padding: const EdgeInsets.all(16),
                                            margin: const EdgeInsets.only(bottom: 16),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: Colors.orange.withValues(alpha: 0.3),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(Icons.payment, color: Colors.orange),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        'Waiting for Payment',
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          color: Colors.orange[900],
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        'Please wait for the merchant to make payment before proceeding.',
                                                        style: TextStyle(
                                                          color: Colors.orange[900],
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                      _buildActionButton(
                                        label: _payment != null && !_payment!.isConfirmed
                                            ? 'Confirm Payment First'
                                            : 'Mark as Picked Up (Photo Required)',
                                        onPressed: (_payment == null || _payment!.isConfirmed)
                                            ? _markAsPickedUp
                                            : () {
                                                if (_payment!.isPending) {
                                                  _showPaymentConfirmationDialog();
                                                } else {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(
                                                      content: Text('Payment must be confirmed before proceeding.'),
                                                      backgroundColor: AppColors.error,
                                                    ),
                                                  );
                                                }
                                              },
                                        color: (_payment == null || _payment!.isConfirmed)
                                            ? Colors.blue
                                            : Colors.grey,
                                        icon: (_payment == null || _payment!.isConfirmed)
                                            ? Icons.camera_alt
                                            : Icons.payment,
                                        isPrimary: (_payment == null || _payment!.isConfirmed),
                                      ),
                                    ],

                                    if (isAssignedToMe &&
                                        _delivery!.status == AppConstants.deliveryStatusPickedUp) ...[
                                      // Navigation Mode Button
                                      Container(
                                        margin: const EdgeInsets.only(bottom: 12),
                                        child: ElevatedButton(
                                          onPressed: () async {
                                            await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => DeliveryInTransitScreen(
                                                  deliveryId: widget.deliveryId,
                                                ),
                                              ),
                                            );
                                            await _loadDelivery();
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.blue,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 20),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            elevation: 4,
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              const Icon(Icons.navigation, size: 28),
                                              const SizedBox(width: 12),
                                              const Text(
                                                'Open Navigation Mode',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      _buildActionButton(
                                        label: 'Start Delivery (In Transit)',
                                        onPressed: () => _updateStatus(AppConstants.deliveryStatusInTransit),
                                        color: Colors.orange,
                                        icon: Icons.directions_car,
                                        isPrimary: true,
                                      ),
                                    ],

                                    if (isAssignedToMe &&
                                        _delivery!.status == AppConstants.deliveryStatusInTransit) ...[
                                      // Navigation Mode Button - Primary Action
                                      Container(
                                        margin: const EdgeInsets.only(bottom: 12),
                                        child: ElevatedButton(
                                          onPressed: () async {
                                            await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => DeliveryInTransitScreen(
                                                  deliveryId: widget.deliveryId,
                                                ),
                                              ),
                                            );
                                            // Refresh when returning from navigation mode
                                            await _loadDelivery();
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.orange,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 20),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            elevation: 4,
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              const Icon(Icons.navigation, size: 28),
                                              const SizedBox(width: 12),
                                              const Text(
                                                'Open Navigation Mode',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      
                                      // Show proximity status
                                      if (_currentPosition != null &&
                                          _delivery!.dropoffLatitude != null &&
                                          _delivery!.dropoffLongitude != null) ...[
                                        Container(
                                          margin: const EdgeInsets.only(bottom: 12),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: _isNearDropoffLocation()
                                                ? Colors.green.withOpacity(0.1)
                                                : Colors.orange.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: _isNearDropoffLocation()
                                                  ? Colors.green.withOpacity(0.3)
                                                  : Colors.orange.withOpacity(0.3),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                _isNearDropoffLocation()
                                                    ? Icons.check_circle
                                                    : Icons.location_on,
                                                color: _isNearDropoffLocation()
                                                    ? Colors.green[700]
                                                    : Colors.orange[700],
                                                size: 20,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  _isNearDropoffLocation()
                                                      ? 'You are at the drop-off location. You can now confirm delivery.'
                                                      : 'Please proceed to the drop-off location to confirm delivery.',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: _isNearDropoffLocation()
                                                        ? Colors.green[700]
                                                        : Colors.orange[700],
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                      _buildActionButton(
                                        label: 'Confirm Delivery at Drop-off (Photo Required)',
                                        onPressed: _isNearDropoffLocation() || 
                                                  _delivery!.dropoffLatitude == null ||
                                                  _delivery!.dropoffLongitude == null
                                            ? _markAsCompleted
                                            : () {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: const Text(
                                                      'Please proceed to the drop-off location to confirm delivery.',
                                                    ),
                                                    backgroundColor: Colors.orange,
                                                    behavior: SnackBarBehavior.floating,
                                                  ),
                                                );
                                              },
                                        color: _isNearDropoffLocation() || 
                                               _delivery!.dropoffLatitude == null ||
                                               _delivery!.dropoffLongitude == null
                                            ? AppColors.statusCompleted
                                            : Colors.grey,
                                        icon: Icons.camera_alt,
                                        isPrimary: true,
                                      ),
                                    ],

                                    if (_isUpdating)
                                      Container(
                                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                                        child: const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                        SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'Updating...',
                                              style: TextStyle(fontSize: 12, color: Colors.grey),
                                            ),
                                          ],
                                        ),
                                      ),

                                    if (_delivery!.riderId != null && !isAssignedToMe)
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.blue),
                            ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.info_outline, color: Colors.blue),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                'This delivery is assigned to another rider.',
                                                style: TextStyle(
                                                  color: Colors.blue[900],
                                                  fontSize: 14,
                                                ),
                          ),
                        ),
                      ],
                                        ),
                                      ),

                                    if (_delivery!.status == AppConstants.deliveryStatusCompleted ||
                                        _delivery!.status == AppConstants.deliveryStatusCancelled)
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.grey),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              _delivery!.status == AppConstants.deliveryStatusCompleted
                                                  ? Icons.check_circle
                                                  : Icons.cancel,
                                              color: Colors.grey[700],
                        ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                _delivery!.status == AppConstants.deliveryStatusCompleted
                                                    ? 'This delivery has been completed.'
                                                    : 'This delivery has been cancelled.',
                                                style: TextStyle(
                                                  color: Colors.grey[800],
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                          ],
                          ),
                        ),
                      ],
                                ),
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 16),

                      Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        child: Padding(
                            padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                Row(
                                  children: [
                                    Icon(Icons.map, color: AppColors.primary),
                                    const SizedBox(width: 8),
                              const Text(
                                'Map View',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Hide map during active delivery - use navigation mode instead
                                if (_delivery!.pickupLatitude != null &&
                                    _delivery!.pickupLongitude != null &&
                                    _delivery!.dropoffLatitude != null &&
                                    _delivery!.dropoffLongitude != null &&
                                    _delivery!.status != AppConstants.deliveryStatusPickedUp &&
                                    _delivery!.status != AppConstants.deliveryStatusInTransit)
                                  Container(
                                    height: 300,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.grey[300]!),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: GoogleMap(
                                        initialCameraPosition: _getInitialCameraPosition(),
                                        markers: _buildMapMarkers(),
                                        myLocationEnabled: true,
                                        myLocationButtonEnabled: true,
                                        mapType: MapType.normal,
                                        zoomControlsEnabled: true,
                                        onMapCreated: (GoogleMapController controller) {
                                          _mapController = controller;
                                        },
                                      ),
                                    ),
                                  )
                                else
                              Container(
                                height: 200,
                                decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                          Icon(
                                            Icons.map_outlined,
                                            size: 64,
                                            color: Colors.grey[400],
                                          ),
                                          const SizedBox(height: 12),
                                      Text(
                                            'Location coordinates not available',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 16),

                                if (_delivery!.pickupLatitude != null &&
                                    _delivery!.pickupLongitude != null &&
                                    _delivery!.dropoffLatitude != null &&
                                    _delivery!.dropoffLongitude != null)
                                  Column(
                                    children: [
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton.icon(
                                          onPressed: () => _openNavigation(
                                            destinationLat: _delivery!.pickupLatitude,
                                            destinationLng: _delivery!.pickupLongitude,
                                            destinationLabel: _delivery!.pickupAddress,
                                          ),
                                          icon: const Icon(Icons.navigation, size: 20),
                                          label: const Text(
                                            'Navigate to Pickup',
                                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            foregroundColor: Colors.green,
                                            side: const BorderSide(color: Colors.green, width: 1.5),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton.icon(
                                          onPressed: () => _openNavigation(
                                            destinationLat: _delivery!.dropoffLatitude,
                                            destinationLng: _delivery!.dropoffLongitude,
                                            destinationLabel: _delivery!.dropoffAddress,
                                          ),
                                          icon: const Icon(Icons.navigation, size: 20),
                                          label: const Text(
                                            'Navigate to Dropoff',
                                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                ),
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            foregroundColor: Colors.red,
                                            side: const BorderSide(color: Colors.red, width: 1.5),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                              ),
                            ],
                          ),
                        ),
                      ),
                        const SizedBox(height: 32),
                    ],
                    ),
                  ),
                ),
    );
  }

  Future<bool> _checkIfCanAccept() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.user == null) {
        return false;
      }


      final hasActive = await _deliveryService.hasActiveDelivery(authProvider.user!.id);
      return !hasActive;
    } catch (e) {
      return false;
    }
  }

  Future<void> _acceptPadalaDelivery() async {
    if (_isUpdating) return;
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user == null) return;

    // Validate delivery type
    if (_delivery != null && _delivery!.type != AppConstants.deliveryTypeParcel) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This method is only for Padala deliveries'),
          backgroundColor: AppColors.error,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    if (authProvider.user?.isActive != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your account is pending admin approval'),
          backgroundColor: AppColors.error,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Check for active deliveries
    final hasActive = await _deliveryService.hasActiveDelivery(authProvider.user!.id);
    if (hasActive) {
      final activeDelivery = await _deliveryService.getActiveDelivery(authProvider.user!.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You already have an active delivery (${activeDelivery?.id.substring(0, 8).toUpperCase() ?? "Unknown"})'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    // Capture pickup photo
    final photoFile = await _showPhotoCaptureDialog('Pickup Photo Required');
    if (photoFile == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo is required to accept Padala delivery'),
            backgroundColor: AppColors.error,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      // Assign rider to delivery
      await _deliveryService.assignRider(widget.deliveryId, authProvider.user!.id);
      
      // Upload pickup photo
      final photoUrl = await _storageService.uploadDeliveryPhoto(
        deliveryId: widget.deliveryId,
        imageFile: photoFile,
        photoType: 'pickup',
        riderId: authProvider.user!.id,
      );

      // Update status to picked_up with pickup photo (Padala flow)
      await _updateStatus(
        AppConstants.deliveryStatusPickedUp,
        pickupPhotoUrl: photoUrl,
        skipLoadingState: true,
      );

      // Update rider status to busy
      final riderService = RiderService();
      await riderService.updateRiderStatus(
        authProvider.user!.id,
        AppConstants.riderStatusBusy,
      );

      await _loadDelivery();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Padala picked up successfully'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accepting Padala delivery: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  Future<void> _acceptDelivery() async {
    if (_isUpdating) return;
    
    setState(() {
      _isUpdating = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.user == null) {
        throw Exception('User not authenticated');
      }

      // Validate delivery type - riders can only accept food (pabili) or parcel (padala)
      if (_delivery != null) {
        if (_delivery!.type != AppConstants.deliveryTypeFood &&
            _delivery!.type != AppConstants.deliveryTypeParcel) {
          throw Exception(
              'Riders can only be assigned to Pabili (food) or Padala (parcel) deliveries. This delivery type is not supported.');
        }
      }

      if (authProvider.user?.isActive != true) {
        throw Exception(
            'Your account is pending admin approval. You cannot accept deliveries until your account is approved.');
      }


      final hasActive = await _deliveryService.hasActiveDelivery(authProvider.user!.id);
      if (hasActive) {
        final activeDelivery = await _deliveryService.getActiveDelivery(authProvider.user!.id);
        throw Exception(
            'You already have an active delivery (${activeDelivery?.id.substring(0, 8).toUpperCase() ?? "Unknown"}). Please complete it before accepting a new one.');
      }

      await _deliveryService.assignRider(widget.deliveryId, authProvider.user!.id);
      

      final riderService = RiderService();
      await riderService.updateRiderStatus(
        authProvider.user!.id,
        AppConstants.riderStatusBusy,
      );

      await _loadDelivery();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Delivery accepted successfully'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

}


class _PhotoViewScreen extends StatelessWidget {
  final String imageUrl;
  final String title;

  const _PhotoViewScreen({
    required this.imageUrl,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Center(
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.contain,
          placeholder: (context, url) => const CircularProgressIndicator(),
          errorWidget: (context, url, error) => const Icon(Icons.error),
        ),
      ),
    );
  }
}
