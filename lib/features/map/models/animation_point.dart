import 'package:latlong2/latlong.dart';

class AnimationPoint {
  final LatLng position;
  final double angle;
  
  AnimationPoint({
    required this.position,
    required this.angle,
  });
  
  // Add copyWith method for immutability
  AnimationPoint copyWith({
    LatLng? position,
    double? angle,
  }) {
    return AnimationPoint(
      position: position ?? this.position,
      angle: angle ?? this.angle,
    );
  }
}