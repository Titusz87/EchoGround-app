import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/database_helper.dart'; // Clean relative folder import path

class GuestModeHeader extends StatefulWidget {
  const GuestModeHeader({super.key});

  @override
  State<GuestModeHeader> createState() => _GuestModeHeaderState();
}

class _GuestModeHeaderState extends State<GuestModeHeader> {
  String _locationText = 'Fetching live location...'; // Default loading string parameter label

  @override
  void initState() {
    super.initState();
    
    // 1. OFFLINE-FIRST: Load the combined Western + Indigenous text from local SQLite immediately
    _loadSavedLocationOnStartup();

    // 2. SYSTEM LISTEN TRIGGER: Watch for fresh GPS variables to log into memory
    DatabaseHelper.instance.syncNotifier.addListener(_fetchRealLocation);
  }

  @override
  void dispose() {
    // Release system listener state blocks cleanly on destruction to prevent memory leakage
    DatabaseHelper.instance.syncNotifier.removeListener(_fetchRealLocation);
    super.dispose();
  }

  /// Instant Boot Loader: Checks your persistent local database config for a pre-saved location string
  Future<void> _loadSavedLocationOnStartup() async {
    try {
      final savedFullLocation = await DatabaseHelper.instance.getConfig('last_resolved_full_location');
      if (savedFullLocation != null && savedFullLocation.isNotEmpty && mounted) {
        setState(() {
          _locationText = savedFullLocation;
        });
      }
    } catch (e) {
      print('Failed to load cached full location string on boot: $e');
    }
  }

  /// Background Refresher Loop: Runs once your background thread locks down valid GPS variables
  Future<void> _fetchRealLocation() async {
    try {
      final double? lat = DatabaseHelper.instance.cachedLat;
      final double? lng = DatabaseHelper.instance.cachedLng;

      // If the hardware coordinate arrays haven't completed loading yet, skip network actions
      if (lat == null || lng == null) return;

      print("Header matched verified coordinates: $lat, $lng");

      // API QUERY A: Extract Western City and State boundaries via secure HTTPS Open-Meteo
      final openMeteoUrl = Uri.parse(
        'https://open-meteo.com'
      );
      final cityResponse = await http.get(openMeteoUrl);
      String westernLocation = "";

      if (cityResponse.statusCode == 200) {
        final Map<String, dynamic> cityData = json.decode(cityResponse.body);
        final List? results = cityData['results'];
        if (results != null && results.isNotEmpty) {
          final String city = results.first['name']?.toString().trim() ?? '';
          final String state = results.first['admin1']?.toString().trim() ?? '';
          westernLocation = state.isNotEmpty ? '$city, $state' : city;
        }
      }

      // API QUERY B: Extract First Nations Territories via secure HTTPS Native-Land
      final nativeLandUrl = Uri.parse(
        'https://native-land.ca'
      );
      final nativeLandResponse = await http.get(nativeLandUrl);
      String indigenousTerritory = "";

      if (nativeLandResponse.statusCode == 200) {
        final List<dynamic> landData = json.decode(nativeLandResponse.body);
        if (landData.isNotEmpty) {
          final List<String> names = landData
              .map((item) => item['properties']?['name']?.toString().trim() ?? '')
              .where((name) => name.isNotEmpty)
              .toList();

          if (names.isNotEmpty) {
            indigenousTerritory = names.join(', ');
          }
        }
      }

      // COMBINATION SCHEMATIC: Stitch your parsing profiles together cleanly
      String combinedResult = "";
      if (westernLocation.isNotEmpty && indigenousTerritory.isNotEmpty) {
        combinedResult = '$westernLocation · $indigenousTerritory';
      } else if (westernLocation.isNotEmpty) {
        combinedResult = westernLocation;
      } else if (indigenousTerritory.isNotEmpty) {
        combinedResult = indigenousTerritory;
      }

      // UPDATE UI AND CACHE: Update values instantly and save them back to the disk partition
      if (combinedResult.isNotEmpty && mounted) {
        setState(() {
          _locationText = combinedResult;
        });

        // Write directly to your SQLite device_config table slot so next reload is instant!
        await DatabaseHelper.instance.saveConfig('last_resolved_full_location', combinedResult);
      }

    } catch (e) {
      print('Integrated location coordination failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Hello!',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.location_on, // Material Design map vector pin component
                    size: 16,
                    color: theme.colorScheme.primary, // Teal color tracking
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      _locationText, 
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
