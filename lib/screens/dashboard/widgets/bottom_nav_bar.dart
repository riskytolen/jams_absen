import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// Bottom navigation bar modern dengan floating center button.
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
      color: Colors.transparent,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          // ── Nav bar body ──
          _NavBody(
            currentIndex: currentIndex,
            onTabChanged: onTabChanged,
          ),

          // ── Floating center button ──
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 28,
            child: _FaceScanButton(
              hasCheckedIn: hasCheckedIn,
              onTap: onScanFace,
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════
// NAV BODY
// ═════════════════════════════════════════════════════════
class _NavBody extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabChanged;

  const _NavBody({
    required this.currentIndex,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXxl),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary900.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, -2),
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _NavTab(
              icon: Icons.dashboard_rounded,
              label: 'Beranda',
              isSelected: currentIndex == 0,
              onTap: () => onTabChanged(0),
            ),
            _NavTab(
              icon: Icons.history_rounded,
              label: 'Riwayat',
              isSelected: currentIndex == 1,
              onTap: () => onTabChanged(1),
            ),

            // Spacer untuk center button
            const SizedBox(width: 64),

            _NavTab(
              icon: Icons.event_note_rounded,
              label: 'Cuti',
              isSelected: currentIndex == 3,
              onTap: () => onTabChanged(3),
            ),
            _NavTab(
              icon: Icons.person_rounded,
              label: 'Profil',
              isSelected: currentIndex == 4,
              onTap: () => onTabChanged(4),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════
// NAV TAB
// ═════════════════════════════════════════════════════════
class _NavTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavTab({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 56,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Indicator dot
            AnimatedContainer(
              duration: AppSpacing.durationNormal,
              curve: AppSpacing.curveDefault,
              width: isSelected ? 20 : 0,
              height: 3,
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary600 : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Icon
            AnimatedContainer(
              duration: AppSpacing.durationFast,
              curve: AppSpacing.curveDefault,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary100
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isSelected ? AppColors.primary600 : AppColors.textMuted,
                size: AppSpacing.iconMd,
              ),
            ),
            const SizedBox(height: 3),

            // Label
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.primary600 : AppColors.textMuted,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════
// FACE SCAN CENTER BUTTON
// ═════════════════════════════════════════════════════════
class _FaceScanButton extends StatefulWidget {
  final bool hasCheckedIn;
  final VoidCallback onTap;

  const _FaceScanButton({required this.hasCheckedIn, required this.onTap});

  @override
  State<_FaceScanButton> createState() => _FaceScanButtonState();
}

class _FaceScanButtonState extends State<_FaceScanButton>
    with TickerProviderStateMixin {
  // Scale on tap
  late final AnimationController _tapCtrl;
  late final Animation<double> _tapScale;

  // Pulse ring (hanya saat belum absen)
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseScale;
  late final Animation<double> _pulseOpacity;

  @override
  void initState() {
    super.initState();

    _tapCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _tapScale = Tween(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _tapCtrl, curve: Curves.easeInOut),
    );

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _pulseScale = Tween(begin: 1.0, end: 1.35).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut),
    );
    _pulseOpacity = Tween(begin: 0.5, end: 0.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut),
    );

    if (!widget.hasCheckedIn) {
      _pulseCtrl.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _FaceScanButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hasCheckedIn && !oldWidget.hasCheckedIn) {
      _pulseCtrl.stop();
      _pulseCtrl.reset();
    } else if (!widget.hasCheckedIn && oldWidget.hasCheckedIn) {
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
    final isChecked = widget.hasCheckedIn;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Button area
        SizedBox(
          width: 76,
          height: 76,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Pulse ring
              if (!isChecked)
                ListenableBuilder(
                  listenable: _pulseCtrl,
                  builder: (_, _) => Transform.scale(
                    scale: _pulseScale.value,
                    child: Container(
                      width: 66,
                      height: 66,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primary600
                              .withValues(alpha: _pulseOpacity.value),
                          width: 2.5,
                        ),
                      ),
                    ),
                  ),
                ),

              // Main button
              GestureDetector(
                onTapDown: isChecked ? null : (_) => _tapCtrl.forward(),
                onTapUp: isChecked
                    ? null
                    : (_) {
                        _tapCtrl.reverse();
                        HapticFeedback.mediumImpact();
                        widget.onTap();
                      },
                onTapCancel: isChecked ? null : () => _tapCtrl.reverse(),
                child: ListenableBuilder(
                  listenable: _tapScale,
                  builder: (_, child) =>
                      Transform.scale(scale: _tapScale.value, child: child),
                  child: AnimatedContainer(
                    duration: AppSpacing.durationNormal,
                    curve: AppSpacing.curveDefault,
                    width: 66,
                    height: 66,
                    decoration: BoxDecoration(
                      gradient: isChecked ? null : AppColors.primaryGradient,
                      color: isChecked ? AppColors.success : null,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surface, width: 4),
                    ),
                    child: AnimatedSwitcher(
                      duration: AppSpacing.durationFast,
                      child: Icon(
                        isChecked
                            ? Icons.verified_rounded
                            : Icons.face_retouching_natural_rounded,
                        key: ValueKey(isChecked),
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 2),

        // Label
        AnimatedDefaultTextStyle(
          duration: AppSpacing.durationFast,
          style: TextStyle(
            color: isChecked ? AppColors.success : AppColors.primary600,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
          child: Text(isChecked ? 'Tercatat' : 'Absen'),
        ),
      ],
    );
  }
}
