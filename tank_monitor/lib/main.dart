import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/telemetry_provider.dart';
import 'providers/usage_provider.dart';
import 'screens/home_screen.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/notification_service.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Flutter bindings & services
  await Firebase.initializeApp();
  await NotificationService.showNotification(message);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Set up background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize local notification plugin
  await NotificationService.init();

  // Request permissions (iOS) and configure foreground handling
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    provisional: false,
    sound: true,
  );

  // Foreground message handling
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
