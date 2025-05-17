// lib/features/map/repositories/map_repository.dart

import 'package:latlong2/latlong.dart';
import 'package:mercab/core/services/location_service.dart';

abstract class MapRepository {
  Future<LatLng> getCurrentLocation();
  Future<LocationData> getCurrentLocationWithDetails();
  Stream<LocationData> getLocationStream();
  Future<List<LatLng>> calculateRoute(LatLng start, LatLng end);
  Future<String> getAddressFromLocation(LatLng location);
}