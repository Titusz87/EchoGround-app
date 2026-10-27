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
      double? lat;
      double? lng;

      // 1. Try to read GPS tracking sensors if allowed by the user
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      LocationPermission permission = await Geolocator.checkPermission();

      if (serviceEnabled && 
          permission != LocationPermission.denied && 
          permission != LocationPermission.deniedForever) {
        try {
          Position position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
          ).timeout(const Duration(seconds: 2));
          
          lat = position.latitude;
          lng = position.longitude;
        } catch (_) {
          print("GPS sensor timed out. Moving to network IP tracking...");
        }
      }

      // 2. PRIMARY LOOKUP: Query BigDataCloud via HTTPS (Handles auto-IP matching on server side)
      final primaryUrl = Uri.parse(
        lat != null && lng != null
            ? 'https://bigdatacloud.net'
            : 'https://bigdatacloud.net'
      );

      final response = await http.get(primaryUrl);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final String city = data['city']?.toString().trim() ?? data['locality']?.toString().trim() ?? '';
        final String state = data['principalSubdivision']?.toString().trim() ?? '';

        if (city.isNotEmpty && mounted) {
          setState(() {
            _locationText = state.isNotEmpty ? '$city, $state' : city;
          });
          return; // Primary network lookup succeeded!
        }
      }

      // 3. SECURE SECONDARY FAILOVER: If the primary API breaks, parse another secure HTTPS IP location service
      print("Querying secondary backup IP localization matrix...");
      final fallbackUrl = Uri.parse('https://ipapi.co');
      final fallbackResponse = await http.get(fallbackUrl);

      if (fallbackResponse.statusCode == 200) {
        final Map<String, dynamic> fallbackData = json.decode(fallbackResponse.body);
        final String city = fallbackData['city']?.toString().trim() ?? '';
        final String stateCode = fallbackData['region_code']?.toString().trim() ?? ''; // e.g., "SA" or "NSW"

        if (city.isNotEmpty && mounted) {
          setState(() {
            _locationText = stateCode.isNotEmpty ? '$city, $stateCode' : city;
          });
          return; // Secondary network lookup succeeded!
        }
      }

      if (mounted) setState(() { _locationText = 'Location Unresolved'; });

    } catch (e) {
      print('All dynamic location tracking paths blocked by system: $e');
      if (mounted) {
        setState(() {
          _locationText = 'Location Services Restricted'; 
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
