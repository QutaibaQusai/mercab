// lib/data/repositories/map_repository_impl.dart

import 'package:latlong2/latlong.dart';
import 'package:mercab/core/services/location_service.dart';
import 'package:mercab/core/services/routing_service.dart';
import 'package:mercab/features/map/repositories/map_repository.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class MapRepositoryImpl implements MapRepository {
  @override
  Future<LatLng> getCurrentLocation() async {
    return await LocationService.getCurrentLocation();
  }
  
  @override
  Future<LocationData> getCurrentLocationWithDetails() async {
    return await LocationService.getCurrentLocationWithDetails();
  }
  
  @override
  Stream<LocationData> getLocationStream() {
    return LocationService.getLocationStream();
  }
  
  @override
  Future<List<LatLng>> calculateRoute(LatLng start, LatLng end) async {
    return await RoutingService.getRoute(start, end);
  }
  
  @override
  Future<String> getAddressFromLocation(LatLng location) async {
    try {
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
        return data['display_name'] ?? "Unknown location";
      } else {
        return "Error fetching address. Try moving the map to another location.";
      }
    } catch (e) {
      return "Error fetching address. Please check your internet connection.";
    }
  }
}