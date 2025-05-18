// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mercab/features/map/providers/location_provider.dart';
import 'package:mercab/features/map/providers/map_provider.dart';
import 'package:mercab/features/map/providers/car_provider.dart';
import 'package:mercab/features/map/screens/map_screen.dart';
import 'package:mercab/config/theme.dart';
import 'package:mercab/data/repositories/map_repository_impl.dart';
import 'package:mercab/features/map/repositories/map_repository.dart';

void main() {
  // Ensure Flutter is initialized before plugins
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Repository providers
        Provider<MapRepository>(
          create: (_) => MapRepositoryImpl(),
        ),
        
        // Map and Car providers
        ChangeNotifierProvider(
          create: (context) => MapProvider(
            repository: Provider.of<MapRepository>(context, listen: false),
          ),
        ),
        ChangeNotifierProvider(create: (_) => CarProvider()),
      ],
      child: MaterialApp(
        title: 'Mercab',
        theme: appTheme,
        home: const AnimatedLocationApp(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

// Widget to create the animated location provider
class AnimatedLocationApp extends StatefulWidget {
  const AnimatedLocationApp({Key? key}) : super(key: key);

  @override
  _AnimatedLocationAppState createState() => _AnimatedLocationAppState();
}

class _AnimatedLocationAppState extends State<AnimatedLocationApp> with TickerProviderStateMixin {
  late LocationProvider _locationProvider;

  @override
  void initState() {
    super.initState();
    final repository = Provider.of<MapRepository>(context, listen: false);
    _locationProvider = LocationProvider(repository: repository);
    _locationProvider.vsync = this;
    
    // Optionally set a custom animation speed
    // _locationProvider.animationSpeedFactor = 2.0; // Twice as slow
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _locationProvider,
      child: const MapScreen(),
    );
  }

  @override
  void dispose() {
    _locationProvider.dispose();
    super.dispose();
  }
}