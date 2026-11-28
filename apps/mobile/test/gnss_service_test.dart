import 'package:flutter_test/flutter_test.dart';
import 'package:hikenav_mobile/features/gnss/gnss_service.dart';
import 'package:geo_core/geo_core.dart';

void main() {
  group('GnssService Replay Mode', () {
    test('defaultTrack() menghasilkan 30 fix berurutan', () async {
      final fixes = await ReplayGnssSource.defaultTrack().toList();
      expect(fixes.length, equals(30));
    });

    test('fix bergerak ke arah utara (latitude meningkat)', () async {
      final fixes = await ReplayGnssSource.defaultTrack().toList();
      expect(fixes.last.latitude, greaterThan(fixes.first.latitude));
    });

    test('fix bergerak naik ketinggian (altitude meningkat)', () async {
      final fixes = await ReplayGnssSource.defaultTrack().toList();
      expect(fixes.last.altitude, greaterThan(fixes.first.altitude));
    });

    test('semua fix default track lolos gating A_max=30m', () async {
      final gating = FixGating(aMax: 30.0, vMax: 5.0);
      final fixes = await ReplayGnssSource.defaultTrack().toList();
      int rejected = 0;
      for (final fix in fixes) {
        if (!gating.evaluate(fix).isAccepted) rejected++;
      }
      expect(rejected, equals(0));
    });

    test('fromCsv() memuat fix dari string CSV dengan benar', () async {
      const csv = '''timestamp,latitude,longitude,altitude,accuracy,speed,bearing,satellitesUsed,satellitesVisible,passed
1732334400000,-7.45320,110.43850,2600.0,8.5,1.4,15.0,9,12,1
1732334402000,-7.45305,110.43855,2610.0,9.0,1.3,15.0,9,12,1
1732334404000,-7.45290,110.43860,2620.0,8.0,1.5,16.0,10,13,1''';

      final fixes = await ReplayGnssSource.fromCsv(csv).toList();
      expect(fixes.length, equals(3));
      expect(fixes.first.latitude, closeTo(-7.45320, 0.000001));
      expect(fixes.first.altitude, closeTo(2600.0, 0.1));
      expect(fixes.last.satellitesUsed, equals(10));
    });

    test('GnssService replay mode mengalirkan fix tanpa error', () async {
      final service = GnssService(mode: GnssSourceMode.replay);
      final received = <GnssFix>[];

      await service.start();
      final sub = service.fixStream.listen(received.add);

      // Tunggu semua 30 fix selesai di-stream (50ms per fix = ~1.5 detik)
      await Future<void>.delayed(const Duration(seconds: 3));
      await sub.cancel();
      await service.dispose();

      expect(received.length, equals(30));
    });

    test('defaultStatusStream() menghasilkan snapshot satelit dengan konstelasi dan C/N0',
        () async {
      final snapshots =
          await ReplayGnssSource.defaultStatusStream(ticks: 3).toList();
      expect(snapshots.length, equals(3));
      expect(snapshots.first.visibleCount, equals(12));
      expect(snapshots.first.usedCount, equals(9));
      expect(snapshots.first.averageCn0Used, isNotNull);
    });
  });
}
