import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// Bottom nav — clean flat, center scan button prominent.
class DashboardBottomNav extends StatelessWidget {
  final int currentIndex;
  final bool hasCheckedIn;
  final ValueChanged<int> onTabChanged;
  final VoidCallback onScanFace;

  const DashboardBottomNav({
    super.key,
    required this.currentIndex,
    required this.hasCheckedIn,
    required this.onTabChanged,
    required this.onScanFace,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              _Tab(
                icon: Icons.home_rounded,
                label: 'Beranda',
                isSelected: currentIndex == 0,
                onTap: () => onTabChanged(0),
              ),
              _Tab(
                icon: Icons.history_rounded,
                label: 'Riwayat',
                isSelected: currentIndex == 1,
                onTap: () => onTabChanged(1),
              ),
              // Center button
              Expanded(
                child: _CenterButton(
                  hasCheckedIn: hasCheckedIn,
                  onTap: onScanFace,
                ),
              ),
              _Tab(
                icon: Icons.event_note_rounded,
                label: 'Cuti',
                isSelected: currentIndex == 3,
                onTap: () => onTabChanged(3),
              ),
              _Tab(
                icon: Icons.person_rounded,
                label: 'Profil',
                isSelected: currentIndex == 4,
                onTap: () => onTabChanged(4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════
// TAB
// ═════════════════════════════════════════════════════════
class _Tab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _Tab({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppColors.accent : AppColors.textMuted;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            // Indicator
            AnimatedContainer(
              duration: AppSpacing.durationFast,
              width: isSelected ? 16 : 0,
              height: 2.5,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════
// CENTER BUTTON
// ═════════════════════════════════════════════════════════
class _CenterButton extends StatefulWidget {
  final bool hasCheckedIn;
  final VoidCallback onTap;

  const _CenterButton({required this.hasCheckedIn, required this.onTap});

  @override
  State<_CenterButton> createState() => _CenterButtonState();
}

class _CenterButtonState extends State<_CenterButton>
    with TickerProviderStateMixin {
  late final AnimationController _tapCtrl;
  late final Animation<double> _tapScale;
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _tapCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );
    _tapScale = Tween(begin: 1.0, end: 0.90).animate(
      CurvedAnimation(parent: _tapCtrl, curve: Curves.easeInOut),
    );
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    if (!widget.hasCheckedIn) _pulseCtrl.repeat();
  }

  @override
  void didUpdateWidget(covariant _CenterButton old) {
    super.didUpdateWidget(old);
    if (widget.hasCheckedIn && !old.hasCheckedIn) {
      _pulseCtrl.stop();
      _pulseCtrl.reset();
    } else if (!widget.hasCheckedIn && old.hasCheckedIn) {
      _pulseCtrl.repeat();
    }
  }

  @override
  void dispose() {
    _tapCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final checked = widget.hasCheckedIn;

    return GestureDetector(
      onTapDown: checked ? null : (_) => _tapCtrl.forward(),
      onTapUp: checked
          ? null
          : (_) {
              _tapCtrl.reverse();
              HapticFeedback.mediumImpact();
              widget.onTap();
            },
      onTapCancel: checked ? null : () => _tapCtrl.reverse(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Pulse
                if (!checked)
                  AnimatedBuilder(
                    animation: _pulseCtrl,
                    builder: (_, _) {
                      final t = _pulseCtrl.value;
                      return Transform.scale(
                        scale: 1.0 + (t * 0.3),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.accent
                                  .withValues(alpha: 0.4 * (1 - t)),
                              width: 2,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                // Button
                ListenableBuilder(
                  listenable: _tapScale,
                  builder: (_, child) =>
                      Transform.scale(scale: _tapScale.value, child: child),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: checked ? null : AppColors.accentGradient,
                      color: checked ? AppColors.success : null,
                      shape: BoxShape.circle,
                      boxShadow: checked
                          ? []
                          : [
                              BoxShadow(
                                color: AppColors.accent.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                    ),
                    child: Icon(
                      checked
                          ? Icons.verified_rounded
                          : Icons.face_retouching_natural_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            checked ? 'Tercatat' : 'Absen',
            style: TextStyle(
              color: checked ? AppColors.success : AppColors.accent,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
