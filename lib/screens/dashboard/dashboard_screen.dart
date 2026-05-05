import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/attendance_service.dart';
import '../../core/services/attendance_realtime_service.dart';
import '../../core/services/location_service.dart';
import '../../core/services/strict_location_validator.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/menu_item_model.dart';
import '../../models/pegawai_model.dart';
import '../../widgets/cards/attendance_progress_card.dart';
import '../../widgets/cards/recent_activity_card.dart';
import '../../widgets/common/app_notification.dart';
import '../attendance/attendance_history_screen.dart';
import '../attendance/division_picker_sheet.dart';
import '../attendance/face_verification_screen.dart';
import '../leave/leave_screen.dart';
import '../login/login_screen.dart';
import '../profile/profile_screen.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/stats_section.dart';
import 'widgets/menu_grid_section.dart';


/// Dashboard — Deep Navy, corporate, card-based layout.
class DashboardScreen extends StatefulWidget {
  final Pegawai pegawai;

  const DashboardScreen({super.key, required this.pegawai});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _hasCheckedIn = false;
  AttendanceInfo? _attendanceInfo;
  late Pegawai _pegawai;
  late AttendanceRealtimeService _realtimeService;

  @override
  void initState() {
    super.initState();
    _pegawai = widget.pegawai;
    _realtimeService = AttendanceRealtimeService(employeeId: _pegawai.id);
    _checkTodayAttendance();
    _setupRealtimeListener();
  }

  @override
  void dispose() {
    _realtimeService.dispose();
    super.dispose();
  }

  /// Setup realtime listener untuk auto-update data absensi.
  void _setupRealtimeListener() {
    // Listen ke perubahan data
    _realtimeService.onDataChanged.addListener(_onAttendanceDataChanged);
    
    // Subscribe ke realtime channel
    _realtimeService.subscribe();
  }

  /// Callback saat data absensi berubah dari realtime.
  void _onAttendanceDataChanged() {
    final record = _realtimeService.onDataChanged.value;
    
    if (record == null) {
      // Data dihapus
      if (mounted) {
        setState(() {
          _hasCheckedIn = false;
          _attendanceInfo = null;
        });
      }
      return;
    }
    
    // Data ada — update UI
    if (mounted) {
      try {
        final jamMasuk = record['jam_masuk'] as String;
        final timeStr = jamMasuk.substring(0, 5);
        final status = record['status'] as String;
        final durasi = record['durasi_telat'] as int? ?? 0;
        final divisionData = record['divisions'] as Map<String, dynamic>?;
        final divisionName = divisionData?['nama'] as String? ?? '-';
        final scheduleJamMasuk = record['schedule_jam_masuk'] as String?;
        final scheduleTime = scheduleJamMasuk?.substring(0, 5);
        final toleransi = record['toleransi_menit'] as int? ?? 0;

        setState(() {
          _hasCheckedIn = true;
          _attendanceInfo = AttendanceInfo(
            clockInTime: timeStr,
            status: status,
            durasiTelat: durasi,
            divisionName: divisionName,
            scheduleTime: scheduleTime,
            toleransiMenit: toleransi,
          );
        });
      } catch (e) {
        debugPrint('[Dashboard] Error parsing realtime data: $e');
      }
    }
  }

  /// Cek apakah sudah absen hari ini (restore state setelah restart).
  /// Ini adalah initial load — realtime listener akan handle updates.
  Future<void> _checkTodayAttendance() async {
    try {
      final record = await AttendanceService.getTodayRecord(_pegawai.id);
      if (record != null && mounted) {
        final jamMasuk = record['jam_masuk'] as String;
        final timeStr = jamMasuk.substring(0, 5);
        final status = record['status'] as String;
        final durasi = record['durasi_telat'] as int? ?? 0;
        final divisionData = record['divisions'] as Map<String, dynamic>?;
        final divisionName = divisionData?['nama'] as String? ?? '-';
        final scheduleJamMasuk = record['schedule_jam_masuk'] as String?;
        final scheduleTime = scheduleJamMasuk?.substring(0, 5);
        final toleransi = record['toleransi_menit'] as int? ?? 0;

        setState(() {
          _hasCheckedIn = true;
          _attendanceInfo = AttendanceInfo(
            clockInTime: timeStr,
            status: status,
            durasiTelat: durasi,
            divisionName: divisionName,
            scheduleTime: scheduleTime,
            toleransiMenit: toleransi,
          );
        });
        
        // Set initial value untuk realtime listener
        _realtimeService.onDataChanged.value = record;
      }
    } catch (_) {
      // Silently fail — dashboard tetap tampil normal
    }
  }

  // ── Menu items (2 kolom grid, card per item) ────────────
  List<MenuItemModel> get _menuItems => [
        MenuItemModel(
          title: 'Riwayat',
          subtitle: 'Catatan kehadiran',
          icon: Icons.history_rounded,
          gradient: AppColors.skyGradient,
          onTap: () => _onMenuTap('Riwayat Absen'),
        ),
        MenuItemModel(
          title: 'Cuti',
          subtitle: 'Ajukan permohonan',
          icon: Icons.event_note_rounded,
          gradient: AppColors.orangeGradient,
          badge: '2',
          onTap: () => _onMenuTap('Cuti & Izin'),
        ),
        MenuItemModel(
          title: 'Pendapatan',
          subtitle: 'Slip gaji & bonus',
          icon: Icons.account_balance_wallet_rounded,
          gradient: AppColors.tealGradient,
          onTap: () => _onMenuTap('Pendapatan'),
        ),
        MenuItemModel(
          title: 'Info',
          subtitle: 'Info perusahaan',
          icon: Icons.campaign_rounded,
          gradient: AppColors.amberGradient,
          badge: '3',
          onTap: () => _onMenuTap('Pengumuman'),
        ),
        MenuItemModel(
          title: 'Jadwal',
          subtitle: 'Shift & kalender',
          icon: Icons.calendar_month_rounded,
          gradient: AppColors.blueGradient,
          onTap: () => _onMenuTap('Jadwal Kerja'),
        ),
        MenuItemModel(
          title: 'Dokumen',
          subtitle: 'File & surat',
          icon: Icons.folder_rounded,
          gradient: AppColors.cyanGradient,
          onTap: () => _onMenuTap('Dokumen'),
        ),
        MenuItemModel(
          title: 'Profil',
          subtitle: 'Data pribadi',
          icon: Icons.person_rounded,
          gradient: AppColors.purpleGradient,
          onTap: _openProfile,
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
        if (_hasCheckedIn && _attendanceInfo != null)
          ActivityItem(
            title: 'Absen Masuk',
            subtitle: _attendanceInfo!.isLate
                ? 'Terlambat ${_attendanceInfo!.durasiTelat} mnt \u2014 ${_attendanceInfo!.divisionName}'
                : 'Tepat waktu \u2014 ${_attendanceInfo!.divisionName}',
            time: _attendanceInfo!.clockInTime,
            icon: Icons.login_rounded,
            color: _attendanceInfo!.isLate ? AppColors.warning : AppColors.success,
          ),
        const ActivityItem(
          title: 'Absen Masuk',
          subtitle: 'Terverifikasi \u2014 Tepat waktu',
          time: '08:02',
          icon: Icons.login_rounded,
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
          subtitle: 'Terverifikasi \u2014 Terlambat 5 mnt',
          time: '2 hari lalu',
          icon: Icons.login_rounded,
          color: AppColors.warning,
        ),
      ];

  // ── Callbacks ──────────────────────────────────────────
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
    switch (label) {
      case 'Riwayat Absen':
      case 'Riwayat Aktivitas':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AttendanceHistoryScreen(
              employeeId: _pegawai.id,
              employeeName: _pegawai.nama,
            ),
          ),
        );
        break;
      case 'Cuti & Izin':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LeaveScreen(
              employeeId: _pegawai.id,
              employeeName: _pegawai.nama,
            ),
          ),
        );
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Navigasi ke $label'),
            duration: const Duration(milliseconds: 800),
          ),
        );
    }
  }

  /// Dialog untuk menampilkan error face verification dengan opsi retry
  void _showFaceVerificationErrorDialog(String errorMessage) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.face_rounded,
                color: AppColors.error,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Verifikasi Wajah Gagal',
                style: AppTextStyles.h4.copyWith(
                  color: AppColors.error,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              errorMessage,
              style: AppTextStyles.body.copyWith(
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            // Tips untuk retry
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.info.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_rounded,
                        color: AppColors.info,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Tips untuk retry:',
                        style: AppTextStyles.labelSm.copyWith(
                          color: AppColors.info,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Pastikan pencahayaan cukup\n• Posisikan wajah di tengah frame\n• Hindari bayangan di wajah\n• Kedipkan mata dengan natural',
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.info,
                      fontSize: 12,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Batal',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _onScanFace(); // Retry
            },
            child: Text(
              'Coba Lagi',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
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

  /// Flow absen lengkap:
  /// 1. Pilih divisi
  /// 2. Ambil lokasi divisi dari database
  /// 3. Validasi lokasi GPS (ketat, per divisi)
  /// 4. Verifikasi wajah (liveness + face match)
  /// 5. Submit attendance record
  Future<void> _onScanFace() async {
    if (_hasCheckedIn) return;

    // ── 1. Pilih divisi ──
    final division = await showDivisionPickerSheet(context);
    if (division == null || !mounted) return;

    final divisionId = division['id'] as int;
    final divisionName = division['nama'] as String;

    // ── 2. Ambil lokasi divisi ──
    _showLoading('Mengambil data lokasi divisi...');
    List<Map<String, dynamic>> divisionLocations;
    try {
      divisionLocations = await AttendanceService.getDivisionLocations(divisionId);
    } on AttendanceException catch (e) {
      if (!mounted) return;
      _hideLoading();
      AppNotification.show(
        context,
        type: NotificationType.error,
        title: 'Lokasi Divisi Tidak Ditemukan',
        message: e.message,
        duration: const Duration(seconds: 4),
      );
      return;
    }
    _hideLoading();

    if (!mounted) return;

    // ── 3. Validasi lokasi GPS (KETAT, per divisi) ──
    _showLoading('Memverifikasi lokasi GPS...');
    late Position validatedPosition;
    try {
      await LocationService.ensureReady();
      
      // Ambil posisi GPS
      final position = await LocationService.getCurrentPosition();
      
      // Validasi ketat per divisi
      final primaryLocation = divisionLocations.first;
      final validationResult = await StrictLocationValidator.validateLocationForDivision(
        position: position,
        divisionId: divisionId,
        divisionLatitude: primaryLocation['latitude'] as double,
        divisionLongitude: primaryLocation['longitude'] as double,
        divisionRadius: primaryLocation['radius'] as double,
        employeeId: _pegawai.id,
      );

      if (!validationResult.isValid) {
        if (!mounted) return;
        _hideLoading();
        AppNotification.show(
          context,
          type: NotificationType.error,
          title: 'Lokasi Tidak Valid',
          message: validationResult.message,
          duration: const Duration(seconds: 5),
        );
        return;
      }

      // Simpan posisi yang sudah divalidasi
      validatedPosition = validationResult.position!;

      if (!mounted) return;
      _hideLoading();
    } on LocationException catch (e) {
      if (!mounted) return;
      _hideLoading();
      AppNotification.show(
        context,
        type: NotificationType.error,
        title: 'Gagal Verifikasi Lokasi',
        message: e.message,
        duration: const Duration(seconds: 5),
      );
      return;
    }

    if (!mounted) return;

    // ── 4. Verifikasi wajah ──
    final faceResult = await Navigator.of(context).push<FaceVerificationResult>(
      MaterialPageRoute(
        builder: (_) => FaceVerificationScreen(employeeId: _pegawai.id),
      ),
    );

    if (faceResult == null || !faceResult.success || !mounted) {
      if (faceResult != null && !faceResult.success && faceResult.errorMessage != null) {
        if (faceResult.errorMessage != 'Dibatalkan') {
          _showFaceVerificationErrorDialog(faceResult.errorMessage!);
        }
      }
      return;
    }

    // ── 5. Submit absen ──
    _showLoading('Mencatat absensi...');
    try {
      final result = await AttendanceService.submitAttendance(
        employeeId: _pegawai.id,
        divisionId: divisionId,
        validatedPosition: validatedPosition, // Pass validated position
      );

      if (!mounted) return;
      _hideLoading();

      final status = result['status'] as String;
      final jamMasuk = result['jam_masuk'] as String;
      final timeStr = jamMasuk.substring(0, 5); // HH:mm
      final isLate = status == 'Terlambat';
      final durasi = result['durasi_telat'] as int? ?? 0;
      final scheduleJamMasuk = result['schedule_jam_masuk'] as String?;
      final scheduleTime = scheduleJamMasuk?.substring(0, 5);
      final toleransi = result['toleransi_menit'] as int? ?? 0;

      setState(() {
        _hasCheckedIn = true;
        _attendanceInfo = AttendanceInfo(
          clockInTime: timeStr,
          status: status,
          durasiTelat: durasi,
          divisionName: divisionName,
          scheduleTime: scheduleTime,
          toleransiMenit: toleransi,
        );
      });

      HapticFeedback.mediumImpact();

      AppNotification.show(
        context,
        type: isLate ? NotificationType.warning : NotificationType.success,
        title: isLate ? 'Terlambat $durasi menit' : 'Absen Berhasil',
        message: isLate
            ? 'Tercatat masuk $timeStr di divisi $divisionName'
            : 'Tercatat masuk $timeStr \u2014 Tepat waktu',
        duration: const Duration(seconds: 4),
      );
    } on AttendanceException catch (e) {
      if (!mounted) return;
      _hideLoading();
      AppNotification.show(
        context,
        type: NotificationType.error,
        title: 'Gagal Absen',
        message: e.message,
        duration: const Duration(seconds: 5),
      );
    } catch (e) {
      if (!mounted) return;
      _hideLoading();
      AppNotification.show(
        context,
        type: NotificationType.error,
        title: 'Terjadi Kesalahan',
        message: 'Gagal mencatat absensi. Silakan coba lagi.',
        duration: const Duration(seconds: 4),
      );
    }
  }

  OverlayEntry? _loadingOverlay;

  void _showLoading(String message) {
    _loadingOverlay?.remove();
    _loadingOverlay = OverlayEntry(
      builder: (_) => _GPSVerificationOverlay(message: message),
    );
    Overlay.of(context).insert(_loadingOverlay!);
  }

  void _hideLoading() {
    _loadingOverlay?.remove();
    _loadingOverlay = null;
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
        body: RefreshIndicator(
          onRefresh: _realtimeService.refresh,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              // ── Header ──
              SliverToBoxAdapter(
                child: DashboardHeader(
                  userName: _pegawai.nama,
                  department: _pegawai.id,
                  position: _pegawai.jabatanNama ?? '-',
                  avatarUrl: _pegawai.fotoDiri,
                  notificationCount: 3,
                  hasCheckedIn: _hasCheckedIn,
                  attendanceInfo: _attendanceInfo,
                  onNotificationTap: () => _onMenuTap('Notifikasi'),
                  onAvatarTap: _openProfile,
                  onLogoutTap: _onLogout,
                  onAbsenTap: _onScanFace,
                ),
              ),

              // ── Body ──
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),

                    // Menu
                    MenuGridSection(items: _menuItems),
                    const SizedBox(height: 12),

                    // Stats
                    const StatsSection(monthLabel: 'Mei 2026'),
                    const SizedBox(height: 12),

                    // Attendance progress
                    const AttendanceProgressCard(
                      percentage: 92,
                      totalPresent: 20,
                      workingDays: 22,
                    ),
                    const SizedBox(height: 12),

                    // Recent activity
                    RecentActivityCard(
                      activities: _activities,
                      onViewAll: () => _onMenuTap('Riwayat Aktivitas'),
                    ),

                    // Bottom safe area padding (untuk tombol bawaan / gesture bar HP)
                    // Gunakan viewPadding agar selalu dapat nilai asli
                    // meskipun Scaffold sudah consume padding
                    SizedBox(
                      height: MediaQuery.of(context).viewPadding.bottom + 32,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════
// GPS VERIFICATION OVERLAY — Professional loading state
// ═════════════════════════════════════════════════════════
class _GPSVerificationOverlay extends StatefulWidget {
  final String message;

  const _GPSVerificationOverlay({required this.message});

  @override
  State<_GPSVerificationOverlay> createState() => _GPSVerificationOverlayState();
}

class _GPSVerificationOverlayState extends State<_GPSVerificationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fadeIn;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..forward();
    _fadeIn = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _scale = Tween(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  IconData get _icon {
    final msg = widget.message.toLowerCase();
    if (msg.contains('lokasi') || msg.contains('gps')) {
      return Icons.my_location_rounded;
    } else if (msg.contains('absensi') || msg.contains('mencatat')) {
      return Icons.cloud_upload_rounded;
    } else if (msg.contains('divisi') || msg.contains('data')) {
      return Icons.dns_rounded;
    }
    return Icons.hourglass_top_rounded;
  }

  String get _subtitle {
    final msg = widget.message.toLowerCase();
    if (msg.contains('gps') || msg.contains('lokasi')) {
      return 'Memeriksa keamanan & akurasi lokasi';
    } else if (msg.contains('absensi') || msg.contains('mencatat')) {
      return 'Menyimpan data ke server';
    } else if (msg.contains('divisi')) {
      return 'Mengambil koordinat area kerja';
    }
    return 'Mohon tunggu sebentar';
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeIn,
      child: Material(
        color: Colors.black.withValues(alpha: 0.55),
        child: Center(
          child: ScaleTransition(
            scale: _scale,
            child: Container(
              width: 280,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated icon with ring
                  _PulsingIcon(icon: _icon),
                  const SizedBox(height: 20),

                  // Title
                  Text(
                    widget.message,
                    style: AppTextStyles.h4.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),

                  // Subtitle
                  Text(
                    _subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textMuted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: const LinearProgressIndicator(
                      minHeight: 3,
                      backgroundColor: Color(0xFFE2E8F0),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════
// PULSING ICON — Animated ring around icon
// ═════════════════════════════════════════════════════════
class _PulsingIcon extends StatefulWidget {
  final IconData icon;

  const _PulsingIcon({required this.icon});

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulse = Tween(begin: 0.0, end: 1.0).animate(
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
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, child) {
        return Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.primary50,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(
                  alpha: 0.1 + (_pulse.value * 0.15),
                ),
                blurRadius: 12 + (_pulse.value * 8),
                spreadRadius: _pulse.value * 4,
              ),
            ],
          ),
          child: child,
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          widget.icon,
          color: AppColors.primary,
          size: 28,
        ),
      ),
    );
  }
}
