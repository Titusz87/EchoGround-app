import 'dart:async';
import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:maplibre_gl/maplibre_gl.dart';

/// Immutable result model containing resolved coordinates and place labels.
class GuestLocationResult {
  final LatLng? coordinates;
  final String locality;
  final String territory;
  final bool hasError;

  const GuestLocationResult({
    required this.coordinates,
    required this.locality,
    required this.territory,
    this.hasError = false,
  });
}

/// Handles GPS permissions, device positioning, reverse geocoding, and
/// First Nations territory lookups for Guest Mode.
class GuestLocationService {
  static const String _nativeLandKey = String.fromEnvironment(
    'NATIVE_LAND_KEY',
  );
  static const Duration _gpsTimeout = Duration(seconds: 12);
  static const Duration _apiTimeout = Duration(seconds: 8);

  /// Resolves the device position along with locality and First Nations names.
  Future<GuestLocationResult> fetchLocationDetails() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const GuestLocationResult(
          coordinates: null,
          locality: 'Location services are disabled.',
          territory: 'Enable GPS and tap to retry.',
          hasError: true,
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return const GuestLocationResult(
          coordinates: null,
          locality: 'Location permission is off.',
          territory: 'Enable permission and tap to retry.',
          hasError: true,
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: _gpsTimeout,
        ),
      );

      if (!_isValidCoordinate(position.latitude, position.longitude)) {
        return const GuestLocationResult(
          coordinates: null,
          locality: 'Invalid GPS coordinates received.',
          territory: 'Tap to retry.',
          hasError: true,
        );
      }

      final coordinates = LatLng(position.latitude, position.longitude);

      final results = await Future.wait<String>([
        _lookupLocality(coordinates),
        _lookupTerritories(coordinates),
      ]);

      final locality = results[0];
      final territory = results[1];

      return GuestLocationResult(
        coordinates: coordinates,
        locality: locality.isNotEmpty ? locality : 'Location detected',
        territory: territory.isNotEmpty
            ? territory
            : 'First Nations region unavailable',
      );
    } on TimeoutException {
      return const GuestLocationResult(
        coordinates: null,
        locality: 'Location request timed out.',
        territory: 'Tap to retry.',
        hasError: true,
      );
    } on LocationServiceDisabledException {
      return const GuestLocationResult(
        coordinates: null,
        locality: 'Location services are disabled.',
        territory: 'Enable GPS and tap to retry.',
        hasError: true,
      );
    } catch (_) {
      return const GuestLocationResult(
        coordinates: null,
        locality: 'Location unavailable.',
        territory: 'Tap to retry.',
        hasError: true,
      );
    }
  }

  /// Validates that coordinates fall within standard WGS84 bounds.
  bool _isValidCoordinate(double lat, double lng) {
    return lat >= -90.0 && lat <= 90.0 && lng >= -180.0 && lng <= 180.0;
  }

  /// Resolves [point] into a "City, State" label using BigDataCloud.
  Future<String> _lookupLocality(LatLng point) async {
    try {
      final uri = Uri.https(
        'api.bigdatacloud.net',
        '/data/reverse-geocode-client',
        {
          'latitude': point.latitude.toString(),
          'longitude': point.longitude.toString(),
          'localityLanguage': 'en',
        },
      );

      final response = await http.get(uri).timeout(_apiTimeout);
      if (response.statusCode != 200) return '';

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return '';

      final city = decoded['city']?.toString().trim() ?? '';
      final locality = city.isNotEmpty
          ? city
          : decoded['locality']?.toString().trim() ?? '';
      final state = decoded['principalSubdivision']?.toString().trim() ?? '';

      return {locality, state}.where((part) => part.isNotEmpty).join(', ');
    } on TimeoutException {
      return '';
    } on FormatException {
      return '';
    } catch (_) {
      return '';
    }
  }

  /// Queries Native Land Digital for First Nations territories at [point].
  Future<String> _lookupTerritories(LatLng point) async {
    final trimmedKey = _nativeLandKey.trim();
    if (trimmedKey.isEmpty) return '';

    try {
      final uri = Uri.https('native-land.ca', '/api/index.php', {
        'maps': 'territories',
        'position': '${point.latitude},${point.longitude}',
        'key': trimmedKey,
      });

      final response = await http.get(uri).timeout(_apiTimeout);
      if (response.statusCode != 200) return '';

      final decoded = jsonDecode(response.body);
      final features = decoded is Map ? decoded['features'] : decoded;
      if (features is! List) return '';

      final territoryNames = <String>{};
      for (final feature in features.whereType<Map>()) {
        final properties = feature['properties'];
        if (properties is! Map) continue;

        final rawName = properties['Name'] ?? properties['name'];
        final cleanName = rawName?.toString().trim() ?? '';
        if (cleanName.isNotEmpty) {
          territoryNames.add(cleanName);
        }
      }

      return territoryNames.join(', ');
    } on TimeoutException {
      return '';
    } on FormatException {
      return '';
    } catch (_) {
      return '';
    }
  }
}
