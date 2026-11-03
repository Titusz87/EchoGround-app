import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class CommunityPlanApi {
  final http.Client? client;
  final String baseUrl;
  CommunityPlanApi({this.client, this.baseUrl = const String.fromEnvironment('BACKEND_URL')});

  Future<void> submit({required int id, required String body}) async {
    final base = Uri.tryParse(baseUrl.trim());
    if (base == null || !base.hasAuthority || !['http', 'https'].contains(base.scheme)) {
      throw const CommunityPlanApiError('The backend URL is not configured.');
    }
    if (id <= 0 || body.trim().isEmpty) {
      throw const CommunityPlanApiError('A registered device ID and plan text are required.');
    }
    final url = Uri.parse('${baseUrl.trim().replaceFirst(RegExp(r'/+$'), '')}/community-leader/create-community-plans');
    final ownClient = client == null;
    final transport = client ?? http.Client();
    try {
      final response = await transport.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id': id, 'body': body.trim()}),
      ).timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw CommunityPlanApiError('The server rejected the plan (HTTP ${response.statusCode}). Your draft is retained.');
      }
      dynamic result;
      try { result = jsonDecode(response.body); } catch (_) {
        throw const CommunityPlanApiError('The server response could not be confirmed. Check before submitting again.');
      }
      if (result is! Map || result['status'] != 'ok') {
        throw const CommunityPlanApiError('The server did not confirm that the plan was saved. Your draft is retained.');
      }
    } on TimeoutException {
      throw const CommunityPlanApiError('The request timed out. It may have reached the server; check before submitting again.');
    } on http.ClientException {
      throw const CommunityPlanApiError('The connection failed. Saving could not be confirmed; check before submitting again.');
    } finally {
      if (ownClient) transport.close();
    }
  }
}

class CommunityPlanApiError implements Exception {
  final String message;
  const CommunityPlanApiError(this.message);
  @override
  String toString() => message;
}
