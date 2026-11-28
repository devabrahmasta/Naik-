import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hikenav_mobile/features/map/offline_package.dart';

void main() {
  OfflinePackageManifest validManifest() {
    return const OfflinePackageManifest(
      packageId: 'merbabu-selo-v1',
      routeId: 'merbabu-selo',
      areaName: 'Gunung Merbabu - Jalur Selo',
      version: 1,
      estimatedBytes: 12,
      files: [
        OfflinePackageFile(
          name: 'map.mbtiles',
          type: 'mbtiles',
          sizeBytes: 8,
          url: 'https://example.invalid/map.mbtiles',
        ),
        OfflinePackageFile(
          name: 'elevation.hgt',
          type: 'srtm',
          sizeBytes: 4,
          url: 'https://example.invalid/elevation.hgt',
        ),
      ],
    );
  }

  test('manifest valid diterima', () {
    expect(validManifest().validate(), isTrue);
  });

  test('nama berkas traversal ditolak', () {
    const invalid = OfflinePackageManifest(
      packageId: 'invalid',
      routeId: 'invalid',
      areaName: 'Invalid',
      version: 1,
      estimatedBytes: 1,
      files: [
        OfflinePackageFile(
          name: '../map.mbtiles',
          type: 'mbtiles',
          sizeBytes: 1,
          url: 'https://example.invalid/map.mbtiles',
        ),
      ],
    );
    expect(invalid.validate(), isFalse);
  });

  test('manifest dapat diserialkan dan dibaca kembali', () {
    final manifest = validManifest();
    final decoded = OfflinePackageManifest.fromJson(
      jsonDecode(jsonEncode(manifest.toJson()))
          as Map<String, dynamic>,
    );
    expect(decoded.packageId, 'merbabu-selo-v1');
    expect(decoded.files, hasLength(2));
  });

  test('ukuran paket diformat dalam satuan yang terbaca', () {
    expect(
      OfflinePackageManifest.formatBytes(512),
      '512 B',
    );
    expect(
      OfflinePackageManifest.formatBytes(1024 * 1024),
      '1.0 MB',
    );
  });
}
