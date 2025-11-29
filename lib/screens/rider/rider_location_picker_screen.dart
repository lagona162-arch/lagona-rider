import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/google_maps_service.dart';
import '../../core/services/rider_service.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/models/rider_model.dart';




class RiderLocationPickerScreen extends StatefulWidget {
  final RiderModel? currentRider;

  const RiderLocationPickerScreen({
    super.key,
    this.currentRider,
  });

  @override
  State<RiderLocationPickerScreen> createState() => _RiderLocationPickerScreenState();
}

class _RiderLocationPickerScreenState extends State<RiderLocationPickerScreen> {
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  String? _selectedAddress;
  bool _isUpdating = false;
  final GoogleMapsService _mapsService = GoogleMapsService();
  final RiderService _riderService = RiderService();

  @override
  void initState() {
    super.initState();

    if (widget.currentRider?.latitude != null &&
        widget.currentRider?.longitude != null) {
      _selectedLocation = LatLng(
        widget.currentRider!.latitude!,
        widget.currentRider!.longitude!,
      );
      _selectedAddress = widget.currentRider!.currentAddress;
    }
  }

  Set<Marker> get _markers {
    if (_selectedLocation == null) return {};
    
    return {
      GoogleMapsService.createMarker(
        markerId: 'rider_location',
        position: _selectedLocation!,
        title: 'Your Location',
        snippet: _selectedAddress ?? 'Selected location',
      ),
    };
  }

  CameraPosition get _initialCameraPosition {
    if (_selectedLocation != null) {
      return GoogleMapsService.createCameraPosition(
        target: _selectedLocation!,
        zoom: 15.0,
      );
    }
    

    return GoogleMapsService.createCameraPosition(
      target: const LatLng(14.5995, 120.9842), 
      zoom: 12.0,
    );
  }

  Future<void> _onMapTap(LatLng position) async {
    setState(() {
      _selectedLocation = position;
      _selectedAddress = null; 
    });


    try {
      final address = await _mapsService.getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );
      
      if (mounted) {
        setState(() {
          _selectedAddress = address;
        });
      }
    } catch (e) {

      debugPrint('Failed to get address: $e');
    }


    if (_mapController != null) {
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(position, 15.0),
      );
    }
  }

  Future<void> _saveLocation() async {
    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a location on the map'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('User not authenticated'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {

      await _riderService.updateRiderLocation(
        authProvider.user!.id,
        _selectedLocation!.latitude,
        _selectedLocation!.longitude,
        _selectedAddress,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Location updated successfully'),
          backgroundColor: AppColors.success,
        ),
      );


      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update location: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Update Location'),
      ),
      body: Stack(
        children: [

          GoogleMap(
            initialCameraPosition: _initialCameraPosition,
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
            },
            onTap: _onMapTap,
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            mapType: MapType.normal,
            zoomControlsEnabled: true,
          ),

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [

                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Selected Location',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  if (_selectedLocation != null) ...[
                    Text(
                      'Latitude: ${_selectedLocation!.latitude.toStringAsFixed(6)}',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    Text(
                      'Longitude: ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    if (_selectedAddress != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Address:',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        _selectedAddress!,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ] else ...[
                    Text(
                      'Tap on the map to select your location',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isUpdating || _selectedLocation == null
                        ? null
                        : _saveLocation,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppColors.primary,
                    ),
                    child: _isUpdating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Save Location',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

