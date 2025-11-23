import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/models/delivery_model.dart';
import '../../core/services/delivery_service.dart';
import '../../core/services/rider_service.dart';
import '../../core/services/location_service.dart';
import '../../core/services/google_maps_service.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_colors.dart';

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
  DeliveryModel? _delivery;
  bool _isLoading = true;
  bool _isUpdating = false;
  GoogleMapController? _mapController;
  Position? _currentPosition;

  Timer? _locationUpdateTimer;

  @override
  void initState() {
    super.initState();
    _loadDelivery();
    _getCurrentLocation();
    // Update location every 10 seconds to refresh ETA
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
        });
      }
    } catch (e) {
      // Silently fail - location not critical for viewing
    }
  }

  /// Calculate ETA to pickup location
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

  /// Calculate ETA to dropoff location
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
      
      // Handle auto-assignment: if riderId is set but status is pending, auto-mark as accepted
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (delivery != null && 
          authProvider.user != null &&
          delivery.riderId == authProvider.user!.id &&
          delivery.status == AppConstants.deliveryStatusPending) {
        // Auto-accept the delivery
        try {
          await _deliveryService.updateDeliveryStatus(
            widget.deliveryId,
            AppConstants.deliveryStatusAccepted,
          );
          // Update rider status to busy
          final riderService = RiderService();
          await riderService.updateRiderStatus(
            authProvider.user!.id,
            AppConstants.riderStatusBusy,
          );
          // Reload delivery with updated status
          final updatedDelivery = await _deliveryService.getDeliveryById(widget.deliveryId);
          if (mounted) {
            setState(() {
              _delivery = updatedDelivery;
              _isLoading = false;
            });
          }
          return;
        } catch (e) {
          // If auto-accept fails, continue with original delivery
        }
      }
      
      if (mounted) {
      setState(() {
        _delivery = delivery;
        _isLoading = false;
      });
      }
    } catch (e) {
      if (mounted) {
      setState(() {
        _isLoading = false;
      });
      }
    }
  }

  Future<void> _updateStatus(String status) async {
    if (_isUpdating) return;
    
    setState(() {
      _isUpdating = true;
    });

    try {
      await _deliveryService.updateDeliveryStatus(widget.deliveryId, status);
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
    final statuses = [
      AppConstants.deliveryStatusPending,
      AppConstants.deliveryStatusAccepted,
      AppConstants.deliveryStatusPickedUp,
      AppConstants.deliveryStatusInTransit,
      AppConstants.deliveryStatusCompleted,
    ];

    final currentIndex = statuses.indexOf(_delivery!.status);
    
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
            const SizedBox(height: 20),
            ...statuses.asMap().entries.map((entry) {
              final index = entry.key;
              final status = entry.value;
              final isCompleted = currentIndex > index;
              final isCurrent = currentIndex == index;
              final isPending = currentIndex < index;

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    // Status indicator
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
                    // Status text
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
      // Navigation from current location to destination
      url = 'https://www.google.com/maps/dir/?api=1&destination=$destinationLat,$destinationLng&destination_place_id=${destinationLabel ?? ''}';
    } else {
      // Just show destination if current location not available
      url = 'https://www.google.com/maps/search/?api=1&query=$destinationLat,$destinationLng';
    }

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
  }

  Set<Marker> _buildMapMarkers() {
    final markers = <Marker>{};
    
    // Pickup marker (green)
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
    
    // Dropoff marker (red)
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
    
    // Current location marker (blue, if available)
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
    // If we have both pickup and dropoff, center between them
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
    
    // Otherwise, use pickup or dropoff
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
    
    // Default to Manila
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
                        // Delivery Header Card
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
                                        _delivery!.type == AppConstants.deliveryTypePabili
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
                                      _delivery!.type == AppConstants.deliveryTypePabili
                                          ? 'Pabili Delivery'
                                          : 'Padala Delivery',
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
                                      Icon(Icons.attach_money, size: 18, color: Colors.grey[700]),
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
                        // Status Stepper
                        _buildStatusStepper(),
                      const SizedBox(height: 16),
                        // Pickup Location Card
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
                                  // ETA to Pickup (only show if not picked up yet and we have current location)
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
                        // Dropoff Location Card
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
                                  // ETA to Dropoff (only show if picked up and we have current location)
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
                        // Action Buttons Section
                        Consumer<AuthProvider>(
                          builder: (context, authProvider, _) {
                            if (authProvider.user == null) {
                              return const SizedBox.shrink();
                            }

                            // Check if this delivery is assigned to current rider
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
                                    
                                    // Accept Delivery (for pending deliveries not assigned to anyone)
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
                                          
                                          return _buildActionButton(
                                            label: 'Accept Delivery',
                                            onPressed: () => _acceptDelivery(),
                                            color: AppColors.statusAccepted,
                                            icon: Icons.check_circle,
                                            isPrimary: true,
                                          );
                                        },
                                      ),
                                    // Accept Delivery (if assigned to me but status is still pending - fallback)
                                    if (isAssignedToMe &&
                                        _delivery!.status == AppConstants.deliveryStatusPending)
                                      _buildActionButton(
                                        label: 'Accept Delivery',
                                        onPressed: () => _updateStatus(AppConstants.deliveryStatusAccepted),
                                        color: AppColors.statusAccepted,
                                        icon: Icons.check_circle,
                                        isPrimary: true,
                                      ),
                                    // Mark as Picked Up (for accepted/ready/prepared - only if assigned to me)
                                    if (isAssignedToMe &&
                                        (_delivery!.status == AppConstants.deliveryStatusAccepted ||
                                         _delivery!.status == AppConstants.deliveryStatusReady ||
                                         _delivery!.status == AppConstants.deliveryStatusPrepared))
                                      _buildActionButton(
                                        label: 'Mark as Picked Up',
                                        onPressed: () => _updateStatus(AppConstants.deliveryStatusPickedUp),
                                        color: Colors.blue,
                                        icon: Icons.inventory_2,
                                        isPrimary: true,
                                      ),
                                    // Start Delivery / In Transit (for picked up - only if assigned to me)
                                    if (isAssignedToMe &&
                                        _delivery!.status == AppConstants.deliveryStatusPickedUp)
                                      _buildActionButton(
                                        label: 'Start Delivery (In Transit)',
                                        onPressed: () => _updateStatus(AppConstants.deliveryStatusInTransit),
                                        color: Colors.orange,
                                        icon: Icons.directions_car,
                                        isPrimary: true,
                                      ),
                                    // Show loading indicator (non-blocking, shows alongside buttons)
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
                                    // Show message if delivery is assigned to someone else
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
                                    // Show message if delivery is completed or cancelled
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
                        // Map View Card
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
                                // Google Maps Widget
                                if (_delivery!.pickupLatitude != null &&
                                    _delivery!.pickupLongitude != null &&
                                    _delivery!.dropoffLatitude != null &&
                                    _delivery!.dropoffLongitude != null)
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
                                // Navigation Buttons
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

      // Check if rider already has an active delivery
      final hasActive = await _deliveryService.hasActiveDelivery(authProvider.user!.id);
      return !hasActive;
    } catch (e) {
      return false;
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

      // Check if user is active before allowing delivery acceptance
      if (authProvider.user?.isActive != true) {
        throw Exception(
            'Your account is pending admin approval. You cannot accept deliveries until your account is approved.');
      }

      // Check if rider already has an active delivery
      final hasActive = await _deliveryService.hasActiveDelivery(authProvider.user!.id);
      if (hasActive) {
        final activeDelivery = await _deliveryService.getActiveDelivery(authProvider.user!.id);
        throw Exception(
            'You already have an active delivery (${activeDelivery?.id.substring(0, 8).toUpperCase() ?? "Unknown"}). Please complete it before accepting a new one.');
      }

      await _deliveryService.assignRider(widget.deliveryId, authProvider.user!.id);
      
      // Update rider status to busy
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
