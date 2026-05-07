import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/services/announcement_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/document_service.dart';
import '../../core/services/update_service.dart';
import '../../core/services/attendance_service.dart';
import '../../core/services/attendance_realtime_service.dart';
import '../../core/services/leave_service.dart';
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
import '../dokumen/dokumen_screen.dart';
import '../pengaturan/pengaturan_screen.dart';
import '../info/info_screen.dart';
import '../rekap_titik/rekap_titik_screen.dart';
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
  int _pendingLeaveCount = 0;
  int _announcementCount = 0;

  // Statistik & aktivitas
  Map<String, int> _stats = {};
  Map<String, int> _prevStats = {};
  List<Map<String, dynamic>> _recentActivities = [];
  bool _statsLoaded = false;

  // SP (Surat Peringatan) aktif
  Map<String, dynamic>? _activeSP;

  @override
  void initState() {
    super.initState();
    _pegawai = widget.pegawai;
    _realtimeService = AttendanceRealtimeService(employeeId: _pegawai.id);
    _checkTodayAttendance();
    _setupRealtimeListener();
    _fetchPendingLeaveCount();
    _fetchAnnouncementCount();
    _fetchStatsAndActivity();
    _fetchActiveSP();
    _checkForceUpdate();
    _refreshPegawaiData();
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

        // Refresh statistik setelah data absen berubah
        _fetchStatsAndActivity();
      } catch (e) {
        debugPrint('[Dashboard] Error parsing realtime data: $e');
      }
    }
  }

  /// Refresh data pegawai dari database (sync jabatan, status, dll).
  Future<void> _refreshPegawaiData() async {
    final updated = await AuthService.refreshPegawai(_pegawai.id);
    if (updated != null && mounted) {
      setState(() => _pegawai = updated);
    }
  }

  /// Refresh semua data dashboard.
  Future<void> _refreshAll() async {
    await Future.wait([
      _realtimeService.refresh(),
      _fetchStatsAndActivity(),
      _fetchPendingLeaveCount(),
      _fetchAnnouncementCount(),
      _refreshPegawaiData(),
    ]);
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

  /// Fetch jumlah permohonan cuti/izin/sakit yang masih pending.
  Future<void> _fetchPendingLeaveCount() async {
    final count = await LeaveService.getPendingCount(employeeId: _pegawai.id);
    if (mounted) {
      setState(() => _pendingLeaveCount = count);
    }
  }

  /// Fetch SP aktif untuk pegawai.
  Future<void> _fetchActiveSP() async {
    final docs = await DocumentService.getDocuments(
      employeeId: _pegawai.id,
      kategori: 'SP',
    );
    if (mounted) {
      // Ambil SP aktif dengan tingkat tertinggi
      final activeList = docs.where((d) => d['status'] == 'Aktif').toList();
      if (activeList.isNotEmpty) {
        // Urutkan: SP-3 > SP-2 > SP-1
        activeList.sort((a, b) {
          final aLevel = a['tingkat_sp'] as String? ?? '';
          final bLevel = b['tingkat_sp'] as String? ?? '';
          return bLevel.compareTo(aLevel);
        });
        setState(() => _activeSP = activeList.first);
      }
    }
  }

  /// Hitung periode aktif (tgl 8 — tgl 7).
  Map<String, String> get _currentPeriod {
    final now = DateTime.now();
    final DateTime start;
    final DateTime end;
    if (now.day >= 8) {
      start = DateTime(now.year, now.month, 8);
      end = DateTime(now.year, now.month + 1, 7);
    } else {
      start = DateTime(now.year, now.month - 1, 8);
      end = DateTime(now.year, now.month, 7);
    }
    String fmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return {'start': fmt(start), 'end': fmt(end)};
  }

  String get _periodLabel {
    final now = DateTime.now();
    final DateTime start;
    final DateTime end;
    if (now.day >= 8) {
      start = DateTime(now.year, now.month, 8);
      end = DateTime(now.year, now.month + 1, 7);
    } else {
      start = DateTime(now.year, now.month - 1, 8);
      end = DateTime(now.year, now.month, 7);
    }
    final startLabel = '${start.day} ${_monthShort(start.month)}';
    final endLabel = '${end.day} ${_monthShort(end.month)} ${end.year}';
    return '$startLabel — $endLabel';
  }

  static String _monthShort(int m) {
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return months[m > 12 ? m - 12 : m];
  }

  /// Hitung periode sebelumnya (1 bulan sebelum periode aktif).
  Map<String, String> get _previousPeriod {
    final now = DateTime.now();
    final DateTime start;
    final DateTime end;
    if (now.day >= 8) {
      start = DateTime(now.year, now.month - 1, 8);
      end = DateTime(now.year, now.month, 7);
    } else {
      start = DateTime(now.year, now.month - 2, 8);
      end = DateTime(now.year, now.month - 1, 7);
    }
    String fmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return {'start': fmt(start), 'end': fmt(end)};
  }

  /// Fetch statistik kehadiran (current + previous) & aktivitas terbaru.
  Future<void> _fetchStatsAndActivity() async {
    final period = _currentPeriod;
    final prev = _previousPeriod;
    final results = await Future.wait([
      AttendanceService.getAttendanceStats(
        employeeId: _pegawai.id,
        startDate: period['start']!,
        endDate: period['end']!,
      ),
      AttendanceService.getAttendanceStats(
        employeeId: _pegawai.id,
        startDate: prev['start']!,
        endDate: prev['end']!,
      ),
      AttendanceService.getRecentActivity(employeeId: _pegawai.id),
    ]);
    if (mounted) {
      setState(() {
        _stats = results[0] as Map<String, int>;
        _prevStats = results[1] as Map<String, int>;
        _recentActivities = results[2] as List<Map<String, dynamic>>;
        _statsLoaded = true;
      });
    }
  }

  /// Fetch jumlah pengumuman aktif sesuai jabatan pegawai.
  Future<void> _fetchAnnouncementCount() async {
    final count = await AnnouncementService.getActiveCount(
      jabatanId: _pegawai.jabatanId,
    );
    if (mounted) {
      setState(() => _announcementCount = count);
    }
  }

  // ── Menu items (2 kolom grid, card per item) ────────────
  List<MenuItemModel> get _menuItems => [
        MenuItemModel(
          title: 'Riwayat',
          subtitle: 'Riwayat kehadiran',
          icon: Icons.history_rounded,
          gradient: AppColors.skyGradient,
          onTap: () => _onMenuTap('Riwayat Absen'),
        ),
        MenuItemModel(
          title: 'Cuti',
          subtitle: 'Ajukan permohonan',
          icon: Icons.event_note_rounded,
          gradient: AppColors.orangeGradient,
          badge: _pendingLeaveCount > 0 ? '$_pendingLeaveCount' : null,
          onTap: () => _onMenuTap('Cuti & Izin'),
        ),
        MenuItemModel(
          title: 'Pendapatan',
          subtitle: 'Slip gaji & bonus',
          icon: Icons.account_balance_wallet_rounded,
          gradient: AppColors.tealGradient,
          badge: 'Soon',
          onTap: () => _onMenuTap('Pendapatan'),
        ),
        MenuItemModel(
          title: 'Info',
          subtitle: 'Info perusahaan',
          icon: Icons.campaign_rounded,
          gradient: AppColors.amberGradient,
          badge: _announcementCount > 0 ? '$_announcementCount' : null,
          onTap: () => _onMenuTap('Pengumuman'),
        ),
        MenuItemModel(
          title: 'Dokumen',
          subtitle: 'File & surat',
          icon: Icons.folder_rounded,
          gradient: AppColors.blueGradient,
          onTap: () => _onMenuTap('Dokumen'),
        ),
        MenuItemModel(
          title: 'Rekap',
          subtitle: 'Rekap titik',
          icon: Icons.location_on_rounded,
          gradient: AppColors.cyanGradient,
          onTap: () => _onMenuTap('Rekap Titik'),
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

  // ── Recent activities (dari database) ──────────────────
  List<ActivityItem> get _activities {
    return _recentActivities.map((record) {
      final status = record['status'] as String;
      final tanggal = DateTime.parse(record['tanggal'] as String);
      final jamMasuk = (record['jam_masuk'] as String?)?.substring(0, 5) ?? '-';
      final durasiTelat = record['durasi_telat'] as int? ?? 0;
      final divData = record['divisions'] as Map<String, dynamic>?;
      final divName = divData?['nama'] as String? ?? '-';

      final String title;
      final String subtitle;
      final IconData icon;
      final Color color;
      final String time;

      switch (status) {
        case 'Hadir':
          title = 'Hadir';
          subtitle = 'Tepat waktu \u2014 $divName';
          icon = Icons.check_circle_rounded;
          color = AppColors.success;
          time = jamMasuk;
          break;
        case 'Terlambat':
          title = 'Terlambat';
          subtitle = '+$durasiTelat menit \u2014 $divName';
          icon = Icons.watch_later_rounded;
          color = AppColors.warning;
          time = jamMasuk;
          break;
        case 'Izin':
          title = 'Izin';
          subtitle = 'Izin hari ini';
          icon = Icons.mail_rounded;
          color = AppColors.warning;
          time = _formatRelativeDate(tanggal);
          break;
        case 'Sakit':
          title = 'Sakit';
          subtitle = 'Tidak masuk karena sakit';
          icon = Icons.local_hospital_rounded;
          color = AppColors.error;
          time = _formatRelativeDate(tanggal);
          break;
        case 'Cuti':
          title = 'Cuti';
          subtitle = 'Sedang cuti';
          icon = Icons.beach_access_rounded;
          color = const Color(0xFF0891B2);
          time = _formatRelativeDate(tanggal);
          break;
        case 'Alpha':
          title = 'Alpha';
          subtitle = 'Tidak hadir tanpa keterangan';
          icon = Icons.cancel_rounded;
          color = const Color(0xFF7C3AED);
          time = _formatRelativeDate(tanggal);
          break;
        case 'Libur':
          title = 'Libur';
          subtitle = 'Hari libur';
          icon = Icons.event_busy_rounded;
          color = const Color(0xFF6366F1);
          time = _formatRelativeDate(tanggal);
          break;
        default:
          title = status;
          subtitle = divName;
          icon = Icons.circle_outlined;
          color = AppColors.textMuted;
          time = jamMasuk;
      }

      return ActivityItem(
        title: title,
        subtitle: subtitle,
        time: time,
        icon: icon,
        color: color,
      );
    }).toList();
  }

  int get _totalWorkingDays {
    final total = (_stats['hadir'] ?? 0) +
        (_stats['terlambat'] ?? 0) +
        (_stats['izin'] ?? 0) +
        (_stats['alpha'] ?? 0);
    return total > 0 ? total : 1; // Hindari division by zero
  }

  double get _attendancePercentage {
    final present = (_stats['hadir'] ?? 0) + (_stats['terlambat'] ?? 0);
    final total = _totalWorkingDays;
    return (present / total * 100).clamp(0, 100);
  }

  static String _formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = today.difference(target).inDays;

    if (diff == 0) return 'Hari ini';
    if (diff == 1) return 'Kemarin';
    if (diff < 7) return '$diff hari lalu';
    return '${date.day}/${date.month}';
  }

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
        ).then((_) => _fetchPendingLeaveCount());
        break;
      case 'Rekap Titik':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RekapTitikScreen(
              employeeId: _pegawai.id,
              employeeName: _pegawai.nama,
            ),
          ),
        );
        break;
      case 'Dokumen':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DokumenScreen(
              employeeId: _pegawai.id,
              employeeName: _pegawai.nama,
            ),
          ),
        );
        break;
      case 'Pengumuman':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => InfoScreen(jabatanId: _pegawai.jabatanId),
          ),
        ).then((_) => _fetchAnnouncementCount());
        break;
      case 'Pendapatan':
        _showComingSoonDialog();
        break;
      case 'Pengaturan':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const PengaturanScreen(),
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

  /// Cek update saat buka aplikasi — force update jika ada.
  Future<void> _checkForceUpdate() async {
    try {
      final info = await UpdateService.checkForUpdate();
      debugPrint('[Dashboard] Update check: current=${info.currentVersion}, '
          'latest=${info.latestVersion}, hasUpdate=${info.hasUpdate}, '
          'downloadUrl=${info.downloadUrl != null ? "ada" : "null"}');
      if (info.hasUpdate && mounted) {
        _showForceUpdateDialog(info);
      }
    } catch (e) {
      debugPrint('[Dashboard] checkForceUpdate error: $e');
    }
  }

  void _showForceUpdateDialog(UpdateInfo info) {
    DownloadStatus status = DownloadStatus.idle;
    double progress = 0;
    String? errorMsg;

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Force Update',
      barrierColor: Colors.black.withValues(alpha: 0.7),
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (_, anim, _, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: anim, child: child),
        );
      },
      pageBuilder: (ctx, _, _) {
        return PopScope(
          canPop: false,
          child: StatefulBuilder(
            builder: (ctx, setDialogState) {
              final bool isProcessing = status == DownloadStatus.preparing ||
                  status == DownloadStatus.downloading ||
                  status == DownloadStatus.installing;

              return Center(
                child: Container(
                  width: 320,
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        blurRadius: 40,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ── Icon ──
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              gradient: status == DownloadStatus.failed
                                  ? AppColors.roseGradient
                                  : status == DownloadStatus.completed
                                      ? AppColors.emeraldGradient
                                      : AppColors.accentGradient,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: (status == DownloadStatus.failed
                                          ? AppColors.error
                                          : AppColors.accent)
                                      .withValues(alpha: 0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Icon(
                              status == DownloadStatus.failed
                                  ? Icons.error_rounded
                                  : status == DownloadStatus.completed
                                      ? Icons.check_circle_rounded
                                      : status == DownloadStatus.installing
                                          ? Icons.install_mobile_rounded
                                          : Icons.system_update_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // ── Title ──
                          Text(
                            status == DownloadStatus.failed
                                ? 'Update Gagal'
                                : status == DownloadStatus.completed
                                    ? 'Siap Install'
                                    : isProcessing
                                        ? 'Memperbarui...'
                                        : 'Update Diperlukan',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // ── Description ──
                          if (!isProcessing && status != DownloadStatus.failed)
                            const Text(
                              'Versi baru tersedia. Anda harus memperbarui aplikasi untuk melanjutkan.',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                color: AppColors.textSecondary,
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),

                          if (status == DownloadStatus.failed && errorMsg != null)
                            Text(
                              errorMsg!,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: AppColors.error,
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),

                          const SizedBox(height: 14),

                          // ── Version badge ──
                          if (!isProcessing)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceAlt,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'v${info.currentVersion}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 8),
                                    child: Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 16,
                                      color: AppColors.accent,
                                    ),
                                  ),
                                  Text(
                                    'v${info.latestVersion}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.accent,
                                    ),
                                  ),
                                  if (info.fileSize != null) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.textMuted.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        info.fileSize!,
                                        style: const TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                          // ── Step progress (saat downloading) ──
                          if (isProcessing) ...[
                            const SizedBox(height: 8),
                            // Step indicators
                            _UpdateStepRow(
                              steps: [
                                _UpdateStep(
                                  label: 'Persiapan',
                                  isActive: status == DownloadStatus.preparing,
                                  isDone: status == DownloadStatus.downloading ||
                                      status == DownloadStatus.installing ||
                                      status == DownloadStatus.completed,
                                ),
                                _UpdateStep(
                                  label: 'Unduh',
                                  isActive: status == DownloadStatus.downloading,
                                  isDone: status == DownloadStatus.installing ||
                                      status == DownloadStatus.completed,
                                ),
                                _UpdateStep(
                                  label: 'Install',
                                  isActive: status == DownloadStatus.installing,
                                  isDone: status == DownloadStatus.completed,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Progress bar
                            if (status == DownloadStatus.downloading) ...[
                              Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      minHeight: 10,
                                      backgroundColor: AppColors.surfaceAlt,
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                        AppColors.accent,
                                      ),
                                    ),
                                  ),
                                  Positioned.fill(
                                    child: Center(
                                      child: Text(
                                        '${(progress * 100).toStringAsFixed(0)}%',
                                        style: TextStyle(
                                          fontSize: 7,
                                          fontWeight: FontWeight.w800,
                                          color: progress > 0.5
                                              ? Colors.white
                                              : AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Mengunduh update...',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],

                            if (status == DownloadStatus.preparing)
                              Column(
                                children: [
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: AppColors.accent,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Mempersiapkan...',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),

                            if (status == DownloadStatus.installing)
                              Column(
                                children: [
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: AppColors.success,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Membuka installer...',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                          ],

                          const SizedBox(height: 20),

                          // ── Fallback: no APK available ──
                          if ((status == DownloadStatus.idle ||
                                  status == DownloadStatus.failed) &&
                              info.downloadUrl == null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                'File update belum tersedia. Hubungi admin.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),

                          // ── Action button ──
                          if ((status == DownloadStatus.idle ||
                                  status == DownloadStatus.failed ||
                                  status == DownloadStatus.completed) &&
                              info.downloadUrl != null)
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: status == DownloadStatus.failed
                                      ? AppColors.roseGradient
                                      : status == DownloadStatus.completed
                                          ? AppColors.emeraldGradient
                                          : AppColors.accentGradient,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (status == DownloadStatus.failed
                                              ? AppColors.error
                                              : status == DownloadStatus.completed
                                                  ? AppColors.success
                                                  : AppColors.accent)
                                          .withValues(alpha: 0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () async {
                                      errorMsg = null;
                                      setDialogState(() {});
                                      try {
                                        await UpdateService.downloadAndInstall(
                                          downloadUrl: info.downloadUrl!,
                                          onProgress: (p) {
                                            progress = p;
                                            setDialogState(() {});
                                          },
                                          onStatusChanged: (s) {
                                            status = s;
                                            setDialogState(() {});
                                          },
                                        );
                                      } catch (e) {
                                        status = DownloadStatus.failed;
                                        errorMsg = 'Gagal. Periksa koneksi internet dan coba lagi.';
                                        progress = 0;
                                        setDialogState(() {});
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Center(
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            status == DownloadStatus.failed
                                                ? Icons.refresh_rounded
                                                : status == DownloadStatus.completed
                                                    ? Icons.install_mobile_rounded
                                                    : Icons.download_rounded,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            status == DownloadStatus.failed
                                                ? 'Coba Lagi'
                                                : status == DownloadStatus.completed
                                                    ? 'Install Sekarang'
                                                    : 'Update Sekarang',
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                          // ── Wajib notice ──
                          if (status == DownloadStatus.idle) ...[
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.lock_rounded,
                                  size: 12,
                                  color: AppColors.textMuted,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Update wajib untuk melanjutkan',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showComingSoonDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Coming Soon',
      barrierColor: Colors.black.withValues(alpha: 0.6),
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (_, anim, _, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: anim, child: child),
        );
      },
      pageBuilder: (ctx, _, _) {
        return Center(
          child: Container(
            width: 300,
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  blurRadius: 40,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated icon
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: AppColors.tealGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0D9488).withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.rocket_launch_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Title
                  const Text(
                    'Segera Hadir!',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Description
                  Text(
                    'Fitur Pendapatan sedang dalam tahap pengembangan. Anda akan bisa melihat slip gaji, bonus, dan rincian pendapatan di sini.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),

                  // Coming soon badge
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D9488).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF0D9488).withValues(alpha: 0.2),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 14,
                          color: Color(0xFF0D9488),
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Coming Soon',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0D9488),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Close button
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Mengerti',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
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
      
      // Validasi ketat per divisi (semua lokasi dicek)
      final validationResult = await StrictLocationValidator.validateLocationForDivision(
        position: position,
        divisionId: divisionId,
        locations: divisionLocations,
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
           onRefresh: _refreshAll,
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

                    // SP Warning Banner
                    if (_activeSP != null)
                      _SPWarningBanner(sp: _activeSP!),

                    // Menu
                    MenuGridSection(items: _menuItems),
                    const SizedBox(height: 12),

                    // Stats
                    if (_statsLoaded)
                      StatsSection(
                        periodLabel: _periodLabel,
                        hadir: _stats['hadir'] ?? 0,
                        terlambat: _stats['terlambat'] ?? 0,
                        izin: _stats['izin'] ?? 0,
                        alpha: _stats['alpha'] ?? 0,
                        prevHadir: _prevStats['hadir'] ?? 0,
                        prevTerlambat: _prevStats['terlambat'] ?? 0,
                        prevIzin: _prevStats['izin'] ?? 0,
                        prevAlpha: _prevStats['alpha'] ?? 0,
                      ),
                    const SizedBox(height: 12),

                    // Attendance progress
                    if (_statsLoaded)
                      AttendanceProgressCard(
                        percentage: _attendancePercentage,
                        totalPresent: (_stats['hadir'] ?? 0) + (_stats['terlambat'] ?? 0),
                        workingDays: _totalWorkingDays,
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
// UPDATE STEP ROW — Step indicators for download process
// ═════════════════════════════════════════════════════════
class _UpdateStep {
  final String label;
  final bool isActive;
  final bool isDone;

  const _UpdateStep({
    required this.label,
    required this.isActive,
    required this.isDone,
  });
}

class _UpdateStepRow extends StatelessWidget {
  final List<_UpdateStep> steps;

  const _UpdateStepRow({required this.steps});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < steps.length; i++) ...[
          _buildStep(steps[i], i + 1),
          if (i < steps.length - 1)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(1),
                  color: steps[i].isDone
                      ? AppColors.success.withValues(alpha: 0.4)
                      : AppColors.border,
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildStep(_UpdateStep step, int number) {
    final Color dotColor;
    final Color textColor;

    if (step.isDone) {
      dotColor = AppColors.success;
      textColor = AppColors.success;
    } else if (step.isActive) {
      dotColor = AppColors.accent;
      textColor = AppColors.accent;
    } else {
      dotColor = AppColors.border;
      textColor = AppColors.textMuted;
    }

    return Column(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: step.isDone || step.isActive
                ? dotColor.withValues(alpha: 0.12)
                : AppColors.surfaceAlt,
            shape: BoxShape.circle,
            border: Border.all(
              color: dotColor,
              width: step.isActive ? 2 : 1.5,
            ),
          ),
          child: Center(
            child: step.isDone
                ? Icon(Icons.check_rounded, size: 12, color: dotColor)
                : Text(
                    '$number',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: dotColor,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          step.label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: step.isActive ? FontWeight.w700 : FontWeight.w500,
            color: textColor,
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════
// SP WARNING BANNER — Peringatan surat peringatan aktif
// ═════════════════════════════════════════════════════════
class _SPWarningBanner extends StatefulWidget {
  final Map<String, dynamic> sp;

  const _SPWarningBanner({required this.sp});

  @override
  State<_SPWarningBanner> createState() => _SPWarningBannerState();
}

class _SPWarningBannerState extends State<_SPWarningBanner> {
  bool _isDismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_isDismissed) return const SizedBox.shrink();

    final tingkat = widget.sp['tingkat_sp'] as String? ?? 'SP';
    final pelanggaran = widget.sp['pelanggaran'] as String?;
    final tanggalBerakhir = widget.sp['tanggal_berakhir'] as String?;

    // Severity: SP-3 paling berat
    final bool isSevere = tingkat == 'SP-3';
    final bool isModerate = tingkat == 'SP-2';

    final Color bannerColor = isSevere
        ? const Color(0xFFDC2626)
        : isModerate
            ? const Color(0xFFD97706)
            : const Color(0xFFEA580C);

    final Color bgColor = isSevere
        ? const Color(0xFFFEF2F2)
        : isModerate
            ? const Color(0xFFFFFBEB)
            : const Color(0xFFFFF7ED);

    final String nasehat = isSevere
        ? 'Ini adalah peringatan terakhir. Pelanggaran berikutnya dapat berakibat pemutusan hubungan kerja. Mohon segera perbaiki kinerja dan sikap Anda.'
        : isModerate
            ? 'Anda telah menerima peringatan kedua. Mohon tingkatkan kedisiplinan dan patuhi peraturan perusahaan agar tidak berlanjut ke tahap berikutnya.'
            : 'Jadikan ini sebagai pengingat untuk memperbaiki diri. Patuhi peraturan perusahaan dan tunjukkan kinerja terbaik Anda.';

    // Sisa hari SP
    String? sisaHari;
    if (tanggalBerakhir != null) {
      final end = DateTime.parse(tanggalBerakhir);
      final diff = end.difference(DateTime.now()).inDays;
      if (diff > 0) sisaHari = '$diff hari lagi';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: bannerColor.withValues(alpha: 0.25),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: bannerColor.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 10, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: bannerColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isSevere
                          ? Icons.gpp_bad_rounded
                          : Icons.warning_amber_rounded,
                      color: bannerColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Title + tingkat
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Surat Peringatan',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: bannerColor,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: bannerColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                tingkat,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: bannerColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (sisaHari != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Berlaku $sisaHari',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: bannerColor.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Dismiss
                  GestureDetector(
                    onTap: () => setState(() => _isDismissed = true),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: bannerColor.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Pelanggaran
            if (pelanggaran != null && pelanggaran.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: bannerColor.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.report_rounded,
                        size: 13,
                        color: bannerColor.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          pelanggaran,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Nasehat
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: bannerColor.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lightbulb_rounded,
                      size: 14,
                      color: bannerColor.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        nasehat,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════
// GPS VERIFICATION OVERLAY — Animated radar-style loading
// ═════════════════════════════════════════════════════════
class _GPSVerificationOverlay extends StatefulWidget {
  final String message;

  const _GPSVerificationOverlay({required this.message});

  @override
  State<_GPSVerificationOverlay> createState() => _GPSVerificationOverlayState();
}

class _GPSVerificationOverlayState extends State<_GPSVerificationOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _entryCtrl;
  late final AnimationController _radarCtrl;
  late final AnimationController _dotCtrl;
  late final Animation<double> _fadeIn;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    // Entry animation
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();
    _fadeIn = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _scale = Tween(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutBack),
    );

    // Radar sweep animation
    _radarCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    // Dot pulse animation
    _dotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _radarCtrl.dispose();
    _dotCtrl.dispose();
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
        color: Colors.black.withValues(alpha: 0.6),
        child: Center(
          child: ScaleTransition(
            scale: _scale,
            child: Container(
              width: 300,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    blurRadius: 40,
                    offset: const Offset(0, 12),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Radar animation
                  _RadarWidget(
                    radarCtrl: _radarCtrl,
                    dotCtrl: _dotCtrl,
                    icon: _icon,
                  ),
                  const SizedBox(height: 24),

                  // Title
                  Text(
                    widget.message,
                    style: AppTextStyles.h4.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),

                  // Subtitle
                  Text(
                    _subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textMuted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Animated progress dots
                  _AnimatedProgressDots(controller: _dotCtrl),
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
// RADAR WIDGET — Animated concentric rings with sweep
// ═════════════════════════════════════════════════════════
class _RadarWidget extends StatelessWidget {
  final AnimationController radarCtrl;
  final AnimationController dotCtrl;
  final IconData icon;

  const _RadarWidget({
    required this.radarCtrl,
    required this.dotCtrl,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer ring 3 (largest, faintest)
          AnimatedBuilder(
            animation: dotCtrl,
            builder: (_, _) {
              return Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withValues(
                      alpha: 0.06 + (dotCtrl.value * 0.04),
                    ),
                    width: 1,
                  ),
                ),
              );
            },
          ),

          // Outer ring 2
          AnimatedBuilder(
            animation: dotCtrl,
            builder: (_, _) {
              return Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withValues(
                      alpha: 0.1 + (dotCtrl.value * 0.06),
                    ),
                    width: 1.5,
                  ),
                ),
              );
            },
          ),

          // Inner ring
          AnimatedBuilder(
            animation: dotCtrl,
            builder: (_, _) {
              return Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(
                    alpha: 0.04 + (dotCtrl.value * 0.03),
                  ),
                  border: Border.all(
                    color: AppColors.primary.withValues(
                      alpha: 0.15 + (dotCtrl.value * 0.1),
                    ),
                    width: 1.5,
                  ),
                ),
              );
            },
          ),

          // Rotating sweep line
          AnimatedBuilder(
            animation: radarCtrl,
            builder: (_, _) {
              return Transform.rotate(
                angle: radarCtrl.value * 2 * 3.14159,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      startAngle: 0,
                      endAngle: 1.2,
                      colors: [
                        AppColors.primary.withValues(alpha: 0.25),
                        AppColors.primary.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // Center icon
          AnimatedBuilder(
            animation: dotCtrl,
            builder: (_, child) {
              return Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(
                        alpha: 0.15 + (dotCtrl.value * 0.1),
                      ),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: child,
              );
            },
            child: Container(
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════
// ANIMATED PROGRESS DOTS — Three bouncing dots
// ═════════════════════════════════════════════════════════
class _AnimatedProgressDots extends StatelessWidget {
  final AnimationController controller;

  const _AnimatedProgressDots({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            // Stagger each dot
            final delay = index * 0.2;
            final value = ((controller.value + delay) % 1.0);
            final opacity = 0.3 + (value < 0.5 ? value : 1.0 - value) * 1.4;
            final scale = 0.6 + (value < 0.5 ? value : 1.0 - value) * 0.8;

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: Transform.scale(
                scale: scale.clamp(0.6, 1.0),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(
                      alpha: opacity.clamp(0.3, 1.0),
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
