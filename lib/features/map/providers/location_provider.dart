// lib/features/map/providers/location_provider.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/material.dart';
import 'package:mercab/core/services/location_service.dart';
import 'package:mercab/features/map/repositories/map_repository.dart';
import 'dart:async';
import 'dart:math' as math;

class LocationProvider extends ChangeNotifier {
  final MapRepository? _repository;
  
  LocationProvider({MapRepository? repository}) : _repository = repository;
  
  LatLng? _currentUserLocation;
  bool _isLoading = false;
  String? _locationErrorMessage;
  double _accuracy = 0.0; // Accuracy in meters
  double _heading = 0.0; // Heading in degrees
  bool _isLocationInitialized = false;
  
  // Marker for user location on map
  Marker? _userLocationMarker;
  CircleMarker? _accuracyCircleMarker;
  
  // Location stream
  StreamSubscription<LocationData>? _locationStreamSubscription;

  // Getters
  LatLng? get currentUserLocation => _currentUserLocation;
  bool get isLoading => _isLoading;
  String? get locationErrorMessage => _locationErrorMessage;
  bool get hasLocationError => _locationErrorMessage != null;
  Marker? get userLocationMarker => _userLocationMarker;
  CircleMarker? get accuracyCircleMarker => _accuracyCircleMarker;
  bool get isLocationInitialized => _isLocationInitialized;
  
  // Initialize location tracking on startup
Future<void> initLocationTracking() async {
  _isLoading = true;
  notifyListeners();
  
  try {
    // Check permissions first
    await LocationService.checkAndRequestPermission();
    
    // Get initial location
    await getCurrentLocation();
    
    // Start listening to location updates
    _startLocationUpdates();
    
    _isLocationInitialized = true;
  } catch (e) {
    _locationErrorMessage = e.toString();
    print("Location error: $_locationErrorMessage");
  } finally {
    _isLoading = false;
    notifyListeners();
  }
}
  void _startLocationUpdates() {
    // Cancel any existing subscription
    _locationStreamSubscription?.cancel();
    
    try {
      final locationStream = _repository != null 
          ? _repository!.getLocationStream()
          : LocationService.getLocationStream();
      
      _locationStreamSubscription = locationStream.listen(
        (locationData) {
          print("Location update received: ${locationData.location}");
          _currentUserLocation = locationData.location;
          _accuracy = locationData.accuracy;
          _heading = locationData.heading;
          
          _updateLocationMarkers();
          notifyListeners();
        },
        onError: (error) {
          print("Location stream error: $error");
          _locationErrorMessage = error.toString();
          notifyListeners();
        }
      );
    } catch (e) {
      print("Error starting location updates: $e");
      _locationErrorMessage = e.toString();
      notifyListeners();
    }
  }
  
  // Get current location once
  Future<void> getCurrentLocation() async {
    if (_isLoading) return;
    
    _isLoading = true;
    _locationErrorMessage = null;
    notifyListeners();
    
    try {
      final locationData = _repository != null 
          ? await _repository!.getCurrentLocationWithDetails() 
          : await LocationService.getCurrentLocationWithDetails();
      
      _currentUserLocation = locationData.location;
      _accuracy = locationData.accuracy;
      _heading = locationData.heading;
      
      _updateLocationMarkers();
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      print("Error getting current location: $e");
      _locationErrorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }
  
  void _updateLocationMarkers() {
    if (_currentUserLocation == null) return;
    
    // Create accuracy circle
    _accuracyCircleMarker = CircleMarker(
      point: _currentUserLocation!,
      color: Colors.blue.withOpacity(0.15),
      borderColor: Colors.blue.withOpacity(0.5),
      borderStrokeWidth: 1,
      useRadiusInMeter: true,
      radius: _accuracy, // Use actual accuracy in meters
    );
    
    // Create clean user location marker with heading
    _userLocationMarker = Marker(
      width: 40.0,
      height: 40.0,
      point: _currentUserLocation!,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Blue circle for current position
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.7),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
          // Heading indicator using Icon instead of custom painter
          Transform.rotate(
            angle: (_heading * (math.pi / 180)) - (math.pi / 2),
            child: const SizedBox(
              width: 40,
              height: 40,
              child: Icon(
                Icons.navigation,
                color: Colors.blue,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Clear error message
  void clearError() {
    _locationErrorMessage = null;
    notifyListeners();
  }
  
  @override
  void dispose() {
    _locationStreamSubscription?.cancel();
    super.dispose();
  }
}