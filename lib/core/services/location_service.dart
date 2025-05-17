// lib/core/services/location_service.dart (updated)

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';

class LocationData {
  final LatLng location;
  final double accuracy;
  final double heading;
  
  LocationData({
    required this.location,
    required this.accuracy,
    required this.heading,
  });
}

class LocationService {
  /// Gets a continuous stream of location updates
  static Stream<LocationData> getLocationStream() {
    // Create a stream from geolocator position updates
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // Update when moved 5 meters
        timeLimit: Duration(seconds: 2), // Update at least every 2 seconds
      ),
    ).map((position) {
      // Convert Position to LocationData
      return LocationData(
        location: LatLng(position.latitude, position.longitude),
        accuracy: position.accuracy,
        heading: _normalizeHeading(position.heading),
      );
    }).asBroadcastStream(); // Make it a broadcast stream so multiple listeners can subscribe
  }
  
  /// Get the current location with accuracy and heading information
  static Future<LocationData> getCurrentLocationWithDetails() async {
    await checkAndRequestPermission();

    // Get the current position with full details
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    
    return LocationData(
      location: LatLng(position.latitude, position.longitude),
      accuracy: position.accuracy,
      heading: _normalizeHeading(position.heading),
    );
  }
  
  // Normalize heading value
  static double _normalizeHeading(double? rawHeading) {
    if (rawHeading == null) return 0.0;
    double heading = rawHeading;
    if (heading < 0) heading += 360; // Normalize negative values
    return heading;
  }
  
  // Make this method public
  static Future<void> checkAndRequestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationServiceException(
        'Location services are disabled. Please enable location in your device settings.',
      );
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw LocationServiceException(
          'Location permissions are denied. Please allow location access.',
        );
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      throw LocationServiceException(
        'Location permissions are permanently denied. Please enable in app settings.',
      );
    }
  }
  
  /// Legacy method for backwards compatibility
  static Future<LatLng> getCurrentLocation() async {
    final locationData = await getCurrentLocationWithDetails();
    return locationData.location;
  }
}

class LocationServiceException implements Exception {
  final String message;
  
  LocationServiceException(this.message);
  
  @override
  String toString() => 'LocationServiceException: $message';
}