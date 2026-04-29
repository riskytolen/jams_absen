import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/activity_item_model.dart';

// Re-export agar import lama tetap bekerja
export '../../models/activity_item_model.dart';

/// Card yang menampilkan daftar aktivitas terbaru.
///
/// Menampilkan empty state jika [activities] kosong.
class RecentActivityCard extends StatelessWidget {
  final List<ActivityItem> activities;
  final VoidCallback? onViewAll;

  const RecentActivityCard({
    super.key,
    required this.activities,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return Container(
      margin: AppSpacing.screenH,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Aktivitas Terbaru', style: theme.titleSmall),
                GestureDetector(
                  onTap: onViewAll,
                  child: Text(
                    'Lihat Semua',
                    style: AppTextStyles.buttonSm,
                  ),
                ),
              ],
            ),
          ),

          // Items atau Empty State
          if (activities.isEmpty)
            _EmptyState()
          else
            ...activities.asMap().entries.map((e) {
              return _ActivityTile(
                item: e.value,
                showDivider: e.key < activities.length - 1,
              );
            }),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}

// ── Empty State ──────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.xxl,
        horizontal: AppSpacing.lg,
      ),
      child: Column(
        children: [
          Icon(
            Icons.inbox_rounded,
            size: AppSpacing.huge,
            color: AppColors.textMuted.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Belum ada aktivitas',
            style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Aktivitas absensi akan muncul di sini',
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}

// ── Activity Tile ────────────────────────────────────────
class _ActivityTile extends StatelessWidget {
  final ActivityItem item;
  final bool showDivider;

  const _ActivityTile({required this.item, required this.showDivider});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Row(
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.10),
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: Icon(
                    item.icon,
                    color: item.color,
                    size: AppSpacing.iconLg - 4,
                  ),
                ),
                const SizedBox(width: AppSpacing.md + 2),

                // Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: AppTextStyles.label.copyWith(fontSize: 13.5),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle,
                        style: AppTextStyles.caption.copyWith(fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: AppSpacing.sm),

                // Time
                Text(item.time, style: AppTextStyles.labelSm),
              ],
            ),
          ),
          if (showDivider)
            Divider(
              height: 1,
              color: AppColors.border.withValues(alpha: 0.5),
            ),
        ],
      ),
    );
  }
}
