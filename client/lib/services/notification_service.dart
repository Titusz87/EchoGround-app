// client/lib/services/notification_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class NotificationService {
  static Future<void> initFirebase() async {
    // Looks for variables injected at compile time by the build engine
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: String.fromEnvironment('FIREBASE_API_KEY'),
        appId: String.fromEnvironment('FIREBASE_APP_ID'),
        messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
        projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
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
      // Looks for your VAPID key injected at compile time
      await messaging.register(
        vapidKey: const String.fromEnvironment('FIREBASE_VAPID_KEY'),
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
    // 1. Pull base deployment server path from environment parameters
    const String backendBaseUrl = String.fromEnvironment('BACKEND_URL');
    
    // 2. UPDATED: Target Evan's explicit subpath address channel
    final url = Uri.parse('$backendBaseUrl/person/create');
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        // 3. UPDATED: Match the exact variable naming conventions expected by StartupRequest
        body: jsonEncode({
          'fcm_token': token,
          'latitude': lat,
          'longitude': lng,
        }),
      );
      print('Backend registration server status code: ${response.statusCode}');
      print('Backend Response Body Array context: ${response.body}');
    } catch (e) {
      print('Network connection error: $e');
    }
  }

}
