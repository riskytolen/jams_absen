import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/activity_item_model.dart';

// Re-export
export '../../models/activity_item_model.dart';

/// Card aktivitas terbaru — timeline style.
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // ── Header (di luar card) ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Aktivitas Terbaru', style: AppTextStyles.h4),
              GestureDetector(
                onTap: onViewAll,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Semua',
                        style: AppTextStyles.buttonSm.copyWith(fontSize: 11),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 10,
                        color: AppColors.accent,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Card ──
          Container(
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
            child: activities.isEmpty
                ? _EmptyState()
                : Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    child: Column(
                      children: activities.asMap().entries.map((e) {
                        final isLast = e.key == activities.length - 1;
                        return _TimelineTile(item: e.value, isLast: isLast);
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════
// EMPTY STATE
// ═════════════════════════════════════════════════════════
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.inbox_rounded,
              size: 26,
              color: AppColors.textMuted.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Belum ada aktivitas',
            style: AppTextStyles.label.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 4),
          Text(
            'Aktivitas absensi akan muncul di sini',
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════
// TIMELINE TILE
// ═════════════════════════════════════════════════════════
class _TimelineTile extends StatelessWidget {
  final ActivityItem item;
  final bool isLast;

  const _TimelineTile({required this.item, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Timeline line + dot ──
          SizedBox(
            width: 24,
            child: Column(
              children: [
                const SizedBox(height: 14),
                // Dot
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: item.color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: item.color.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
                // Line
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: AppColors.border.withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // ── Content ──
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  // Icon
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(item.icon, color: item.color, size: 16),
                  ),
                  const SizedBox(width: 10),
                  // Text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: AppTextStyles.label.copyWith(fontSize: 12.5),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          item.subtitle,
                          style: AppTextStyles.caption.copyWith(fontSize: 10.5),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Time
                  Text(
                    item.time,
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 10.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
