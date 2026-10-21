// client/lib/services/notification_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class NotificationService {
  static Future<void> initFirebase() async {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "YOUR_API_KEY",
        appId: "YOUR_APP_ID",
        messagingSenderId: "YOUR_SENDER_ID",
        projectId: "YOUR_PROJECT_ID",
      ),
    );
  }

  static Future<void> setupPushNotifications(BuildContext context) async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    NotificationSettings settings = await messaging.requestPermission();
    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
       print('Push notification permissions denied by user.');
       return;
    }

    messaging.onRegistered.listen((String installationId) async {
      print("FCM Web Application Registered. ID: $installationId");
      
      try {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) return;

        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) return;
        }
        
        if (permission == LocationPermission.deniedForever) return;

        // UPDATED: Modern geolocation positional tracking using LocationSettings wrapper
        Position position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );
        print("Live Coordinates: Lat: ${position.latitude}, Lng: ${position.longitude}");

        await _sendTokenToExternalServer(installationId, position.latitude, position.longitude);

      } catch (e) {
        print('Error gathering real-time spatial footprint data: $e');
      }
    }).onError((err) {
      print('Error getting Firebase Installation ID from stream: $err');
    });

    try {
      await messaging.register(
        vapidKey: "YOUR_PUBLIC_VAPID_KEY_FROM_FIREBASE_CONSOLE",
      );
    } catch (e) {
      print('Error during FCM web manual registration handshake step: $e');
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Foreground dataset update received: ${message.data}');
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message.data['body'] ?? 'New Incident Updated Nearby!'),
            backgroundColor: Colors.teal,
          ),
        );
      }
    });
  }

  static Future<void> _sendTokenToExternalServer(String token, double lat, double lng) async {
    final url = Uri.parse('https://your-external-backend-server.com');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': token, 'lat': lat, 'lng': lng}),
      );
      print('Backend registration server status code: ${response.statusCode}');
    } catch (e) {
      print('Error mapping payload onto external structure: $e');
    }
  }
}
