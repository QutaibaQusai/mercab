import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/material.dart';
import 'package:mercab/core/services/location_service.dart';
import 'package:mercab/features/map/repositories/map_repository.dart';

class LocationProvider extends ChangeNotifier {
  final MapRepository? _repository;
  
  LocationProvider({MapRepository? repository}) : _repository = repository;
  
  LatLng? _currentUserLocation;
  bool _isLoading = false;
  String? _locationErrorMessage;
  
  // Marker for user location on map
  Marker? _userLocationMarker;

  // Getters
  LatLng? get currentUserLocation => _currentUserLocation;
  bool get isLoading => _isLoading;
  String? get locationErrorMessage => _locationErrorMessage;
  bool get hasLocationError => _locationErrorMessage != null;
  Marker? get userLocationMarker => _userLocationMarker;
  
  // Method to get current location
  Future<void> getCurrentLocation() async {
    if (_isLoading) return;
    
    _isLoading = true;
    _locationErrorMessage = null;
    notifyListeners();
    
    try {
      // If repository is provided, use it, otherwise use direct service
      final currentLocation = _repository != null 
          ? await _repository!.getCurrentLocation() 
          : await LocationService.getCurrentLocation();
      
      _currentUserLocation = currentLocation;
      
      // Create a marker for the current location
      _userLocationMarker = Marker(
        width: 20.0,
        height: 20.0,
        point: currentLocation,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
        ),
      );
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _locationErrorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Clear error message
  void clearError() {
    _locationErrorMessage = null;
    notifyListeners();
  }
}