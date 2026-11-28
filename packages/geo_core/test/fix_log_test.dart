import 'dart:io';

import 'package:geo_core/geo_core.dart';
import 'package:test/test.dart';

List<LogRow> readLog(String name) {
  return parseFixLogCsv(File('../../data/logs/$name').readAsStringSync());
}

/// Memutar ulang log lewat pipeline lengkap: gating -> jarak ke rute -> L3.
/// Mengembalikan nomor baris (mulai 0) tempat alarm bunyi.
List<int> replay(List<LogRow> rows, Route route) {
  final gating = FixGating();
  final distance = RouteDistanceCalculator(route);
  final detector = OffRouteDetector();
  final alarmAt = <int>[];

  for (var i = 0; i < rows.length; i++) {
    final fix = rows[i].fix;
    final g = gating.evaluate(
      fix,
    ); // kolom passed diabaikan, gating dihitung ulang
    if (g.status == GatingStatus.rejectedAccuracy) {
      detector.weakSignal();
    } else if (g.isAccepted) {
      final d = distance.distanceTo(fix.latitude, fix.longitude);
      detector.update(
        crossTrackDistance: d.meters,
        accuracy: fix.accuracy,
        timestamp: fix.timestamp,
      );
    }
    if (detector.shouldAlarm) alarmAt.add(i);
  }
  return alarmAt;
}

GeoPoint pointOf(LogRow row) => GeoPoint(row.fix.latitude, row.fix.longitude);

void main() {
  test('membaca log contoh milik tim', () {
    final rows = readLog('merbabu_selo_sample.csv');
    expect(rows.length, 20);
    expect(rows[6].fix.accuracy, 35.0);
    expect(rows[6].passed, isFalse);
    expect(rows[0].fix.timestamp.millisecondsSinceEpoch, 1732334400000);
  });

  test('tulis CSV lalu baca lagi menghasilkan nilai yang sama', () {
    final original = readLog('merbabu_selo_sample.csv');
    final again = parseFixLogCsv(fixLogToCsv(original));

    expect(again.length, original.length);
    for (var i = 0; i < original.length; i++) {
      final a = original[i].fix;
      final b = again[i].fix;
      expect(b.timestamp, a.timestamp);
      expect(b.latitude, a.latitude);
      expect(b.longitude, a.longitude);
      expect(b.altitude, a.altitude);
      expect(b.accuracy, a.accuracy);
      expect(b.satellitesUsed, a.satellitesUsed);
      expect(again[i].passed, original[i].passed);
    }
  });

  test('baris rusak melempar FormatException dengan nomor baris', () {
    const text =
        '$csvHeader\n'
        '1732334400000,-7.45,110.43,2600,8,1,15,9,12,1\n'
        '1732334402000,abc,110.43,2600,8,1,15,9,12,1\n';
    expect(
      () => parseFixLogCsv(text),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          'Baris log ke-3 tidak valid.',
        ),
      ),
    );
  });

  test('ekspor GPX hanya berisi fix lolos dan bisa dibaca parseGpx', () {
    final rows = readLog('merbabu_selo_sample.csv');
    final result = parseGpx(fixLogToGpx(rows, 'Selo & Pos 1'));

    expect(result, isA<GpxOk>());
    final route = (result as GpxOk).route;
    expect(route.name, 'Selo & Pos 1');
    expect(route.segments.single.length, 19); // 20 fix, 1 ditolak
    expect(route.segments.single.first.ele, 2600.0);
  });

  test('replay: berjalan di atas rute, alarm tidak pernah bunyi', () {
    final rows = readLog('contoh-sintetis-keluar-jalur.csv');
    // Rute = jalur yang memang dilalui: ke utara, lalu ke timur.
    final route = Route('Sesuai jalur', [
      [pointOf(rows[0]), pointOf(rows[29]), pointOf(rows[59])],
    ]);
    expect(replay(rows, route), isEmpty);
  });

  test('replay: salah belok, alarm bunyi sekali dan tidak saat sinyal lemah', () {
    final rows = readLog('contoh-sintetis-keluar-jalur.csv');
    // Rute hanya ke utara, jadi belokan ke timur = keluar jalur.
    final route = Route('Ke utara', [
      [pointOf(rows[0]), pointOf(rows[29])],
    ]);

    // Fix 42 pertama di atas 30 m (31,2 m). Fix 45 lemah (dilewati).
    // Syarat 5 fix terpenuhi di fix 47, syarat 15 dtk baru di fix 50 (16 dtk).
    expect(replay(rows, route), [50]);
  });
}
