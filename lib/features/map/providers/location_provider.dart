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
  final MapRepository? repository;
  TickerProvider? _vsync;
  
  // Animation controller for smooth movement
  AnimationController? _animationController;
  Animation<double>? _animation;
  LatLng? _previousLocation;
  LatLng? _targetLocation;
  LatLng? _displayLocation;
  
  // Animation controller for accuracy circle
  AnimationController? _accuracyAnimationController;
  Animation<double>? _accuracyAnimation;
  double _displayAccuracy = 0.0; // The visually displayed accuracy (animated)
  double _targetAccuracy = 0.0;  // The actual accuracy we're animating towards
  
  // Animation speed factor (higher = slower)
  double _animationSpeedFactor = 1.0;
  
  LatLng? _currentUserLocation;
  bool _isLoading = false;
  String? _locationErrorMessage;
  double _accuracy = 0.0; // Accuracy in meters
  double _heading = 0.0; // Heading in degrees
  bool _isLocationInitialized = false;
  
  // Function for updating display accuracy during animation
  VoidCallback _updateDisplayAccuracyListener = () {};
  
  // Timer for smooth rotation
  Timer? _smoothRotationTimer;
  
  // Marker for user location on map
  Marker? _userLocationMarker;
  CircleMarker? _accuracyCircleMarker;
  
  // Location stream
  StreamSubscription<LocationData>? _locationStreamSubscription;

  LocationProvider({this.repository});
  
  // Getters and setters for animation speed
  double get animationSpeedFactor => _animationSpeedFactor;
  set animationSpeedFactor(double value) {
    _animationSpeedFactor = value;
    notifyListeners();
  }
  
  // Set up animations when vsync is provided
  set vsync(TickerProvider tickerProvider) {
    _vsync = tickerProvider;
    _initializeAnimationController();
  }
  
  void _initializeAnimationController() {
    if (_vsync != null) {
      // Position animation controller
      _animationController = AnimationController(
        vsync: _vsync!,
        duration: const Duration(milliseconds: 1000),
      );
      
      _animation = CurvedAnimation(
        parent: _animationController!,
        curve: Curves.easeInOut,
      );
      
      _animationController!.addListener(_updateDisplayLocation);
      
      // Accuracy animation controller - separate from position
      _accuracyAnimationController = AnimationController(
        vsync: _vsync!,
        duration: const Duration(milliseconds: 800),
      );
      
      _accuracyAnimation = CurvedAnimation(
        parent: _accuracyAnimationController!,
        curve: Curves.easeInOut,
      );
      
      _accuracyAnimationController!.addListener(() {
        _updateDisplayAccuracyListener();
      });
    }
  }

  // Getters
  LatLng? get currentUserLocation => _displayLocation ?? _currentUserLocation;
  bool get isLoading => _isLoading;
  String? get locationErrorMessage => _locationErrorMessage;
  bool get hasLocationError => _locationErrorMessage != null;
  Marker? get userLocationMarker => _userLocationMarker;
  CircleMarker? get accuracyCircleMarker => _accuracyCircleMarker;
  bool get isLocationInitialized => _isLocationInitialized;
  double get accuracy => _displayAccuracy;
  double get heading => _heading;
  
  // Initialize location tracking on startup
  Future<void> initLocationTracking() async {
    print("LocationProvider.initLocationTracking called");
    _isLoading = true;
    notifyListeners();
    
    try {
      // Check permissions first
      await LocationService.checkAndRequestPermission();
      
      // Get initial location quickly
      final initialLocationData = await LocationService.getFastThenAccurateLocation();
      _currentUserLocation = initialLocationData.location;
      _displayLocation = _currentUserLocation; // Initial display matches actual
      _previousLocation = _currentUserLocation; // Set initial previous location
      _accuracy = initialLocationData.accuracy;
      _displayAccuracy = initialLocationData.accuracy; // Initialize display accuracy
      _targetAccuracy = initialLocationData.accuracy;  // Initialize target accuracy
      _heading = initialLocationData.heading;
      
      // Update UI immediately with this quick fix
      _updateLocationMarkers();
      _isLocationInitialized = true;
      _isLoading = false;
      notifyListeners();
      
      // Start smooth rotation for compass immediately
      _startSmoothRotation();
      
      // Start continuous location updates
      _startLocationUpdates();
      
    } catch (e) {
      _locationErrorMessage = e.toString();
      print("Location error: $_locationErrorMessage");
      _isLoading = false;
      notifyListeners();
    }
  }
  
  void _startSmoothRotation() {
    // Cancel any existing timer
    _smoothRotationTimer?.cancel();
    
    // Create timer for smooth compass rotation
    _smoothRotationTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_currentUserLocation != null) {
        // Create a smooth rotation effect by small increments
        // This is just visual smoothing for the compass needle
        final targetHeading = _heading;
        var currentDisplayHeading = _heading;
        
        // Rotate a small amount each time to smooth animation
        if ((targetHeading - currentDisplayHeading).abs() > 180) {
          // Handle the wrap-around case (e.g., going from 350° to 10°)
          if (targetHeading > currentDisplayHeading) {
            currentDisplayHeading += 2.0;
            if (currentDisplayHeading >= 360) {
              currentDisplayHeading -= 360;
            }
          } else {
            currentDisplayHeading -= 2.0;
            if (currentDisplayHeading < 0) {
              currentDisplayHeading += 360;
            }
          }
        } else {
          // Normal case
          if (targetHeading > currentDisplayHeading) {
            currentDisplayHeading += 2.0;
          } else if (targetHeading < currentDisplayHeading) {
            currentDisplayHeading -= 2.0;
          }
        }
        
        _heading = currentDisplayHeading;
        _updateLocationMarkers();
        notifyListeners();
      }
    });
  }
  
  void _startLocationUpdates() {
    print("LocationProvider._startLocationUpdates called");
    // Cancel any existing subscription
    _locationStreamSubscription?.cancel();
    
    try {
      print("Starting location updates stream");
      final locationStream = repository != null 
          ? repository!.getLocationStream()
          : LocationService.getLocationStream();
      
      _locationStreamSubscription = locationStream.listen(
        (locationData) {
          print("Location update received: ${locationData.location.latitude}, ${locationData.location.longitude}, accuracy: ${locationData.accuracy}m");
          
          // Save actual location data
          _currentUserLocation = locationData.location;
          _accuracy = locationData.accuracy; // This is the true accuracy
          _heading = locationData.heading;
          
          // Animate both location and accuracy
          _animateToNewLocation(locationData.location);
          _animateAccuracy(locationData.accuracy);
          
          notifyListeners();
        },
        onError: (error) {
          print("Location stream error: $error");
          _locationErrorMessage = error.toString();
          notifyListeners();
        },
        onDone: () {
          print("Location stream done");
        }
      );
      print("Location updates stream setup complete");
    } catch (e) {
      print("Error starting location updates: $e");
      _locationErrorMessage = e.toString();
      notifyListeners();
    }
  }
  
  // Animate marker to new location
  void _animateToNewLocation(LatLng newLocation) {
    // If animations not initialized or no previous location, just set without animation
    if (_animationController == null || _previousLocation == null) {
      _previousLocation = newLocation;
      _displayLocation = newLocation;
      _updateLocationMarkers();
      return;
    }
    
    // Calculate distance to determine animation speed
    final double distance = _calculateDistance(_previousLocation!, newLocation);
    
    // Skip animation for teleports (unreasonably large distances)
    if (distance > 1000) { // More than 1km jump
      _previousLocation = newLocation;
      _displayLocation = newLocation;
      _updateLocationMarkers();
      return;
    }
    
    // Set animation duration based on distance and speed factor
    final duration = Duration(
      // Apply speed factor to make animation slower or faster
      milliseconds: (math.min(2000, math.max(500, (distance * 300).toInt())) * _animationSpeedFactor).toInt(),
    );
    _animationController!.duration = duration;
    
    // Store values for the animation
    _previousLocation = _displayLocation;
    _targetLocation = newLocation;
    
    // Reset and start animation
    _animationController!.reset();
    _animationController!.forward();
  }
  
  // Animate accuracy radius
  void _animateAccuracy(double newAccuracy) {
    // Skip if animation controller not initialized
    if (_accuracyAnimationController == null) {
      _displayAccuracy = newAccuracy;
      _targetAccuracy = newAccuracy;
      return;
    }
    
    // Skip tiny changes (e.g., less than 1 meter difference)
    if (_targetAccuracy != 0 && (newAccuracy - _targetAccuracy).abs() < 1.0) {
      return;
    }
    
    // Store values for the animation
    double startAccuracy = _displayAccuracy;
    _targetAccuracy = newAccuracy;
    
    // Duration depends on the magnitude of the change
    final double change = (newAccuracy - startAccuracy).abs();
    final Duration duration = Duration(
      // Slower for bigger changes
      milliseconds: (math.min(1500, math.max(400, change * 20)) * _animationSpeedFactor).toInt(),
    );
    _accuracyAnimationController!.duration = duration;
    
    // Update listener function with the new values
    _updateDisplayAccuracyListener = () {
      if (_accuracyAnimation != null) {
        _displayAccuracy = startAccuracy + (_targetAccuracy - startAccuracy) * _accuracyAnimation!.value;
        _updateLocationMarkers();
        notifyListeners();
      }
    };
    
    // Reset and start animation
    _accuracyAnimationController!.reset();
    _accuracyAnimationController!.forward();
  }
  
  // Update display location during animation
  void _updateDisplayLocation() {
    if (_previousLocation != null && _targetLocation != null && _animation != null) {
      // Calculate interpolated position
      final double t = _animation!.value;
      final double lat = _previousLocation!.latitude + 
          (_targetLocation!.latitude - _previousLocation!.latitude) * t;
      final double lng = _previousLocation!.longitude + 
          (_targetLocation!.longitude - _previousLocation!.longitude) * t;
      
      _displayLocation = LatLng(lat, lng);
      _updateLocationMarkers();
      notifyListeners();
    }
  }
  
  // Helper to calculate distance between two points
  double _calculateDistance(LatLng point1, LatLng point2) {
    const int earthRadius = 6371; // km
    final double lat1 = point1.latitude * (math.pi / 180);
    final double lat2 = point2.latitude * (math.pi / 180);
    final double lon1 = point1.longitude * (math.pi / 180);
    final double lon2 = point2.longitude * (math.pi / 180);
    
    final double dLat = lat2 - lat1;
    final double dLon = lon2 - lon1;
    
    final double a = math.sin(dLat/2) * math.sin(dLat/2) +
                     math.cos(lat1) * math.cos(lat2) * 
                     math.sin(dLon/2) * math.sin(dLon/2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a));
    
    // Distance in meters
    return earthRadius * c * 1000;
  }
  
  // Get current location once
  Future<void> getCurrentLocation() async {
    print("LocationProvider.getCurrentLocation called");
    if (_isLoading) return;
    
    _isLoading = true;
    _locationErrorMessage = null;
    notifyListeners();
    
    try {
      // Use fast-then-accurate approach for better UX
      final locationData = await LocationService.getFastThenAccurateLocation();
      
      print("Got location data: ${locationData.location.latitude}, ${locationData.location.longitude}");
      
      _currentUserLocation = locationData.location;
      _displayLocation = locationData.location; // Set display location without animation
      _previousLocation = locationData.location;
      _accuracy = locationData.accuracy;
      _displayAccuracy = locationData.accuracy; // Set display accuracy without animation
      _targetAccuracy = locationData.accuracy;
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
    if (_displayLocation == null) return;
    
    // Create accuracy circle using the animated accuracy value
    _accuracyCircleMarker = CircleMarker(
      point: _displayLocation!,
      color: Colors.blue.withOpacity(0.15),
      borderColor: Colors.blue.withOpacity(0.5),
      borderStrokeWidth: 1,
      useRadiusInMeter: true,
      radius: _displayAccuracy, // Use the animated accuracy value
    );
    
    // Create clean user location marker with heading
    _userLocationMarker = Marker(
      width: 40.0,
      height: 40.0,
      point: _displayLocation!,
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
  
  void clearError() {
    _locationErrorMessage = null;
    notifyListeners();
  }
  
  @override
  void dispose() {
    print("LocationProvider disposing");
    _smoothRotationTimer?.cancel();
    _locationStreamSubscription?.cancel();
    _animationController?.dispose();
    _accuracyAnimationController?.dispose();
    super.dispose();
  }
}