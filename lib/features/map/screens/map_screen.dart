import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:mercab/features/map/providers/location_provider.dart';
import 'package:mercab/features/map/providers/map_provider.dart';
import 'package:mercab/features/map/providers/car_provider.dart';
import 'package:mercab/core/widgets/coordinate_input_widget.dart';
import 'package:mercab/config/constants.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(appName),
        elevation: 0,
      ),
      body: _buildMapBody(context),
    );
  }

  Widget _buildMapBody(BuildContext context) {
    final locationProvider = Provider.of<LocationProvider>(context);
    final mapProvider = Provider.of<MapProvider>(context);
    final carProvider = Provider.of<CarProvider>(context);
    
    return Stack(
      children: [
        FlutterMap(
          mapController: mapProvider.mapController,
          options: MapOptions(
            initialCenter: MapProvider.initialCenter,
            initialZoom: defaultMapZoom,
            interactionOptions: const InteractionOptions(
              enableMultiFingerGestureRace: true,
            ),
            onMapEvent: (event) {
              if (mapProvider.isInPinMode) {
                // Handle map interaction for pin mode
                if (event is MapEventMoveStart) {
                  mapProvider.setSelectingPin(true);
                } else if (event is MapEventMoveEnd) {
                  mapProvider.setSelectingPin(false);
                  mapProvider.getAddressFromCurrentCenter();
                }
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://api.maptiler.com/maps/streets/{z}/{x}/{y}.png?key=$mapTilerApiKey',    
              userAgentPackageName: 'com.example.mercab',
              subdomains: const ['a', 'b', 'c', 'd'],
            ),
            
            // Polyline Layer (Route Display)
            PolylineLayer(
              polylines: [
                if (mapProvider.showRoute && mapProvider.routePoints.isNotEmpty)
                  Polyline(
                    points: mapProvider.routePoints,
                    strokeWidth: 5.0,
                    color: Colors.black.withOpacity(0.7),
                    borderColor: Colors.white,
                    borderStrokeWidth: 1.0,
                  ),
              ],
            ),
            
            // Marker Layer
            MarkerLayer(markers: _buildAllMarkers(context)),
          ],
        ),
        
        // Center pin (only show when in pin mode)
        if (mapProvider.isInPinMode)
          _buildCenterPin(context),
        
        // Route info box (when route is active and not in pin mode)
        if (mapProvider.showRoute && 
            mapProvider.routePoints.isNotEmpty && 
            !mapProvider.isInPinMode)
          _buildRouteInfoBox(context),
        
        // Pin address box (when pin mode is active)
        if (mapProvider.isInPinMode)
          _buildPinAddressBox(context),
        
        // Map control buttons
        _buildMapControls(context),
        
        // Only show coordinate input when not in pin mode
        if (!mapProvider.isInPinMode)
          CoordinateInputWidget(
            onCoordinatesSubmitted: (lat, lng, angle) {
              _handleCoordinatesSubmitted(context, lat, lng, angle);
            },
          ),
        
        // Route calculation indicator
        if (mapProvider.isCalculatingRoute)
          _buildCalculatingRouteIndicator(),
      ],
    );
  }

  List<Marker> _buildAllMarkers(BuildContext context) {
    final locationProvider = Provider.of<LocationProvider>(context);
    final carProvider = Provider.of<CarProvider>(context);
    
    List<Marker> markers = [];
    
    // Add car markers
    for (final carMarker in carProvider.carMarkers) {
      markers.add(
        Marker(
          width: 80.0,
          height: 80.0,
          point: carMarker.position,
          child: _buildCarMarker(carMarker.angle),
        ),
      );
    }
    
    // Add animation marker
    if (carProvider.isAnimating && carProvider.animationPoint != null) {
      markers.add(
        Marker(
          width: 40.0,
          height: 40.0,
          point: carProvider.animationPoint!.position,
          child: _buildAnimationMarker(carProvider.animationPoint!.angle),
        ),
      );
    }
    
    // Add user location marker
    if (locationProvider.userLocationMarker != null) {
      markers.add(locationProvider.userLocationMarker!);
    }
    
    return markers;
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
  
  Widget _buildCenterPin(BuildContext context) {
    final mapProvider = Provider.of<MapProvider>(context);
    
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!mapProvider.isSelectingPin)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Text(
                'Drop-off',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          
          const SizedBox(height: 4),
          
          mapProvider.isSelectingPin
            ? Container(
                height: 6, 
                width: 6, 
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 5,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              )
            :  Container(
                height: 12, 
                width: 12, 
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.8),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 5,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              )
        ],
      ),
    );
  }
  
  Widget _buildRouteInfoBox(BuildContext context) {
    final mapProvider = Provider.of<MapProvider>(context);
    
    return Positioned(
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
              'Distance: ~${mapProvider.calculateRouteDistance().toStringAsFixed(2)} km',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPinAddressBox(BuildContext context) {
    final mapProvider = Provider.of<MapProvider>(context);
    
    return Positioned(
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
                  'Drop-off Location',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: mapProvider.togglePinMode,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              mapProvider.isGettingAddress ? "Fetching address..." : mapProvider.currentAddress,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
  
  // Widget _buildMapAttribution() {
  //   return Positioned(
  //     left: 10,
  //     bottom: 10,
  //     child: Container(
  //       padding: const EdgeInsets.all(4),
  //       color: Colors.white.withOpacity(0.7),
  //       child: const Text(
  //         mapAttribution,
  //         style: TextStyle(fontSize: 10, color: Colors.black87),
  //       ),
  //     ),
  //   );
  // }
  
  Widget _buildMapControls(BuildContext context) {
    final locationProvider = Provider.of<LocationProvider>(context);
    final mapProvider = Provider.of<MapProvider>(context);
    
    return Positioned(
      right: 16,
      bottom: 200,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pin mode button
          FloatingActionButton(
            heroTag: 'pinMode',
            mini: true,
            onPressed: mapProvider.togglePinMode,
            backgroundColor: mapProvider.isInPinMode ? Colors.blue : Colors.deepPurple,
            child: Icon(
              mapProvider.isInPinMode ? Icons.location_off : Icons.location_searching,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          
          // Route toggle button
          FloatingActionButton(
            heroTag: 'toggleRoute',
            mini: true,
            onPressed: mapProvider.toggleRouteDisplay,
            backgroundColor: mapProvider.showRoute ? Colors.blue : Colors.grey,
            child: Icon(
              mapProvider.showRoute ? Icons.route : Icons.route_outlined,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          
          // Current location button
          FloatingActionButton(
            heroTag: 'currentLocation',
            mini: true,
            onPressed: locationProvider.isLoading 
              ? null 
              : () async {
                  await locationProvider.getCurrentLocation();
                  if (locationProvider.currentUserLocation != null) {
                    mapProvider.moveToLocation(locationProvider.currentUserLocation!);
                    // Calculate route if needed
                    _calculateRouteIfNeeded(context);
                  } else if (locationProvider.hasLocationError) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(locationProvider.locationErrorMessage!),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                },
            backgroundColor: locationProvider.isLoading ? Colors.grey : Colors.blue,
            child: locationProvider.isLoading 
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
            onPressed: mapProvider.moveToInitialLocation,
            child: const Icon(Icons.center_focus_strong),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCalculatingRouteIndicator() {
    return Positioned(
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
    );
  }

  void _handleCoordinatesSubmitted(BuildContext context, double lat, double lng, double angle) {
    final carProvider = Provider.of<CarProvider>(context, listen: false);
    final mapProvider = Provider.of<MapProvider>(context, listen: false);
    
    // Add car marker
    carProvider.addCarMarker(lat, lng, angle);
    
    // Move map to the new marker
    mapProvider.moveToLocation(LatLng(lat, lng));
    
    // Calculate route if needed
    _calculateRouteIfNeeded(context);
    
    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Car marker added at Lat: $lat, Lng: $lng'),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.green,
      ),
    );
  }
  
  void _calculateRouteIfNeeded(BuildContext context) {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    final mapProvider = Provider.of<MapProvider>(context, listen: false);
    final carProvider = Provider.of<CarProvider>(context, listen: false);
    
    // Only calculate route if we have user location, at least one car marker, and routes are enabled
    if (locationProvider.currentUserLocation != null && 
        carProvider.carMarkers.isNotEmpty && 
        mapProvider.showRoute) {
      
      final lastCarMarker = carProvider.getLastCarMarker();
      if (lastCarMarker != null) {
        // Calculate and display route
        mapProvider.calculateRoute(
          locationProvider.currentUserLocation!,
          lastCarMarker.position,
        ).then((_) {
          // Once route is calculated, start animation
          if (mapProvider.routePoints.isNotEmpty) {
            // Animate from car to user (reversed route)
            carProvider.startAnimation(List.from(mapProvider.routePoints.reversed));
          }
        });
      }
    }
  }
}