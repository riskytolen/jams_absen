import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../widgets/cards/stats_card.dart';

/// Section statistik kehadiran bulanan (4 card grid 2x2).
class StatsSection extends StatelessWidget {
  final String monthLabel;

  const StatsSection({super.key, required this.monthLabel});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return Padding(
      padding: AppSpacing.screenH,
      child: Column(
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Statistik Bulan Ini', style: theme.titleLarge),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary100,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Text(
                  monthLabel,
                  style: AppTextStyles.labelSm.copyWith(
                    color: AppColors.primary800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.base),

          // Row 1
          const Row(
            children: [
              Expanded(
                child: StatsCard(
                  title: 'Total Hadir',
                  value: '20',
                  subtitle: 'dari 22 hari',
                  icon: Icons.check_circle_outline_rounded,
                  color: AppColors.success,
                  bgColor: AppColors.successBg,
                ),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: StatsCard(
                  title: 'Terlambat',
                  value: '2',
                  subtitle: 'rata-rata 15 mnt',
                  icon: Icons.watch_later_outlined,
                  color: AppColors.warning,
                  bgColor: AppColors.warningBg,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Row 2
          const Row(
            children: [
              Expanded(
                child: StatsCard(
                  title: 'Cuti / Izin',
                  value: '1',
                  subtitle: 'sisa cuti: 10',
                  icon: Icons.event_busy_rounded,
                  color: AppColors.info,
                  bgColor: AppColors.infoBg,
                ),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: StatsCard(
                  title: 'Lembur',
                  value: '8j',
                  subtitle: '4 hari lembur',
                  icon: Icons.more_time_rounded,
                  color: AppColors.error,
                  bgColor: AppColors.errorBg,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
