import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

class LocationUtils {
  // Calculate distance between two points in kilometers
  static double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const int earthRadius = 6371; 
    
    final double latDistance = _toRadians(lat2 - lat1);
    final double lonDistance = _toRadians(lon2 - lon1);
    
    final double a = math.sin(latDistance / 2) * math.sin(latDistance / 2) +
                     math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
                     math.sin(lonDistance / 2) * math.sin(lonDistance / 2);
    
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }
  
  // Calculate distance between two LatLng points
  static double calculateDistanceBetweenPoints(LatLng point1, LatLng point2) {
    return calculateDistance(
      point1.latitude, point1.longitude,
      point2.latitude, point2.longitude
    );
  }
  
  // Calculate total distance for a route
  static double calculateRouteDistance(List<LatLng> points) {
    if (points.isEmpty) return 0;
    
    double totalDistance = 0;
    for (int i = 0; i < points.length - 1; i++) {
      totalDistance += calculateDistanceBetweenPoints(points[i], points[i + 1]);
    }
    
    return totalDistance;
  }
  
  // Calculate angle between two points (in radians)
  static double calculateAngle(LatLng from, LatLng to) {
    final double dx = to.longitude - from.longitude;
    final double dy = to.latitude - from.latitude;
    return math.atan2(dx, dy);
  }
  
  // Convert degrees to radians
  static double _toRadians(double degree) {
    return degree * (math.pi / 180);
  }
  
  // Convert radians to degrees
  static double toDegrees(double radians) {
    return radians * (180 / math.pi);
  }
  
  // Generate a fallback route (straight line with slight curve)
  static List<LatLng> generateFallbackRoute(LatLng start, LatLng end) {
    // Create a more natural path with intermediate points
    final middlePoint = LatLng(
      (start.latitude + end.latitude) / 2,
      (start.longitude + end.longitude) / 2
    );
    
    // Add a slight offset to create a curved path
    final offset = 0.002; // Slight curve
    
    return [
      start,
      LatLng(
        middlePoint.latitude + offset,
        middlePoint.longitude - offset,
      ),
      end
    ];
  }
}