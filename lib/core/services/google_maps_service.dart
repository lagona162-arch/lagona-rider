import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Service for Google Maps integration
/// Handles map interactions and location synchronization
class GoogleMapsService {
  /// Get coordinates from a map tap/selection
  /// Returns a LatLng object with the selected location
  static LatLng getCoordinatesFromTap(LatLng position) {
    return position;
  }

  /// Get address from coordinates using reverse geocoding
  /// This syncs with Google Maps Geocoding API via geocoding package
  Future<String?> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        
        // Build address string
        final addressParts = <String>[];
        
        if (placemark.street != null && placemark.street!.isNotEmpty) {
          addressParts.add(placemark.street!);
        }
        if (placemark.subLocality != null && placemark.subLocality!.isNotEmpty) {
          addressParts.add(placemark.subLocality!);
        }
        if (placemark.locality != null && placemark.locality!.isNotEmpty) {
          addressParts.add(placemark.locality!);
        }
        if (placemark.administrativeArea != null && placemark.administrativeArea!.isNotEmpty) {
          addressParts.add(placemark.administrativeArea!);
        }
        if (placemark.postalCode != null && placemark.postalCode!.isNotEmpty) {
          addressParts.add(placemark.postalCode!);
        }
        if (placemark.country != null && placemark.country!.isNotEmpty) {
          addressParts.add(placemark.country!);
        }
        
        return addressParts.join(', ');
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get coordinates from an address using forward geocoding
  /// This syncs with Google Maps Geocoding API
  Future<LatLng?> getCoordinatesFromAddress(String address) async {
    try {
      final locations = await locationFromAddress(address);
      
      if (locations.isNotEmpty) {
        final location = locations.first;
        return LatLng(location.latitude, location.longitude);
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Create a marker for a specific location
  static Marker createMarker({
    required String markerId,
    required LatLng position,
    String? title,
    String? snippet,
    BitmapDescriptor? icon,
  }) {
    return Marker(
      markerId: MarkerId(markerId),
      position: position,
      infoWindow: InfoWindow(
        title: title,
        snippet: snippet,
      ),
      icon: icon ?? BitmapDescriptor.defaultMarker,
    );
  }

  /// Create camera position for a specific location
  static CameraPosition createCameraPosition({
    required LatLng target,
    double zoom = 14.0,
    double tilt = 0.0,
    double bearing = 0.0,
  }) {
    return CameraPosition(
      target: target,
      zoom: zoom,
      tilt: tilt,
      bearing: bearing,
    );
  }
}

