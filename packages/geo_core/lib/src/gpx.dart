import 'package:xml/xml.dart';

import 'geo_point.dart';

/// A reference route. Segments are kept apart: joining them would draw a
/// false line across the gap and L3 would treat the gap as "on route".
class Route {
  final String? name;
  final List<List<GeoPoint>> segments;

  const Route(this.name, this.segments);
}

sealed class GpxResult {
  const GpxResult();
}

final class GpxOk extends GpxResult {
  final Route route;
  const GpxOk(this.route);
}

/// [message] is Indonesian and ready to show to the user.
final class GpxError extends GpxResult {
  final String message;
  const GpxError(this.message);

  @override
  String toString() => 'GpxError($message)';
}

/// Parses GPX 1.0/1.1 text. Never throws: bad input returns [GpxError].
/// Reads `trk/trkseg/trkpt`; falls back to `rte/rtept` when there is no track.
GpxResult parseGpx(String text) {
  if (text.trim().isEmpty) return const GpxError('Berkas GPX kosong.');

  final XmlDocument doc;
  try {
    doc = XmlDocument.parse(text);
  } on XmlException {
    return const GpxError('Berkas GPX rusak atau tidak lengkap.');
  }

  final root = doc.childElements.firstOrNull;
  if (root == null || root.localName != 'gpx') {
    return const GpxError('Berkas ini bukan GPX.');
  }

  var owner = root.findAllElements('trk', namespaceUri: '*').firstOrNull;
  var raw = [
    for (final seg in root.findAllElements('trkseg', namespaceUri: '*'))
      seg.findElements('trkpt', namespaceUri: '*').toList(),
  ];
  if (raw.every((s) => s.isEmpty)) {
    owner = root.findAllElements('rte', namespaceUri: '*').firstOrNull;
    raw = [
      for (final rte in root.findAllElements('rte', namespaceUri: '*'))
        rte.findElements('rtept', namespaceUri: '*').toList(),
    ];
  }
  if (raw.every((s) => s.isEmpty)) {
    return const GpxError('Berkas GPX tidak berisi titik jalur.');
  }

  final segments = <List<GeoPoint>>[];
  var n = 0;
  for (final seg in raw) {
    final points = <GeoPoint>[];
    for (final el in seg) {
      n++;
      final lat = double.tryParse(el.getAttribute('lat') ?? '');
      final lon = double.tryParse(el.getAttribute('lon') ?? '');
      // One bad point rejects the file: a route with silent holes is worse
      // for off-route alarms than a clear error.
      if (lat == null ||
          lon == null ||
          !lat.isFinite ||
          !lon.isFinite ||
          lat.abs() > 90 ||
          lon.abs() > 180) {
        return GpxError('Koordinat titik ke-$n tidak valid.');
      }
      final ele = double.tryParse(
          el.getElement('ele', namespaceUri: '*')?.innerText.trim() ?? '');
      points.add(GeoPoint(lat, lon, ele != null && ele.isFinite ? ele : null));
    }
    // A segment with < 2 points cannot form a line, so it adds nothing to L3.
    if (points.length >= 2) segments.add(points);
  }
  if (segments.isEmpty) {
    return const GpxError('Rute butuh minimal 2 titik berurutan.');
  }

  final name = owner?.getElement('name', namespaceUri: '*')?.innerText.trim();
  return GpxOk(Route(name == null || name.isEmpty ? null : name, segments));
}
