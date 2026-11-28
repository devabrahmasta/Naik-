import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hikenav_mobile/core/theme/app_theme.dart';
import 'package:hikenav_mobile/features/gnss/gnss_service.dart';
import 'package:hikenav_mobile/features/onboarding/location_permission_screen.dart';
import 'package:hikenav_mobile/core/platform/gnss_channel.dart';

void main() {
  Widget wrapScreen(GnssService service, {VoidCallback? onContinue}) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: MediaQuery(
        data: const MediaQueryData(size: Size(390, 844)),
        child: LocationPermissionScreen(
          gnssService: service,
          onContinue: onContinue,
        ),
      ),
    );
  }

  testWidgets('menjelaskan izin sebelum menampilkan tindakan',
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
    expect(
      find.textContaining('Tidak memakai lokasi diam-diam'),
      findsNothing,
    );
    expect(
      find.textContaining('tidak akan mengambil posisi pengguna'),
      findsOneWidget,
    );
  });

  testWidgets('menampilkan keadaan GPS mati dan tombol pengaturan',
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

    expect(find.text('Layanan lokasi mati'), findsOneWidget);
    expect(find.text('Buka Pengaturan Lokasi'), findsOneWidget);
  });

  testWidgets('menampilkan siap dan memanggil callback lanjut',
      (tester) async {
    var continued = false;
    final service = GnssService(
      mode: GnssSourceMode.hardware,
      nativeStateReader: () async => const GnssNativeState(
        hasPermission: true,
        isGpsEnabled: true,
      ),
    );
    addTearDown(service.dispose);

    await tester.pumpWidget(wrapScreen(
      service,
      onContinue: () => continued = true,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Lokasi siap'), findsOneWidget);
    expect(find.text('Lanjutkan'), findsOneWidget);

    await tester.tap(find.text('Lanjutkan'));
    await tester.pump();

    expect(continued, isTrue);
  });

  testWidgets('native tidak tersedia menampilkan galat dan retry',
      (tester) async {
    final service = GnssService(
      mode: GnssSourceMode.hardware,
      nativeStateReader: () async => null,
    );
    addTearDown(service.dispose);

    await tester.pumpWidget(wrapScreen(service));
    await tester.pumpAndSettle();

    expect(find.text('GNSS tidak dapat diperiksa'), findsOneWidget);
    expect(find.text('Coba Lagi'), findsOneWidget);
    expect(find.text('Buka Pengaturan Aplikasi'), findsOneWidget);
  });

  testWidgets('permintaan izin ditolak tetap menampilkan pengaturan',
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
}
