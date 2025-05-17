import 'package:flutter/material.dart';
import 'package:mercab/features/map/screens/map_screen.dart';

class AppRoutes {
  static const String map = '/';
  
  static Map<String, WidgetBuilder> getRoutes() {
    return {
      map: (context) => const MapScreen(),
    };
  }
}