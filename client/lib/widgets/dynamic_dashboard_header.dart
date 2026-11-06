import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/database_helper.dart'; 

class DynamicDashboardHeader extends StatefulWidget {
  const DynamicDashboardHeader({super.key, this.locationOnly = false});

  final bool locationOnly;

  @override
  State<DynamicDashboardHeader> createState() => _DynamicDashboardHeaderState();
}

class _DynamicDashboardHeaderState extends State<DynamicDashboardHeader> {
  static const String _nativeLandApiKey = String.fromEnvironment('NATIVE_LAND_KEY');

  String _locationText = 'Fetching live location...';
  String? _lastName;
  String? _membersCount;
  bool _isLoadingAuth = true;

  @override
  void initState() {
    super.initState();
    _loadSavedDataOnStartup().then((_) {
      if (mounted && widget.locationOnly) _fetchRealLocation();
    });
    
    // ADDED LISTENER: Re-reads database profile rows automatically whenever syncNotifier ticks up!
    DatabaseHelper.instance.syncNotifier.addListener(_loadSavedDataOnStartup);
    DatabaseHelper.instance.syncNotifier.addListener(_fetchRealLocation);
  }

  @override
  void dispose() {
    // CLEANUP: Clean up the new listener to prevent background memory leaks
    DatabaseHelper.instance.syncNotifier.removeListener(_loadSavedDataOnStartup);
    DatabaseHelper.instance.syncNotifier.removeListener(_fetchRealLocation);
    super.dispose();
  }

  Future<void> _loadSavedDataOnStartup() async {
    try {
      final savedFullLocation = await DatabaseHelper.instance.getConfig('last_resolved_full_location');
      
      // Look for the cached keys inside local SQLite device settings table
      String? lastName = await DatabaseHelper.instance.getConfig('household_last_name');
      String? count = await DatabaseHelper.instance.getConfig('household_count');

      if (mounted) {
        setState(() {
          if (savedFullLocation != null && savedFullLocation.isNotEmpty) {
            _locationText = savedFullLocation;
          }
          // FIXED: to strictly track local database values
          _lastName = lastName;
          _membersCount = count;
          _isLoadingAuth = false;
        });
      }
    } catch (e) {
      print('Failed to load cached workspace configs on boot: $e');
      if (mounted) {
        setState(() => _isLoadingAuth = false);
      }
    }
  }

  Future<void> _fetchRealLocation() async {
    try {
      final double? lat = DatabaseHelper.instance.cachedLat;
      final double? lng = DatabaseHelper.instance.cachedLng;

      if (lat == null || lng == null) return;

      // Western location (BigDataCloud)
      String westernLocation = "";
      try {
        final bigDataCloudUrl = Uri.https(
          'api.bigdatacloud.net',
          '/data/reverse-geocode-client',
          {
            'latitude': lat.toString(),
            'longitude': lng.toString(),
            'localityLanguage': 'en',
          },
        );
        final cityResponse = await http.get(bigDataCloudUrl);

        if (cityResponse.statusCode == 200) {
          final Map<String, dynamic> cityData = json.decode(cityResponse.body);
          final String city = cityData['city']?.toString().trim() ??
              cityData['locality']?.toString().trim() ??
              '';
          final String state =
              cityData['principalSubdivision']?.toString().trim() ?? '';

          if (city.isNotEmpty) {
            westernLocation = state.isNotEmpty ? '$city, $state' : city;
          }
        } else {
          print('BigDataCloud request failed: ${cityResponse.statusCode}');
        }
      } catch (e) {
        print('BigDataCloud lookup failed: $e');
      }

      // Indigenous territory (Native Land)
      String indigenousTerritory = "";

      if (_nativeLandApiKey.isEmpty) {
        print('NATIVE_LAND_KEY was not provided at build time; skipping Native Land lookup.');
      } else {
        try {
          final nativeLandUrl = Uri.https(
            'native-land.ca',
            '/api/index.php',
            {
              'maps': 'territories',
              'position': '$lat,$lng',
              'key': _nativeLandApiKey,
            },
          );
          final nativeLandResponse = await http.get(nativeLandUrl);

          if (nativeLandResponse.statusCode == 200) {
            final List<dynamic> landData = json.decode(nativeLandResponse.body);
            final List<String> names = landData
                .map((item) =>
                    item['properties']?['Name']?.toString().trim() ??
                    item['properties']?['name']?.toString().trim() ??
                    '')
                .where((name) => name.isNotEmpty)
                .toList();

            if (names.isNotEmpty) {
              indigenousTerritory = names.join(', ');
            }
          } else {
            print('Native Land request failed: ${nativeLandResponse.statusCode}');
          }
        } catch (e) {
          print('Native Land lookup failed (possibly CORS on web): $e');
        }
      }

      // Combine locations
      String combinedResult = "";
      if (westernLocation.isNotEmpty && indigenousTerritory.isNotEmpty) {
        combinedResult = '$westernLocation · $indigenousTerritory';
      } else if (westernLocation.isNotEmpty) {
        combinedResult = westernLocation;
      } else if (indigenousTerritory.isNotEmpty) {
        combinedResult = indigenousTerritory;
      }

      if (combinedResult.isNotEmpty && mounted) {
        setState(() {
          _locationText = combinedResult;
        });
        await DatabaseHelper.instance
            .saveConfig('last_resolved_full_location', combinedResult);
        print("Location text stashed successfully: $combinedResult");
      }
    } catch (e) {
      print('Integrated location coordination failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingAuth) return const SizedBox(height: 60);

    final theme = Theme.of(context);
    if (widget.locationOnly) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_on, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              _locationText,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.white70),
            ),
          ),
        ],
      );
    }
    final bool isUserLoggedIn = _lastName != null && _lastName!.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: isUserLoggedIn ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isUserLoggedIn ? 'Name: $_lastName' : '',
            textAlign: isUserLoggedIn ? TextAlign.center : TextAlign.start,
            style: TextStyle(
              fontSize: 16,                         
              fontWeight: FontWeight.normal,        
              color: Colors.white.withValues(alpha: 0.9), 
            ),
          ),
          if (isUserLoggedIn) ...[
            const SizedBox(height: 2),
            Text(
              'members: ${_membersCount ?? "0"}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: Colors.white60),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: isUserLoggedIn ? MainAxisAlignment.center : MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.location_on,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  _locationText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: isUserLoggedIn ? TextAlign.center : TextAlign.start,
                  style: const TextStyle(fontSize: 14, color: Colors.white70),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
