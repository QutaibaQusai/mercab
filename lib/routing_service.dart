import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:flutter/material.dart';

class RoutingService {
  static const String _baseUrl = 'https://api.openrouteservice.org/v2/directions/';
  static const String _apiKey = '5b3ce3597851110001cf6248305bac4e21e74502aefe00a9539a4515';
  
  static Future<List<LatLng>> getRoute(LatLng start, LatLng end) async {
    try {
      debugPrint('Calculating route from ${start.latitude},${start.longitude} to ${end.latitude},${end.longitude}');
      
      final response = await http.post(
        Uri.parse('${_baseUrl}driving-car/geojson'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json, application/geo+json, application/gpx+xml, img/png; charset=utf-8',
          'Authorization': _apiKey,
        },
        body: jsonEncode({
          'coordinates': [
            [start.longitude, start.latitude],
            [end.longitude, end.latitude],
          ],
        }),
      );
      
      debugPrint('Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          
          if (data == null) {
            debugPrint('API response is null');
            return _getFallbackRoute(start, end);
          }
          
          if (!data.containsKey('features') || 
                ['features'] == null || 
              data['features'].isEmpty) {
            debugPrint('No features in API response');
            return _getFallbackRoute(start, end);
          }
          
          final features = data['features'];
          if (features[0] == null || 
              !features[0].containsKey('geometry') || 
              features[0]['geometry'] == null) {
            debugPrint('No geometry in API response');
            return _getFallbackRoute(start, end);
          }
          
          final geometry = features[0]['geometry'];
          if (!geometry.containsKey('coordinates') || 
              geometry['coordinates'] == null) {
            debugPrint('No coordinates in API response');
            return _getFallbackRoute(start, end);
          }
          
          final coordinates = geometry['coordinates'] as List;
          List<LatLng> points = [];
          
          for (var coord in coordinates) {
            if (coord is List && coord.length >= 2) {
              points.add(LatLng(coord[1], coord[0]));
            }
          }
          
          if (points.isEmpty) {
            debugPrint('No valid coordinates found in API response');
            return _getFallbackRoute(start, end);
          }
          
          debugPrint('Route calculated: ${points.length} points');
          return points;
        } catch (e) {
          debugPrint('Error parsing API response: $e');
          return _getFallbackRoute(start, end);
        }
      } else {
        debugPrint('Failed to calculate route: ${response.statusCode} - ${response.body}');
        
        return _getRouteWithAlternativeMethod(start, end);
      }
    } catch (e) {
      debugPrint('Error calculating route: $e');
      return _getRouteWithAlternativeMethod(start, end);
    }
  }
  
  static Future<List<LatLng>> _getRouteWithAlternativeMethod(LatLng start, LatLng end) async {
    try {
      debugPrint('Trying alternative routing method');
      
      final String coordinates = '${start.longitude},${start.latitude}|${end.longitude},${end.latitude}';
      final Uri uri = Uri.parse('https://api.openrouteservice.org/v2/directions/driving-car')
          .replace(queryParameters: {
        'api_key': _apiKey,
        'coordinates': coordinates,
        'format': 'geojson',
      });
      
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          
          if (data != null && 
              data.containsKey('features') && 
              data['features'] != null && 
              data['features'].isNotEmpty) {
            
            final features = data['features'];
            final geometry = features[0]['geometry'];
            final coordinates = geometry['coordinates'] as List;
            
            List<LatLng> points = [];
            for (var coord in coordinates) {
              if (coord is List && coord.length >= 2) {
                points.add(LatLng(coord[1], coord[0]));
              }
            }
            
            if (points.isNotEmpty) {
              debugPrint('Alternative route method successful: ${points.length} points');
              return points;
            }
          }
        } catch (e) {
          debugPrint('Error in alternative method: $e');
        }
      } else {
        debugPrint('Alternative method failed: ${response.statusCode} - ${response.body}');
      }
      
      // If everything fails, return fallback route
      return _getFallbackRoute(start, end);
    } catch (e) {
      debugPrint('Error in alternative method: $e');
      return _getFallbackRoute(start, end);
    }
  }
  
  // Generate a fallback route (straight line)
  static List<LatLng> _getFallbackRoute(LatLng start, LatLng end) {
    debugPrint('Using fallback route (straight line)');
    
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