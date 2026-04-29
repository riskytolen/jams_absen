import 'package:flutter/material.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../models/menu_item_model.dart';
import '../../../widgets/cards/menu_card.dart';

/// Section grid menu utama dengan animasi staggered.
class MenuGridSection extends StatelessWidget {
  final List<MenuItemModel> items;

  const MenuGridSection({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return Padding(
      padding: AppSpacing.screenH,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Menu Utama', style: theme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 1.15,
            ),
            itemCount: items.length,
            itemBuilder: (_, i) => _StaggeredEntry(
              index: i,
              child: MenuCard(item: items[i]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Staggered animation wrapper ──────────────────────────
class _StaggeredEntry extends StatelessWidget {
  final int index;
  final Widget child;

  const _StaggeredEntry({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(
        milliseconds: AppSpacing.durationSlow.inMilliseconds + (index * 60),
      ),
      curve: AppSpacing.curveDefault,
      builder: (_, value, child) => Transform.translate(
        offset: Offset(0, 16 * (1 - value)),
        child: Opacity(opacity: value, child: child),
      ),
      child: child,
    );
  }
}
