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

      // 1. Attempt GPS checking rules smoothly
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
          print("GPS hardware tracking bypassed. Transitioning to fallback...");
        }
      }

      // 2. PRIMARY CLOUD FALLBACK: Query ipapi via secure HTTPS 
      // This service natively permits unrestricted client-side cross-origin browser handshakes
      print("Querying secure cloud geolocation services...");
      final url = Uri.parse(
        lat != null && lng != null
            ? 'https://ipapi.co'
            : 'https://ipapi.co'
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        // Safe unpacking of geography parameters from the JSON response tree
        final String city = data['city']?.toString().trim() ?? 'Unknown City';
        final String stateCode = data['region_code']?.toString().trim() ?? ''; // e.g., "SA" or "NSW"

        if (city.isNotEmpty && mounted) {
          setState(() {
            _locationText = stateCode.isNotEmpty ? '$city, $stateCode' : city;
          });
          return; // Server lookup completely successful!
        }
      }

      if (mounted) setState(() { _locationText = 'Location Unresolved'; });

    } catch (e) {
      print('Cloud tracking exception handled safely: $e');
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
