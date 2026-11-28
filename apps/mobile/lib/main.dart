import 'package:flutter/material.dart';
import 'package:geo_core/geo_core.dart';
import 'package:hikenav_mobile/core/theme/app_theme.dart';
// import 'package:hikenav_mobile/features/gnss/gnss_status_screen.dart';
import 'package:hikenav_mobile/features/map/offline_package.dart';
import 'package:hikenav_mobile/features/map/package_download_screen.dart';

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
    final demoPackage = OfflinePackageManifest(
      packageId: 'contoh-area-v1',
      routeId: 'contoh-rute',
      areaName: 'Contoh Area Gunung',
      version: 1,
      estimatedBytes: 5 * 1024 * 1024,
      files: const [
        OfflinePackageFile(
          name: 'map.mbtiles',
          type: 'mbtiles',
          sizeBytes: 4 * 1024 * 1024,
          url: 'https://example.invalid/paket/map.mbtiles',
        ),
        OfflinePackageFile(
          name: 'elevation.hgt',
          type: 'srtm',
          sizeBytes: 1024 * 1024,
          url: 'https://example.invalid/paket/elevation.hgt',
        ),
        OfflinePackageFile(
          name: 'route.gpx',
          type: 'gpx',
          sizeBytes: 10 * 1024,
          url: 'https://example.invalid/paket/route.gpx',
        ),
      ],
    );

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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FilledButton.icon(
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
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    PackageDownloadScreen(manifest: demoPackage),
                              ),
                            );
                          },
                          icon: const Icon(Icons.download_rounded),
                          label: const Text('Unduh Paket Offline'),
                        ),
                      ],
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
