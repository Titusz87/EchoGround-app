import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';

import '../../services/database_helper.dart';
import '../echoground_banner.dart';

class GuestModeHeader extends StatefulWidget {
  const GuestModeHeader({super.key});

  @override
  State<GuestModeHeader> createState() => _GuestModeHeaderState();
}

class _GuestModeHeaderState extends State<GuestModeHeader> {
  static const String _nativeLandApiKey = String.fromEnvironment(
    'NATIVE_LAND_KEY',
  );

  String _locationText = 'Fetching live location...';

  @override
  void initState() {
    super.initState();
    _loadSavedLocationOnStartup();
    DatabaseHelper.instance.syncNotifier.addListener(_fetchRealLocation);
  }

  @override
  void dispose() {
    DatabaseHelper.instance.syncNotifier.removeListener(_fetchRealLocation);
    super.dispose();
  }

  Future<void> _loadSavedLocationOnStartup() async {
    try {
      final savedFullLocation = await DatabaseHelper.instance.getConfig(
        'last_resolved_full_location',
      );
      if (savedFullLocation != null &&
          savedFullLocation.isNotEmpty &&
          mounted) {
        setState(() {
          _locationText = savedFullLocation;
        });
      }
    } catch (e) {
      print('Failed to load cached location on boot: $e');
    }
  }

  Future<void> _fetchRealLocation() async {
    try {
      final double? lat = DatabaseHelper.instance.cachedLat;
      final double? lng = DatabaseHelper.instance.cachedLng;

      if (lat == null || lng == null) return;

      print("Header matched verified coordinates: $lat, $lng");

      // API QUERY A: City and state via BigDataCloud (CORS-friendly HTTPS)
      final bigDataCloudUrl = Uri.parse(
        'https://api.bigdatacloud.net/data/reverse-geocode-client'
        '?latitude=$lat&longitude=$lng&localityLanguage=en',
      );
      final cityResponse = await http.get(bigDataCloudUrl);
      String westernLocation = "";

      if (cityResponse.statusCode == 200) {
        final Map<String, dynamic> cityData = json.decode(cityResponse.body);
        final String city =
            cityData['city']?.toString().trim() ??
            cityData['locality']?.toString().trim() ??
            '';
        final String state =
            cityData['principalSubdivision']?.toString().trim() ?? '';

        if (city.isNotEmpty) {
          westernLocation = state.isNotEmpty ? '$city, $state' : city;
        }
      }

      // API QUERY B: Native Land territories, with the injected API key.
      // "$_nativeLandApiKey" is Dart string interpolation: at runtime it is
      // replaced with the value that was passed via --dart-define.
      String indigenousTerritory = "";

      if (_nativeLandApiKey.isEmpty) {
        print(
          'NATIVE_LAND_KEY was not provided at build time; skipping Native Land lookup.',
        );
      } else {
        final nativeLandUrl = Uri.parse(
          'https://native-land.ca/api/index.php'
          '?maps=territories&position=$lat,$lng&key=$_nativeLandApiKey',
        );
        final nativeLandResponse = await http.get(nativeLandUrl);

        if (nativeLandResponse.statusCode == 200) {
          final List<dynamic> landData = json.decode(nativeLandResponse.body);
          if (landData.isNotEmpty) {
            final List<String> names = landData
                .map(
                  (item) =>
                      item['properties']?['Name']?.toString().trim() ??
                      item['properties']?['name']?.toString().trim() ??
                      '',
                )
                .where((name) => name.isNotEmpty)
                .toList();

            if (names.isNotEmpty) {
              indigenousTerritory = names.join(', ');
            }
          }
        } else {
          print('Native Land request failed: ${nativeLandResponse.statusCode}');
        }
      }

      // Combine both results
      String combinedResult = "";
      if (westernLocation.isNotEmpty && indigenousTerritory.isNotEmpty) {
        combinedResult = '$westernLocation · $indigenousTerritory';
      } else if (westernLocation.isNotEmpty) {
        combinedResult = westernLocation;
      } else if (indigenousTerritory.isNotEmpty) {
        combinedResult = indigenousTerritory;
      }

      // Update UI and cache
      if (combinedResult.isNotEmpty && mounted) {
        setState(() {
          _locationText = combinedResult;
        });
        await DatabaseHelper.instance.saveConfig(
          'last_resolved_full_location',
          combinedResult,
        );
        print("Location text stashed successfully: $combinedResult");
      }
    } catch (e) {
      print('Integrated location coordination failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const EchoGroundBanner(),
        const SizedBox(height: 20),
        const Text(
          'Hello, you are in Guest mode.',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(Icons.location_on, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                _locationText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
