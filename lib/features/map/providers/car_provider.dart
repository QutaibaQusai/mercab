import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:mercab/features/map/models/car_marker.dart';
import 'package:mercab/features/map/models/animation_point.dart';
import 'package:mercab/core/utils/location_utils.dart';
import 'dart:async';
import 'dart:math' as math;

class CarProvider extends ChangeNotifier {
  final List<CarMarker> _carMarkers = [];
  
  // Animation properties
  bool _isAnimating = false;
  Timer? _animationTimer;
  int _currentRoutePointIndex = 0;
  AnimationPoint? _animationPoint;
  double _animationSpeed = 50.0; // milliseconds per point
  List<LatLng> _animationRoute = [];
  
  // Getters
  List<CarMarker> get carMarkers => _carMarkers;
  bool get isAnimating => _isAnimating;
  AnimationPoint? get animationPoint => _animationPoint;
  
  // Methods
  void addCarMarker(double lat, double lng, double angle) {
    final position = LatLng(lat, lng);
    final markerId = 'car_${DateTime.now().millisecondsSinceEpoch}';
    
    _carMarkers.add(CarMarker(
      position: position,
      angle: angle,
      id: markerId,
    ));
    
    notifyListeners();
  }
  
  CarMarker? getLastCarMarker() {
    if (_carMarkers.isEmpty) return null;
    return _carMarkers.last;
  }
  
  void removeCarMarker(String id) {
    _carMarkers.removeWhere((marker) => marker.id == id);
    notifyListeners();
  }
  
  void clearCarMarkers() {
    _carMarkers.clear();
    notifyListeners();
  }
  
  void startAnimation(List<LatLng> route) {
    if (route.isEmpty) return;
    
    // Stop any existing animation
    stopAnimation();
    
    _animationRoute = route;
    _isAnimating = true;
    _currentRoutePointIndex = 0;
    
    // Set initial animation point
    if (_animationRoute.isNotEmpty) {
      final initialPosition = _animationRoute[0];
      double initialAngle = 0.0;
      
      // Calculate initial angle if there's a next point
      if (_animationRoute.length > 1) {
        initialAngle = LocationUtils.calculateAngle(initialPosition, _animationRoute[1]);
      }
      
      _animationPoint = AnimationPoint(
        position: initialPosition,
        angle: initialAngle,
      );
    }
    
    notifyListeners();
    
    // Start animation timer
    _animationTimer = Timer.periodic(
      Duration(milliseconds: _animationSpeed.toInt()), 
      (_) => _animateNextStep()
    );
  }
  
  void stopAnimation() {
    _animationTimer?.cancel();
    _isAnimating = false;
    _animationPoint = null;
    notifyListeners();
  }
  
  void _animateNextStep() {
    if (_currentRoutePointIndex >= _animationRoute.length - 1) {
      // Reset to beginning for continuous animation
      _currentRoutePointIndex = 0;
      
      if (_animationRoute.isNotEmpty) {
        final initialPosition = _animationRoute[0];
        double initialAngle = _animationPoint?.angle ?? 0.0;
        
        // Calculate initial angle if there's a next point
        if (_animationRoute.length > 1) {
          initialAngle = LocationUtils.calculateAngle(initialPosition, _animationRoute[1]);
        }
        
        _animationPoint = AnimationPoint(
          position: initialPosition,
          angle: initialAngle,
        );
      }
      
      notifyListeners();
      return;
    }
    
    // Move to next point
    _currentRoutePointIndex++;
    
    final currentPoint = _animationRoute[_currentRoutePointIndex];
    
    // Calculate angle between current and next point
    double angle = _animationPoint?.angle ?? 0.0;
    if (_currentRoutePointIndex < _animationRoute.length - 1) {
      final nextPoint = _animationRoute[_currentRoutePointIndex + 1];
      angle = LocationUtils.calculateAngle(currentPoint, nextPoint);
    }
    
    // Update animation point
    _animationPoint = AnimationPoint(
      position: currentPoint,
      angle: angle,
    );
    
    notifyListeners();
  }
  
  void setAnimationSpeed(double speed) {
    _animationSpeed = speed;
    
    // Restart animation if already running
    if (_isAnimating) {
      _animationTimer?.cancel();
      _animationTimer = Timer.periodic(
        Duration(milliseconds: _animationSpeed.toInt()), 
        (_) => _animateNextStep()
      );
    }
  }
  
  @override
  void dispose() {
    _animationTimer?.cancel();
    super.dispose();
  }
}