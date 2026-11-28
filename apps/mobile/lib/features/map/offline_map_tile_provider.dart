import 'dart:io';

import 'package:flutter_map_mbtiles/flutter_map_mbtiles.dart';

class OfflineMapPackage {
  final String path;
  final MbTilesTileProvider provider;

  const OfflineMapPackage._(this.path, this.provider);

  static OfflineMapPackage? open(String? path) {
    if (path == null || path.trim().isEmpty) return null;
    final file = File(path);
    if (!file.existsSync()) return null;

    try {
      return OfflineMapPackage._(
        path,
        MbTilesTileProvider.fromPath(path: path),
      );
    } on Object {
      return null;
    }
  }

  void dispose() => provider.dispose();
}
