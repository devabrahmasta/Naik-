import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geo_core/geo_core.dart';
import 'package:hikenav_mobile/core/theme/app_theme.dart';

/// Menggambar skyplot polar untuk posisi azimut dan elevasi satelit GNSS (US-01).
///
/// Pusat lingkaran = zenit (elevasi 90 derajat).
/// Lingkaran luar = cakrawala (elevasi 0 derajat).
/// Utara (U / 0 derajat) berada di atas.
class SkyplotPainter extends CustomPainter {
  final List<SatelliteInfo> satellites;
  final TextScaler textScaler;

  const SkyplotPainter({
    required this.satellites,
    this.textScaler = TextScaler.noScaling,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = math.min(size.width, size.height) / 2 - 22;
    if (outerRadius <= 20) return;

    // Latar lingkaran skyplot
    final bgPaint = Paint()
      ..color = AppColors.bg
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, outerRadius, bgPaint);

    // Garis cincin elevasi (0, 30, 60 derajat)
    final gridPaint = Paint()
      ..color = AppColors.divider
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final outerBorderPaint = Paint()
      ..color = AppColors.ink2.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawCircle(center, outerRadius, outerBorderPaint); // 0°
    canvas.drawCircle(center, outerRadius * (2 / 3), gridPaint); // 30°
    canvas.drawCircle(center, outerRadius * (1 / 3), gridPaint); // 60°

    // Garis sumbu U-S dan B-T
    canvas.drawLine(
      Offset(center.dx, center.dy - outerRadius),
      Offset(center.dx, center.dy + outerRadius),
      gridPaint,
    );
    canvas.drawLine(
      Offset(center.dx - outerRadius, center.dy),
      Offset(center.dx + outerRadius, center.dy),
      gridPaint,
    );

    // Label arah mata angin (U, T, S, B)
    _drawLabel(
      canvas,
      'U',
      Offset(center.dx, center.dy - outerRadius - 12),
      AppTypography.label.copyWith(color: AppColors.ink, fontSize: 12),
    );
    _drawLabel(
      canvas,
      'S',
      Offset(center.dx, center.dy + outerRadius + 12),
      AppTypography.label.copyWith(color: AppColors.ink2, fontSize: 12),
    );
    _drawLabel(
      canvas,
      'T',
      Offset(center.dx + outerRadius + 12, center.dy),
      AppTypography.label.copyWith(color: AppColors.ink2, fontSize: 12),
    );
    _drawLabel(
      canvas,
      'B',
      Offset(center.dx - outerRadius - 12, center.dy),
      AppTypography.label.copyWith(color: AppColors.ink2, fontSize: 12),
    );

    // Label elevasi 30° dan 60°
    final degreeStyle = AppTypography.caption.copyWith(
      fontSize: 10,
      color: AppColors.ink2,
    );
    _drawLabel(
      canvas,
      '60°',
      Offset(center.dx + 14, center.dy - outerRadius * (1 / 3) + 2),
      degreeStyle,
    );
    _drawLabel(
      canvas,
      '30°',
      Offset(center.dx + 14, center.dy - outerRadius * (2 / 3) + 2),
      degreeStyle,
    );

    // Gambar titik satelit: yang tidak dipakai dulu, lalu yang terpakai di atasnya
    final sorted = [...satellites]
      ..sort((a, b) => (a.usedInFix ? 1 : 0).compareTo(b.usedInFix ? 1 : 0));

    for (final sat in sorted) {
      final elev = sat.elevationDegrees.clamp(0.0, 90.0);
      final r = outerRadius * (1.0 - elev / 90.0);
      final rad = (sat.azimuthDegrees - 90.0) * math.pi / 180.0;
      final pos = Offset(
        center.dx + r * math.cos(rad),
        center.dy + r * math.sin(rad),
      );

      final color = _constellationColor(sat.constellation);

      if (sat.usedInFix) {
        // Satelit terpakai: lingkaran penuh berwarna dengan tepi putih tegas
        canvas.drawCircle(
          pos,
          10.5,
          Paint()
            ..color = AppColors.surface
            ..style = PaintingStyle.fill,
        );
        canvas.drawCircle(
          pos,
          8.5,
          Paint()
            ..color = color
            ..style = PaintingStyle.fill,
        );
        _drawLabel(
          canvas,
          sat.displayId,
          Offset(pos.dx, pos.dy + 15),
          AppTypography.caption.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        );
      } else {
        // Satelit terlihat tapi tidak terpakai: cincin berongga (pembeda non-warna)
        canvas.drawCircle(
          pos,
          7.0,
          Paint()
            ..color = AppColors.bg
            ..style = PaintingStyle.fill,
        );
        canvas.drawCircle(
          pos,
          7.0,
          Paint()
            ..color = color.withValues(alpha: 0.85)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0,
        );
        _drawLabel(
          canvas,
          sat.displayId,
          Offset(pos.dx, pos.dy + 14),
          AppTypography.caption.copyWith(
            fontSize: 9.5,
            color: AppColors.ink2,
          ),
        );
      }
    }
  }

  static Color _constellationColor(GnssConstellation constellation) {
    return switch (constellation) {
      GnssConstellation.gps => AppColors.primary,
      GnssConstellation.glonass => AppColors.track,
      GnssConstellation.galileo => const Color(0xFF2D6A6A),
      GnssConstellation.beidou => AppColors.accent,
      GnssConstellation.qzss => const Color(0xFF6E579B),
      _ => AppColors.ink2,
    };
  }

  void _drawLabel(
    Canvas canvas,
    String text,
    Offset center,
    TextStyle style,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout();

    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant SkyplotPainter oldDelegate) {
    return oldDelegate.satellites != satellites ||
        oldDelegate.textScaler != textScaler;
  }
}
