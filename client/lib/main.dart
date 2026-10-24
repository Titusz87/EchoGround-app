import 'package:flutter/material.dart';
import 'services/notification_service.dart';
import 'screens/guest_mode/guest_mode_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Initialize modular Firebase settings
  await NotificationService.initFirebase();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // 2. Fire off the automated location tracking loops
    NotificationService.setupPushNotifications(context);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
      ),
      // Every user in Guest mode by default
      home: const GuestModeDashboard(),
    );
  }
}
