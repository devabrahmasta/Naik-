import 'package:xml/xml.dart';

import '../models/gnss_fix.dart';

/// Satu baris log (US-10): fix GNSS dan apakah ia lolos gating.
class LogRow {
  final GnssFix fix;
  final bool passed;

  const LogRow(this.fix, this.passed);
}

/// Header CSV, sama persis dengan `data/logs/merbabu_selo_sample.csv` milik tim.
const csvHeader =
    'timestamp,latitude,longitude,altitude,accuracy,speed,bearing,'
    'satellitesUsed,satellitesVisible,passed';

/// Ekspor log ke teks CSV.
String fixLogToCsv(List<LogRow> rows) {
  final lines = <String>[csvHeader];
  for (final row in rows) {
    final f = row.fix;
    lines.add(
      '${f.timestamp.millisecondsSinceEpoch},${f.latitude},${f.longitude},'
      '${f.altitude},${f.accuracy},${f.speed},${f.bearing},'
      '${f.satellitesUsed},${f.satellitesVisible},${row.passed ? 1 : 0}',
    );
  }
  return '${lines.join('\n')}\n';
}

/// Membaca teks CSV log untuk replay.
/// Baris kosong, komentar `//`, dan header dilewati.
List<LogRow> parseFixLogCsv(String text) {
  final rows = <LogRow>[];
  final lines = text.split('\n');

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty || line.startsWith('//') || line.startsWith('timestamp')) {
      continue;
    }

    final error = FormatException('Baris log ke-${i + 1} tidak valid.');
    final parts = line.split(',');
    if (parts.length != 10) throw error;

    final timestamp = int.tryParse(parts[0]);
    final numbers = <double>[];
    for (var j = 1; j <= 6; j++) {
      final value = double.tryParse(parts[j]);
      if (value == null) throw error;
      numbers.add(value);
    }
    final satellitesUsed = int.tryParse(parts[7]);
    final satellitesVisible = int.tryParse(parts[8]);
    final passed = parts[9].trim();

    if (timestamp == null ||
        satellitesUsed == null ||
        satellitesVisible == null ||
        (passed != '1' && passed != '0')) {
      throw error;
    }

    final fix = GnssFix(
      timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp),
      latitude: numbers[0],
      longitude: numbers[1],
      altitude: numbers[2],
      accuracy: numbers[3],
      speed: numbers[4],
      bearing: numbers[5],
      satellitesUsed: satellitesUsed,
      satellitesVisible: satellitesVisible,
    );
    rows.add(LogRow(fix, passed == '1'));
  }
  return rows;
}

/// Ekspor log ke teks GPX. Hanya fix yang lolos gating, supaya garis
/// jalur tidak melompat ke fix yang buruk.
String fixLogToGpx(List<LogRow> rows, String name) {
  final b = XmlBuilder();
  b.processing('xml', 'version="1.0" encoding="UTF-8"');
  b.element(
    'gpx',
    attributes: {
      'version': '1.1',
      'creator': 'HikeNav',
      'xmlns': 'http://www.topografix.com/GPX/1/1',
    },
    nest: () {
      b.element(
        'trk',
        nest: () {
          b.element('name', nest: name);
          b.element(
            'trkseg',
            nest: () {
              for (final row in rows) {
                if (!row.passed) continue;
                final f = row.fix;
                b.element(
                  'trkpt',
                  attributes: {'lat': '${f.latitude}', 'lon': '${f.longitude}'},
                  nest: () {
                    b.element('ele', nest: '${f.altitude}');
                    b.element(
                      'time',
                      nest: f.timestamp.toUtc().toIso8601String(),
                    );
                  },
                );
              }
            },
          );
        },
      );
    },
  );
  return b.buildDocument().toXmlString(pretty: true);
}
