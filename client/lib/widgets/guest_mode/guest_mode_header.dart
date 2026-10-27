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

      // 1. Try to read hardware GPS tracking data if available
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
          print("GPS hardware tracking bypassed. Moving to IP location tracking...");
        }
      }

      // 2. NETWORK PATH ROUTING (100% Dynamic - Zero Hardcoding)
      http.Response response;

      if (lat != null && lng != null) {
        // PATH A: GPS is active—query Open-Meteo's open-access reverse geocoding API over secure HTTPS
        print("Querying secure cloud reverse geocoder via coordinates...");
        final url = Uri.parse(
          'https://open-meteo.com'
        );
        response = await http.get(url);

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(response.body);
          final List? results = data['results'];
          
          if (results != null && results.isNotEmpty) {
            final String city = results.first['name']?.toString().trim() ?? '';
            final String state = results.first['admin1']?.toString().trim() ?? '';
            
            if (city.isNotEmpty && mounted) {
              setState(() { _locationText = state.isNotEmpty ? '$city, $state' : city; });
              return; // Success! Exit loop cleanly
            }
          }
        }
      }

      // PATH B: GPS is blocked—query ipapi's clean zero-parameter address block
      // Omitting coordinates forces their server to trace your IP routing to return your true city
      print("Querying secure zero-parameter IP geolocation endpoint...");
      final ipUrl = Uri.parse('https://ipapi.co/json/'); // FIXED: No parameters passed inside paths
      response = await http.get(ipUrl);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        // Ensure the server did not return a soft rate-limiting error payload
        if (data['error'] != true) {
          final String city = data['city']?.toString().trim() ?? 'Unknown City';
          final String stateCode = data['region_code']?.toString().trim() ?? ''; 

          if (city.isNotEmpty && mounted) {
            setState(() {
              _locationText = stateCode.isNotEmpty ? '$city, $stateCode' : city;
            });
            return; // Success! Exit loop cleanly
          }
        }
      }

      if (mounted) setState(() { _locationText = 'Location Unresolved'; });

    } catch (e) {
      print('⚠️ Safe Dynamic Reverse Geocoding failed: $e');
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
