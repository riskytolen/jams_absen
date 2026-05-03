import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/greeting_helper.dart';

/// Header dashboard — Deep Navy, corporate, clean.
class DashboardHeader extends StatelessWidget {
  final String userName;
  final String department;
  final String position;
  final String? avatarUrl;
  final int notificationCount;
  final bool hasCheckedIn;
  final String? clockInTime;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onLogoutTap;
  final VoidCallback? onAbsenTap;

  const DashboardHeader({
    super.key,
    required this.userName,
    required this.department,
    required this.position,
    required this.hasCheckedIn,
    this.avatarUrl,
    this.notificationCount = 0,
    this.clockInTime,
    this.onNotificationTap,
    this.onAvatarTap,
    this.onLogoutTap,
    this.onAbsenTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            children: [
              _TopBar(
                userName: userName,
                avatarUrl: avatarUrl,
                notificationCount: notificationCount,
                onNotificationTap: onNotificationTap,
                onAvatarTap: onAvatarTap,
                onLogoutTap: onLogoutTap,
              ),
              const SizedBox(height: 24),
              _ClockCard(
                hasCheckedIn: hasCheckedIn,
                clockInTime: clockInTime,
                department: department,
                position: position,
                onAbsenTap: onAbsenTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════
// TOP BAR
// ═════════════════════════════════════════════════════════
class _TopBar extends StatelessWidget {
  final String userName;
  final String? avatarUrl;
  final int notificationCount;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onLogoutTap;

  const _TopBar({
    required this.userName,
    required this.notificationCount,
    this.avatarUrl,
    this.onNotificationTap,
    this.onAvatarTap,
    this.onLogoutTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: onAvatarTap,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.6),
                width: 2,
              ),
            ),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primary600,
              backgroundImage:
                  avatarUrl != null ? NetworkImage(avatarUrl!) : null,
              child: avatarUrl == null
                  ? const Icon(Icons.person_rounded,
                      color: Colors.white, size: 20)
                  : null,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${GreetingHelper.greeting} ${GreetingHelper.emoji}',
                style: AppTextStyles.onDarkMuted.copyWith(fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                userName,
                style: AppTextStyles.onDarkTitle.copyWith(fontSize: 16),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        _HeaderAction(
          icon: Icons.notifications_outlined,
          badgeCount: notificationCount,
          onTap: onNotificationTap,
        ),
        const SizedBox(width: 8),
        _HeaderAction(
          icon: Icons.logout_rounded,
          onTap: onLogoutTap,
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════
// HEADER ACTION BUTTON
// ═════════════════════════════════════════════════════════
class _HeaderAction extends StatelessWidget {
  final IconData icon;
  final int badgeCount;
  final VoidCallback? onTap;

  const _HeaderAction({
    required this.icon,
    this.badgeCount = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap?.call();
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white.withValues(alpha: 0.8), size: 20),
          ),
          if (badgeCount > 0)
            Positioned(
              right: 3,
              top: 3,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary900, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════
// CLOCK CARD
// ═════════════════════════════════════════════════════════
class _ClockCard extends StatefulWidget {
  final bool hasCheckedIn;
  final String? clockInTime;
  final String department;
  final String position;
  final VoidCallback? onAbsenTap;

  const _ClockCard({
    required this.hasCheckedIn,
    required this.department,
    required this.position,
    this.clockInTime,
    this.onAbsenTap,
  });

  @override
  State<_ClockCard> createState() => _ClockCardState();
}

class _ClockCardState extends State<_ClockCard> {
  late Timer _timer;
  DateTime _now = DateTime.now();

  static final _timeFormat = DateFormat('HH:mm');
  static final _secFormat = DateFormat('ss');
  static final _dateFormat = DateFormat('EEEE, dd MMMM yyyy', 'id_ID');

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          // ── Department badge ──
          Row(
            children: [
              Icon(
                Icons.badge_outlined,
                color: Colors.white.withValues(alpha: 0.5),
                size: 14,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '${widget.department} \u2022 ${widget.position}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Time ──
          RepaintBoundary(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  _timeFormat.format(_now),
                  style: AppTextStyles.numericLg.copyWith(
                    fontSize: 48,
                    letterSpacing: 2,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  _secFormat.format(_now),
                  style: AppTextStyles.numericLg.copyWith(
                    fontSize: 20,
                    color: AppColors.accentLight,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _dateFormat.format(_now),
            style: AppTextStyles.onDarkCaption.copyWith(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),

          const SizedBox(height: 20),

          // ── Absen button ──
          _AbsenButton(
            hasCheckedIn: widget.hasCheckedIn,
            clockInTime: widget.clockInTime,
            onTap: widget.onAbsenTap,
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════
// ABSEN BUTTON — full width, di dalam clock card
// ═════════════════════════════════════════════════════════
class _AbsenButton extends StatefulWidget {
  final bool hasCheckedIn;
  final String? clockInTime;
  final VoidCallback? onTap;

  const _AbsenButton({
    required this.hasCheckedIn,
    this.clockInTime,
    this.onTap,
  });

  @override
  State<_AbsenButton> createState() => _AbsenButtonState();
}

class _AbsenButtonState extends State<_AbsenButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );
    _scale = Tween(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final checked = widget.hasCheckedIn;

    return GestureDetector(
      onTapDown: checked ? null : (_) => _ctrl.forward(),
      onTapUp: checked
          ? null
          : (_) {
              _ctrl.reverse();
              HapticFeedback.mediumImpact();
              widget.onTap?.call();
            },
      onTapCancel: checked ? null : () => _ctrl.reverse(),
      child: ListenableBuilder(
        listenable: _scale,
        builder: (_, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: checked ? null : AppColors.accentGradient,
            color: checked ? AppColors.success : null,
            borderRadius: BorderRadius.circular(14),
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                checked
                    ? Icons.verified_rounded
                    : Icons.face_retouching_natural_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                checked ? 'Tercatat Masuk ${widget.clockInTime}' : 'Absen Masuk',
                style: AppTextStyles.button.copyWith(fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
