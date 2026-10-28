import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/database_helper.dart';

class GuestModeHeader extends StatefulWidget {
  const GuestModeHeader({super.key});

  @override
  State<GuestModeHeader> createState() => _GuestModeHeaderState();
}

class _GuestModeHeaderState extends State<GuestModeHeader> {
  String _locationText = 'Fetching live location...';

  @override
  void initState() {
    super.initState();
    _fetchRealLocation();
  }

  Future<void> _fetchRealLocation() async {
    try {
      // 1. Give the background notification handshake a short moment to finish locking down the GPS coordinates
      await Future.delayed(const Duration(milliseconds: 600));

      // 2. Extract the exact precision coordinates logged inside memory by your notification manager
      final double? lat = DatabaseHelper.instance.cachedLat;
      final double? lng = DatabaseHelper.instance.cachedLng;

      if (lat != null && lng != null) {
        print("Header extracted logged coordinates: $lat, $lng");
        
        // 3. Query Open-Meteo's open-access reverse geocoding API over secure HTTPS
        final url = Uri.parse(
          'https://open-meteo.com'
        );
        
        final response = await http.get(url);

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(response.body);
          final List? results = data['results'];
          
          if (results != null && results.isNotEmpty) {
            final String city = results.first['name']?.toString().trim() ?? '';
            final String state = results.first['admin1']?.toString().trim() ?? '';
            
            if (city.isNotEmpty && mounted) {
              setState(() {
                _locationText = state.isNotEmpty ? '$city, $state' : city;
              });
              return; // Success! Real city title rendered cleanly.
            }
          }
        }
      }

      // If the coordinate stream hasn't arrived or the lookup fails, maintain a clean systemic placeholder
      if (mounted) {
        setState(() {
          _locationText = 'Location Services Restricted';
        });
      }

    } catch (e) {
      print('Logged coordinates translation failed: $e');
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
                      _locationText, 
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
