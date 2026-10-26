import 'package:flutter/material.dart';
import 'services/notification_service.dart';
import 'screens/guest_mode/guest_mode_dashboard.dart';
import 'services/database_helper.dart'; 
import 'package:firebase_messaging/firebase_messaging.dart';

// Modern conditional import: Swaps out the blank mobile stub for the real web listener when running on a browser
import 'services/web_listener_stub.dart'
    if (dart.library.js) 'services/web_listener.dart';

void initializeNotificationDatabaseSync() async {
  // CASE 1: App is open/active in the foreground (Works everywhere out-of-the-box)
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    if (message.data.isNotEmpty) {
      await DatabaseHelper.instance.insertNotification(message.data);
    }
  });

  // CASE 2: Background capture logic (Runs code on Web, safely runs a blank function on Mobile)
  initWebMessageListener();

  // --- SQLite Local Verification Debug Loop ---
  try {
    print("Checking local SQLite cache contents...");
    final storedIncidents = await DatabaseHelper.instance.fetchAllNotifications();
    
    if (storedIncidents.isEmpty) {
      print("SQLite Status: Connected cleanly, but database is currently EMPTY.");
    } else {
      print("SQLite Status: Found ${storedIncidents.length} saved entries!");
      for (var row in storedIncidents) {
        print("   -> Loaded Incident ID: ${row['id']} | Event Type: ${row['event_type']} | Status: ${row['status']}");
      }
    }
  } catch (e) {
    print("SQLite Database Error during startup: $e");
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize modular Firebase settings
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
    // Fire off the automated location tracking loops
    NotificationService.setupPushNotifications(context);
    
    // Activate the cross-platform SQLite background listener tracking loops
    initializeNotificationDatabaseSync();
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
      home: const GuestModeDashboard(),
    );
  }
}

