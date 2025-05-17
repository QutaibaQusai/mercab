import 'package:latlong2/latlong.dart';

class CarMarker {
  final LatLng position;
  final double angle;
  final String id;
  
  CarMarker({
    required this.position,
    required this.angle,
    required this.id,
  });
  
  // Add copyWith method for immutability
  CarMarker copyWith({
    LatLng? position,
    double? angle,
    String? id,
  }) {
    return CarMarker(
      position: position ?? this.position,
      angle: angle ?? this.angle,
      id: id ?? this.id,
    );
  }
}