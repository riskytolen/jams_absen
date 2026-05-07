import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/services/attendance_service.dart';

/// Screen riwayat absensi — professional, timeline-style.
class AttendanceHistoryScreen extends StatefulWidget {
  final String employeeId;
  final String employeeName;

  const AttendanceHistoryScreen({
    super.key,
    required this.employeeId,
    required this.employeeName,
  });

  @override
  State<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  late DateTime _periodStart;
  late DateTime _periodEnd;
  List<Map<String, dynamic>> _records = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initPeriod();
    _loadData();
  }

  /// Hitung periode aktif: tanggal 8 — tanggal 7 bulan berikutnya.
  void _initPeriod() {
    final now = DateTime.now();
    if (now.day >= 8) {
      _periodStart = DateTime(now.year, now.month, 8);
      _periodEnd = DateTime(now.year, now.month + 1, 7);
    } else {
      _periodStart = DateTime(now.year, now.month - 1, 8);
      _periodEnd = DateTime(now.year, now.month, 7);
    }
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String get _periodLabel {
    final startLabel = DateFormat('dd MMM', 'id_ID').format(_periodStart);
    final endLabel = DateFormat('dd MMM yyyy', 'id_ID').format(_periodEnd);
    return '$startLabel — $endLabel';
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final data = await AttendanceService.getAttendanceHistory(
      employeeId: widget.employeeId,
      startDate: _formatDate(_periodStart),
      endDate: _formatDate(_periodEnd),
    );
    if (mounted) {
      setState(() {
        _records = data;
        _isLoading = false;
      });
    }
  }

  void _changePeriod(int delta) {
    HapticFeedback.selectionClick();
    setState(() {
      _periodStart = DateTime(_periodStart.year, _periodStart.month + delta, 8);
      _periodEnd = DateTime(_periodStart.year, _periodStart.month + 1, 7);
    });
    _loadData();
  }

  int get _totalHadir =>
      _records.where((r) => r['status'] == 'Hadir').length;
  int get _totalTelat =>
      _records.where((r) => r['status'] == 'Terlambat').length;
  int get _totalIzin =>
      _records.where((r) =>
          r['status'] == 'Izin' ||
          r['status'] == 'Sakit' ||
          r['status'] == 'Cuti').length;
  int get _totalAlpha =>
      _records.where((r) => r['status'] == 'Alpha').length;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            // ── Header ──
            _Header(
              employeeName: widget.employeeName,
              periodLabel: _periodLabel,
              totalHadir: _totalHadir,
              totalTelat: _totalTelat,
              totalIzin: _totalIzin,
              totalAlpha: _totalAlpha,
              totalRecords: _records.length,
              onBack: () => Navigator.of(context).pop(),
              onPrevMonth: () => _changePeriod(-1),
              onNextMonth: () => _changePeriod(1),
            ),

            // ── List ──
            Expanded(
              child: _isLoading
                  ? _buildLoading()
                  : _records.isEmpty
                      ? _buildEmpty()
                      : _buildList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Memuat riwayat...',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.event_busy_rounded,
                size: 32,
                color: AppColors.textMuted.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Belum Ada Data',
              style: AppTextStyles.h4.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              'Tidak ada catatan kehadiran\npada bulan ini',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primary,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(
          16, 12, 16,
          MediaQuery.of(context).viewPadding.bottom + 24,
        ),
        itemCount: _records.length,
        itemBuilder: (context, index) {
          final record = _records[index];
          final isLast = index == _records.length - 1;
          return _TimelineItem(record: record, isLast: isLast);
        },
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════
// HEADER — Gradient, stats, month selector
// ═════════════════════════════════════════════════════════
class _Header extends StatelessWidget {
  final String employeeName;
  final String periodLabel;
  final int totalHadir;
  final int totalTelat;
  final int totalIzin;
  final int totalAlpha;
  final int totalRecords;
  final VoidCallback onBack;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;

  const _Header({
    required this.employeeName,
    required this.periodLabel,
    required this.totalHadir,
    required this.totalTelat,
    required this.totalIzin,
    required this.totalAlpha,
    required this.totalRecords,
    required this.onBack,
    required this.onPrevMonth,
    required this.onNextMonth,
  });

  @override
  Widget build(BuildContext context) {

    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 16, 18),
          child: Column(
            children: [
              // App bar row
              Row(
                children: [
                  IconButton(
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: Colors.white,
                    iconSize: 22,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Riwayat Kehadiran',
                          style: AppTextStyles.onDarkTitle.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          employeeName,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.6),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Month selector
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: onPrevMonth,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.chevron_left_rounded,
                          color: Colors.white.withValues(alpha: 0.8),
                          size: 20,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        periodLabel,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: onNextMonth,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.white.withValues(alpha: 0.8),
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Stats row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      _HeaderStat(
                        count: totalHadir,
                        label: 'Hadir',
                        color: const Color(0xFF34D399),
                      ),
                      _divider(),
                      _HeaderStat(
                        count: totalTelat,
                        label: 'Telat',
                        color: const Color(0xFFF87171),
                      ),
                      _divider(),
                      _HeaderStat(
                        count: totalIzin,
                        label: 'Izin',
                        color: const Color(0xFFFBBF24),
                      ),
                      _divider(),
                      _HeaderStat(
                        count: totalAlpha,
                        label: 'Alpha',
                        color: const Color(0xFFA78BFA),
                      ),
                      _divider(),
                      _HeaderStat(
                        count: totalRecords,
                        label: 'Total',
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: Colors.white.withValues(alpha: 0.1),
    );
  }
}

// ═════════════════════════════════════════════════════════
// HEADER STAT
// ═════════════════════════════════════════════════════════
class _HeaderStat extends StatelessWidget {
  final int count;
  final String label;
  final Color color;

  const _HeaderStat({
    required this.count,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════
// TIMELINE ITEM — Record with timeline connector
// ═════════════════════════════════════════════════════════
class _TimelineItem extends StatelessWidget {
  final Map<String, dynamic> record;
  final bool isLast;

  const _TimelineItem({required this.record, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final tanggal = DateTime.parse(record['tanggal'] as String);
    final jamMasuk = (record['jam_masuk'] as String).substring(0, 5);
    final status = record['status'] as String;
    final durasiTelat = record['durasi_telat'] as int? ?? 0;
    final denda = record['denda'] as int? ?? 0;
    final divisionData = record['divisions'] as Map<String, dynamic>?;
    final divisionName = divisionData?['nama'] as String? ?? '-';
    final scheduleJamMasuk = record['schedule_jam_masuk'] as String?;
    final scheduleTime = scheduleJamMasuk?.substring(0, 5);

    final alasanManual = record['alasan_manual'] as String?;
    final isPresent = status == 'Hadir' || status == 'Terlambat';

    final Color statusColor;
    final IconData statusIcon;
    final String statusLabel;

    switch (status) {
      case 'Hadir':
        statusColor = const Color(0xFF059669);
        statusIcon = Icons.check_circle_rounded;
        statusLabel = 'Tepat Waktu';
        break;
      case 'Terlambat':
        statusColor = const Color(0xFFDC2626);
        statusIcon = Icons.warning_rounded;
        statusLabel = 'Terlambat +$durasiTelat mnt';
        break;
      case 'Izin':
        statusColor = const Color(0xFFD97706);
        statusIcon = Icons.mail_rounded;
        statusLabel = 'Izin';
        break;
      case 'Sakit':
        statusColor = const Color(0xFFD97706);
        statusIcon = Icons.local_hospital_rounded;
        statusLabel = 'Sakit';
        break;
      case 'Cuti':
        statusColor = const Color(0xFF0891B2);
        statusIcon = Icons.beach_access_rounded;
        statusLabel = 'Cuti';
        break;
      case 'Alpha':
        statusColor = const Color(0xFF7C3AED);
        statusIcon = Icons.cancel_rounded;
        statusLabel = 'Alpha';
        break;
      default:
        statusColor = AppColors.textMuted;
        statusIcon = Icons.circle_outlined;
        statusLabel = status;
    }

    final dayName = DateFormat('EEEE', 'id_ID').format(tanggal);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Timeline connector ──
          SizedBox(
            width: 40,
            child: Column(
              children: [
                // Date number
                Text(
                  '${tanggal.day}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  DateFormat('MMM', 'id_ID').format(tanggal),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                // Dot
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withValues(alpha: 0.3),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                // Line
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      margin: const EdgeInsets.only(top: 4),
                      color: AppColors.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // ── Card ──
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: day + time
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    child: Row(
                      children: [
                        // Status icon
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Icon(statusIcon, color: statusColor, size: 18),
                        ),
                        const SizedBox(width: 10),
                        // Day + status
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dayName,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textDark,
                                ),
                              ),
                              Text(
                                statusLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: statusColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Clock-in time
                        if (isPresent)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: statusColor.withValues(alpha: 0.15),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              jamMasuk,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: statusColor,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Alasan manual (dari admin web)
                  if (alasanManual != null && alasanManual.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.infoBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.info.withValues(alpha: 0.15),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.admin_panel_settings_rounded,
                              size: 13,
                              color: AppColors.info,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                alasanManual,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.info,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Bottom detail row (hanya untuk Hadir/Terlambat)
                  if (isPresent)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt.withValues(alpha: 0.5),
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(14),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Division
                          Icon(
                            Icons.location_on_rounded,
                            size: 12,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            divisionName,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          // Schedule
                          if (scheduleTime != null) ...[
                            const SizedBox(width: 10),
                            Icon(
                              Icons.schedule_rounded,
                              size: 12,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'Jadwal $scheduleTime',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          const Spacer(),
                          // Denda
                          if (denda > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDC2626).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '-Rp ${_formatCurrency(denda)}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFDC2626),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatCurrency(int amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}jt';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}rb';
    }
    return amount.toString();
  }
}
