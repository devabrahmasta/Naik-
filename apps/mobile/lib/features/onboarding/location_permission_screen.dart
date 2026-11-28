import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../gnss/gnss_service.dart';

class LocationPermissionScreen extends StatefulWidget {
  final GnssService? gnssService;
  final VoidCallback? onContinue;

  const LocationPermissionScreen({
    super.key,
    this.gnssService,
    this.onContinue,
  });

  @override
  State<LocationPermissionScreen> createState() =>
      _LocationPermissionScreenState();
}

class _LocationPermissionScreenState extends State<LocationPermissionScreen>
    with WidgetsBindingObserver {
  late final GnssService _service;
  late final bool _ownsService;
  StreamSubscription<GnssReadiness>? _readinessSubscription;
  GnssReadiness _readiness =
      const GnssReadiness(state: GnssReadinessState.checking);
  bool _showExplanation = true;
  bool _isRequesting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ownsService = widget.gnssService == null;
    _service = widget.gnssService ??
        GnssService(mode: GnssSourceMode.hardware);

    _readinessSubscription = _service.readinessStream.listen((readiness) {
      if (!mounted) return;
      setState(() {
        _readiness = readiness;
      });
    });
    _initialize();
  }

  Future<void> _initialize() async {
    await _service.start();
    if (!mounted) return;
    setState(() {
      _readiness = _service.currentReadiness;
    });
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
    _readinessSubscription?.cancel();
    if (_ownsService) _service.dispose();
    super.dispose();
  }

  Future<void> _requestPermission() async {
    setState(() {
      _isRequesting = true;
      _showExplanation = false;
    });
    await _service.requestPermission();
    if (!mounted) return;
    setState(() {
      _isRequesting = false;
      _readiness = _service.currentReadiness;
    });
  }

  Future<void> _openAppSettings() async {
    await _service.openAppSettings();
  }

  Future<void> _openLocationSettings() async {
    await _service.openLocationSettings();
  }

  void _continue() {
    final callback = widget.onContinue;
    if (callback != null) {
      callback();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = _readiness.state;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 680;
            final horizontalPadding = isWide ? 32.0 : 16.0;

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                12,
                horizontalPadding,
                24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 36,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        tooltip: 'Kembali',
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.surface,
                          foregroundColor: AppColors.ink,
                          minimumSize: const Size(48, 48),
                          elevation: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      height: isWide ? 300 : 220,
                      decoration: BoxDecoration(
                        color: AppColors.tonal,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        _headerIcon(state),
                        size: isWide ? 100 : 84,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _title(state),
                      style: AppTypography.title,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _description(state),
                      style: AppTypography.body,
                    ),
                    if (_showExplanation &&
                        state == GnssReadinessState.permissionDenied) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Izin digunakan untuk menentukan posisi, akurasi, dan satelit. HikeNav tidak memakai lokasi diam-diam atau mengirimnya ke server.',
                        style: AppTypography.caption,
                      ),
                    ],
                    const SizedBox(height: 24),
                    _buildActions(state, reduceMotion),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  IconData _headerIcon(GnssReadinessState state) {
    switch (state) {
      case GnssReadinessState.ready:
        return Icons.location_on_rounded;
      case GnssReadinessState.permissionDenied:
        return Icons.location_off_rounded;
      case GnssReadinessState.gpsDisabled:
        return Icons.gps_off_rounded;
      case GnssReadinessState.error:
        return Icons.error_outline_rounded;
      case GnssReadinessState.checking:
        return Icons.satellite_alt_rounded;
    }
  }

  String _title(GnssReadinessState state) {
    switch (state) {
      case GnssReadinessState.checking:
        return 'Memeriksa lokasi';
      case GnssReadinessState.ready:
        return 'Lokasi siap';
      case GnssReadinessState.permissionDenied:
        return 'Izin lokasi diperlukan';
      case GnssReadinessState.gpsDisabled:
        return 'Layanan lokasi mati';
      case GnssReadinessState.error:
        return 'GNSS tidak dapat diperiksa';
    }
  }

  String _description(GnssReadinessState state) {
    switch (state) {
      case GnssReadinessState.checking:
        return 'HikeNav memeriksa apakah izin lokasi dan layanan GPS sudah tersedia.';
      case GnssReadinessState.ready:
        return 'Izin lokasi tersedia. Anda dapat melanjutkan ke persiapan pendakian.';
      case GnssReadinessState.permissionDenied:
        return 'HikeNav membutuhkan lokasi tepat untuk menampilkan posisi, akurasi GNSS, dan navigasi rute. Tanpa izin, aplikasi tidak akan mengambil posisi pengguna.';
      case GnssReadinessState.gpsDisabled:
        return 'Aktifkan layanan lokasi perangkat agar HikeNav dapat membaca posisi dan satelit.';
      case GnssReadinessState.error:
        return _readiness.message ??
            'Terjadi kesalahan saat memeriksa layanan lokasi.';
    }
  }

  Widget _buildActions(
    GnssReadinessState state,
    bool reduceMotion,
  ) {
    if (state == GnssReadinessState.ready) {
      return FilledButton.icon(
        onPressed: _continue,
        icon: const Icon(Icons.check_circle_rounded),
        label: const Text('Lanjutkan'),
      );
    }

    if (state == GnssReadinessState.checking) {
      return FilledButton.icon(
        onPressed: null,
        icon: reduceMotion
            ? const Icon(Icons.satellite_alt_rounded)
            : const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
        label: const Text('Memeriksa'),
      );
    }

    if (state == GnssReadinessState.gpsDisabled) {
      return FilledButton.icon(
        onPressed: _openLocationSettings,
        icon: const Icon(Icons.location_searching_rounded),
        label: const Text('Buka Pengaturan Lokasi'),
      );
    }

    if (state == GnssReadinessState.permissionDenied) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: _isRequesting ? null : _requestPermission,
            icon: const Icon(Icons.location_on_rounded),
            label: const Text('Izinkan Lokasi'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _openAppSettings,
            icon: const Icon(Icons.settings_rounded),
            label: const Text('Buka Pengaturan Aplikasi'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: _initialize,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Coba Lagi'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _openAppSettings,
          icon: const Icon(Icons.settings_rounded),
          label: const Text('Buka Pengaturan Aplikasi'),
        ),
      ],
    );
  }
}
