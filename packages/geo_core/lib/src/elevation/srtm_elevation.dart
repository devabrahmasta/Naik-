import 'dart:typed_data';

abstract interface class ElevationProvider {
  double? elevationAt(double latitude, double longitude);
}

/// Membaca satu tile SRTM .hgt berukuran 1201 x 1201 atau 3601 x 3601.
class SrtmElevationRaster implements ElevationProvider {
  final double southLatitude;
  final double westLongitude;
  final int size;
  final ByteData bytes;
  final Endian endian;

  SrtmElevationRaster({
    required this.southLatitude,
    required this.westLongitude,
    required this.size,
    required this.bytes,
    this.endian = Endian.big,
  }) {
    if (bytes.lengthInBytes != size * size * 2) {
      throw ArgumentError(
        'Ukuran data SRTM tidak sesuai: $size x $size.',
      );
    }
  }

  /// Membuat raster dari hasil pembacaan berkas `.hgt`.
  factory SrtmElevationRaster.fromBytes({
    required double southLatitude,
    required double westLongitude,
    required int size,
    required List<int> data,
  }) {
    final bytes = Uint8List.fromList(data);
    return SrtmElevationRaster(
      southLatitude: southLatitude,
      westLongitude: westLongitude,
      size: size,
      bytes: ByteData.sublistView(bytes),
    );
  }

  @override
  double? elevationAt(double latitude, double longitude) {
    final northLatitude = southLatitude + 1.0;
    final eastLongitude = westLongitude + 1.0;
    if (latitude < southLatitude ||
        latitude > northLatitude ||
        longitude < westLongitude ||
        longitude > eastLongitude) {
      return null;
    }

    final latScale = (northLatitude - latitude) * (size - 1);
    final lonScale = (longitude - westLongitude) * (size - 1);
    final row0 = latScale.floor().clamp(0, size - 1).toInt();
    final row1 = (row0 + 1).clamp(0, size - 1).toInt();
    final col0 = lonScale.floor().clamp(0, size - 1).toInt();
    final col1 = (col0 + 1).clamp(0, size - 1).toInt();

    final v00 = _read(row0, col0);
    final v10 = _read(row1, col0);
    final v01 = _read(row0, col1);
    final v11 = _read(row1, col1);
    if (v00 == null || v10 == null || v01 == null || v11 == null) {
      return null;
    }

    final latWeight = latScale - latScale.floor();
    final lonWeight = lonScale - lonScale.floor();
    final top = v00 + (v01 - v00) * lonWeight;
    final bottom = v10 + (v11 - v10) * lonWeight;
    return top + (bottom - top) * latWeight;
  }

  int? _read(int row, int column) {
    final offset = (row * size + column) * 2;
    final raw = bytes.getInt16(offset, endian);
    return raw == -32768 ? null : raw;
  }
}
