/// Abstraksi penyimpanan lokal SQLite untuk rute, rekaman jejak, waypoint, dan log fix GNSS.
/// Diimplementasikan sesuai US-04, US-05, US-07, US-10.
abstract class AppDatabase {
  Future<void> initialize();
  Future<void> close();
}
