import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationService {
  /// Determine the current position of the device.
  /// 
  /// Returns a [Future] that resolves to a [LatLng] containing the device's position.
  /// 
  /// When the location services are not enabled or permissions are denied,
  /// a [LocationServiceException] will be thrown.
  static Future<LatLng> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationServiceException(
        'Location services are disabled. Please enable location in your device settings.',
      );
    }

    // Check location permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw LocationServiceException(
          'Location permissions are denied. Please allow location access.',
        );
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      throw LocationServiceException(
        'Location permissions are permanently denied. Please enable in app settings.',
      );
    } 

    // Get the current position.
    final position = await Geolocator.getCurrentPosition();
    return LatLng(position.latitude, position.longitude);
  }
}

class LocationServiceException implements Exception {
  final String message;
  
  LocationServiceException(this.message);
  
  @override
  String toString() => 'LocationServiceException: $message';
}