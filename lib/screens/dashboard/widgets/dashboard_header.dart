import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/greeting_helper.dart';
import '../../../core/services/server_time_service.dart';

/// Data absensi untuk ditampilkan di header.
class AttendanceInfo {
  final String clockInTime;
  final String status; // 'Hadir' atau 'Terlambat'
  final int durasiTelat; // menit
  final String divisionName;
  final String? scheduleTime; // Jam masuk jadwal (HH:mm)
  final int toleransiMenit; // Toleransi menit
  // Clock-out support (untuk divisi yang menerapkan jam pulang)
  final String? scheduleJamPulang; // Jadwal jam pulang (HH:mm). NULL = divisi tidak wajib absen pulang.
  final String? clockOutTime;      // Realisasi jam pulang. NULL = belum absen pulang.
  final String? statusPulang;      // 'Tepat'|'Cepat'|'Lupa Pulang'|null

  const AttendanceInfo({
    required this.clockInTime,
    required this.status,
    required this.durasiTelat,
    required this.divisionName,
    this.scheduleTime,
    this.toleransiMenit = 0,
    this.scheduleJamPulang,
    this.clockOutTime,
    this.statusPulang,
  });

  bool get isLate => status == 'Terlambat';
  bool get isPresent => status == 'Hadir' || status == 'Terlambat';
  bool get isLeave => status == 'Izin' || status == 'Sakit' || status == 'Cuti';
  bool get isAlpha => status == 'Alpha';
  bool get isLibur => status == 'Libur';

  /// Apakah divisi pegawai menerapkan jam pulang.
  bool get requiresClockOut => scheduleJamPulang != null;

  /// Apakah pegawai sudah absen pulang.
  bool get hasClockedOut => clockOutTime != null;

  /// Batas waktu telat = jadwal + toleransi.
  String? get batasTelatTime {
    if (scheduleTime == null) return null;
    try {
      final parts = scheduleTime!.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final jadwal = DateTime(2000, 1, 1, hour, minute);
      final batas = jadwal.add(Duration(minutes: toleransiMenit));
      return '${batas.hour.toString().padLeft(2, '0')}:${batas.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return null;
    }
  }
}

/// Dashboard Header — Professional attendance app header.
///
/// Layout:
/// ┌──────────────────────────────────────────┐
/// │  ■ JAMS LOGISTICS                [🔔][⏻] │
/// │                                          │
/// │ ┌──────────────────────────────────────┐ │
/// │ │ Selamat Pagi,                        │ │
/// │ │ Ahmad Risky              [Avatar]     │ │
/// │ │ Staff IT • Jadwal 08:00              │ │
/// │ │                                      │ │
/// │ │        08:45:32                      │ │
/// │ │    Senin, 05 Mei 2026                │ │
/// │ │                                      │ │
/// │ │ ┌──────────────────────────────────┐ │ │
/// │ │ │ ✓ TEPAT WAKTU    Masuk 08:45     │ │ │
/// │ │ │   📍 Divisi IT                   │ │ │
/// │ │ └──────────────────────────────────┘ │ │
/// │ └──────────────────────────────────────┘ │
/// └──────────────────────────────────────────┘
class DashboardHeader extends StatelessWidget {
  final String userName;
  final String department;
  final String position;
  final String? avatarUrl;
  final int notificationCount;
  final bool hasCheckedIn;
  final AttendanceInfo? attendanceInfo;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onLogoutTap;
  final VoidCallback? onAbsenTap;
  final VoidCallback? onClockOutTap;

  const DashboardHeader({
    super.key,
    required this.userName,
    required this.department,
    required this.position,
    required this.hasCheckedIn,
    this.avatarUrl,
    this.notificationCount = 0,
    this.attendanceInfo,
    this.onNotificationTap,
    this.onAvatarTap,
    this.onLogoutTap,
    this.onAbsenTap,
    this.onClockOutTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Company bar ──
              _CompanyBar(
                notificationCount: notificationCount,
                onNotificationTap: onNotificationTap,
                onLogoutTap: onLogoutTap,
              ),
              const SizedBox(height: 12),

              // ── Main card ──
              _MainCard(
                userName: userName,
                department: department,
                position: position,
                avatarUrl: avatarUrl,
                hasCheckedIn: hasCheckedIn,
                attendanceInfo: attendanceInfo,
                onAvatarTap: onAvatarTap,
                onAbsenTap: onAbsenTap,
                onClockOutTap: onClockOutTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════
// COMPANY BAR
// ═════════════════════════════════════════════════════════
class _CompanyBar extends StatelessWidget {
  final int notificationCount;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onLogoutTap;

  const _CompanyBar({
    required this.notificationCount,
    this.onNotificationTap,
    this.onLogoutTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Logo
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            'assets/logo.png',
            width: 30,
            height: 30,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'JAMS LOGISTICS',
          style: AppTextStyles.label.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 0.8,
          ),
        ),
        const Spacer(),
        _ActionIcon(
          icon: Icons.notifications_outlined,
          badgeCount: notificationCount,
          onTap: onNotificationTap,
        ),
        const SizedBox(width: 8),
        _ActionIcon(
          icon: Icons.logout_rounded,
          onTap: onLogoutTap,
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════
// ACTION ICON
// ═════════════════════════════════════════════════════════
class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final int badgeCount;
  final VoidCallback? onTap;

  const _ActionIcon({
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
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 1,
              ),
            ),
            child: Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 21),
          ),
          if (badgeCount > 0)
            Positioned(
              right: -3,
              top: -3,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary900, width: 2),
                ),
                child: Center(
                  child: Text(
                    badgeCount > 9 ? '9+' : '$badgeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════
// MAIN CARD — Employee info + clock + status
// ═════════════════════════════════════════════════════════
class _MainCard extends StatefulWidget {
  final String userName;
  final String department;
  final String position;
  final String? avatarUrl;
  final bool hasCheckedIn;
  final AttendanceInfo? attendanceInfo;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onAbsenTap;
  final VoidCallback? onClockOutTap;

  const _MainCard({
    required this.userName,
    required this.department,
    required this.position,
    required this.hasCheckedIn,
    this.avatarUrl,
    this.attendanceInfo,
    this.onAvatarTap,
    this.onAbsenTap,
    this.onClockOutTap,
  });

  @override
  State<_MainCard> createState() => _MainCardState();
}

class _MainCardState extends State<_MainCard> {
  late Timer _timer;
  DateTime _now = ServerTimeService.getEstimatedServerTime() ?? DateTime.now();

  static final _timeFormat = DateFormat('HH:mm');
  static final _secFormat = DateFormat('ss');
  static final _dateFormat = DateFormat('EEEE, dd MMMM yyyy', 'id_ID');

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _now = ServerTimeService.getEstimatedServerTime() ?? DateTime.now();
        });
      }
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
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.1),
            Colors.white.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // ── Employee section ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Greeting + name + position
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${GreetingHelper.greeting} ${GreetingHelper.emoji}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.userName,
                        style: AppTextStyles.onDarkTitle.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _InfoPill(
                            icon: Icons.work_outline_rounded,
                            text: widget.position,
                          ),
                          const SizedBox(width: 6),
                          _InfoPill(
                            icon: Icons.badge_rounded,
                            text: widget.department,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Avatar
                GestureDetector(
                  onTap: widget.onAvatarTap,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.4),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: AppColors.primary600,
                      backgroundImage: widget.avatarUrl != null
                          ? NetworkImage(widget.avatarUrl!)
                          : null,
                      child: widget.avatarUrl == null
                          ? const Icon(Icons.person_rounded,
                              color: Colors.white, size: 22)
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Clock section ──
          RepaintBoundary(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          _timeFormat.format(_now),
                          style: AppTextStyles.numericLg.copyWith(
                            fontSize: 38,
                            letterSpacing: 2,
                            height: 1,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _secFormat.format(_now),
                          style: AppTextStyles.numericLg.copyWith(
                            fontSize: 18,
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _dateFormat.format(_now),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.45),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // ── Status / CTA ──
          if (!widget.hasCheckedIn)
            _AbsenButton(onTap: widget.onAbsenTap)
          else if (widget.attendanceInfo != null &&
              widget.attendanceInfo!.requiresClockOut &&
              !widget.attendanceInfo!.hasClockedOut)
            _ClockOutButton(
              info: widget.attendanceInfo!,
              onTap: widget.onClockOutTap,
            )
          else
            _StatusCard(info: widget.attendanceInfo!),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════
// INFO PILL — Small tag for position/schedule
// ═════════════════════════════════════════════════════════
class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.5), size: 11),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════
// STATUS CARD — Standalone, high contrast, separated
// ═════════════════════════════════════════════════════════
class _StatusCard extends StatelessWidget {
  final AttendanceInfo info;

  const _StatusCard({required this.info});

  @override
  Widget build(BuildContext context) {
    final Color bgColor;
    final Color lightColor;
    final IconData icon;
    final String label;
    final String desc;

    switch (info.status) {
      case 'Terlambat':
        bgColor = const Color(0xFFDC2626);
        lightColor = const Color(0xFFFEE2E2);
        icon = Icons.warning_rounded;
        label = 'TERLAMBAT';
        desc = '+${info.durasiTelat} menit dari jadwal';
        break;
      case 'Izin':
        bgColor = const Color(0xFFD97706);
        lightColor = const Color(0xFFFEF3C7);
        icon = Icons.mail_rounded;
        label = 'IZIN';
        desc = 'Anda sedang izin hari ini';
        break;
      case 'Sakit':
        bgColor = const Color(0xFFDC2626);
        lightColor = const Color(0xFFFEE2E2);
        icon = Icons.local_hospital_rounded;
        label = 'SAKIT';
        desc = 'Semoga lekas sembuh';
        break;
      case 'Cuti':
        bgColor = const Color(0xFF0891B2);
        lightColor = const Color(0xFFCFFAFE);
        icon = Icons.beach_access_rounded;
        label = 'CUTI';
        desc = 'Anda sedang cuti hari ini';
        break;
      case 'Alpha':
        bgColor = const Color(0xFF7C3AED);
        lightColor = const Color(0xFFEDE9FE);
        icon = Icons.cancel_rounded;
        label = 'ALPHA';
        desc = 'Tidak hadir tanpa keterangan';
        break;
      case 'Libur':
        bgColor = const Color(0xFF6366F1);
        lightColor = const Color(0xFFE0E7FF);
        icon = Icons.event_busy_rounded;
        label = 'HARI LIBUR';
        desc = 'Hari ini adalah hari libur Anda';
        break;
      default: // 'Hadir'
        bgColor = const Color(0xFF059669);
        lightColor = const Color(0xFFD1FAE5);
        icon = Icons.check_circle_rounded;
        label = 'TEPAT WAKTU';
        desc = 'Absensi tercatat dengan baik';
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: bgColor.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: bgColor.withValues(alpha: 0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Main status row ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                // Icon container
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),

                // Label + desc
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        desc,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // Clock-in time (hanya untuk Hadir/Terlambat)
                if (info.isPresent)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      info.clockInTime,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Hari Ini',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Detail footer (hanya untuk Hadir/Terlambat) ──
          if (info.isPresent)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.12),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(14),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on_rounded,
                    color: lightColor.withValues(alpha: 0.85),
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    info.divisionName,
                    style: TextStyle(
                      color: lightColor.withValues(alpha: 0.85),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  // Jadwal & batas telat
                  if (info.scheduleTime != null) ...[
                  Icon(
                    Icons.schedule_rounded,
                    color: lightColor.withValues(alpha: 0.7),
                    size: 12,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    'Jadwal ${info.scheduleTime}',
                    style: TextStyle(
                      color: lightColor.withValues(alpha: 0.7),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (info.batasTelatTime != null) ...[
                    Container(
                      width: 1,
                      height: 10,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      color: lightColor.withValues(alpha: 0.3),
                    ),
                    Icon(
                      Icons.timer_outlined,
                      color: lightColor.withValues(alpha: 0.7),
                      size: 12,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      'Batas ${info.batasTelatTime}',
                      style: TextStyle(
                        color: lightColor.withValues(alpha: 0.7),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════
// ABSEN BUTTON — Premium, animated, eye-catching
// ═════════════════════════════════════════════════════════
class _AbsenButton extends StatefulWidget {
  final VoidCallback? onTap;

  const _AbsenButton({this.onTap});

  @override
  State<_AbsenButton> createState() => _AbsenButtonState();
}

class _AbsenButtonState extends State<_AbsenButton>
    with TickerProviderStateMixin {
  late final AnimationController _tapCtrl;
  late final Animation<double> _tapScale;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;
  late final AnimationController _shimmerCtrl;
  late final Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();
    _tapCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _tapScale = Tween(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _tapCtrl, curve: Curves.easeInOut),
    );

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _pulse = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();
    _shimmer = Tween(begin: -0.5, end: 1.5).animate(
      CurvedAnimation(parent: _shimmerCtrl, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _tapCtrl.dispose();
    _pulseCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _tapCtrl.forward(),
      onTapUp: (_) {
        _tapCtrl.reverse();
        HapticFeedback.mediumImpact();
        widget.onTap?.call();
      },
      onTapCancel: () => _tapCtrl.reverse(),
      child: AnimatedBuilder(
        animation: _tapScale,
        builder: (_, child) => Transform.scale(
          scale: _tapScale.value,
          child: child,
        ),
        child: AnimatedBuilder(
          animation: Listenable.merge([_pulse, _shimmer]),
          builder: (context, child) {
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1D4ED8),
                    Color(0xFF2563EB),
                    Color(0xFF3B82F6),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(
                      alpha: 0.2 + (_pulse.value * 0.25),
                    ),
                    blurRadius: 14 + (_pulse.value * 10),
                    spreadRadius: _pulse.value * 1.5,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: const Color(0xFF1D4ED8).withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  children: [
                    // Shimmer light sweep
                    Positioned(
                      top: 0,
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _ShimmerPainter(
                            progress: _shimmer.value,
                          ),
                        ),
                      ),
                    ),
                    // Content
                    child!,
                  ],
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Row(
              children: [
                // Face icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.face_retouching_natural_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),

                // Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Absen Masuk',
                        style: AppTextStyles.button.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Verifikasi wajah untuk absensi',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ),
                ),

                // Arrow
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom painter for shimmer light sweep effect.
class _ShimmerPainter extends CustomPainter {
  final double progress;

  _ShimmerPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.width * progress;
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: 0.07),
          Colors.white.withValues(alpha: 0.12),
          Colors.white.withValues(alpha: 0.07),
          Colors.white.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
      ).createShader(
        Rect.fromCenter(
          center: Offset(center, size.height / 2),
          width: size.width * 0.5,
          height: size.height,
        ),
      );

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ShimmerPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ═════════════════════════════════════════════════════════
// CLOCK-OUT BUTTON — Hijau, muncul saat sudah check-in
// dan divisi wajib absen pulang
// ═════════════════════════════════════════════════════════
class _ClockOutButton extends StatefulWidget {
  final AttendanceInfo info;
  final VoidCallback? onTap;

  const _ClockOutButton({required this.info, this.onTap});

  @override
  State<_ClockOutButton> createState() => _ClockOutButtonState();
}

class _ClockOutButtonState extends State<_ClockOutButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _tapCtrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _tapCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _scale = Tween<double>(begin: 1, end: 0.97).animate(
      CurvedAnimation(parent: _tapCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _tapCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheduleStr = widget.info.scheduleJamPulang ?? '';
    return GestureDetector(
      onTapDown: (_) => _tapCtrl.forward(),
      onTapUp: (_) {
        HapticFeedback.lightImpact();
        _tapCtrl.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _tapCtrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF10B981), Color(0xFF059669)],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Absen Pulang',
                      style: AppTextStyles.button.copyWith(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      scheduleStr.isNotEmpty
                          ? 'Jadwal pulang $scheduleStr WIB'
                          : 'Verifikasi wajah untuk absen pulang',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.white.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.7),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
