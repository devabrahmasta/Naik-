import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geo_core/geo_core.dart';
import 'package:hikenav_mobile/core/theme/app_theme.dart';
import 'package:hikenav_mobile/features/gnss/gnss_service.dart';
import 'package:hikenav_mobile/features/gnss/widgets/skyplot_painter.dart';

/// Layar Status GNSS dan Skyplot (US-01).
///
/// Menampilkan status satelit terlihat dan terpakai, konstelasi, nilai C/N0,
/// akurasi horizontal, skyplot polar, serta kondisi GPS mati / izin ditolak.
class GnssStatusScreen extends StatefulWidget {
  /// Opsional untuk injeksi dependensi saat pengujian widget.
  /// Jika null, layar membuat [GnssService] sendiri dan membuangnya saat ditutup.
  final GnssService? gnssService;

  const GnssStatusScreen({super.key, this.gnssService});

  @override
  State<GnssStatusScreen> createState() => _GnssStatusScreenState();
}

class _GnssStatusScreenState extends State<GnssStatusScreen>
    with WidgetsBindingObserver {
  late final GnssService _service;
  late final bool _ownsService;

  StreamSubscription<GnssReadiness>? _readinessSub;
  StreamSubscription<GnssFix>? _fixSub;
  StreamSubscription<GnssStatusSnapshot>? _statusSub;

  GnssReadiness _readiness =
      const GnssReadiness(state: GnssReadinessState.checking);
  GnssFix? _latestFix;
  GnssStatusSnapshot? _latestStatus;
  String? _streamError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _ownsService = widget.gnssService == null;
    _service = widget.gnssService ?? GnssService(mode: GnssSourceMode.hardware);

    _readinessSub = _service.readinessStream.listen((next) {
      if (!mounted) return;
      setState(() {
        _readiness = next;
      });
    });

    _fixSub = _service.fixStream.listen(
      (fix) {
        if (!mounted) return;
        setState(() {
          _latestFix = fix;
          _streamError = null;
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _streamError = error.toString();
        });
      },
    );

    _statusSub = _service.statusStream.listen(
      (snapshot) {
        if (!mounted) return;
        setState(() {
          _latestStatus = snapshot;
          _streamError = null;
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _streamError = error.toString();
        });
      },
    );

    _initializeService();
  }

  Future<void> _initializeService() async {
    await _service.start();
    if (mounted) {
      setState(() {
        _readiness = _service.currentReadiness;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Saat pengguna kembali dari Pengaturan Android, periksa ulang izin/GPS
    if (state == AppLifecycleState.resumed &&
        _service.mode == GnssSourceMode.hardware) {
      _initializeService();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _readinessSub?.cancel();
    _fixSub?.cancel();
    _statusSub?.cancel();
    if (_ownsService) {
      _service.dispose();
    }
    super.dispose();
  }

  Future<void> _switchMode(GnssSourceMode newMode) async {
    setState(() {
      _latestFix = null;
      _latestStatus = null;
      _streamError = null;
      _readiness = const GnssReadiness(state: GnssReadinessState.checking);
    });
    await _service.setMode(newMode);
    if (mounted) {
      setState(() {
        _readiness = _service.currentReadiness;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Status GNSS'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Kembali',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 680;
            final horizontalPadding = isWide ? 24.0 : 16.0;

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                8,
                horizontalPadding,
                24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ModeSelectorStrip(
                    activeMode: _service.mode,
                    onModeChanged: _switchMode,
                  ),
                  const SizedBox(height: 16),
                  _buildBodyByState(isWide),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBodyByState(bool isWide) {
    if (_streamError != null) {
      return _GnssActionStateCard(
        icon: Icons.error_outline_rounded,
        iconColor: AppColors.danger,
        backgroundColor: AppColors.warnBg,
        title: 'Gagal membaca sinyal GNSS',
        description: _streamError!,
        primaryLabel: 'Coba Lagi',
        onPrimaryTap: _initializeService,
        secondaryLabel: _service.mode == GnssSourceMode.hardware
            ? 'Beralih ke Simulasi'
            : null,
        onSecondaryTap: _service.mode == GnssSourceMode.hardware
            ? () => _switchMode(GnssSourceMode.replay)
            : null,
      );
    }

    switch (_readiness.state) {
      case GnssReadinessState.checking:
        return const _CheckingStateCard();

      case GnssReadinessState.permissionDenied:
        return _GnssActionStateCard(
          icon: Icons.location_off_rounded,
          iconColor: AppColors.accent,
          backgroundColor: AppColors.warnBg,
          title: 'Izin lokasi diperlukan',
          description:
              'HikeNav memerlukan izin lokasi tepat untuk membaca sinyal satelit dan akurasi posisi langsung dari perangkat tanpa internet.',
          primaryLabel: 'Izinkan Lokasi',
          onPrimaryTap: () async {
            await _service.requestPermission();
            if (mounted) {
              setState(() {
                _readiness = _service.currentReadiness;
              });
            }
          },
          secondaryLabel: 'Buka Pengaturan Aplikasi',
          onSecondaryTap: _service.openAppSettings,
          tertiaryLabel: 'Gunakan Simulasi',
          onTertiaryTap: () => _switchMode(GnssSourceMode.replay),
        );

      case GnssReadinessState.gpsDisabled:
        return _GnssActionStateCard(
          icon: Icons.gps_off_rounded,
          iconColor: AppColors.accent,
          backgroundColor: AppColors.warnBg,
          title: 'GPS perangkat mati',
          description:
              'Aktifkan layanan lokasi (GPS) pada perangkat agar satelit dapat dilacak dan posisi Anda dapat diketahui.',
          primaryLabel: 'Buka Pengaturan Lokasi',
          onPrimaryTap: _service.openLocationSettings,
          secondaryLabel: 'Periksa Ulang',
          onSecondaryTap: _initializeService,
          tertiaryLabel: 'Gunakan Simulasi',
          onTertiaryTap: () => _switchMode(GnssSourceMode.replay),
        );

      case GnssReadinessState.error:
        return _GnssActionStateCard(
          icon: Icons.sensors_off_rounded,
          iconColor: AppColors.danger,
          backgroundColor: AppColors.warnBg,
          title: 'Sensor GNSS tidak tersedia',
          description: _readiness.message ??
              'Perangkat atau emulator ini tidak menyediakan sensor GNSS langsung.',
          primaryLabel: 'Gunakan Simulasi',
          onPrimaryTap: () => _switchMode(GnssSourceMode.replay),
          secondaryLabel: 'Coba Lagi',
          onSecondaryTap: _initializeService,
        );

      case GnssReadinessState.ready:
        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSignalStatusBanner(),
                    const SizedBox(height: 16),
                    _buildMetricGrid(),
                    const SizedBox(height: 16),
                    _buildSkyplotCard(),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildConstellationSection(),
                    const SizedBox(height: 16),
                    _buildSatelliteListCard(),
                  ],
                ),
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSignalStatusBanner(),
            const SizedBox(height: 16),
            _buildMetricGrid(),
            const SizedBox(height: 16),
            _buildSkyplotCard(),
            const SizedBox(height: 16),
            _buildConstellationSection(),
            const SizedBox(height: 16),
            _buildSatelliteListCard(),
          ],
        );
    }
  }

  Widget _buildSignalStatusBanner() {
    final fix = _latestFix;
    final status = _latestStatus;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    if (fix == null) {
      final visibleInfo = status != null && status.visibleCount > 0
          ? '${status.visibleCount} satelit mulai tertangkap. Tunggu di area terbuka.'
          : 'Menunggu tangkapan sinyal satelit di area terbuka.';

      return _SurfaceCard(
        backgroundColor: AppColors.tonal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (reduceMotion)
                  const Icon(
                    Icons.satellite_alt_rounded,
                    color: AppColors.primaryText,
                    size: 24,
                  )
                else
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.primaryText,
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Mencari satelit',
                    style: AppTypography.headline.copyWith(
                      color: AppColors.primaryText,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              visibleInfo,
              style: AppTypography.body.copyWith(fontSize: 14),
            ),
            if (_service.mode == GnssSourceMode.hardware) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _service.openLocationSettings,
                icon: const Icon(Icons.settings_rounded, size: 18),
                label: const Text('Buka Pengaturan Lokasi'),
              ),
            ],
          ],
        ),
      );
    }

    // Evaluasi akurasi terhadap ambang batas A_max = 30m (PRD L1)
    final double acc = fix.accuracy;
    final bool isWeak = acc > 30.0;
    final bool isGood = acc <= 15.0;

    final Color bg = isWeak ? AppColors.warnBg : AppColors.tonal;
    final Color fg = isWeak ? AppColors.accentText : AppColors.primaryText;
    final IconData icon = isWeak
        ? Icons.warning_amber_rounded
        : (isGood ? Icons.gps_fixed_rounded : Icons.gps_not_fixed_rounded);
    final String label = isWeak
        ? 'Sinyal GPS lemah'
        : (isGood ? 'Sinyal kuat dan siap' : 'Sinyal cukup baik');
    final String detail = isWeak
        ? 'Akurasi ${acc.toStringAsFixed(1)} m melewati batas aman 30 m. Peringatan keluar jalur ditunda sementara.'
        : 'Akurasi horizontal ${acc.toStringAsFixed(1)} m. Posisi dapat dipercaya untuk navigasi.';

    return Semantics(
      liveRegion: true,
      label: '$label. $detail',
      child: _SurfaceCard(
        backgroundColor: bg,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: fg, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTypography.headline.copyWith(color: fg),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    detail,
                    style: AppTypography.body.copyWith(
                      fontSize: 14,
                      color: AppColors.ink,
                    ),
                  ),
                  if (fix.isMock) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Sumber terdeteksi sebagai lokasi simulasi/mock sistem.',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.accentText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricGrid() {
    final fix = _latestFix;
    final status = _latestStatus;

    final int? used = status?.usedCount ?? fix?.satellitesUsed;
    final int? visible = status?.visibleCount ??
        ((fix != null && fix.satellitesVisible > 0)
            ? fix.satellitesVisible
            : null);

    final String satValue = (used == null && visible == null)
        ? '-'
        : '${used ?? '-'} / ${visible ?? '-'}';

    final String accuracyValue =
        fix != null ? '${fix.accuracy.toStringAsFixed(1)} m' : '-';

    final double? avgCn0 = status?.averageCn0Used ?? status?.averageCn0Visible;
    final String cn0Value =
        avgCn0 != null ? '${avgCn0.toStringAsFixed(1)} dB-Hz' : '-';

    final String coordValue = fix != null
        ? '${fix.latitude.toStringAsFixed(5)}, ${fix.longitude.toStringAsFixed(5)}'
        : '-';

    return LayoutBuilder(
      builder: (context, constraints) {
        final double itemWidth = (constraints.maxWidth - 12) / 2;
        final bool singleCol = constraints.maxWidth < 300;
        final double cardWidth = singleCol ? constraints.maxWidth : itemWidth;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: cardWidth,
              child: _MetricTile(
                icon: Icons.satellite_alt_rounded,
                label: 'Satelit terpakai',
                value: satValue,
                subtitle: 'Terpakai / terlihat',
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _MetricTile(
                icon: Icons.my_location_rounded,
                label: 'Akurasi horizontal',
                value: accuracyValue,
                subtitle: 'Batas baik <= 30 m',
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _MetricTile(
                icon: Icons.network_cell_rounded,
                label: 'Rata-rata C/N0',
                value: cn0Value,
                subtitle: 'Kuat sinyal satelit',
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _MetricTile(
                icon: Icons.pin_drop_rounded,
                label: 'Koordinat fix',
                value: coordValue,
                subtitle: fix != null
                    ? 'Tinggi ${fix.altitude.toStringAsFixed(0)} m'
                    : 'Belum ada posisi',
                compactValue: true,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSkyplotCard() {
    final satellites = _latestStatus?.satellites ?? const <SatelliteInfo>[];
    final usedCount = _latestStatus?.usedCount ?? 0;
    final visibleCount = _latestStatus?.visibleCount ?? 0;

    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.radar_rounded,
                color: AppColors.primaryText,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Skyplot satelit',
                  style: AppTypography.headline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Posisi azimut dan sudut elevasi satelit di atas cakrawala.',
            style: AppTypography.caption,
          ),
          const SizedBox(height: 16),
          if (satellites.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.public_rounded,
                    size: 36,
                    color: AppColors.ink2,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Belum ada data sebaran satelit',
                    textAlign: TextAlign.center,
                    style: AppTypography.label,
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Daftar satelit dan posisi skyplot akan muncul otomatis saat sinyal tertangkap.',
                    textAlign: TextAlign.center,
                    style: AppTypography.caption,
                  ),
                ],
              ),
            )
          else ...[
            Semantics(
              label:
                  'Grafik skyplot GNSS menampilkan $usedCount satelit terpakai dari $visibleCount satelit terlihat. Lihat daftar di bawah untuk rincian angka per satelit.',
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 300, maxHeight: 300),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: CustomPaint(
                      painter: SkyplotPainter(
                        satellites: satellites,
                        textScaler: MediaQuery.textScalerOf(context),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 8,
              children: [
                _LegendItem(filled: true, label: 'Dipakai dalam fix'),
                _LegendItem(filled: false, label: 'Terlihat saja'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConstellationSection() {
    final counts = _latestStatus?.constellationCounts ?? const {};

    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Konstelasi aktif',
            style: AppTypography.headline,
          ),
          const SizedBox(height: 10),
          if (counts.isEmpty)
            const Text(
              'Belum ada konstelasi yang terdeteksi.',
              style: AppTypography.caption,
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: counts.entries.map((entry) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.tonal,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '${entry.key.label}: ${entry.value}',
                    style: AppTypography.tabular(
                      AppTypography.label.copyWith(
                        color: AppColors.primaryText,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildSatelliteListCard() {
    final satellites = [...(_latestStatus?.satellites ?? const <SatelliteInfo>[])]
      ..sort((a, b) {
        if (a.usedInFix != b.usedInFix) {
          return a.usedInFix ? -1 : 1;
        }
        return b.cn0DbHz.compareTo(a.cn0DbHz);
      });

    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Rincian satelit dan C/N0',
                  style: AppTypography.headline,
                ),
              ),
              Text(
                '${satellites.length} satelit',
                style: AppTypography.tabular(AppTypography.caption),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Satelit dengan C/N0 lebih tinggi memberi akurasi lebih stabil.',
            style: AppTypography.caption,
          ),
          const SizedBox(height: 12),
          if (satellites.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Daftar rincian satelit masih kosong.',
                style: AppTypography.caption,
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: satellites.length,
              separatorBuilder: (_, _) => const Divider(
                height: 16,
                thickness: 1,
                color: AppColors.divider,
              ),
              itemBuilder: (context, index) {
                return _SatelliteRow(satellite: satellites[index]);
              },
            ),
        ],
      ),
    );
  }
}

/// Sakelar sumber data: Sensor Nyata vs Simulasi Replay (untuk uji di dalam ruangan).
class _ModeSelectorStrip extends StatelessWidget {
  final GnssSourceMode activeMode;
  final ValueChanged<GnssSourceMode> onModeChanged;

  const _ModeSelectorStrip({
    required this.activeMode,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeSegmentButton(
              label: 'Sensor Nyata',
              icon: Icons.sensors_rounded,
              selected: activeMode == GnssSourceMode.hardware,
              onTap: () => onModeChanged(GnssSourceMode.hardware),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ModeSegmentButton(
              label: 'Simulasi Replay',
              icon: Icons.play_circle_outline_rounded,
              selected: activeMode == GnssSourceMode.replay,
              onTap: () => onModeChanged(GnssSourceMode.replay),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeSegmentButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ModeSegmentButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? AppColors.primary : Colors.transparent;
    final fg = selected ? Colors.white : AppColors.ink2;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18, color: fg),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: AppTypography.label.copyWith(color: fg),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  final Widget child;
  final Color backgroundColor;

  const _SurfaceCard({
    required this.child,
    this.backgroundColor = AppColors.surface,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.card,
      ),
      child: child,
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String subtitle;
  final bool compactValue;

  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.subtitle,
    this.compactValue = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: AppColors.tonal,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: AppColors.primaryText),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.ink2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: AppTypography.tabular(
              compactValue
                  ? AppTypography.label.copyWith(fontSize: 14)
                  : AppTypography.title.copyWith(fontSize: 20),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: AppTypography.caption,
          ),
        ],
      ),
    );
  }
}

class _SatelliteRow extends StatelessWidget {
  final SatelliteInfo satellite;

  const _SatelliteRow({required this.satellite});

  @override
  Widget build(BuildContext context) {
    final double ratio = (satellite.cn0DbHz / 50.0).clamp(0.0, 1.0);
    final Color barColor = satellite.usedInFix
        ? AppColors.primary
        : AppColors.ink2.withValues(alpha: 0.45);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  satellite.displayId,
                  style: AppTypography.tabular(AppTypography.label),
                ),
                const SizedBox(width: 8),
                Text(
                  satellite.constellation.label,
                  style: AppTypography.caption.copyWith(color: AppColors.ink),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: satellite.usedInFix ? AppColors.tonal : AppColors.bg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                satellite.usedInFix ? 'Dipakai' : 'Terlihat',
                style: AppTypography.caption.copyWith(
                  color: satellite.usedInFix
                      ? AppColors.primaryText
                      : AppColors.ink2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 8,
                  backgroundColor: AppColors.bg,
                  valueColor: AlwaysStoppedAnimation<Color>(barColor),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${satellite.cn0DbHz.toStringAsFixed(1)} dB-Hz',
              style: AppTypography.tabular(
                AppTypography.label.copyWith(fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Elevasi ${satellite.elevationDegrees.toStringAsFixed(0)}° · Azimut ${satellite.azimuthDegrees.toStringAsFixed(0)}°',
          style: AppTypography.tabular(AppTypography.caption),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final bool filled;
  final String label;

  const _LegendItem({required this.filled, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? AppColors.primary : Colors.transparent,
            border: filled
                ? null
                : Border.all(color: AppColors.primary, width: 2),
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(label, style: AppTypography.caption),
        ),
      ],
    );
  }
}

class _CheckingStateCard extends StatelessWidget {
  const _CheckingStateCard();

  @override
  Widget build(BuildContext context) {
    return const _SurfaceCard(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16),
            Text(
              'Memeriksa kesiapan sensor GNSS...',
              style: AppTypography.label,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _GnssActionStateCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final String title;
  final String description;
  final String primaryLabel;
  final VoidCallback onPrimaryTap;
  final String? secondaryLabel;
  final VoidCallback? onSecondaryTap;
  final String? tertiaryLabel;
  final VoidCallback? onTertiaryTap;

  const _GnssActionStateCard({
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.title,
    required this.description,
    required this.primaryLabel,
    required this.onPrimaryTap,
    this.secondaryLabel,
    this.onSecondaryTap,
    this.tertiaryLabel,
    this.onTertiaryTap,
  });

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      backgroundColor: backgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.surface,
              child: Icon(icon, color: iconColor, size: 26),
            ),
          ),
          const SizedBox(height: 16),
          Text(title, style: AppTypography.title.copyWith(fontSize: 20)),
          const SizedBox(height: 8),
          Text(description, style: AppTypography.body.copyWith(fontSize: 15)),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: onPrimaryTap,
            child: Text(primaryLabel),
          ),
          if (secondaryLabel != null && onSecondaryTap != null) ...[
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: onSecondaryTap,
              child: Text(secondaryLabel!),
            ),
          ],
          if (tertiaryLabel != null && onTertiaryTap != null) ...[
            const SizedBox(height: 8),
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                foregroundColor: AppColors.ink,
              ),
              onPressed: onTertiaryTap,
              child: Text(tertiaryLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
