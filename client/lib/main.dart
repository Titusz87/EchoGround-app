import 'package:flutter/material.dart';

import 'services/notification_service.dart';
import 'screens/guest_mode/guest_mode_dashboard.dart';
import 'services/database_helper.dart';
import 'screens/app_gatekeeper.dart';

import 'package:firebase_messaging/firebase_messaging.dart';

import 'services/web_listener_stub.dart'
    if (dart.library.js) 'services/web_listener.dart';

void initializeNotificationDatabaseSync() async {
  // Enforces data connection locks cleanly right at boot time
  await DatabaseHelper.instance.database;

  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    try {
      if (message.data != null) {
        final Map<String, dynamic> cleanData = Map<String, dynamic>.from(
          message.data,
        );
        if (cleanData.isNotEmpty) {
          print(
            "Foreground raw payload sanitized safely. Ingesting row entries...",
          );
          await DatabaseHelper.instance.insertNotification(cleanData);
        }
      }
    } catch (e) {
      print("Intercepted a foreground payload extraction issue safely: $e");
    }
  });

  initWebMessageListener();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.initFirebase();
  initializeNotificationDatabaseSync();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _pushStarted = false;
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
      home: Builder(
        builder: (context) {
          if (!_pushStarted) {
            _pushStarted = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) NotificationService.setupPushNotifications(context);
            });
          }
          return const AppGatekeeper();
        },
      ),
    );
  }
}
