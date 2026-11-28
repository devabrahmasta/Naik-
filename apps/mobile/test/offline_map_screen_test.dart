import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geo_core/geo_core.dart';
import 'package:hikenav_mobile/core/platform/gnss_channel.dart';
import 'package:hikenav_mobile/core/theme/app_theme.dart';
import 'package:hikenav_mobile/features/gnss/gnss_service.dart';
import 'package:hikenav_mobile/features/map/map_screen.dart';

void main() {
  Widget wrapScreen(GnssService service) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: MediaQuery(
        data: const MediaQueryData(size: Size(390, 844)),
        child: OfflineMapScreen(gnssService: service),
      ),
    );
  }

  GnssFix fix({
    double accuracy = 8.5,
    bool isMock = false,
  }) {
    return GnssFix(
      latitude: -7.45320,
      longitude: 110.43850,
      altitude: 2650,
      accuracy: accuracy,
      speed: 1.2,
      bearing: 20,
      satellitesUsed: 8,
      satellitesVisible: 12,
      timestamp: DateTime(2026, 11, 28, 11, 0),
      isMock: isMock,
    );
  }

  GnssService serviceWithFixStream(StreamController<GnssFix> fixes) {
    return GnssService(
      mode: GnssSourceMode.hardware,
      nativeStateReader: () async => const GnssNativeState(
        hasPermission: true,
        isGpsEnabled: true,
      ),
      customFixStream: fixes.stream,
    );
  }

  testWidgets('menampilkan kanvas offline kosong tanpa paket',
      (tester) async {
    final fixes = StreamController<GnssFix>.broadcast();
    final service = serviceWithFixStream(fixes);
    addTearDown(fixes.close);
    addTearDown(service.dispose);

    await tester.pumpWidget(wrapScreen(service));
    await tester.pumpAndSettle();

    expect(find.text('Peta area belum tersedia'), findsOneWidget);
    expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
  });

  testWidgets('menampilkan koordinat dan menolak fix mock',
      (tester) async {
    final fixes = StreamController<GnssFix>.broadcast();
    final service = serviceWithFixStream(fixes);
    addTearDown(fixes.close);
    addTearDown(service.dispose);

    await tester.pumpWidget(wrapScreen(service));
    await tester.pumpAndSettle();

    fixes.add(fix(isMock: true));
    await tester.pump();
    expect(find.textContaining('-7.45320'), findsNothing);

    fixes.add(fix());
    await tester.pump();
    expect(find.textContaining('-7.45320'), findsOneWidget);
    expect(find.textContaining('8.5 m akurasi'), findsOneWidget);
  });

  testWidgets('mempertahankan status sinyal lemah untuk akurasi buruk',
      (tester) async {
    final fixes = StreamController<GnssFix>.broadcast();
    final service = serviceWithFixStream(fixes);
    addTearDown(fixes.close);
    addTearDown(service.dispose);

    await tester.pumpWidget(wrapScreen(service));
    await tester.pumpAndSettle();

    fixes.add(fix(accuracy: 35));
    await tester.pump();
    expect(find.text('Sinyal GPS lemah'), findsOneWidget);
  });
}
