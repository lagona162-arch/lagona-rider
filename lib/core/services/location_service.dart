import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:math';


enum LocationPermissionStatus {
  granted,
  denied,
  deniedForever,
  serviceDisabled,
}

class LocationService {

  Future<LocationPermissionStatus> checkPermissionStatus() async {

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationPermissionStatus.serviceDisabled;
    }


    final permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.deniedForever) {
      return LocationPermissionStatus.deniedForever;
    }
    
    if (permission == LocationPermission.denied) {
      return LocationPermissionStatus.denied;
    }
    

    return LocationPermissionStatus.granted;
  }



  Future<bool> requestPermission() async {

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {

      return false;
    }


    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.deniedForever) {

      return false;
    }
    
    if (permission == LocationPermission.denied) {

      permission = await Geolocator.requestPermission();
      
      if (permission == LocationPermission.denied || 
          permission == LocationPermission.deniedForever) {
        return false;
      }
    }
    

    return true;
  }


  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }


  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }


  Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }

  Future<Position> getCurrentPosition() async {
    bool serviceEnabled;
    LocationPermission permission;


    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }


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
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000; 
  }




  Duration calculateETA(
    double distanceKm, {
    double averageSpeedKmh = 30.0, 
  }) {
    if (distanceKm <= 0) {
      return Duration.zero;
    }
    

    final hours = distanceKm / averageSpeedKmh;
    final minutes = (hours * 60).round();
    

    return Duration(minutes: minutes.clamp(1, 180)); 
  }


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




  Future<List<Map<String, dynamic>>> searchAddressSuggestions(String query) async {
    if (query.trim().isEmpty) return [];
    try {

      final locations = await locationFromAddress(query);
      if (locations.isEmpty) return [];


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

        }
        results.add({
          'label': label,
          'latitude': lat,
          'longitude': lng,
        });
      }

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

