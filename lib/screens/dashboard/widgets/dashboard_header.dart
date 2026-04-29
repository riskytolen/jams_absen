import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/greeting_helper.dart';
import '../../../widgets/cards/live_clock_widget.dart';

/// Header dashboard — berisi profil, jam, dan info absen hari ini.
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
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(AppSpacing.radiusXxl + 4),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TopBar(
                userName: userName,
                avatarUrl: avatarUrl,
                notificationCount: notificationCount,
                onNotificationTap: onNotificationTap,
                onAvatarTap: onAvatarTap,
                onLogoutTap: onLogoutTap,
              ),
              const SizedBox(height: AppSpacing.xl),
              const LiveClockWidget(),
              const SizedBox(height: AppSpacing.sm),
              _DepartmentChip(department: department, position: position),
              const SizedBox(height: AppSpacing.lg),
              _AttendanceStrip(
                hasCheckedIn: hasCheckedIn,
                clockInTime: clockInTime,
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
        // Avatar
        GestureDetector(
          onTap: onAvatarTap,
          child: Container(
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: CircleAvatar(
              radius: 21,
              backgroundColor: Colors.white.withValues(alpha: 0.20),
              backgroundImage:
                  avatarUrl != null ? NetworkImage(avatarUrl!) : null,
              child: avatarUrl == null
                  ? const Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                      size: AppSpacing.iconMd,
                    )
                  : null,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md + 2),

        // Greeting
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${GreetingHelper.greeting} ${GreetingHelper.emoji}',
                style: AppTextStyles.onDarkBody,
              ),
              const SizedBox(height: 2),
              Text(userName, style: AppTextStyles.onDarkTitle),
            ],
          ),
        ),

        _NotificationBell(
          count: notificationCount,
          onTap: onNotificationTap,
        ),
        const SizedBox(width: AppSpacing.sm),
        _LogoutButton(onTap: onLogoutTap),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════
// NOTIFICATION BELL
// ═════════════════════════════════════════════════════════
class _NotificationBell extends StatelessWidget {
  final int count;
  final VoidCallback? onTap;

  const _NotificationBell({required this.count, this.onTap});

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
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.20),
              ),
            ),
            child: const Icon(
              Icons.notifications_outlined,
              color: Colors.white,
              size: AppSpacing.iconMd,
            ),
          ),
          if (count > 0)
            Positioned(
              right: 5,
              top: 5,
              child: Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary800, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════
// LOGOUT BUTTON
// ═════════════════════════════════════════════════════════
class _LogoutButton extends StatelessWidget {
  final VoidCallback? onTap;

  const _LogoutButton({this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap?.call();
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.20),
          ),
        ),
        child: const Icon(
          Icons.logout_rounded,
          color: Colors.white,
          size: AppSpacing.iconMd,
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════
// DEPARTMENT CHIP
// ═════════════════════════════════════════════════════════
class _DepartmentChip extends StatelessWidget {
  final String department;
  final String position;

  const _DepartmentChip({required this.department, required this.position});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.business_rounded,
            color: Colors.white.withValues(alpha: 0.85),
            size: AppSpacing.iconXs,
          ),
          const SizedBox(width: AppSpacing.sm - 2),
          Text(
            '$department  \u2022  $position',
            style: AppTextStyles.onDarkCaption,
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════
// ATTENDANCE INFO STRIP
// ═════════════════════════════════════════════════════════
class _AttendanceStrip extends StatelessWidget {
  final bool hasCheckedIn;
  final String? clockInTime;

  const _AttendanceStrip({required this.hasCheckedIn, this.clockInTime});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.base,
        horizontal: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          _StripItem(
            icon: Icons.login_rounded,
            label: 'Jam Masuk',
            value: clockInTime ?? '--:--',
            isActive: hasCheckedIn,
          ),
          const _StripDivider(),
          _StripItem(
            icon: hasCheckedIn
                ? Icons.check_circle_rounded
                : Icons.schedule_rounded,
            label: 'Status',
            value: hasCheckedIn ? 'Tepat Waktu' : 'Menunggu',
            isActive: hasCheckedIn,
          ),
          const _StripDivider(),
          const _StripItem(
            icon: Icons.face_rounded,
            label: 'Metode',
            value: 'Face ID',
            isActive: false,
          ),
        ],
      ),
    );
  }
}

class _StripItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isActive;

  const _StripItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = isActive ? AppColors.secondaryLight : Colors.white;

    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: AppSpacing.iconMd),
          const SizedBox(height: 7),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(label, style: AppTextStyles.onDarkMuted),
        ],
      ),
    );
  }
}

class _StripDivider extends StatelessWidget {
  const _StripDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      color: Colors.white.withValues(alpha: 0.20),
    );
  }
}
