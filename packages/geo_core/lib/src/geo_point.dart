/// A WGS84 position. [ele] is metres, null when unknown.
class GeoPoint {
  final double lat;
  final double lon;
  final double? ele;

  const GeoPoint(this.lat, this.lon, [this.ele]);

  @override
  String toString() => 'GeoPoint($lat, $lon, $ele)';
}
