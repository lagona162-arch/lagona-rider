import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:math';

/// Location permission status
enum LocationPermissionStatus {
  granted,
  denied,
  deniedForever,
  serviceDisabled,
}

class LocationService {
  /// Check location permission status
  Future<LocationPermissionStatus> checkPermissionStatus() async {
    // Check if location services are enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationPermissionStatus.serviceDisabled;
    }

    // Check location permissions
    final permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.deniedForever) {
      return LocationPermissionStatus.deniedForever;
    }
    
    if (permission == LocationPermission.denied) {
      return LocationPermissionStatus.denied;
    }
    
    // Permission is granted (whileInUse or always)
    return LocationPermissionStatus.granted;
  }

  /// Request location permissions proactively
  /// Returns true if permission is granted, false otherwise
  Future<bool> requestPermission() async {
    // Check if location services are enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are disabled - user needs to enable them in settings
      return false;
    }

    // Check current permission status
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.deniedForever) {
      // Permission is permanently denied - user must enable in settings
      return false;
    }
    
    if (permission == LocationPermission.denied) {
      // Request permission
      permission = await Geolocator.requestPermission();
      
      if (permission == LocationPermission.denied || 
          permission == LocationPermission.deniedForever) {
        return false;
      }
    }
    
    // Permission is granted
    return true;
  }

  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Open location settings
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  /// Open app settings (for permission denied forever)
  Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }

  Future<Position> getCurrentPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    // Check location permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    // Get current position
    return await Geolocator.getCurrentPosition();
  }

  Future<String> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      List<Placemark> placemarks =
          await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        final place = placemarks[0];
        return '${place.street}, ${place.locality}, ${place.administrativeArea}';
      }
      return 'Unknown location';
    } catch (e) {
      return 'Unknown location';
    }
  }

  Future<Location> getCoordinatesFromAddress(String address) async {
    try {
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        return locations.first;
      }
      throw Exception('No coordinates found for address');
    } catch (e) {
      throw Exception('Failed to get coordinates: $e');
    }
  }

  double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000; // in km
  }

  /// Calculate estimated time of arrival (ETA) in minutes
  /// Based on distance and average speed
  /// Uses average speed of 30 km/h for city traffic (adjustable)
  Duration calculateETA(
    double distanceKm, {
    double averageSpeedKmh = 30.0, // Average speed in city traffic
  }) {
    if (distanceKm <= 0) {
      return Duration.zero;
    }
    
    // Calculate time in hours, then convert to minutes
    final hours = distanceKm / averageSpeedKmh;
    final minutes = (hours * 60).round();
    
    // Minimum 1 minute, maximum reasonable time
    return Duration(minutes: minutes.clamp(1, 180)); // Max 3 hours
  }

  /// Format ETA duration as a human-readable string
  String formatETA(Duration eta) {
    if (eta.inMinutes < 1) {
      return 'Less than 1 min';
    } else if (eta.inMinutes < 60) {
      return '${eta.inMinutes} min';
    } else {
      final hours = eta.inHours;
      final minutes = eta.inMinutes % 60;
      if (minutes == 0) {
        return '$hours ${hours == 1 ? 'hour' : 'hours'}';
      } else {
        return '$hours ${hours == 1 ? 'hour' : 'hours'} $minutes min';
      }
    }
  }

  /// Search address suggestions using forward geocoding.
  /// Returns a list of maps with keys: label, latitude, longitude.
  /// Note: This uses geocoding and may return approximate results.
  Future<List<Map<String, dynamic>>> searchAddressSuggestions(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      // Try to fetch multiple possible locations for the query
      final locations = await locationFromAddress(query);
      if (locations.isEmpty) return [];

      // Limit to first 5 results to keep UI responsive
      final top = locations.take(5).toList();
      final results = <Map<String, dynamic>>[];
      for (final loc in top) {
        final lat = loc.latitude;
        final lng = loc.longitude;
        String label = 'Unknown';
        try {
          final placemarks = await placemarkFromCoordinates(lat, lng);
          if (placemarks.isNotEmpty) {
            final p = placemarks.first;
            final parts = <String>[];
            if (p.street != null && p.street!.isNotEmpty) parts.add(p.street!);
            if (p.subLocality != null && p.subLocality!.isNotEmpty) parts.add(p.subLocality!);
            if (p.locality != null && p.locality!.isNotEmpty) parts.add(p.locality!);
            if (p.administrativeArea != null && p.administrativeArea!.isNotEmpty) {
              parts.add(p.administrativeArea!);
            }
            if (p.postalCode != null && p.postalCode!.isNotEmpty) parts.add(p.postalCode!);
            if (p.country != null && p.country!.isNotEmpty) parts.add(p.country!);
            label = parts.join(', ');
          }
        } catch (_) {
          // ignore reverse geocode failures
        }
        results.add({
          'label': label,
          'latitude': lat,
          'longitude': lng,
        });
      }
      // Deduplicate by label
      final seen = <String>{};
      return results.where((e) {
        final l = e['label'] as String;
        if (seen.contains(l)) return false;
        seen.add(l);
        return true;
      }).toList();
    } catch (e) {
      return [];
    }
  }
}

