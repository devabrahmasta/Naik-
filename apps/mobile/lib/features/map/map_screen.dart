import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geo_core/geo_core.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_theme.dart';
import '../gnss/gnss_service.dart';
import 'offline_map_tile_provider.dart';

class OfflineMapScreen extends StatefulWidget {
  final GnssService? gnssService;
  final String? mbtilesPath;
  final List<GeoPoint> routePoints;

  const OfflineMapScreen({
    super.key,
    this.gnssService,
    this.mbtilesPath,
    this.routePoints = const [],
  });

  @override
  State<OfflineMapScreen> createState() => _OfflineMapScreenState();
}

class _OfflineMapScreenState extends State<OfflineMapScreen>
    with WidgetsBindingObserver {
  late final GnssService _service;
  late final bool _ownsService;
  final MapController _mapController = MapController();
  final FixGating _gating = FixGating();

  StreamSubscription<GnssFix>? _fixSubscription;
  StreamSubscription<GnssReadiness>? _readinessSubscription;
  OfflineMapPackage? _mapPackage;

  GnssFix? _acceptedFix;
  GnssFix? _latestRawFix;
  GnssReadiness _readiness =
      const GnssReadiness(state: GnssReadinessState.checking);
  bool _followingPosition = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _ownsService = widget.gnssService == null;
    _service = widget.gnssService ??
        GnssService(mode: GnssSourceMode.hardware);

    _mapPackage = OfflineMapPackage.open(widget.mbtilesPath);
    _readinessSubscription = _service.readinessStream.listen((value) {
      if (!mounted) return;
      setState(() => _readiness = value);
    });
    _fixSubscription = _service.fixStream.listen((fix) {
      final result = _gating.evaluate(fix);
      if (!mounted) return;
      setState(() {
        _latestRawFix = fix;
        if (result.isAccepted) {
          _acceptedFix = fix;
        } else {
          _acceptedFix = null;
        }
      });

      if (result.isAccepted && _followingPosition) {
        _mapController.move(
          LatLng(fix.latitude, fix.longitude),
          _mapController.camera.zoom,
        );
      }
    });

    _initialize();
  }

  Future<void> _initialize() async {
    await _service.start();
    if (!mounted) return;
    setState(() => _readiness = _service.currentReadiness);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _service.mode == GnssSourceMode.hardware) {
      _initialize();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fixSubscription?.cancel();
    _readinessSubscription?.cancel();
    _mapPackage?.dispose();
    _mapController.dispose();
    if (_ownsService) _service.dispose();
    super.dispose();
  }

  LatLng get _initialCenter {
    if (_acceptedFix != null) {
      return LatLng(_acceptedFix!.latitude, _acceptedFix!.longitude);
    }
    if (widget.routePoints.isNotEmpty) {
      final first = widget.routePoints.first;
      return LatLng(first.lat, first.lon);
    }
    return const LatLng(-7.4532, 110.4385);
  }

  String get _gpsStatus {
    if (_readiness.state == GnssReadinessState.permissionDenied) {
      return 'Izin lokasi diperlukan';
    }
    if (_readiness.state == GnssReadinessState.gpsDisabled) {
      return 'GPS perangkat mati';
    }
    if (_latestRawFix != null &&
        !_latestRawFix!.isMock &&
        _latestRawFix!.accuracy > 30) {
      return 'Sinyal GPS lemah';
    }
    if (_acceptedFix == null) {
      if (_readiness.state == GnssReadinessState.checking) {
        return 'Memeriksa GNSS';
      }
      return 'Mencari satelit';
    }
    if (_acceptedFix!.accuracy > 30) {
      return 'Sinyal GPS lemah';
    }
    return '${_acceptedFix!.accuracy.toStringAsFixed(1)} m akurasi';
  }

  void _recenter() {
    final fix = _acceptedFix;
    if (fix == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Belum ada posisi GPS yang valid')),
      );
      return;
    }
    setState(() => _followingPosition = true);
    _mapController.move(
      LatLng(fix.latitude, fix.longitude),
      _mapController.camera.zoom < 15
          ? 15
          : _mapController.camera.zoom,
    );
  }

  void _openLocationSettings() {
    _service.openLocationSettings();
  }

  @override
  Widget build(BuildContext context) {
    final route = widget.routePoints
        .map((point) => LatLng(point.lat, point.lon))
        .toList(growable: false);
    final accepted = _acceptedFix;

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: route.isNotEmpty ? 14 : 12,
              minZoom: 12,
              maxZoom: 16,
            ),
            children: [
              if (_mapPackage != null)
                TileLayer(
                  tileProvider: _mapPackage!.provider,
                  minNativeZoom: 12,
                  maxNativeZoom: 16,
                ),
              if (route.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: route,
                      strokeWidth: 4,
                      color: AppColors.route,
                      pattern: const StrokePattern.dotted(),
                    ),
                  ],
                ),
              if (accepted != null)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: LatLng(
                        accepted.latitude,
                        accepted.longitude,
                      ),
                      radius: accepted.accuracy,
                      useRadiusInMeter: true,
                      color: AppColors.track.withValues(alpha: 0.16),
                      borderColor: AppColors.track.withValues(alpha: 0.55),
                      borderStrokeWidth: 1.5,
                    ),
                  ],
                ),
              if (accepted != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(
                        accepted.latitude,
                        accepted.longitude,
                      ),
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.track,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 4,
                          ),
                          boxShadow: AppShadows.float,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (_mapPackage == null)
            Positioned(
              left: 16,
              right: 16,
              top: 170,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: AppShadows.card,
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Peta area belum tersedia',
                      style: AppTypography.headline,
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Gunakan paket MBTiles offline atau unduh area terlebih dahulu.',
                      style: AppTypography.body,
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            left: 16,
            right: 16,
            top: MediaQuery.paddingOf(context).top + 12,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _IconButton(
                  tooltip: 'Kembali',
                  icon: Icons.arrow_back_rounded,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 52),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: AppShadows.float,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Navigasi',
                          style: AppTypography.caption,
                        ),
                        Text(
                          _gpsStatus,
                          style: AppTypography.label,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 16,
            bottom: accepted == null ? 72 : 112,
            child: _IconButton(
              tooltip: 'Pusatkan posisi',
              icon: Icons.my_location_rounded,
              onPressed: _recenter,
            ),
          ),
          if (accepted != null)
            Positioned(
              left: 16,
              right: 76,
              bottom: 32,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: AppShadows.card,
                ),
                child: Text(
                  '${accepted.latitude.toStringAsFixed(5)}, '
                  '${accepted.longitude.toStringAsFixed(5)}',
                  style: AppTypography.label,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          if (_readiness.state == GnssReadinessState.permissionDenied)
            Positioned(
              left: 16,
              right: 16,
              bottom: 32,
              child: FilledButton(
                onPressed: _openLocationSettings,
                child: const Text('Buka Pengaturan Lokasi'),
              ),
            ),
          Positioned(
            left: 16,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '© OpenStreetMap contributors',
                style: TextStyle(
                  color: AppColors.ink2,
                  fontSize: 10,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  const _IconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          boxShadow: AppShadows.card,
        ),
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          icon: Icon(icon, color: AppColors.ink),
        ),
      ),
    );
  }
}
