import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/menu_item_model.dart';

/// Card menu grid dengan animasi scale-on-tap dan haptic feedback.
class MenuCard extends StatefulWidget {
  final MenuItemModel item;

  const MenuCard({super.key, required this.item});

  @override
  State<MenuCard> createState() => _MenuCardState();
}

class _MenuCardState extends State<MenuCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) => _ctrl.forward();

  void _handleTapUp(TapUpDetails _) {
    _ctrl.reverse();
    HapticFeedback.lightImpact();
    widget.item.onTap?.call();
  }

  void _handleTapCancel() => _ctrl.reverse();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _scale,
      builder: (_, child) =>
          Transform.scale(scale: _scale.value, child: child),
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        child: _CardBody(item: widget.item),
      ),
    );
  }
}

// ── Card Body ────────────────────────────────────────────
class _CardBody extends StatelessWidget {
  final MenuItemModel item;

  const _CardBody({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg + 2),
        boxShadow: AppShadows.card,
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Stack(
        children: [
          // Decorative circle — subtle tint
          Positioned(
            right: -12,
            top: -12,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: item.gradient.colors
                      .map((c) => c.withValues(alpha: 0.06))
                      .toList(),
                ),
              ),
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(AppSpacing.base),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    gradient: item.gradient,
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusMd),
                    boxShadow: AppShadows.colored(
                      item.gradient.colors.first,
                      opacity: 0.25,
                    ),
                  ),
                  child: Icon(
                    item.icon,
                    color: Colors.white,
                    size: AppSpacing.iconLg,
                  ),
                ),
                const Spacer(),

                // Title
                Text(
                  item.title,
                  style: AppTextStyles.label.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  style: AppTextStyles.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Badge
          if (item.badge != null)
            Positioned(
              right: 10,
              top: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusFull),
                ),
                child: Text(
                  item.badge!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
