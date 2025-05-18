// lib/core/services/location_service.dart

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:io';

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
    print("Setting up location stream");
    
    // For testing in simulator/emulator, use simulated location
    if (!Platform.isAndroid && !Platform.isIOS) {
      print("Using simulated location updates for development");
      return getSimulatedLocationStream();
    }
    
    // Create a stream from geolocator position updates
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best, // Balance between accuracy and speed
        distanceFilter: 0, // Update on ANY movement (no minimum threshold)
        // The following settings differ between platforms
        timeLimit: null,
        // Android-specific settings
      ),
    ).map((position) {
      print("Raw location update: ${position.latitude}, ${position.longitude}");
      // Convert Position to LocationData
      return LocationData(
        location: LatLng(position.latitude, position.longitude),
        accuracy: position.accuracy,
        heading: _normalizeHeading(position.heading),
      );
    }).asBroadcastStream(); // Make it a broadcast stream
  }
  
  // For development, make simulated updates faster
  static Stream<LocationData> getSimulatedLocationStream() {
    // Create a periodic timer with FASTER updates (500ms)
    return Stream.periodic(const Duration(milliseconds: 500), (count) {
      // Create a base location with some random variation
      final baseLatitude = 31.9539;
      final baseLongitude = 35.9106;
      
      // Add some random movement (within about 100 meters)
      final latitude = baseLatitude + (math.Random().nextDouble() - 0.5) * 0.001;
      final longitude = baseLongitude + (math.Random().nextDouble() - 0.5) * 0.001;
      
      // Simulate changing accuracy - alternating between more and less accurate
      final accuracy = 15.0 + math.sin(count * 0.2) * 10.0; // Oscillates between 5m and 25m
      
      // Simulate changing heading
      final heading = (count * 10.0) % 360; // Faster rotation for more responsive appearance
      
      print("Simulated location update: $latitude, $longitude, accuracy: ${accuracy.toStringAsFixed(1)}m, heading: ${heading.toStringAsFixed(1)}°");
      
      return LocationData(
        location: LatLng(latitude, longitude),
        accuracy: accuracy,
        heading: heading,
      );
    }).asBroadcastStream();
  }
  
  // Get fast location first, then improve with better sources
  static Future<LocationData> getFastThenAccurateLocation() async {
    await checkAndRequestPermission();
    
    // Get a quick, low-accuracy fix first
    try {
      final quickPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.reduced,
        timeLimit: const Duration(seconds: 1),
      );
      
      print("Got quick location: ${quickPosition.latitude}, ${quickPosition.longitude}");
      
      // Return this immediately to the UI
      final quickData = LocationData(
        location: LatLng(quickPosition.latitude, quickPosition.longitude),
        accuracy: quickPosition.accuracy,
        heading: _normalizeHeading(quickPosition.heading),
      );
      
      // Then start a high-accuracy request in the background
      Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high)
        .then((precisePosition) {
          print("Got precise location: ${precisePosition.latitude}, ${precisePosition.longitude}");
          // This will be delivered later via the position stream
        });
      
      return quickData;
    } catch (e) {
      print("Fast location failed: $e");
      // Fall back to standard method if the quick one fails
      return getCurrentLocationWithDetails();
    }
  }
  
  /// Get the current location with accuracy and heading information
  static Future<LocationData> getCurrentLocationWithDetails() async {
    await checkAndRequestPermission();

    try {
      // Get the current position with full details
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      print("Got current position: ${position.latitude}, ${position.longitude}");
      
      return LocationData(
        location: LatLng(position.latitude, position.longitude),
        accuracy: position.accuracy,
        heading: _normalizeHeading(position.heading),
      );
    } catch (e) {
      print("Error getting current position: $e");
      throw LocationServiceException(
        'Failed to get current location: $e',
      );
    }
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
    
    print("Location permissions granted");
  }
  
  /// Legacy method for backwards compatibility
  static Future<LatLng> getCurrentLocation() async {
    final locationData = await getFastThenAccurateLocation();
    return locationData.location;
  }
}

class LocationServiceException implements Exception {
  final String message;
  
  LocationServiceException(this.message);
  
  @override
  String toString() => 'LocationServiceException: $message';
}