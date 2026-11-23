/// Titik 2D pada bidang proyeksi lokal dalam satuan meter (x = Timur, y = Utara).
class LocalPoint {
  final double x; // Jarak ke timur dari titik acuan (meter)
  final double y; // Jarak ke utara dari titik acuan (meter)

  const LocalPoint(this.x, this.y);

  @override
  String toString() => 'LocalPoint(x: ${x.toStringAsFixed(1)}m, y: ${y.toStringAsFixed(1)}m)';
}
