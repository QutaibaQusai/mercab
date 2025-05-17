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
        
        // State providers
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider(create: (_) => MapProvider()),
        ChangeNotifierProvider(create: (_) => CarProvider()),
      ],
      child: MaterialApp(
        title: 'Mercab',
        theme: appTheme,
        home: const MapScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}