import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'database_helper.dart';
import 'session_store.dart';
import 'notification_service.dart';

class AuthService {
  static String? lastError;
  static const String _backendBaseUrl = String.fromEnvironment('BACKEND_URL');

  /// Verifies if local storage holds a valid backend identity key.
  /// Safely returns null on missing values so the dashboard stays in Guest Mode.
  static Future<int?> ensureBackendPersonId(BuildContext context) async {
    lastError = null;
    try {
      final raw = await DatabaseHelper.instance.getConfig('backend_person_id').timeout(const Duration(seconds: 8));
      final saved = int.tryParse((raw ?? '').trim());
      if (saved != null && saved >= 0) return saved;
    } on TimeoutException {
      lastError = 'Could not read the saved device ID: local storage did not respond. Keep your saved data and restart the client.';
      return null;
    }
    try {
      final id = await NotificationService.ensureDeviceIdentity(context);
      if (id == null) lastError = NotificationService.lastRegistrationError ?? 'Device setup has not finished. Retry after checking permission prompts.';
      return id;
    } on TimeoutException {
      lastError = 'Local device storage did not respond. Restart the client without clearing its saved data.';
      return null;
    }
  }

  /// Handles Login Requests for both Roles dynamically with validation
  static Future<bool> login({
    int? id,
    String? phone,
    required String password,
    required bool isLeader,
  }) async {
    lastError = null;
    final number = phone?.trim();
    if ((number == null || number.isEmpty) && id == null) {
      lastError = 'Enter the phone number used when you created this account.';
      return false;
    }
    final endpoint = isLeader ? 'community-leader/login' : 'household/login';
    try {
      // A notification token is optional. Phone/password login never waits for
      // GPS, notification permission or a new backend device registration.
      String? token = NotificationService.currentRegistrationToken;
      if (token == null || token.isEmpty) {
        try { token = await DatabaseHelper.instance.getConfig('last_fcm_token').timeout(const Duration(seconds: 2)); } catch (_) {}
      }
      final response = await http.post(Uri.parse('$_backendBaseUrl/$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          if (number != null && number.isNotEmpty) 'phone': number else 'id': id,
          'password': password,
          if (token != null && token.isNotEmpty) 'fcm_token': token,
        }),
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        lastError = response.statusCode == 401
            ? 'The phone number and password do not match an account for this role.'
            : 'Sign-in was rejected by the backend (HTTP ${response.statusCode}).';
        return false;
      }
      final data = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
      if (data['status'] != 'ok') { lastError = 'The backend did not confirm sign-in.'; return false; }
      final accountId = int.tryParse((data['id'] ?? ((number == null || number.isEmpty) ? id : null))?.toString() ?? '');
      if (accountId == null || accountId < 0) {
        lastError = 'The login response has no account ID. Apply the matching backend update and restart it.';
        return false;
      }
      final db = DatabaseHelper.instance;
      final database = await db.database;
      final metadata = <String, String>{'backend_person_id': '$accountId'};
      if (isLeader) {
        metadata['auth_leader_name'] = data['first_name']?.toString() ?? '';
        metadata['auth_community_name'] = data['community_name']?.toString() ?? '';
        metadata['community_name'] = metadata['auth_community_name']!;
        metadata['meta_community_mapping_$accountId'] = metadata['auth_community_name']!;
      } else {
        metadata['household_last_name'] = data['last_name']?.toString() ?? '';
        metadata['household_count'] = data['count']?.toString() ?? '';
        metadata['household_profile.v1.$accountId'] = jsonEncode({
          'family': metadata['household_last_name'], 'count': data['count'],
          'community': data['community_name']?.toString() ?? '',
        });
      }
      await database.transaction((txn) async {
        for (final entry in metadata.entries) {
          await txn.rawInsert('INSERT OR REPLACE INTO device_config (key, value) VALUES (?, ?)', [entry.key, entry.value]);
        }
      });
      // Always use the server-confirmed account, never the pre-login device ID.
      await SessionStore.activate(id: accountId, isLeader: isLeader);
      db.syncNotifier.value++;
      return true;
    } catch (failure) {
      lastError = failure is TimeoutException
          ? 'The sign-in server did not respond within 15 seconds. Check the backend and retry.'
          : 'Could not complete sign-in. Check the backend connection and client storage.';
      return false;
    }
  }

  /// Looks for individual numeric word sequences inside a text phrase dynamically
  static String? _parseNumericValueFromString(String sentence) {
    try {
      final RegExp numRegex = RegExp(r'\b\d+\b');
      final match = numRegex.firstMatch(sentence);
      if (match != null) {
        return match.group(
          0,
        ); // Returns the first dynamic digits found in the text sentence string
      }
    } catch (_) {}
    return null;
  }

  /// Helper function to parse fallback words if the quote split logic behaves unexpectedly
  static String? secondaryNameFallbackFromMessage(String message) {
    try {
      final words = message.split(' ');
      if (words.isNotEmpty) return words.last;
    } catch (_) {}
    return null;
  }

  /// Handles Registration Requests dynamically.
  static Future<bool> register({
    required int id,
    required String password,
    required String phone,
    required String secondaryName,
    required String communityName,
    required int count,
    required bool isLeader,
  }) async {
    lastError = null;
    try {
      if (isLeader) {
        // --- COMMUNITY LEADER ACCOUNT ROUTE FLOW ---
        final url = Uri.parse('$_backendBaseUrl/community-leader/create');
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'id': id,
            'first_name': secondaryName,
            'phone': phone,
            'password': password,
            'community_name': communityName,
          }),
        ).timeout(const Duration(seconds: 15));

        print(
          'Leader Create Status: ${response.statusCode} | Body: ${response.body}',
        );

        //Persist configuration metadata state locally to SQLite immediately upon successful response codes
        if (response.statusCode == 200 || response.statusCode == 201) {
          final result = jsonDecode(response.body);
          if (result is! Map || result['status'] != 'ok') return false;
          await DatabaseHelper.instance.saveConfig('auth_leader_name', secondaryName);
          await SessionStore.activate(id: id, isLeader: true);
          await DatabaseHelper.instance.saveConfig(
            'auth_community_name',
            communityName,
          );
          await DatabaseHelper.instance.saveConfig(
            'community_households_count',
            '1',
          );
          await DatabaseHelper.instance.saveConfig(
            'community_members_count',
            '1',
          );
          print(
            'LEADER REGISTRATION PERSISTED: Successfully saved Community "$communityName" to database config keys.',
          );
        }

        return response.statusCode == 200 || response.statusCode == 201;
      } else {
        // --- HOUSEHOLD ACCOUNT FLOW (TWO-STEP CHAIN) ---

        // STEP 1: Create the base household profile entry row
        final createUrl = Uri.parse('$_backendBaseUrl/household/create');
        final createResponse = await http.post(
          createUrl,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'id': id,
            'last_name': secondaryName,
            'phone': phone,
            'count': count,
            'password': password,
          }),
        ).timeout(const Duration(seconds: 15));

        print(
          'Step 1 (Household Create) Status: ${createResponse.statusCode} | Body: ${createResponse.body}',
        );

        if (createResponse.statusCode != 200 &&
            createResponse.statusCode != 201) {
          print('Step 1 Failed: Profile creation rejected.');
          return false;
        }

        final Map<String, dynamic> createData = jsonDecode(createResponse.body);
        if (createData['status'] == 'failure' ||
            createData['status'] == 'error') {
          return false;
        }

        // STEP 2: Immediately execute a PATCH operation to attach this profile to a community
        final registerUrl = Uri.parse('$_backendBaseUrl/household/register');
        final registerResponse = await http.patch(
          registerUrl,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'id': id, 'community_name': communityName}),
        ).timeout(const Duration(seconds: 15));

        print(
          'Step 2 (Household Community Link) Status: ${registerResponse.statusCode} | Body: ${registerResponse.body}',
        );

        if (registerResponse.statusCode == 200 ||
            registerResponse.statusCode == 201) {
          final result = jsonDecode(registerResponse.body);
          if (result is! Map || result['status'] != 'ok') return false;
          await SessionStore.activate(id: id, isLeader: false);
          String savedLastName = secondaryName;
          final String message = createData['message']?.toString() ?? '';

          if (message.contains('last name ')) {
            savedLastName = message.split('last name ').last.trim();
          }

          await DatabaseHelper.instance.saveConfig(
            'household_last_name',
            savedLastName,
          );
          await DatabaseHelper.instance.saveConfig(
            'household_count',
            count.toString(),
          );
          print(
            'HOUSEHOLD REGISTRATION PERSISTED: Linked to ($communityName) successfully.',
          );

          DatabaseHelper.instance.syncNotifier.value++;
          return true;
        }
        print('Step 2 Failed: Community relationship assignment rejected.');
        return false;
      }
    } catch (e) {
      lastError = e is TimeoutException ? 'The backend did not respond in time. Account creation may have reached the server; check before registering again.' : 'Could not complete account creation. Check the backend and your connection.';
      print('Registration pipeline processing thread failure: $e');
      return false;
    }
  }
}
