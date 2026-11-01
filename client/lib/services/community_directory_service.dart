import 'dart:convert';

import 'package:http/http.dart' as http;

abstract class CommunityDirectoryStore {
  Future<String?> read();
  Future<void> write(String value);
}

class CommunityDirectorySnapshot {
  const CommunityDirectorySnapshot({
    required this.names,
    required this.savedAt,
  });
  final List<String> names;
  final String savedAt;
  Map<String, dynamic> toJson() => {
    'version': 1,
    'names': names,
    'savedAt': savedAt,
  };
  factory CommunityDirectorySnapshot.fromJson(Map<String, dynamic> j) {
    if (j['version'] != 1 ||
        j['savedAt'] is! String ||
        DateTime.tryParse(j['savedAt']) == null) {
      throw const FormatException('Invalid saved community directory');
    }
    return CommunityDirectorySnapshot(
      names: validatedCommunityNames(j['names']),
      savedAt: j['savedAt'],
    );
  }
}

List<String> validatedCommunityNames(Object? raw) {
  if (raw is! List || raw.length > 10000)
    throw const FormatException('Invalid community list');
  final names = <String, String>{};
  for (final value in raw) {
    if (value is! String || value.trim().isEmpty || value.trim().length > 250) {
      throw const FormatException('Invalid community name');
    }
    final name = value.trim();
    names.putIfAbsent(name.toLowerCase(), () => name);
  }
  final result = names.values.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return List.unmodifiable(result);
}

/// Public names only. No account IDs, passwords, contacts or plan uploads.
/// Opening a dropdown reads the cache; only refresh() uses the network.
class CommunityDirectoryService {
  CommunityDirectoryService(
    this.store, {
    http.Client? client,
    this.baseUrl = const String.fromEnvironment('BACKEND_URL'),
  }) : _client = client;
  final CommunityDirectoryStore store;
  final http.Client? _client;
  final String baseUrl;
  CommunityDirectorySnapshot? snapshot;
  Future<CommunityDirectorySnapshot?> load() async {
    final saved = await store.read();
    if (saved == null) return null;
    final next = CommunityDirectorySnapshot.fromJson(
      Map<String, dynamic>.from(jsonDecode(saved)),
    );
    snapshot = next;
    return next;
  }

  Future<CommunityDirectorySnapshot> refresh() async {
    final base = baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.tryParse('$base/household/get-community-names');
    if (base.isEmpty ||
        uri == null ||
        !uri.hasAuthority ||
        !['http', 'https'].contains(uri.scheme)) {
      throw StateError('BACKEND_URL must be configured to update the list.');
    }
    final client = _client ?? http.Client();
    try {
      final response = await client
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200 ||
          response.bodyBytes.length > 2 * 1024 * 1024) {
        throw StateError('Community directory update failed.');
      }
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is! Map || body['status'] != 'ok')
        throw const FormatException('Invalid directory response');
      final next = CommunityDirectorySnapshot(
        names: validatedCommunityNames(body['communities']),
        savedAt: DateTime.now().toUtc().toIso8601String(),
      );
      // Publish only after durable cache save: an offline/invalid/failed update
      // leaves the previous snapshot and its saved time untouched.
      await store.write(jsonEncode(next.toJson()));
      snapshot = next;
      return next;
    } finally {
      if (_client == null) client.close();
    }
  }
}
