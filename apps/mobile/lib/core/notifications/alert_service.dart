/// Layanan notifikasi lokal dan getaran (haptic) offline.
/// Sesuai US-06: Getar pola 3 x 400 ms, banner, dan notifikasi offline.
abstract class AlertService {
  Future<void> triggerOffRouteAlert({
    required double distanceMeters,
    required double bearingDegrees,
  });

  Future<void> dismissOffRouteAlert();
}
