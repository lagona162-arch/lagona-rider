import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/delivery_model.dart';
import '../../core/services/delivery_service.dart';
import '../../core/services/location_service.dart';
import '../../core/services/google_maps_service.dart';

class DeliveryInTransitScreen extends StatefulWidget {
  final String deliveryId;

  const DeliveryInTransitScreen({
    super.key,
    required this.deliveryId,
  });

  @override
  State<DeliveryInTransitScreen> createState() => _DeliveryInTransitScreenState();
}

class _DeliveryInTransitScreenState extends State<DeliveryInTransitScreen> {
  final DeliveryService _deliveryService = DeliveryService();
  final LocationService _locationService = LocationService();
  
  DeliveryModel? _delivery;
  Position? _currentPosition;
  GoogleMapController? _mapController;
  Timer? _locationTimer;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDelivery();
    _startLocationUpdates();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadDelivery() async {
    try {
      final delivery = await _deliveryService.getDeliveryById(widget.deliveryId);
      setState(() {
        _delivery = delivery;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _startLocationUpdates() {
    _updateLocation();
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _updateLocation();
    });
  }

  Future<void> _updateLocation() async {
    try {
      final position = await _locationService.getCurrentPosition();
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
        
        // Update camera position to follow rider
        if (_mapController != null && position != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLng(
              LatLng(position.latitude, position.longitude),
            ),
          );
        }
      }
    } catch (e) {
      // Silently handle location errors
    }
  }

  Future<void> _openNavigation({
    required double? destinationLat,
    required double? destinationLng,
    String? destinationLabel,
  }) async {
    if (destinationLat == null || destinationLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Destination coordinates not available'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    String url;
    if (_currentPosition != null) {
      final origin = '${_currentPosition!.latitude},${_currentPosition!.longitude}';
      final destination = '$destinationLat,$destinationLng';
      url = 'https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$destination';
    } else {
      url = 'https://www.google.com/maps/search/?api=1&query=$destinationLat,$destinationLng';
    }

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening navigation: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Set<Marker> _buildMapMarkers() {
    final Set<Marker> markers = {};

    if (_delivery == null) return markers;

    // Add pickup marker
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

    // Add dropoff marker
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

    // Add current position marker
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
    if (_currentPosition != null) {
      return GoogleMapsService.createCameraPosition(
        target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        zoom: 15.0,
      );
    }

    if (_delivery?.pickupLatitude != null && _delivery?.pickupLongitude != null) {
      return GoogleMapsService.createCameraPosition(
        target: LatLng(_delivery!.pickupLatitude!, _delivery!.pickupLongitude!),
        zoom: 14.0,
      );
    }

    return GoogleMapsService.createCameraPosition(
      target: const LatLng(14.5995, 120.9842),
      zoom: 12.0,
    );
  }

  Widget _buildNavigationCard({
    required String title,
    required String subtitle,
    required Color color,
    required IconData icon,
    required VoidCallback onNavigate,
    String? distance,
    String? eta,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onNavigate,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                color.withOpacity(0.1),
                color.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.navigation, color: color, size: 32),
                ],
              ),
              if (distance != null || eta != null) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (distance != null) ...[
                      Icon(Icons.straighten, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        distance,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                    if (distance != null && eta != null) ...[
                      const SizedBox(width: 16),
                      Container(
                        width: 1,
                        height: 16,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(width: 16),
                    ],
                    if (eta != null) ...[
                      Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        'ETA: $eta',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String? _calculateDistance(double? lat, double? lng) {
    if (_currentPosition == null || lat == null || lng == null) return null;
    final distance = _locationService.calculateDistance(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      lat,
      lng,
    );
    return '${distance.toStringAsFixed(2)} km';
  }

  String? _calculateETA(double? lat, double? lng) {
    if (_currentPosition == null || lat == null || lng == null) return null;
    final distance = _locationService.calculateDistance(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      lat,
      lng,
    );
    final eta = _locationService.calculateETA(distance);
    return _locationService.formatETA(eta);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Navigation Mode'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null || _delivery == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Navigation Mode'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppColors.error),
              const SizedBox(height: 16),
              Text(
                _error ?? 'Delivery not found',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    // For Padala: picked_up status means they have the parcel, show dropoff only
    // For Pabili: picked_up means they got it from merchant, show both locations
    final bool isPadala = _delivery!.type == AppConstants.deliveryTypeParcel;
    final bool needsPickup = _delivery!.status != AppConstants.deliveryStatusPickedUp &&
        _delivery!.status != AppConstants.deliveryStatusInTransit &&
        _delivery!.status != AppConstants.deliveryStatusCompleted;
    
    final bool showBothLocations = !isPadala && (_delivery!.status == AppConstants.deliveryStatusPickedUp ||
        _delivery!.status == AppConstants.deliveryStatusInTransit);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Navigation Mode'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadDelivery();
              _updateLocation();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Status Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.primary.withOpacity(0.8),
                ],
              ),
            ),
            child: Column(
              children: [
                Text(
                  'Delivery #${_delivery!.id.substring(0, 8).toUpperCase()}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    AppConstants.getDeliveryTypeDisplayLabel(_delivery!.type),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Map View
          Expanded(
            flex: 3,
            child: GoogleMap(
              initialCameraPosition: _getInitialCameraPosition(),
              markers: _buildMapMarkers(),
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: true,
              mapType: MapType.normal,
              onMapCreated: (controller) {
                _mapController = controller;
              },
            ),
          ),

          // Navigation Options
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle indicator
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    Text(
                      needsPickup ? 'Navigate to Pickup' : showBothLocations ? 'Choose Destination' : 'Navigate to Drop-off',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Pickup Navigation Card (if not picked up yet or show both)
                    if (needsPickup || showBothLocations)
                      _buildNavigationCard(
                        title: 'Pickup Location',
                        subtitle: _delivery!.pickupAddress ?? 'Address not available',
                        color: Colors.green,
                        icon: Icons.store,
                        distance: _calculateDistance(
                          _delivery!.pickupLatitude,
                          _delivery!.pickupLongitude,
                        ),
                        eta: _calculateETA(
                          _delivery!.pickupLatitude,
                          _delivery!.pickupLongitude,
                        ),
                        onNavigate: () => _openNavigation(
                          destinationLat: _delivery!.pickupLatitude,
                          destinationLng: _delivery!.pickupLongitude,
                          destinationLabel: _delivery!.pickupAddress,
                        ),
                      ),

                    // Spacing between cards when showing both
                    if (showBothLocations) const SizedBox(height: 12),

                    // Dropoff Navigation Card
                    if (!needsPickup || showBothLocations)
                      _buildNavigationCard(
                        title: 'Drop-off Location',
                        subtitle: _delivery!.dropoffAddress ?? 'Address not available',
                        color: Colors.red,
                        icon: Icons.location_on,
                        distance: _calculateDistance(
                          _delivery!.dropoffLatitude,
                          _delivery!.dropoffLongitude,
                        ),
                        eta: _calculateETA(
                          _delivery!.dropoffLatitude,
                          _delivery!.dropoffLongitude,
                        ),
                        onNavigate: () => _openNavigation(
                          destinationLat: _delivery!.dropoffLatitude,
                          destinationLng: _delivery!.dropoffLongitude,
                          destinationLabel: _delivery!.dropoffAddress,
                        ),
                      ),

                    const SizedBox(height: 12),

                    // View Full Details Button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.info_outline),
                        label: const Text('View Full Delivery Details'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: AppColors.primary),
                          foregroundColor: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

