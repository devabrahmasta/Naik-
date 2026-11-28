import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hikenav_mobile/features/gnss/gnss_status_screen.dart';
import 'package:hikenav_mobile/features/onboarding/location_permission_screen.dart';
import 'package:hikenav_mobile/main.dart';

void main() {
  testWidgets('HikeNav smoke test and temporary GNSS navigation check',
      (WidgetTester tester) async {
    const channel = MethodChannel('com.hikenav/gnss_control');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall call) async {
        if (call.method == 'getGnssState') {
          return {
            'hasPermission': false,
            'isGpsEnabled': true,
            'isTracking': false,
            'isMonitoring': false,
          };
        }
        return true;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      );
    });

    await tester.pumpWidget(const HikeNavApp());

    expect(find.text('HikeNav'), findsOneWidget);
    expect(find.text('HikeNav Offline GNSS'), findsOneWidget);
    expect(find.text('Cek Status GNSS'), findsOneWidget);
    expect(find.text('Penggunaan Pertama'), findsOneWidget);

    await tester.tap(find.text('Cek Status GNSS'));
    await tester.pumpAndSettle();

    expect(find.byType(GnssStatusScreen), findsOneWidget);
    expect(find.text('Status GNSS'), findsOneWidget);
    expect(find.text('Izin lokasi diperlukan'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Penggunaan Pertama'));
    await tester.pumpAndSettle();

    expect(find.byType(LocationPermissionScreen), findsOneWidget);
  });
}
