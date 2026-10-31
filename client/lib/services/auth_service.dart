import 'dart:convert';
import 'package:http/http.dart' as http;
import 'database_helper.dart';

class AuthService {
  static const String _backendBaseUrl = String.fromEnvironment('BACKEND_URL');

  /// Handles Login Requests for both Roles dynamically
  static Future<bool> login({
    required int id,
    required String password,
    required bool isLeader,
  }) async {
    final String subPath = isLeader ? 'community-leader/login' : 'household/login';
    final url = Uri.parse('$_backendBaseUrl/$subPath');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id': id,
          'password': password,
        }),
      );

      print('Auth Login Status: ${response.statusCode} | Body: ${response.body}');

      if (response.statusCode == 200) {
        // Save the authenticated role ID locally to your config cache table
        final String configKey = isLeader ? 'auth_leader_id' : 'auth_household_id';
        await DatabaseHelper.instance.saveConfig(configKey, id.toString());
        return true;
      }
      return false;
    } catch (e) {
      print('Login networking thread failed: $e');
      return false;
    }
  }

  /// Handles Registration Requests for both Roles dynamically
  static Future<bool> register({
    required int id,
    required String password,
    required String phone,
    required String secondaryName, // Represents last_name for household, or first_name for leader
    required String communityName, // Exclusive parameter used by leaders
    required bool isLeader,
  }) async {
    final String subPath = isLeader ? 'community-leader/create' : 'household/create';
    final url = Uri.parse('$_backendBaseUrl/$subPath');

    // Dynamically build the exact payload body expected by your swagger models
    final Map<String, dynamic> requestBody = isLeader
        ? {
            'id': id,
            'first_name': secondaryName,
            'phone': phone,
            'password': password,
            'community_name': communityName,
          }
        : {
            'id': id,
            'last_name': secondaryName,
            'phone': phone,
            'count': 0, // Matches your schema contract default count parameter
            'password': password,
          };

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      print('Auth Register Status: ${response.statusCode} | Body: ${response.body}');
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('Registration networking thread failed: $e');
      return false;
    }
  }
}
