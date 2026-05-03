import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Statistik kehadiran — 4 mini card berwarna dalam satu row.
class StatsSection extends StatelessWidget {
  final String monthLabel;

  const StatsSection({super.key, required this.monthLabel});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // ── Header (di luar card) ──
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
                  monthLabel,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
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
            // ── Stats grid 2x2 ──
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    value: '20',
                    label: 'Hadir',
                    icon: Icons.check_circle_rounded,
                    color: AppColors.success,
                    bgColor: AppColors.successBg,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatCard(
                    value: '2',
                    label: 'Terlambat',
                    icon: Icons.watch_later_rounded,
                    color: AppColors.warning,
                    bgColor: AppColors.warningBg,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    value: '1',
                    label: 'Cuti / Izin',
                    icon: Icons.event_busy_rounded,
                    color: AppColors.info,
                    bgColor: AppColors.infoBg,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatCard(
                    value: '22',
                    label: 'Hari Kerja',
                    icon: Icons.calendar_today_rounded,
                    color: AppColors.primary,
                    bgColor: AppColors.primary50,
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
// STAT CARD — mini card berwarna
// ═════════════════════════════════════════════════════════
class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final Color bgColor;

  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: AppTextStyles.numericMd.copyWith(
                    fontSize: 20,
                    color: color,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 10.5,
                    color: color.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
