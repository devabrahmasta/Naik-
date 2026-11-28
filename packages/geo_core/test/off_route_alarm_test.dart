import 'package:geo_core/geo_core.dart';
import 'package:test/test.dart';

final start = DateTime(2026, 1, 1, 8, 0, 0);

/// Kirim satu fix bagus pada detik ke-[second]. Akurasi 5 m, jadi T = 30 m.
void fix(OffRouteDetector d, int second, double distance) {
  d.update(
    crossTrackDistance: distance,
    accuracy: 5,
    timestamp: start.add(Duration(seconds: second)),
  );
}

/// 5 fix di luar jalur (100 m) tiap 4 detik, terkonfirmasi di detik ke-16.
void goOffRoute(OffRouteDetector d, int fromSecond) {
  for (var i = 0; i < 5; i++) {
    fix(d, fromSecond + i * 4, 100);
  }
}

void main() {
  test('alarm bunyi di fix ke-5 saja, tidak di fix ke-6', () {
    final d = OffRouteDetector();
    for (var i = 0; i < 4; i++) {
      fix(d, i * 4, 100);
      expect(d.shouldAlarm, isFalse);
    }

    fix(d, 16, 100); // fix ke-5
    expect(d.isOffRoute, isTrue);
    expect(d.shouldAlarm, isTrue);

    fix(d, 20, 100); // fix ke-6
    expect(d.shouldAlarm, isFalse);
  });

  test('alarm diulang setelah 60 detik, tidak di detik ke-30', () {
    final d = OffRouteDetector();
    goOffRoute(d, 0); // alarm pertama di detik 16

    fix(d, 46, 100);
    expect(d.shouldAlarm, isFalse);

    fix(d, 76, 100);
    expect(d.shouldAlarm, isTrue);
  });

  test('sinyal lemah tidak membunyikan alarm dan tidak mereset hitungan', () {
    final d = OffRouteDetector();
    for (var i = 0; i < 4; i++) {
      fix(d, i * 4, 100);
    }

    d.weakSignal();
    expect(d.isWeakSignal, isTrue);
    expect(d.shouldAlarm, isFalse);
    expect(d.isOffRoute, isFalse);

    fix(d, 16, 100); // tetap dihitung fix ke-5
    expect(d.isWeakSignal, isFalse);
    expect(d.isOffRoute, isTrue);
    expect(d.shouldAlarm, isTrue);
  });

  test('jatah alarm saat sinyal lemah ditunda ke fix bagus berikutnya', () {
    final d = OffRouteDetector();
    goOffRoute(d, 0); // alarm pertama di detik 16

    d.weakSignal(); // sekitar detik 76, jatah alarm kedua
    expect(d.shouldAlarm, isFalse);

    fix(d, 80, 100);
    expect(d.shouldAlarm, isTrue);
  });

  test('kembali ke jalur lalu keluar lagi: alarm langsung bunyi', () {
    final d = OffRouteDetector();
    goOffRoute(d, 0); // alarm pertama di detik 16

    for (var s = 20; s <= 24; s += 2) {
      fix(d, s, 0);
    }
    expect(d.isOffRoute, isFalse);

    // Terkonfirmasi lagi di detik 46, baru 30 dtk dari alarm pertama.
    goOffRoute(d, 30);
    expect(d.isOffRoute, isTrue);
    expect(d.shouldAlarm, isTrue);
  });
}
