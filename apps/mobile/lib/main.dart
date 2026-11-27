import 'package:flutter/material.dart';
import 'package:geo_core/geo_core.dart';
import 'package:hikenav_mobile/core/theme/app_theme.dart';
import 'package:hikenav_mobile/features/gnss/gnss_status_screen.dart';

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
      theme: AppTheme.light(),
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
        title: const Text('HikeNav'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.terrain_rounded,
                  size: 72,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 16),
                const Text(
                  'HikeNav Offline GNSS',
                  textAlign: TextAlign.center,
                  style: AppTypography.title,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Navigasi pendakian offline untuk Android berbasis GNSS',
                  textAlign: TextAlign.center,
                  style: AppTypography.caption,
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.tonal,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Geo Core Ready: ${samplePlane.toString()}',
                    style: AppTypography.label.copyWith(
                      fontSize: 13,
                      color: AppColors.primaryText,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                // TODO(Ariz/Tim): Pintu masuk sementara ke layar US-01 (Status GNSS).
                // Bagian ini boleh diubah, dipindah ke bottom nav / Persiapan mulai,
                // atau diganti saat layar Beranda & Peta offline sudah siap.
                SizedBox(
                  width: double.infinity,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 340),
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const GnssStatusScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.satellite_alt_rounded),
                      label: const Text('Cek Status GNSS'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
