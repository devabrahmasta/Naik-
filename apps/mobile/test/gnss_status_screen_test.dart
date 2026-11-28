import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geo_core/geo_core.dart';
import 'package:hikenav_mobile/core/platform/gnss_channel.dart';
import 'package:hikenav_mobile/core/theme/app_theme.dart';
import 'package:hikenav_mobile/features/gnss/gnss_service.dart';
import 'package:hikenav_mobile/features/gnss/gnss_status_screen.dart';

void main() {
  Widget wrapScreen(
    GnssService service, {
    double width = 390,
    double height = 844,
    double textScale = 1.0,
  }) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, height),
          textScaler: TextScaler.linear(textScale),
        ),
        child: GnssStatusScreen(gnssService: service),
      ),
    );
  }

  GnssStatusSnapshot sampleSnapshot() {
    return GnssStatusSnapshot(
      timestamp: DateTime(2026, 11, 27, 10, 0, 0),
      satellites: const [
        SatelliteInfo(
          svid: 12,
          constellation: GnssConstellation.gps,
          cn0DbHz: 38.4,
          azimuthDegrees: 32,
          elevationDegrees: 68,
          usedInFix: true,
        ),
        SatelliteInfo(
          svid: 4,
          constellation: GnssConstellation.glonass,
          cn0DbHz: 32.0,
          azimuthDegrees: 140,
          elevationDegrees: 45,
          usedInFix: true,
        ),
        SatelliteInfo(
          svid: 19,
          constellation: GnssConstellation.galileo,
          cn0DbHz: 21.0,
          azimuthDegrees: 280,
          elevationDegrees: 15,
          usedInFix: false,
        ),
      ],
    );
  }

  GnssFix sampleFix({double accuracy = 8.5}) {
    return GnssFix(
      latitude: -7.45320,
      longitude: 110.43850,
      altitude: 2650.0,
      accuracy: accuracy,
      speed: 1.2,
      bearing: 20.0,
      satellitesUsed: 2,
      satellitesVisible: 3,
      timestamp: DateTime(2026, 11, 27, 10, 0, 0),
    );
  }

  group('US-01 GnssStatusScreen states', () {
    testWidgets('menampilkan state izin lokasi ditolak dengan tombol aksi',
        (tester) async {
      final service = GnssService(
        mode: GnssSourceMode.hardware,
        nativeStateReader: () async => const GnssNativeState(
          hasPermission: false,
          isGpsEnabled: true,
        ),
      );
      addTearDown(service.dispose);

      await tester.pumpWidget(wrapScreen(service));
      await tester.pumpAndSettle();

      expect(find.text('Izin lokasi diperlukan'), findsOneWidget);
      expect(find.text('Izinkan Lokasi'), findsOneWidget);
      expect(find.text('Buka Pengaturan Aplikasi'), findsOneWidget);
    });

    testWidgets('menampilkan state GPS mati dengan tombol ke pengaturan lokasi',
        (tester) async {
      final service = GnssService(
        mode: GnssSourceMode.hardware,
        nativeStateReader: () async => const GnssNativeState(
          hasPermission: true,
          isGpsEnabled: false,
        ),
      );
      addTearDown(service.dispose);

      await tester.pumpWidget(wrapScreen(service));
      await tester.pumpAndSettle();

      expect(find.text('GPS perangkat mati'), findsOneWidget);
      expect(find.text('Buka Pengaturan Lokasi'), findsOneWidget);
      expect(find.text('Periksa Ulang'), findsOneWidget);
    });

    testWidgets('menampilkan "Mencari satelit" saat siap tetapi belum ada fix',
        (tester) async {
      final fixController = StreamController<GnssFix>.broadcast();
      final statusController = StreamController<GnssStatusSnapshot>.broadcast();
      addTearDown(() async {
        await fixController.close();
        await statusController.close();
      });

      final service = GnssService(
        mode: GnssSourceMode.hardware,
        nativeStateReader: () async => const GnssNativeState(
          hasPermission: true,
          isGpsEnabled: true,
        ),
        customFixStream: fixController.stream,
        customStatusStream: statusController.stream,
      );
      addTearDown(service.dispose);

      await tester.pumpWidget(wrapScreen(service));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Mencari satelit'), findsOneWidget);
      expect(find.text('Buka Pengaturan Lokasi'), findsOneWidget);
    });

    testWidgets(
        'menampilkan satelit terpakai/terlihat, konstelasi, C/N0, akurasi, dan skyplot saat aktif',
        (tester) async {
      final fixController = StreamController<GnssFix>.broadcast();
      final statusController = StreamController<GnssStatusSnapshot>.broadcast();
      addTearDown(() async {
        await fixController.close();
        await statusController.close();
      });

      final service = GnssService(
        mode: GnssSourceMode.hardware,
        nativeStateReader: () async => const GnssNativeState(
          hasPermission: true,
          isGpsEnabled: true,
        ),
        customFixStream: fixController.stream,
        customStatusStream: statusController.stream,
      );
      addTearDown(service.dispose);

      await tester.pumpWidget(wrapScreen(service));
      await tester.pump();

      fixController.add(sampleFix(accuracy: 8.5));
      statusController.add(sampleSnapshot());
      await tester.pump();

      expect(find.text('Sinyal kuat dan siap'), findsOneWidget);
      expect(find.text('2 / 3'), findsOneWidget);
      expect(find.text('8.5 m'), findsOneWidget);
      expect(find.text('35.2 dB-Hz'), findsOneWidget);
      expect(find.text('GPS: 1'), findsOneWidget);
      expect(find.text('GLONASS: 1'), findsOneWidget);
      expect(find.text('Galileo: 1'), findsOneWidget);
      expect(find.text('G12'), findsOneWidget);
      expect(find.text('Skyplot satelit'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('menampilkan peringatan "Sinyal GPS lemah" bila akurasi > 30 m',
        (tester) async {
      final fixController = StreamController<GnssFix>.broadcast();
      final statusController = StreamController<GnssStatusSnapshot>.broadcast();
      addTearDown(() async {
        await fixController.close();
        await statusController.close();
      });

      final service = GnssService(
        mode: GnssSourceMode.hardware,
        nativeStateReader: () async => const GnssNativeState(
          hasPermission: true,
          isGpsEnabled: true,
        ),
        customFixStream: fixController.stream,
        customStatusStream: statusController.stream,
      );
      addTearDown(service.dispose);

      await tester.pumpWidget(wrapScreen(service));
      await tester.pump();

      fixController.add(sampleFix(accuracy: 42.0));
      await tester.pump();

      expect(find.text('Sinyal GPS lemah'), findsOneWidget);
    });

    testWidgets(
        'state error menawarkan tombol Gunakan Simulasi dan beralih ke mode replay',
        (tester) async {
      final service = GnssService(
        mode: GnssSourceMode.hardware,
        nativeStateReader: () async => null,
      );
      addTearDown(service.dispose);

      await tester.pumpWidget(wrapScreen(service));
      await tester.pumpAndSettle();

      expect(find.text('Sensor GNSS tidak tersedia'), findsOneWidget);
      await tester.tap(find.text('Gunakan Simulasi'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));

      expect(service.mode, equals(GnssSourceMode.replay));
      expect(find.text('9 / 12'), findsOneWidget);
    });
  });

  group('US-01 Responsiveness & Text Scaling (R-03)', () {
    testWidgets('tidak overflow di ponsel sempit 360dp dengan textScale 2.0',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fixController = StreamController<GnssFix>.broadcast();
      final statusController = StreamController<GnssStatusSnapshot>.broadcast();
      addTearDown(() async {
        await fixController.close();
        await statusController.close();
      });

      final service = GnssService(
        mode: GnssSourceMode.hardware,
        nativeStateReader: () async => const GnssNativeState(
          hasPermission: true,
          isGpsEnabled: true,
        ),
        customFixStream: fixController.stream,
        customStatusStream: statusController.stream,
      );
      addTearDown(service.dispose);

      await tester.pumpWidget(
        wrapScreen(service, width: 360, height: 640, textScale: 2.0),
      );
      await tester.pump();

      fixController.add(sampleFix(accuracy: 9.2));
      statusController.add(sampleSnapshot());
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('reflow ke tata letak 2 kolom di layar lebar 800x600 tanpa overflow',
        (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fixController = StreamController<GnssFix>.broadcast();
      final statusController = StreamController<GnssStatusSnapshot>.broadcast();
      addTearDown(() async {
        await fixController.close();
        await statusController.close();
      });

      final service = GnssService(
        mode: GnssSourceMode.hardware,
        nativeStateReader: () async => const GnssNativeState(
          hasPermission: true,
          isGpsEnabled: true,
        ),
        customFixStream: fixController.stream,
        customStatusStream: statusController.stream,
      );
      addTearDown(service.dispose);

      await tester.pumpWidget(
        wrapScreen(service, width: 800, height: 600),
      );
      await tester.pump();

      fixController.add(sampleFix());
      statusController.add(sampleSnapshot());
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Skyplot satelit'), findsOneWidget);
      expect(find.text('Rincian satelit dan C/N0'), findsOneWidget);
    });
  });
}
