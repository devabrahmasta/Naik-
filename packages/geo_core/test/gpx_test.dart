import 'dart:io';
import 'dart:math';

import 'package:geo_core/geo_core.dart';
import 'package:test/test.dart';

const _ns11 = 'xmlns="http://www.topografix.com/GPX/1/1"';

String gpx(String body, {String ns = _ns11}) =>
    '<?xml version="1.0"?><gpx version="1.1" $ns>$body</gpx>';

String pt(Object lat, Object lon, [Object? ele, String tag = 'trkpt']) =>
    '<$tag lat="$lat" lon="$lon">${ele == null ? '' : '<ele>$ele</ele>'}</$tag>';

Route ok(String text) {
  final r = parseGpx(text);
  expect(r, isA<GpxOk>(), reason: '$r');
  return (r as GpxOk).route;
}

String err(String text) {
  final r = parseGpx(text);
  expect(r, isA<GpxError>());
  return (r as GpxError).message;
}

void main() {
  test('one track segment: points, elevation and name', () {
    final route = ok(gpx('<trk><name> Jalur A </name><trkseg>'
        '${pt(-7.45, 110.43, 1500)}${pt(-7.46, 110.44, 1520.5)}${pt(-7.47, 110.45)}'
        '</trkseg></trk>'));
    expect(route.name, 'Jalur A');
    expect(route.segments, hasLength(1));
    final p = route.segments.single;
    expect([p[0].lat, p[0].lon, p[0].ele], [-7.45, 110.43, 1500]);
    expect(p[1].ele, 1520.5);
    expect(p[2].ele, isNull);
  });

  test('segments stay separate; empty and 1-point segments are dropped', () {
    final route = ok(gpx('<trk>'
        '<trkseg>${pt(1, 1)}${pt(1, 2)}</trkseg>'
        '<trkseg></trkseg>'
        '<trkseg>${pt(5, 5)}</trkseg>'
        '<trkseg>${pt(2, 1)}${pt(2, 2)}${pt(2, 3)}</trkseg>'
        '</trk>'));
    expect(route.segments.map((s) => s.length), [2, 3]);
    expect(route.name, isNull);
  });

  test('falls back to rte/rtept when there is no track', () {
    final route = ok(gpx('<rte><name>R</name>'
        '${pt(1, 1, null, 'rtept')}${pt(1, 2, null, 'rtept')}</rte>'));
    expect(route.name, 'R');
    expect(route.segments.single, hasLength(2));
  });

  test('GPX 1.0 namespace and non-numeric ele are accepted', () {
    final route = ok(gpx(
        '<trk><trkseg>${pt(1, 1, 'abc')}${pt(1, 2, 10)}</trkseg></trk>',
        ns: 'xmlns="http://www.topografix.com/GPX/1/0"'));
    expect(route.segments.single.map((p) => p.ele), [null, 10]);
  });

  group('errors', () {
    final cases = {
      'empty': ('', 'kosong'),
      'whitespace': ('  \n ', 'kosong'),
      'not xml': ('hello world', 'rusak'),
      'truncated': (gpx('<trk><trkseg>${pt(1, 1)}').substring(0, 60), 'rusak'),
      'kml root': ('<kml><Placemark/></kml>', 'bukan GPX'),
      'no points': (gpx('<trk><trkseg></trkseg></trk>'), 'tidak berisi titik'),
      'one point': (
        gpx('<trk><trkseg>${pt(1, 1)}</trkseg></trk>'),
        'minimal 2'
      ),
      'lat > 90': (
        gpx('<trk><trkseg>${pt(1, 1)}${pt(91, 1)}</trkseg></trk>'),
        'titik ke-2'
      ),
      'lon not a number': (
        gpx('<trk><trkseg>${pt(1, 'abc')}${pt(1, 1)}</trkseg></trk>'),
        'titik ke-1'
      ),
      'lat missing': (
        gpx('<trk><trkseg>${pt(1, 1)}<trkpt lon="1"/></trkseg></trk>'),
        'titik ke-2'
      ),
      'NaN': (
        gpx('<trk><trkseg>${pt('NaN', 1)}${pt(1, 1)}</trkseg></trk>'),
        'titik ke-1'
      ),
    };
    cases.forEach((name, c) {
      test(name, () => expect(err(c.$1), contains(c.$2)));
    });
  });

  test('never throws on mangled input', () {
    final valid =
        File('../../data/routes/contoh-sintetis.gpx').readAsStringSync();
    final rnd = Random(42);
    for (var i = 0; i < 300; i++) {
      final a = rnd.nextInt(valid.length), b = rnd.nextInt(valid.length);
      final chars = valid.split('')..[rnd.nextInt(valid.length)] = '<"&'[i % 3];
      for (final s in [valid.substring(min(a, b), max(a, b)), chars.join()]) {
        expect(parseGpx(s), isA<GpxResult>());
      }
    }
  });

  test('team sample file in data/routes parses', () {
    final route =
        ok(File('../../data/routes/contoh-sintetis.gpx').readAsStringSync());
    expect(route.name, contains('SINTETIS'));
    expect(route.segments.single, hasLength(6));
  });
}
