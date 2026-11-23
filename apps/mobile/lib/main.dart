import 'package:flutter/material.dart';
import 'package:geo_core/geo_core.dart';

void main() {
  runApp(const HikeNavApp());
}

class HikeNavApp extends StatelessWidget {
  const HikeNavApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HikeNav',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF6F4EE), // Token bg
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5A7834), // Token primary
          primary: const Color(0xFF5A7834),
          surface: const Color(0xFFFFFFFF), // Token surface
          onSurface: const Color(0xFF1F2A1C), // Token ink
        ),
      ),
      home: const HikeNavHomePage(),
    );
  }
}

class HikeNavHomePage extends StatelessWidget {
  const HikeNavHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Verifikasi integrasi geo_core di aplikasi mobile
    const samplePlane = LocalPoint(0, 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'HikeNav',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2A1C),
          ),
        ),
        backgroundColor: const Color(0xFFF6F4EE),
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.terrain,
                size: 72,
                color: Color(0xFF5A7834),
              ),
              const SizedBox(height: 16),
              const Text(
                'HikeNav Offline GNSS',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2A1C),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Navigasi pendakian offline untuk Android berbasis GNSS',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF5B6555),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE4EBD3), // Token tonal
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Geo Core Ready: ${samplePlane.toString()}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4E6B2F),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
