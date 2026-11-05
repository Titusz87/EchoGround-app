import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'database_helper.dart';
import 'notification_service.dart';

class AuthService {
  static const String _backendBaseUrl = String.fromEnvironment('BACKEND_URL');

  /// Verifies if local storage holds a valid backend identity key.
  /// Safely returns null on missing values so the dashboard stays in Guest Mode.
  static Future<int?> ensureBackendPersonId(BuildContext context) async {
    // Fetch the persistent device registration identifier from SQLite
    String? savedPersonId = await DatabaseHelper.instance.getConfig(
      'backend_person_id',
    );

    // If it's missing, we let it stay null so the app doesn't force a setup handshake on boot.
    if (savedPersonId == null || savedPersonId.isEmpty) {
      print(
        "Local identity profile empty. Preserving Guest Mode profile canvas...",
      );
      return null;
    }

    return int.tryParse(savedPersonId);
  }

  /// Handles Login Requests for both Roles dynamically with validation
  static Future<bool> login({
    required int id,
    required String password,
    required bool isLeader,
  }) async {
    final String subPath = isLeader
        ? 'community-leader/login'
        : 'household/login';
    final url = Uri.parse('$_backendBaseUrl/$subPath');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id': id, 'password': password}),
      );

      print(
        'Auth Login Status: ${response.statusCode} | Body: ${response.body}',
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        // SECURITY CHECK: backend returns 200 for incorrect login details too.
        if (responseData['status'] == 'failure' ||
            responseData['status'] == 'error') {
          print('Authentication rejected by backend message content.');
          return false;
        }

        // Save the authenticated role ID locally to config cache table
        final String configKey = isLeader
            ? 'auth_leader_id'
            : 'auth_household_id';
        await DatabaseHelper.instance.saveConfig(configKey, id.toString());

        // PERSIST LOGGED IN ACCOUNT IDENTITY INFO NATIVELY
        if (!isLeader) {
          String loggedName = 'Unknown';
          final String message = responseData['message']?.toString() ?? '';

          if (message.contains("'")) {
            final List<String> parts = message.split("'");
            if (parts.length > 1) {
              loggedName =
                  parts[1]; // Safely extracts the true name from single quotes
            }
          } else {
            loggedName = secondaryNameFallbackFromMessage(message) ?? 'Unknown';
          }

          // DYNAMIC MEMBER COUNT PARSER WITH LOCAL PERSISTENCE PREFERENCE:
          // Try to read if a value was permanently logged during the registration session first
          String? extractedCount = await DatabaseHelper.instance.getConfig(
            'household_count',
          );

          // If it's missing or empty from database cache, check if backend sent an explicit JSON key
          if (extractedCount == null || extractedCount.isEmpty) {
            extractedCount =
                (responseData['count'] ??
                        responseData['members_count'] ??
                        responseData['members'])
                    ?.toString();
          }

          // If still missing, check if it can be parsed straight out of the string message response sentence
          if (extractedCount == null || extractedCount.isEmpty) {
            extractedCount = _parseNumericValueFromString(message);
          }

          // Default to an elegant dash indicator if no number is available anywhere
          final String finalCountString =
              (extractedCount != null && extractedCount.isNotEmpty)
              ? extractedCount
              : '—';

          await DatabaseHelper.instance.saveConfig(
            'household_last_name',
            loggedName,
          );
          await DatabaseHelper.instance.saveConfig(
            'household_count',
            finalCountString,
          );

          print(
            'LOCAL CONFIG COMPLETE: Loaded Last Name ($loggedName) and parsed capacity count ($finalCountString) directly to local storage.',
          );

          // Broadcast database sync event instantly to let dynamic header update its view state loop
          DatabaseHelper.instance.syncNotifier.value++;
        } else {
          // --- COMMUNITY LEADER LOGIN PERSISTENCE HANDSHAKE ---
          final String message = responseData['message']?.toString() ?? '';
          String loggedCommunity = 'Unknown';

          if (message.contains("'")) {
            final List<String> parts = message.split("'");
            if (parts.length > 1) {
              loggedCommunity = parts[1]; // Safely extracts the community name from back-end string tokens
            }
          }

          if (loggedCommunity != 'Unknown') {
            await DatabaseHelper.instance.saveConfig(
              'auth_community_name',
              loggedCommunity,
            );
            print(
              'LEADER LOGIN PERSISTED: Extracted and cached Community Name "$loggedCommunity" successfully.',
            );
          }
        }

        return true;
      }
      return false;
    } catch (e) {
      print('Login networking thread failed: $e');
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
  /// For households, it executes Evan's sequential two-step creation and linkage protocol.
  static Future<bool> register({
    required int id,
    required String password,
    required String phone,
    required String secondaryName,
    required String communityName,
    required int count,
    required bool isLeader,
  }) async {
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
        );

        print(
          'Leader Create Status: ${response.statusCode} | Body: ${response.body}',
        );

        // 🛠️ FIXED: Persist configuration metadata state locally to SQLite immediately upon successful response codes
        if (response.statusCode == 200 || response.statusCode == 201) {
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
        );

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
        );

        print(
          'Step 2 (Household Community Link) Status: ${registerResponse.statusCode} | Body: ${registerResponse.body}',
        );

        if (registerResponse.statusCode == 200 ||
            registerResponse.statusCode == 201) {
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
            '💾 HOUSEHOLD REGISTRATION PERSISTED: Linked to ($communityName) successfully.',
          );

          DatabaseHelper.instance.syncNotifier.value++;
          return true;
        }
        print('Step 2 Failed: Community relationship assignment rejected.');
        return false;
      }
    } catch (e) {
      print('Registration pipeline processing thread failure: $e');
      return false;
    }
  }
}
