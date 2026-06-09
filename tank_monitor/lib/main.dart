import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/telemetry_provider.dart';
import 'providers/usage_provider.dart';
import 'screens/home_screen.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/notification_service.dart';

// Handle background Firebase notifications cleanly
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await NotificationService.showNotification(message);
}

void main() async {
  // Ensure framework services are bound before initialization async calls
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Set up background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize local notification plugin channels
  await NotificationService.init();

  // Request permissions for Android 13+ / iOS devices
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    provisional: false,
    sound: true,
  );

  // Foreground message handling (when app is wide open on screen)
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    await NotificationService.showNotification(message);
  });

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
        debugShowCheckedModeBanner: false, // Hides the debug banner for a cleaner look
        theme: ThemeData(
          useMaterial3: true, // Upgrades UI components to sleek modern layouts
          colorSchemeSeed: Colors.green,
          scaffoldBackgroundColor: Colors.white,
          canvasColor: Colors.white,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}