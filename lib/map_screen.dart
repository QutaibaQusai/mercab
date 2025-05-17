import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:mercab/coordinate_input_widget.dart';
import 'package:mercab/location_service.dart';
import 'package:mercab/routing_service.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:math' as math;

class CarMarker {
  final LatLng position;
  final double angle;
  final String id;
  
  CarMarker({
    required this.position,
    required this.angle,
    required this.id,
  });
}

class AnimationPoint {
  final LatLng position;
  final double angle;
  
  AnimationPoint({
    required this.position,
    required this.angle,
  });
}

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final List<CarMarker> _carMarkers = [];
  
  // Default center position (Amman, Jordan)
  static const LatLng _initialCenter = LatLng(31.9539, 35.9106);
  
  // State variables for location and routing
  bool _isLoading = false;
  bool _isCalculatingRoute = false;
  bool _showRoute = true;
  LatLng? _currentUserLocation;
  List<LatLng> _routePoints = [];
  Marker? _userLocationMarker;
  
  // Animation properties
  bool _isAnimating = false;
  Timer? _animationTimer;
  int _currentRoutePointIndex = 0;
  AnimationPoint? _animationPoint;
  double _animationSpeed = 50.0; // milliseconds per point
  List<LatLng> _animationRoute = []; // Separate route for animation
  
  // Pin feature
  bool _isInPinMode = false;
  String _currentAddress = "Move the map to see location addresses";
  bool _isGettingAddress = false;
  Timer? _debounceTimer;
  
  @override
  void initState() {
    super.initState();
    
    // Add listener to map controller for movement
    _mapController.mapEventStream.listen((event) {
      if (event is MapEventMoveEnd && _isInPinMode) {
        _onMapMoveEnd();
      }
    });
  }
  
  void _onMapMoveEnd() {
    if (!_isInPinMode) return;
    
    // Get the center of the map
    final centerLatLng = _mapController.camera.center;
    
    // Debounce to avoid too many API calls
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _getAddressFromLatLng(centerLatLng);
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mercab'),
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Flutter Map as the base layer
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: 12.0,
              interactionOptions: const InteractionOptions(
                enableMultiFingerGestureRace: true,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://api.maptiler.com/maps/streets/{z}/{x}/{y}.png?key=B0783yyGPDMyq5nY7DoR',    
                userAgentPackageName: 'com.example.mercab',
                subdomains: const ['a', 'b', 'c', 'd'],
              ),
              
              PolylineLayer(
                polylines: [
                  if (_showRoute && _routePoints.isNotEmpty)
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 5.0,
                      color: Colors.black.withOpacity(0.7),
                      borderColor: Colors.white,
                      borderStrokeWidth: 1.0,
                    ),
                ],
              ),
              
              MarkerLayer(markers: [
                // Car markers
                ..._carMarkers.map((carMarker) => Marker(
                  width: 80.0,
                  height: 80.0,
                  point: carMarker.position,
                  child: _buildCarMarker(carMarker.angle),
                )),
                
                // Animation marker
                if (_isAnimating && _animationPoint != null)
                  Marker(
                    width: 40.0,
                    height: 40.0,
                    point: _animationPoint!.position,
                    child: _buildAnimationMarker(_animationPoint!.angle),
                  ),
                
                // User location marker
                if (_userLocationMarker != null) _userLocationMarker!,
              ]),
            ],
          ),
          
          // Center pin (only show when in pin mode)
          if (_isInPinMode)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Add some space to account for the bottom shadow of the pin
                  const SizedBox(height: 20),
                  // Pin icon with shadow
                  Container(
                    height: 50,
                    width: 50,
                    decoration: const BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage('assets/pin.png'),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          // Route info box (when route is active and not in pin mode)
          if (_showRoute && _routePoints.isNotEmpty && !_isInPinMode)
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Route to Car',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Distance: ~${_calculateRouteDistance().toStringAsFixed(2)} km',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          
          // Pin address box (when pin mode is active)
          if (_isInPinMode)
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Location Address',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: _togglePinMode,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isGettingAddress ? "address..." : _currentAddress,
                      style: const TextStyle(fontSize: 12),
                    ),
                    // const SizedBox(height: 8),
                    // Row(
                    //   mainAxisAlignment: MainAxisAlignment.center,
                    //   children: [
                    //     ElevatedButton.icon(
                    //       icon: const Icon(Icons.add_location, size: 16),
                    //       label: const Text('Set As Drop-off'),
                    //       style: ElevatedButton.styleFrom(
                    //         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    //         textStyle: const TextStyle(fontSize: 12),
                    //       ),
                    //       onPressed: _setAsDropOff,
                    //     ),
                    //   ],
                    // ),
                  ],
                ),
              ),
            ),
          
          // Map attribution
          Positioned(
            left: 10,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.all(4),
              color: Colors.white.withOpacity(0.7),
              child: const Text(
                '© MapTiler | © OpenStreetMap contributors',
                style: TextStyle(fontSize: 10, color: Colors.black87),
              ),
            ),
          ),
          
          // Map control buttons
          Positioned(
            right: 16,
            bottom: 200,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pin mode button
                FloatingActionButton(
                  heroTag: 'pinMode',
                  mini: true,
                  onPressed: _togglePinMode,
                  backgroundColor: _isInPinMode ? Colors.orange : Colors.deepPurple,
                  child: Icon(
                    _isInPinMode ? Icons.location_off : Icons.location_searching,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                
                // Route toggle button
                FloatingActionButton(
                  heroTag: 'toggleRoute',
                  mini: true,
                  onPressed: _toggleRoute,
                  backgroundColor: _showRoute ? Colors.blue : Colors.grey,
                  child: Icon(
                    _showRoute ? Icons.route : Icons.route_outlined,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                
                // Current location button
                FloatingActionButton(
                  heroTag: 'currentLocation',
                  mini: true,
                  onPressed: _isLoading ? null : _goToCurrentLocation,
                  backgroundColor: _isLoading ? Colors.grey : Colors.blue,
                  child: _isLoading 
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.my_location),
                ),
                const SizedBox(height: 8),
                
                // Reset view button
                FloatingActionButton(
                  heroTag: 'centerMap',
                  mini: true,
                  onPressed: () {
                    _mapController.move(_initialCenter, 13.0);
                  },
                  child: const Icon(Icons.center_focus_strong),
                ),
              ],
            ),
          ),
          
          // Only show coordinate input when not in pin mode
          if (!_isInPinMode)
            CoordinateInputWidget(
              onCoordinatesSubmitted: _addCarMarker,
            ),
          
          if (_isCalculatingRoute)
            Positioned(
              top: 70,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Calculating route...',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _addCarMarker(double lat, double lng, double angle) {
    final position = LatLng(lat, lng);
    final markerId = 'car_${DateTime.now().millisecondsSinceEpoch}';
    
    setState(() {
      _carMarkers.add(CarMarker(
        position: position,
        angle: angle,
        id: markerId,
      ));
    });

    // Move map to the new marker
    _mapController.move(position, _mapController.camera.zoom);
    
    // Calculate route if user location is available
    if (_currentUserLocation != null && _showRoute) {
      _calculateRoute();
    }
    
    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Car marker added at Lat: $lat, Lng: $lng, Angle: ${(angle * 180 / math.pi).round()}°'),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.green,
      ),
    );
  }
  
  Future<void> _goToCurrentLocation() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final currentLocation = await LocationService.getCurrentLocation();
      _currentUserLocation = currentLocation;
      
      // Add a marker for the user's location
      setState(() {
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
      });
      
      // Calculate route if there's at least one car marker and route display is enabled
      if (_carMarkers.isNotEmpty && _showRoute) {
        await _calculateRoute();
      }
      
      // Move to user's location
      _mapController.move(currentLocation, 15.0);
      
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Widget _buildCarMarker(double angle) {
    return Transform.rotate(
      angle: angle,
      child: Image.asset(
        'assets/car.png',
        width: 80,
        height: 80,
      ),
    );
  }
  
  Widget _buildAnimationMarker(double angle) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.7),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 5,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Image.asset("assets/car.png"),
      ),
    );
  }
  
  void _toggleRoute() {
    setState(() {
      _showRoute = !_showRoute;
    });
    
    if (_showRoute && _currentUserLocation != null && _carMarkers.isNotEmpty) {
      _calculateRoute();
    } else {
      setState(() {
        _routePoints = [];
        // Stop any ongoing animation when hiding the route
        _stopAnimation();
      });
    }
  }
  
  Future<void> _calculateRoute() async {
    // Stop any existing animation
    _stopAnimation();
    
    if (_currentUserLocation == null || _carMarkers.isEmpty) {
      return;
    }
    
    setState(() {
      _isCalculatingRoute = true;
    });
    
    try {
      // Get the last car marker
      final lastCarMarker = _carMarkers.last;
      
      // Calculate route between current location and last car marker
      final routePoints = await RoutingService.getRoute(
        _currentUserLocation!,
        lastCarMarker.position,
      );
      
      setState(() {
        // Store the route points for display (from user to car)
        _routePoints = routePoints;
        
        // Create a reversed copy of the route for animation (from car to user)
        _animationRoute = List.from(routePoints.reversed);
      });
      
      // Start the animation automatically after calculating the route
      _startAnimation();
    } catch (e) {
      debugPrint('Error calculating route: $e');
      // Fallback to a straight line if routing fails
      if (_currentUserLocation != null && _carMarkers.isNotEmpty) {
        final simpleRoute = [
          _currentUserLocation!,
          _carMarkers.last.position,
        ];
        
        setState(() {
          _routePoints = simpleRoute;
          _animationRoute = List.from(simpleRoute.reversed);
        });
        
        // Start animation with simple route
        _startAnimation();
      }
      
      // Show error message only if it's not a timeout
      if (!e.toString().contains('timeout')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Using simplified route due to calculation error'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      setState(() {
        _isCalculatingRoute = false;
      });
    }
  }
  
  // Calculate approximate route distance in kilometers
  double _calculateRouteDistance() {
    if (_routePoints.isEmpty) return 0;
    
    double totalDistance = 0;
    for (int i = 0; i < _routePoints.length - 1; i++) {
      totalDistance += _calculateDistance(
        _routePoints[i].latitude, 
        _routePoints[i].longitude,
        _routePoints[i + 1].latitude, 
        _routePoints[i + 1].longitude
      );
    }
    
    return totalDistance;
  }
  
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const int earthRadius = 6371; 
    
    final double latDistance = _toRadians(lat2 - lat1);
    final double lonDistance = _toRadians(lon2 - lon1);
    
    final double a = math.sin(latDistance / 2) * math.sin(latDistance / 2) +
                     math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
                     math.sin(lonDistance / 2) * math.sin(lonDistance / 2);
    
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }
  
  double _toRadians(double degree) {
    return degree * (math.pi / 180);
  }
  
  // Animation methods
  void _startAnimation() {
    if (_animationRoute.isEmpty) {
      return;
    }
    
    setState(() {
      _isAnimating = true;
      _currentRoutePointIndex = 0;
      
      // Set initial animation point at car's position
      if (_animationRoute.isNotEmpty) {
        final initialPosition = _animationRoute[0];
        double initialAngle = 0.0;
        
        // Calculate initial angle if there's a next point
        if (_animationRoute.length > 1) {
          initialAngle = _calculateAngle(initialPosition, _animationRoute[1]);
        }
        
        _animationPoint = AnimationPoint(
          position: initialPosition,
          angle: initialAngle,
        );
      }
    });
    
    // Start the animation timer
    _animationTimer = Timer.periodic(Duration(milliseconds: _animationSpeed.toInt()), (timer) {
      _animateNextStep();
    });
  }
  
  void _stopAnimation() {
    _animationTimer?.cancel();
    setState(() {
      _isAnimating = false;
      _animationPoint = null;
    });
  }
  
  void _animateNextStep() {
    if (_currentRoutePointIndex >= _animationRoute.length - 1) {
      // Reset to beginning for continuous animation
      setState(() {
        _currentRoutePointIndex = 0;
        
        if (_animationRoute.isNotEmpty) {
          final initialPosition = _animationRoute[0];
          double initialAngle = _animationPoint?.angle ?? 0.0;
          
          // Calculate initial angle if there's a next point
          if (_animationRoute.length > 1) {
            initialAngle = _calculateAngle(initialPosition, _animationRoute[1]);
          }
          
          _animationPoint = AnimationPoint(
            position: initialPosition,
            angle: initialAngle,
          );
        }
      });
      return;
    }
    
    setState(() {
      // Move to the next point
      _currentRoutePointIndex++;
      
      final currentPoint = _animationRoute[_currentRoutePointIndex];
      
      // Calculate angle between current and next point (if available)
      double angle = _animationPoint?.angle ?? 0.0;
      if (_currentRoutePointIndex < _animationRoute.length - 1) {
        final nextPoint = _animationRoute[_currentRoutePointIndex + 1];
        angle = _calculateAngle(currentPoint, nextPoint);
      }
      
      // Update animated point position and angle
      _animationPoint = AnimationPoint(
        position: currentPoint,
        angle: angle,
      );
    });
  }
  
  double _calculateAngle(LatLng from, LatLng to) {
    // Calculate the angle between two points (in radians)
    final double dx = to.longitude - from.longitude;
    final double dy = to.latitude - from.latitude;
    return math.atan2(dx, dy);
  }
  
  // Pin mode methods
  void _togglePinMode() {
    setState(() {
      _isInPinMode = !_isInPinMode;
      
      if (_isInPinMode) {
        // If we're entering pin mode, immediately get the address of the center
        _onMapMoveEnd();
      } else {
        // If we're exiting pin mode, reset the address
        _currentAddress = "Move the map to see location addresses";
      }
    });
  }
  
  Future<void> _getAddressFromLatLng(LatLng location) async {
    setState(() {
      _isGettingAddress = true;
    });
    
    try {
      // Using Open Street Map Nominatim API for reverse geocoding
      final response = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=${location.latitude}&lon=${location.longitude}&zoom=18&addressdetails=1'
        ),
        headers: {
          'User-Agent': 'Mercab App',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        String address = data['display_name'] ?? "Unknown location";
        
        setState(() {
          _currentAddress = address;
          _isGettingAddress = false;
        });
      } else {
        setState(() {
          _currentAddress = "Error fetching address. Try moving the map to another location.";
          _isGettingAddress = false;
        });
      }
    } catch (e) {
      setState(() {
        _currentAddress = "Error fetching address. Please check your internet connection.";
        _isGettingAddress = false;
      });
    }
  }
  
  void _setAsDropOff() {
    // Get current center of the map
    final centerLocation = _mapController.camera.center;
    

    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Drop-off location set at: $_currentAddress'),
        duration: const Duration(seconds: 3),
        backgroundColor: Colors.green,
      ),
    );
    
    // Exit pin mode
    setState(() {
      _isInPinMode = false;
      
      // Add a marker for the drop-off location if needed
      // This is optional - you might want to add this to your existing marker system
      /*
      _dropOffMarker = Marker(
        width: 50.0,
        height: 50.0,
        point: centerLocation,
        child: const Icon(
          Icons.location_pin,
          color: Colors.orange,
          size: 40,
        ),
      );
      */
    });
  }
  
  @override
  void dispose() {
    _animationTimer?.cancel();
    _debounceTimer?.cancel();
    super.dispose();
  }
}