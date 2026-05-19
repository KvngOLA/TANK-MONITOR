import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/telemetry_provider.dart';
import 'providers/usage_provider.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const TankMonitorApp());
}

class TankMonitorApp extends StatelessWidget {
  const TankMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TelemetryProvider()),
        ChangeNotifierProvider(create: (_) => UsageProvider()),
      ],
      child: MaterialApp(
        title: 'Tank Monitor',
        theme: ThemeData(
          scaffoldBackgroundColor: Colors.white,
          primarySwatch: Colors.green,
          canvasColor: Colors.white,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
