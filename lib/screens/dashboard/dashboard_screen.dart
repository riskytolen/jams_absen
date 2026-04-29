import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../models/menu_item_model.dart';
import '../../models/pegawai_model.dart';
import '../../widgets/cards/attendance_progress_card.dart';
import '../../widgets/cards/recent_activity_card.dart';
import '../login/login_screen.dart';
import '../profile/profile_screen.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/stats_section.dart';
import 'widgets/menu_grid_section.dart';
import 'widgets/bottom_nav_bar.dart';

/// Halaman utama dashboard aplikasi absen.
class DashboardScreen extends StatefulWidget {
  final Pegawai pegawai;

  const DashboardScreen({super.key, required this.pegawai});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _hasCheckedIn = false;
  String? _clockInTime;
  int _navIndex = 0;
  late Pegawai _pegawai;

  @override
  void initState() {
    super.initState();
    _pegawai = widget.pegawai;
  }

  // ── Menu items ─────────────────────────────────────────
  List<MenuItemModel> get _menuItems => [
        MenuItemModel(
          title: 'Riwayat Absen',
          subtitle: 'Lihat catatan absensi',
          icon: Icons.history_rounded,
          gradient: AppColors.skyGradient,
          onTap: () => _onMenuTap('Riwayat Absen'),
        ),
        MenuItemModel(
          title: 'Cuti & Izin',
          subtitle: 'Ajukan permohonan',
          icon: Icons.event_note_rounded,
          gradient: AppColors.orangeGradient,
          badge: '2',
          onTap: () => _onMenuTap('Cuti & Izin'),
        ),
        MenuItemModel(
          title: 'Profil',
          subtitle: 'Data pribadi anda',
          icon: Icons.person_rounded,
          gradient: AppColors.purpleGradient,
          onTap: _openProfile,
        ),
        MenuItemModel(
          title: 'Pendapatan',
          subtitle: 'Slip gaji & bonus',
          icon: Icons.account_balance_wallet_rounded,
          gradient: AppColors.tealGradient,
          onTap: () => _onMenuTap('Pendapatan'),
        ),
        MenuItemModel(
          title: 'Pengumuman',
          subtitle: 'Info perusahaan',
          icon: Icons.campaign_rounded,
          gradient: AppColors.amberGradient,
          badge: '3',
          onTap: () => _onMenuTap('Pengumuman'),
        ),
        MenuItemModel(
          title: 'Pengaturan',
          subtitle: 'Konfigurasi app',
          icon: Icons.settings_rounded,
          gradient: AppColors.slateGradient,
          onTap: () => _onMenuTap('Pengaturan'),
        ),
      ];

  // ── Recent activities ──────────────────────────────────
  List<ActivityItem> get _activities => [
        if (_hasCheckedIn)
          ActivityItem(
            title: 'Absen Masuk',
            subtitle: 'QR Code terverifikasi \u2014 Tepat waktu',
            time: _clockInTime ?? '--:--',
            icon: Icons.qr_code_scanner_rounded,
            color: AppColors.success,
          ),
        const ActivityItem(
          title: 'Absen Masuk',
          subtitle: 'QR Code terverifikasi \u2014 Tepat waktu',
          time: '08:02',
          icon: Icons.qr_code_scanner_rounded,
          color: AppColors.success,
        ),
        const ActivityItem(
          title: 'Pengajuan Cuti',
          subtitle: 'Cuti tahunan \u2014 Disetujui',
          time: 'Kemarin',
          icon: Icons.event_available_rounded,
          color: AppColors.info,
        ),
        const ActivityItem(
          title: 'Absen Masuk',
          subtitle: 'QR Code terverifikasi \u2014 Terlambat 5 mnt',
          time: '2 hari lalu',
          icon: Icons.qr_code_scanner_rounded,
          color: AppColors.warning,
        ),
        const ActivityItem(
          title: 'Lembur',
          subtitle: '2 jam lembur tercatat',
          time: '3 hari lalu',
          icon: Icons.more_time_rounded,
          color: AppColors.primary600,
        ),
      ];

  // ── Callbacks ──────────────────────────────────────────
  void _onTabChanged(int index) {
    if (index == 4) {
      _openProfile();
      return;
    }
    setState(() => _navIndex = index);
  }

  Future<void> _openProfile() async {
    final updated = await Navigator.of(context).push<Pegawai>(
      MaterialPageRoute(
        builder: (_) => ProfileScreen(pegawai: _pegawai),
      ),
    );
    if (updated != null && mounted) {
      setState(() => _pegawai = updated);
      AuthService.updateCurrentPegawai(updated);
    }
  }

  void _onMenuTap(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Navigasi ke $label'),
        duration: const Duration(milliseconds: 800),
      ),
    );
  }

  void _onLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar'),
        content: const Text('Apakah Anda yakin ingin keluar dari aplikasi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              AuthService.logout();
              Navigator.of(context).pushReplacement(
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      const LoginScreen(),
                  transitionsBuilder:
                      (context, anim, secondaryAnimation, child) {
                    return FadeTransition(
                      opacity: CurvedAnimation(
                        parent: anim,
                        curve: Curves.easeInOut,
                      ),
                      child: child,
                    );
                  },
                  transitionDuration: AppSpacing.durationPage,
                ),
              );
            },
            child: Text(
              'Keluar',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  void _onScanFace() {
    if (_hasCheckedIn) return;

    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    setState(() {
      _hasCheckedIn = true;
      _clockInTime = timeStr;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.verified_rounded, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text('Absen berhasil tercatat!'),
            ),
          ],
        ),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            // ── Header (profil + jam + info absen) ──
            SliverToBoxAdapter(
              child: DashboardHeader(
                userName: _pegawai.nama,
                department: _pegawai.id,
                position: _pegawai.jabatanNama ?? '-',
                avatarUrl: _pegawai.fotoDiri,
                notificationCount: 3,
                hasCheckedIn: _hasCheckedIn,
                clockInTime: _clockInTime,
                onNotificationTap: () => _onMenuTap('Notifikasi'),
                onAvatarTap: _openProfile,
                onLogoutTap: _onLogout,
              ),
            ),

            // ── Body ──
            SliverToBoxAdapter(
              child: Column(
                children: [
                  const SizedBox(height: AppSpacing.xl),

                  // Menu grid
                  MenuGridSection(items: _menuItems),
                  const SizedBox(height: AppSpacing.xl),

                  // Attendance progress
                  const AttendanceProgressCard(
                    percentage: 92,
                    totalPresent: 20,
                    workingDays: 22,
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Stats
                  const StatsSection(monthLabel: 'April 2026'),
                  const SizedBox(height: AppSpacing.xxl),

                  // Recent activity
                  RecentActivityCard(
                    activities: _activities,
                    onViewAll: () => _onMenuTap('Riwayat Aktivitas'),
                  ),

                  // Bottom padding agar konten tidak tertutup nav bar
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: DashboardBottomNav(
          currentIndex: _navIndex,
          hasCheckedIn: _hasCheckedIn,
          onTabChanged: _onTabChanged,
          onScanFace: _onScanFace,
        ),
      ),
    );
  }
}
