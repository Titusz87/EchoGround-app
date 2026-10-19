import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map'),
        centerTitle: true,
      ),

      body: MapLibreMap(
        initialCameraPosition: const CameraPosition(
          // Centered on Australia
          target: LatLng(-25.2744, 133.7751),
          zoom: 2.5,
        ),
        styleString: 'https://tiles.openfreemap.org/styles/dark',
      ),
    );
  }
}
