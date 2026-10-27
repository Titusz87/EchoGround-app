import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart'; // Handles native GPS tracking
import 'package:http/http.dart' as http;      // Standard networking
import 'dart:convert';                        // Handles JSON parsing

class GuestModeHeader extends StatefulWidget {
  const GuestModeHeader({super.key});

  @override
  State<GuestModeHeader> createState() => _GuestModeHeaderState();
}

class _GuestModeHeaderState extends State<GuestModeHeader> {
  String _locationText = 'Fetching live location...'; // Loading placeholder text

  @override
  void initState() {
    super.initState();
    _fetchRealLocation();
  }

  Future<void> _fetchRealLocation() async {
    try {
      // 1. Fetch real hardware device coordinates safely
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      // 2. Query BigDataCloud's official free reverse geocoding API directly via HTTP
      final url = Uri.parse(
        'https://bigdatacloud.net?'
        'latitude=${position.latitude}&longitude=${position.longitude}&localityLanguage=en'
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        // 3. Extract the clean City/Locality and State subdivision attributes
        final String city = data['city']?.toString().trim() ?? 
                            data['locality']?.toString().trim() ?? 
                            'Unknown City';
        final String state = data['principalSubdivision']?.toString().trim() ?? '';

        if (mounted) {
          setState(() {
            _locationText = state.isNotEmpty ? '$city, $state' : city;
          });
        }
      } else {
        throw Exception('Server returned response code: ${response.statusCode}');
      }
    } catch (e) {
      print('⚠️ Bulletproof Reverse Geocoding failed: $e');
      if (mounted) {
        setState(() {
          _locationText = 'Location Unavailable';
        });
      }
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
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              
              // Dynamic Layout Row Panel Container
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.location_on, // Material Design map vector pin component
                    size: 16,
                    color: theme.colorScheme.primary, // Tinted automatically to your custom Teal theme accent
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      _locationText, // Renders live parsed geocode text cleanly
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
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
