import 'package:latlong2/latlong.dart';

abstract class MapRepository {
  Future<LatLng> getCurrentLocation();
  Future<List<LatLng>> calculateRoute(LatLng start, LatLng end);
  Future<String> getAddressFromLocation(LatLng location);
}