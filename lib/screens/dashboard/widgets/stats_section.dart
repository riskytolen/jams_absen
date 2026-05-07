import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Statistik kehadiran — 4 card dengan bar chart perbandingan periode.
class StatsSection extends StatelessWidget {
  final String periodLabel;
  final int hadir;
  final int terlambat;
  final int izin;
  final int alpha;
  final int prevHadir;
  final int prevTerlambat;
  final int prevIzin;
  final int prevAlpha;

  const StatsSection({
    super.key,
    required this.periodLabel,
    required this.hadir,
    required this.terlambat,
    required this.izin,
    required this.alpha,
    this.prevHadir = 0,
    this.prevTerlambat = 0,
    this.prevIzin = 0,
    this.prevAlpha = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // ── Header ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Statistik', style: AppTextStyles.h4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  periodLabel,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Card ──
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        value: hadir,
                        prevValue: prevHadir,
                        label: 'Hadir',
                        icon: Icons.check_circle_rounded,
                        color: AppColors.success,
                        bgColor: AppColors.successBg,
                        positiveIsGood: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(
                        value: terlambat,
                        prevValue: prevTerlambat,
                        label: 'Terlambat',
                        icon: Icons.watch_later_rounded,
                        color: AppColors.warning,
                        bgColor: AppColors.warningBg,
                        positiveIsGood: false,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        value: izin,
                        prevValue: prevIzin,
                        label: 'Cuti / Izin',
                        icon: Icons.event_busy_rounded,
                        color: AppColors.info,
                        bgColor: AppColors.infoBg,
                        positiveIsGood: false,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(
                        value: alpha,
                        prevValue: prevAlpha,
                        label: 'Alpha',
                        icon: Icons.cancel_rounded,
                        color: const Color(0xFF7C3AED),
                        bgColor: const Color(0xFFF5F3FF),
                        positiveIsGood: false,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════
// STAT CARD — with comparison bar chart
// ═════════════════════════════════════════════════════════
class _StatCard extends StatelessWidget {
  final int value;
  final int prevValue;
  final String label;
  final IconData icon;
  final Color color;
  final Color bgColor;
  /// Jika true, naik = bagus (hijau). Jika false, naik = buruk (merah).
  final bool positiveIsGood;

  const _StatCard({
    required this.value,
    required this.prevValue,
    required this.label,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.positiveIsGood,
  });

  @override
  Widget build(BuildContext context) {
    final diff = value - prevValue;
    final bool isUp = diff > 0;
    final bool isDown = diff < 0;
    final bool isNeutral = diff == 0;

    // Warna trend: tergantung apakah naik itu bagus atau buruk
    final Color trendColor;
    if (isNeutral) {
      trendColor = AppColors.textMuted;
    } else if ((isUp && positiveIsGood) || (isDown && !positiveIsGood)) {
      trendColor = AppColors.success;
    } else {
      trendColor = AppColors.error;
    }

    // Bar chart proportions
    final maxVal = value > prevValue ? value : prevValue;
    final double currentRatio = maxVal > 0 ? value / maxVal : 0;
    final double prevRatio = maxVal > 0 ? prevValue / maxVal : 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top: icon + value + trend
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$value',
                      style: AppTextStyles.numericMd.copyWith(
                        fontSize: 18,
                        color: color,
                        height: 1,
                      ),
                    ),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 10,
                        color: color.withValues(alpha: 0.65),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              // Trend indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: trendColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isNeutral
                          ? Icons.remove_rounded
                          : isUp
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded,
                      size: 10,
                      color: trendColor,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      isNeutral ? '0' : '${diff.abs()}',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: trendColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Bar chart comparison
          Row(
            children: [
              // Current period bar
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Bar
                    Stack(
                      children: [
                        Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: currentRatio.clamp(0.05, 1.0),
                          child: Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Saat ini',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                        color: color.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Previous period bar
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: AppColors.textMuted.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: prevRatio.clamp(0.05, 1.0),
                          child: Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: AppColors.textMuted.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Sblmnya ($prevValue)',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textMuted.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
