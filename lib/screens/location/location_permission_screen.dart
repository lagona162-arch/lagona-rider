import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/location_service.dart';

/// Screen to request location permission from the user
class LocationPermissionScreen extends StatefulWidget {
  final VoidCallback? onPermissionGranted;

  const LocationPermissionScreen({
    super.key,
    this.onPermissionGranted,
  });

  @override
  State<LocationPermissionScreen> createState() => _LocationPermissionScreenState();
}

class _LocationPermissionScreenState extends State<LocationPermissionScreen> {
  final LocationService _locationService = LocationService();
  bool _isRequesting = false;
  String? _errorMessage;

  Future<void> _requestPermission() async {
    setState(() {
      _isRequesting = true;
      _errorMessage = null;
    });

    try {
      // Check if location services are enabled
      final isServiceEnabled = await _locationService.isLocationServiceEnabled();
      
      if (!isServiceEnabled) {
        setState(() {
          _errorMessage = 'Location services are disabled. Please enable location services in your device settings.';
          _isRequesting = false;
        });
        return;
      }

      // Request permission
      final granted = await _locationService.requestPermission();
      
      if (!mounted) return;

      if (granted) {
        // Permission granted - verify it was actually granted
        final status = await _locationService.checkPermissionStatus();
        
        if (!mounted) return;
        
        if (status == LocationPermissionStatus.granted) {
          // Permission is verified - call callback immediately to update parent state
          // The callback will optimistically update state, preventing black screen
          if (widget.onPermissionGranted != null) {
            widget.onPermissionGranted!();
            // The parent AuthWrapper will rebuild and show RiderHomeScreen
            // Reset _isRequesting to false since we're done
            if (mounted) {
              setState(() {
                _isRequesting = false;
              });
            }
          }
        } else {
          // Verification failed - show error
          if (mounted) {
            setState(() {
              _errorMessage = 'Failed to verify location permission. Please try again.';
              _isRequesting = false;
            });
          }
        }
      } else {
        // Check the specific reason for denial
        final status = await _locationService.checkPermissionStatus();
        
        if (!mounted) return;
        
        if (status == LocationPermissionStatus.deniedForever) {
          setState(() {
            _errorMessage = 'Location permission is permanently denied. Please enable it in app settings.';
            _isRequesting = false;
          });
        } else {
          setState(() {
            _errorMessage = 'Location permission is required to use this app. Please grant location access.';
            _isRequesting = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to request location permission: $e';
          _isRequesting = false;
        });
      }
    }
  }

  Future<void> _openSettings() async {
    final status = await _locationService.checkPermissionStatus();
    
    if (status == LocationPermissionStatus.serviceDisabled) {
      await _locationService.openLocationSettings();
    } else if (status == LocationPermissionStatus.deniedForever) {
      await _locationService.openAppSettings();
    } else {
      await _locationService.openLocationSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Location Permission'),
        automaticallyImplyLeading: false, // Prevent back navigation
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Location icon
              Icon(
                Icons.location_on,
                size: 120,
                color: AppColors.primary,
              ),
              const SizedBox(height: 32),
              
              // Title
              Text(
                'Location Permission Required',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              // Description
              Text(
                'This app requires location access to track your delivery routes, show your current location on the map, and help you navigate to delivery destinations.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              
              // Additional info
              Text(
                'Your location data is used only for delivery purposes and is not shared with third parties.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              
              // Error message
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: AppColors.error,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: AppColors.error,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              
              // Request Permission Button
              ElevatedButton(
                onPressed: _isRequesting ? null : _requestPermission,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isRequesting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Grant Location Permission',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
              
              // Open Settings Button (if permission is denied)
              if (_errorMessage != null)
                const SizedBox(height: 12),
              if (_errorMessage != null)
                OutlinedButton(
                  onPressed: _openSettings,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    side: BorderSide(color: AppColors.primary),
                  ),
                  child: Text(
                    'Open Settings',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

