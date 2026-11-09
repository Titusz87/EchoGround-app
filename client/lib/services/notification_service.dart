import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import 'database_helper.dart';

class NotificationService {
  static Future<void> initFirebase() async {
    // Looks for variables injected at compile time by the build engine
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: String.fromEnvironment('FIREBASE_API_KEY'),
        appId: String.fromEnvironment('FIREBASE_APP_ID'),
        messagingSenderId: String.fromEnvironment(
          'FIREBASE_MESSAGING_SENDER_ID',
        ),
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

    try {
      // Looks for VAPID key injected at compile time
      await messaging.register(
        vapidKey: const String.fromEnvironment('FIREBASE_VAPID_KEY'),
      );
    } catch (e) {
      print('Error during FCM web manual registration handshake step: $e');
    }

    // Get the generated registration token value
    try {
      // ignore: deprecated_member_use
      String? token = await messaging.getToken(
        vapidKey: const String.fromEnvironment('FIREBASE_VAPID_KEY'),
      );

      if (token != null && token.isNotEmpty) {
        print("FCM Web Application Registered. Token: $token");

        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (serviceEnabled) {
          LocationPermission permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }

          if (permission != LocationPermission.denied &&
              permission != LocationPermission.deniedForever) {
            Position position = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.low,
                timeLimit: Duration(seconds: 5),
              ),
            );
            print(
              "Live Coordinates: Lat: ${position.latitude}, Lng: ${position.longitude}",
            );

            // Cache the raw coordinates in app memory for the header to grab instantly
            DatabaseHelper.instance.cachedLat = position.latitude;
            DatabaseHelper.instance.cachedLng = position.longitude;

            // REAL-TIME SIGNAL BROADCAST: Trigger the database change notification value
            DatabaseHelper.instance.syncNotifier.value++;

            // --- SMART ROUTING MANAGER ENGINE ---
            // Check if this device already holds an established backend profile row index
            final String? savedPersonId = await DatabaseHelper.instance
                .getConfig('backend_person_id');
            final String? lastSavedToken = await DatabaseHelper.instance
                .getConfig('last_fcm_token');

            // Optimization Guard: Skip network entirely if the token hasn't changed
            if (lastSavedToken == token) {
              print("FCM token matches stored state. Skipping network sync.");
              return;
            }

            if (savedPersonId != null) {
              final int? parsedId = int.tryParse(savedPersonId);
              if (parsedId != null) {
                print(
                  "Local Profile ID ($parsedId) detected. Executing in-place token update...",
                );
                final bool updateSuccess = await _updateTokenOnExternalServer(
                  parsedId,
                  token,
                );

                if (updateSuccess) {
                  await DatabaseHelper.instance.saveConfig(
                    'last_fcm_token',
                    token,
                  );
                  print("Token updated successfully for active profile row.");
                  return;
                }
              }
            }

            // Fallback: If no cached row is found, proceed with a fresh registration
            print(
              "No local identity record found. Registering a brand new row mapping...",
            );
            await _sendTokenToExternalServer(
              token,
              position.latitude,
              position.longitude,
            );
          }
        }
      } else {
        print('FCM registration token returned null or empty.');
      }
    } catch (e) {
      print('Error gathering real-time spatial footprint data: $e');
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      try {
        if (message.data != null) {
          // Force convert the raw web object tree into a native, type-safe Dart Map
          final Map<String, dynamic> cleanData = Map<String, dynamic>.from(
            message.data,
          );

          print('Foreground dataset update received and sanitized: $cleanData');

          // 1. ANNOUNCEMENT INTERCEPTOR & FILTER FILTER MODULE
          final String typeStr = (cleanData['type'] ?? '').toString();
          if (typeStr.contains('Announcement')) {
            // Extracts the correct CAPITALIZED key matching backend log payload model
            final String? incomingBody =
                cleanData['Message']?.toString() ??
                cleanData['body']?.toString() ??
                cleanData['message']?.toString();

            if (incomingBody != null) {
              // Permanently persist the clean announcement text message right into  SQLite device configuration keys
              await DatabaseHelper.instance.saveConfig(
                'last_live_announcement',
                incomingBody.trim(),
              );

              // Force fire the system listener notifier to paint the text marquee bar across screens
              DatabaseHelper.instance.syncNotifier.value++;
              print(
                "🎯 ANNOUNCEMENT FILTER ENGAGED: Wiped out report card duplicate and updated banner keys to: $incomingBody",
              );
            }

            // CRITICAL EXIT HANDSHAKE: Aborts the function chain right here so it NEVER drops below
            // to generate a report tile inside your dashboard data tables layout grid!
            return;
          }

          // DYNAMIC VALIDATION INTERCEPTOR HOOK
          // Extracts the numeric ID fragment pushed out from your backend FCM real-time module
          final dynamic validatedId =
              cleanData['validated_id'] ??
              cleanData['incident_id'] ??
              cleanData['id'];
          if (validatedId != null) {
            final String targetNumericId = validatedId.toString().trim();

            // Query local caching tables to scan and flag the matching incident
            final List<Map<String, dynamic>> localItems = await DatabaseHelper
                .instance
                .fetchAllNotifications();

            for (final item in localItems) {
              final String currentId = item['id']?.toString() ?? '';

              // Checks if the row ID matches or encapsulates the backend digits string slice
              if (currentId == targetNumericId ||
                  currentId.contains(targetNumericId)) {
                final db = await DatabaseHelper.instance.database;
                await db.execute(
                  "UPDATE notifications SET status = 'validated' WHERE id = ?",
                  [currentId],
                );

                // Fire the listenable notifier system to paint the green chip overlays on the Household view
                DatabaseHelper.instance.syncNotifier.value++;
                print(
                  " REAL-TIME RECOVERY HANDSHAKE: Mutated status for cache row $currentId to 'validated'.",
                );
                break;
              }
            }
          }

          if (context.mounted) {
            // Extract values safely from the clean, native Dart Map
            final snackBarText =
                cleanData['body']?.toString() ??
                cleanData['message']?.toString() ??
                cleanData['Message']?.toString() ?? // Fallback to capitalized if snackbar needs to draw it
                'New Incident Updated Nearby!';

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(snackBarText),
                backgroundColor: Colors.teal,
              ),
            );
          }
        }
      } catch (e) {
        print('Intercepted a snackbar payload processing issue safely: $e');
      }
    });
  }

  /// Initial Registration: Spawns a new profile entry on the backend and captures the generated ID
  static Future<void> _sendTokenToExternalServer(
    String token,
    double lat,
    double lng,
  ) async {
    const String backendBaseUrl = String.fromEnvironment('BACKEND_URL');
    final url = Uri.parse('$backendBaseUrl/person/create');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fcm_token': token,
          'latitude': lat,
          'longitude': lng,
        }),
      );
      print('Backend registration server status code: ${response.statusCode}');
      print('Backend Response Body Array context: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final dynamic assignedId =
            responseData['person_id'] ?? responseData['id'];

        if (assignedId != null) {
          final String idString = assignedId.toString();
          await DatabaseHelper.instance.saveConfig(
            'backend_person_id',
            idString,
          );
          await DatabaseHelper.instance.saveConfig('last_fcm_token', token);

          print(
            'Bound identity stored to local storage container. Active Person ID: $idString',
          );
        }
      }
    } catch (e) {
      print('Network connection error: $e');
    }
  }

  /// In-place Update: Dispatches the new token to update with matching cached ID
  static Future<bool> _updateTokenOnExternalServer(
    int personId,
    String newFcmToken,
  ) async {
    const String backendBaseUrl = String.fromEnvironment('BACKEND_URL');
    final url = Uri.parse('$backendBaseUrl/person/update-token');

    try {
      final response = await http.patch(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id': personId, 'new_token': newFcmToken}),
      );

      print('Backend update token status code: ${response.statusCode}');
      print('Backend Update Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        return responseData['status'] == 'ok';
      }
      return false;
    } catch (e) {
      print('Error dispatching token update metadata to backend: $e');
      return false;
    }
  }
}
