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
      // 1. Attempt standard GPS tracking permission checks
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      LocationPermission permission = await Geolocator.checkPermission();

      // If hardware tracking is available and allowed, use the precision GPS pathway
      if (serviceEnabled && 
          permission != LocationPermission.denied && 
          permission != LocationPermission.deniedForever) {
        
        Position position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        );

        final url = Uri.parse(
          'https://bigdatacloud.net?'
          'latitude=${position.latitude}&longitude=${position.longitude}&localityLanguage=en'
        );

        final response = await http.get(url);
        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(response.body);
          final String city = data['city']?.toString().trim() ?? data['locality']?.toString().trim() ?? '';
          final String state = data['principalSubdivision']?.toString().trim() ?? '';

          if (city.isNotEmpty && mounted) {
            setState(() { _locationText = state.isNotEmpty ? '$city, $state' : city; });
            return; // GPS lookup succeeded, exit function cleanly
          }
        }
      }
      
      // 2. FALLBACK PATHWAY: If GPS is blocked or unavailable, query via Network IP Address
      // This runs entirely through your internet connection and requires 0 browser permissions!
      print("GPS unavailable. Resolving location via network IP routing...");
      final ipUrl = Uri.parse('http://ip-api.com');
      final ipResponse = await http.get(ipUrl);

      if (ipResponse.statusCode == 200) {
        final Map<String, dynamic> ipData = json.decode(ipResponse.body);
        
        if (ipData['status'] == 'success') {
          final String city = ipData['city']?.toString().trim() ?? 'Unknown City';
          final String stateCode = ipData['region']?.toString().trim() ?? ''; // e.g., "SA" or "NSW"

          if (mounted) {
            setState(() {
              _locationText = stateCode.isNotEmpty ? '$city, $stateCode' : city;
            });
            return;
          }
        }
      }
      
      // Final boundary if both pathways fail completely
      if (mounted) setState(() { _locationText = 'Location Services Restricted'; });

    } catch (e) {
      print('Dynamic location lookups bypassed: $e');
      if (mounted) setState(() { _locationText = 'Location Offline'; });
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
