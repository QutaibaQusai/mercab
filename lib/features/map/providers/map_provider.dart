import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:mercab/core/services/routing_service.dart';
import 'package:mercab/core/utils/location_utils.dart';
import 'dart:async';
import 'package:mercab/features/map/repositories/map_repository.dart';

class MapProvider extends ChangeNotifier {
  final MapRepository? _repository;
  
  MapProvider({MapRepository? repository}) : _repository = repository;
  
  final MapController mapController = MapController();
  
  // Default center (Amman, Jordan)
  static const LatLng initialCenter = LatLng(31.9539, 35.9106);
  
  // Pin mode state
  bool _isInPinMode = false;
  String _currentAddress = "Move the map to see location addresses";
  bool _isGettingAddress = false;
  Timer? _debounceTimer;
  
  // Pin selection state
  bool _isSelectingPin = false;
  LatLng? _selectedLocation;
  
  // Route state
  bool _showRoute = true;
  List<LatLng> _routePoints = [];
  bool _isCalculatingRoute = false;
  
  // Getters for pin mode
  bool get isInPinMode => _isInPinMode;
  String get currentAddress => _currentAddress;
  bool get isGettingAddress => _isGettingAddress;
  
  // Getters for pin selection
  bool get isSelectingPin => _isSelectingPin;
  LatLng? get selectedLocation => _selectedLocation;
  
  // Getters for route
  bool get showRoute => _showRoute;
  List<LatLng> get routePoints => _routePoints;
  bool get isCalculatingRoute => _isCalculatingRoute;
  
  // Pin mode methods
  void togglePinMode() {
    _isInPinMode = !_isInPinMode;
    
    if (_isInPinMode) {
      // When entering pin mode, get the address at the current map center
      getAddressFromCurrentCenter();
    } else {
      // When exiting pin mode, reset selection state
      _isSelectingPin = false;
      _selectedLocation = null;
    }
    
    notifyListeners();
  }
  
  void setSelectingPin(bool isSelecting) {
    _isSelectingPin = isSelecting;
    notifyListeners();
  }
  
  void setSelectedLocation(LatLng? location) {
    _selectedLocation = location;
    notifyListeners();
  }
  
  // Route methods
  void toggleRouteDisplay() {
    _showRoute = !_showRoute;
    notifyListeners();
  }
  
  void moveToLocation(LatLng location, [double zoom = 15.0]) {
    mapController.move(location, zoom);
    // No need to notify as this is UI-only
  }
  
  void moveToInitialLocation() {
    mapController.move(initialCenter, 13.0);
  }
  
  Future<void> getAddressFromCurrentCenter() async {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      _isGettingAddress = true;
      notifyListeners();
      
      try {
        final centerLocation = mapController.camera.center;
        _selectedLocation = centerLocation; // Update selected location
        
        if (_repository != null) {
          final address = await _repository!.getAddressFromLocation(centerLocation);
          _currentAddress = address;
        } else {
          // Fallback if no repository is available
          _currentAddress = "Location at ${centerLocation.latitude.toStringAsFixed(5)}, ${centerLocation.longitude.toStringAsFixed(5)}";
        }
      } catch (e) {
        _currentAddress = "Error fetching address. Please check your internet connection.";
      } finally {
        _isGettingAddress = false;
        notifyListeners();
      }
    });
  }
  
  Future<void> calculateRoute(LatLng start, LatLng end) async {
    _isCalculatingRoute = true;
    notifyListeners();
    
    try {
      List<LatLng> routePoints;
      
      if (_repository != null) {
        routePoints = await _repository!.calculateRoute(start, end);
      } else {
        // Fallback to direct service call if no repository
        routePoints = await RoutingService.getRoute(start, end);
      }
      
      _routePoints = routePoints;
      
    } catch (e) {
      // Fallback to a straight line if routing fails
      _routePoints = LocationUtils.generateFallbackRoute(start, end);
    } finally {
      _isCalculatingRoute = false;
      notifyListeners();
    }
  }
  
  void setRoutePoints(List<LatLng> points) {
    _routePoints = points;
    notifyListeners();
  }
  
  void setCalculatingRoute(bool isCalculating) {
    _isCalculatingRoute = isCalculating;
    notifyListeners();
  }
  
  void clearRoute() {
    _routePoints = [];
    notifyListeners();
  }
  
  // Calculate approximate route distance in kilometers
  double calculateRouteDistance() {
    return LocationUtils.calculateRouteDistance(_routePoints);
  }
  
  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}