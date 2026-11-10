import 'dart:async';
import 'dart:convert';
<<<<<<< HEAD
import 'package:flutter/foundation.dart' show kIsWeb;
=======

>>>>>>> origin/main
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import 'database_helper.dart';

class NotificationService {
  static Future<void> initFirebase() async {
<<<<<<< HEAD
    await Firebase.initializeApp(options: const FirebaseOptions(
      apiKey: String.fromEnvironment('FIREBASE_API_KEY'),
      appId: String.fromEnvironment('FIREBASE_APP_ID'),
      messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
      projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
    ));
=======
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
>>>>>>> origin/main
  }

  static Future<void>? _setupInFlight;
  static Completer<int?>? _identityReady;
  static bool _foregroundListenerAttached = false;
  static String registrationStage = 'starting device setup';
  static String? lastRegistrationError;
  static String? currentRegistrationToken;
  static final _db = DatabaseHelper.instance;

<<<<<<< HEAD
  static void _stage(String value) {
    registrationStage = value;
    // Diagnostic stages only: no tokens, coordinates, names or passwords.
    debugPrint('Device setup: $value');
  }
  static int? _id(String? value) {
    final result = int.tryParse((value ?? '').trim());
    return result != null && result >= 0 ? result : null;
  }
  static void _ready(int id) {
    if (_identityReady != null && !_identityReady!.isCompleted) _identityReady!.complete(id);
  }
=======
    NotificationSettings settings = await messaging.requestPermission();
    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      print('Push notification permissions denied by user.');
      return;
    }
>>>>>>> origin/main

  /// Wait for the identity, not all notification/background setup work.
  static Future<int?> ensureDeviceIdentity(BuildContext context) async {
    final cached = _id(await _db.getConfig('backend_person_id').timeout(const Duration(seconds: 8)));
    if (cached != null) return cached;
    final ready = _identityReady ??= Completer<int?>();
    unawaited(setupPushNotifications(context));
    try {
      return await ready.future.timeout(const Duration(seconds: 35));
    } on TimeoutException {
      lastRegistrationError = 'Device setup is still $registrationStage. Check any permission prompts and retry.';
      return null;
    }
  }

  static Future<void> setupPushNotifications(BuildContext context) {
    if (_setupInFlight != null) return _setupInFlight!;
    _identityReady ??= Completer<int?>();
    return _setupInFlight = _runSetup(context);
  }

  static Future<void> _runSetup(BuildContext context) async {
    lastRegistrationError = null;
    try {
      _attachForegroundListener(context);
      _stage('reading the saved device ID');
      final savedId = _id(await _db.getConfig('backend_person_id').timeout(const Duration(seconds: 8)));
      if (savedId != null) _ready(savedId);

      final messaging = FirebaseMessaging.instance;
      _stage('waiting for notification permission');
      final settings = await messaging.requestPermission().timeout(const Duration(seconds: 12));
      if (![AuthorizationStatus.authorized, AuthorizationStatus.provisional].contains(settings.authorizationStatus)) {
        throw StateError('Notification permission is blocked. This backend currently needs an FCM token for initial device registration. Allow notifications for this app, then retry. Existing saved device IDs can still sign in.');
      }

      _stage('requesting a Firebase notification token');
      // Keep the existing backend-compatible registration-token mode. Do not
      // also call register(), which uses the newer Firebase installation flow.
      // ignore: deprecated_member_use
<<<<<<< HEAD
      final token = await messaging.getToken(
        vapidKey: kIsWeb ? const String.fromEnvironment('FIREBASE_VAPID_KEY') : null,
      ).timeout(const Duration(seconds: 12));
      if (token == null || token.isEmpty) throw StateError('Firebase did not supply a notification token. Check the Firebase configuration and web service worker.');
      currentRegistrationToken = token;

      if (savedId != null) {
        // Known accounts never wait for GPS and are never replaced after an error.
        _stage('updating the notification token');
        final oldToken = await _db.getConfig('last_fcm_token').timeout(const Duration(seconds: 8));
        if (oldToken != token) {
          final response = await http.patch(_url('/person/update-token'), headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'id': savedId, 'new_token': token})).timeout(const Duration(seconds: 15));
          if (response.statusCode != 200 || (jsonDecode(response.body) as Map)['status'] != 'ok') {
            throw StateError('Could not update notifications. The saved device ID has been retained.');
=======
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
>>>>>>> origin/main
          }
          await _db.saveConfig('last_fcm_token', token).timeout(const Duration(seconds: 8));
        }
        // Refresh location for the existing home header, after identity is ready.
        try { await _position(); } catch (_) { debugPrint('Device setup: location unavailable; saved identity retained.'); }
        return;
      }

      _stage('obtaining the location required for initial registration');
      final position = await _position();
      // Check again before creating: another caller may have already saved it.
      final existing = _id(await _db.getConfig('backend_person_id').timeout(const Duration(seconds: 8)));
      if (existing != null) { _ready(existing); return; }
      _stage('registering the device with the backend');
      final response = await http.post(_url('/person/create'), headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'fcm_token': token, 'latitude': position.latitude, 'longitude': position.longitude})).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw StateError('Device registration was rejected by the backend (HTTP ${response.statusCode}).');
      }
      final result = jsonDecode(response.body) as Map;
      final assigned = _id((result['person_id'] ?? result['id'])?.toString());
      if (assigned == null) throw StateError('The backend response did not contain a valid person_id.');
      _stage('saving the device ID on this device');
      final database = await _db.database;
      // Compare and write atomically with the login metadata transaction. An
      // older /person/create response cannot overwrite a recovered account.
      final effectiveId = await database.transaction<int>((txn) async {
        final rows = await txn.query('device_config', where: 'key = ?', whereArgs: ['backend_person_id']);
        final current = _id(rows.isEmpty ? null : rows.first['value']?.toString());
        if (current != null && current != assigned) return current;
        await txn.rawInsert('INSERT OR REPLACE INTO device_config (key, value) VALUES (?, ?)', ['backend_person_id', '$assigned']);
        return assigned;
      }).timeout(const Duration(seconds: 8));
      _ready(effectiveId);
      if (effectiveId != assigned) return;
      await _db.saveConfig('last_fcm_token', token).timeout(const Duration(seconds: 8));
    } on TimeoutException {
      lastRegistrationError = 'Timed out while $registrationStage. ${registrationStage.contains('Firebase') ? 'Check Firebase, the VAPID configuration and service worker.' : registrationStage.contains('permission') ? 'Check the notification permission prompt.' : registrationStage.contains('location') ? 'Check location permission and location services.' : registrationStage.contains('saved') || registrationStage.contains('saving') ? 'Local storage did not respond; keep your saved data and restart the client.' : 'Check the backend connection.'}';
      debugPrint('Device setup timeout: $registrationStage');
    } on StateError catch (failure) {
      lastRegistrationError = failure.message.toString();
      debugPrint('Device setup stopped at: $registrationStage');
    } catch (_) {
      lastRegistrationError = 'Device setup failed while $registrationStage. Check the client console for platform configuration errors.';
      debugPrint('Device setup failed at: $registrationStage');
    } finally {
      if (_identityReady != null && !_identityReady!.isCompleted) _identityReady!.complete(null);
      _identityReady = null;
      _setupInFlight = null;
    }
  }

<<<<<<< HEAD
  static Uri _url(String path) {
    const base = String.fromEnvironment('BACKEND_URL');
    if (base.trim().isEmpty) throw StateError('BACKEND_URL is missing from the client configuration.');
    return Uri.parse('${base.replaceFirst(RegExp(r'/+$'), '')}$path');
  }

  static Future<Position> _position() async {
    if (!await Geolocator.isLocationServiceEnabled().timeout(const Duration(seconds: 5))) throw StateError('Enable location services for initial device registration.');
    var permission = await Geolocator.checkPermission().timeout(const Duration(seconds: 5));
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission().timeout(const Duration(seconds: 12));
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) throw StateError('Allow location access for initial device registration.');
    final position = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 5))).timeout(const Duration(seconds: 7));
    _db.cachedLat = position.latitude;
    _db.cachedLng = position.longitude;
    _db.syncNotifier.value++;
    return position;
  }

  static void _attachForegroundListener(BuildContext context) {
    if (_foregroundListenerAttached) return;
    _foregroundListenerAttached = true;
    FirebaseMessaging.onMessage.listen((message) {
      if (!context.mounted) return;
      final body = message.data['body']?.toString() ?? message.notification?.body ?? 'New community update';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(body), backgroundColor: Colors.teal));
    });
  }
=======
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
>>>>>>> origin/main
}
