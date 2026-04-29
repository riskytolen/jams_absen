import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';

/// Card statistik kecil (hadir, telat, cuti, lembur).
///
/// Menampilkan icon berwarna, value besar, title, dan optional subtitle.
class StatsCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final Color bgColor;

  const StatsCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.bgColor,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: AppSpacing.iconSm),
              ),
              Text(value, style: AppTextStyles.numericMd),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            style: AppTextStyles.labelSm,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: AppTextStyles.caption.copyWith(
                color: color.withValues(alpha: 0.70),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
