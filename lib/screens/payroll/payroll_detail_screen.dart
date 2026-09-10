import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/services/payroll_service.dart';
import '../../core/utils/backup_libur_snapshot.dart';

class PayrollDetailScreen extends StatefulWidget {
  final String employeeId;
  final String employeeName;
  final Map<String, dynamic> payroll;

  const PayrollDetailScreen({
    super.key,
    required this.employeeId,
    required this.employeeName,
    required this.payroll,
  });

  @override
  State<PayrollDetailScreen> createState() => _PayrollDetailScreenState();
}

class _PayrollDetailScreenState extends State<PayrollDetailScreen>
    with WidgetsBindingObserver {
  List<Map<String, dynamic>> _deliveryData = [];
  List<Map<String, dynamic>> _overtimeData = [];
  List<Map<String, dynamic>> _absenData = [];

  Map<String, dynamic>? _freshPayroll;
  bool _isInvalid = false;
  bool _isLoading = true;
  String? _errorMessage;

  bool _titikExpanded = true;
  bool _lemburExpanded = true;
  bool _tambahanExpanded = true;
  bool _absenExpanded = true;
  bool _potonganExpanded = true;

  final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  final _dateFormat = DateFormat('d MMMM yyyy', 'id_ID');
  final _shortDateFormat = DateFormat('d MMM yyyy', 'id_ID');

  static const _pendapatanFields = [
    ('gaji_pokok', 'Gaji Pokok'),
    ('pendapatan_titik', 'Pendapatan Titik'),
    ('tambahan_backup_libur', 'Tambahan Backup Libur'),
    ('lembur', 'Lembur'),
    ('extra_job', 'Extra Job'),
    ('uang_makan', 'Uang Makan'),
    ('insentif', 'Insentif'),
    ('tunjangan_jabatan', 'Tunjangan Jabatan'),
    ('transport', 'Transport'),
    ('tunjangan_lain', 'Tunjangan Lain'),
    ('tambahan_lain', 'Tambahan Lain'),
  ];

  static const _potonganFields = [
    ('potongan_absen', 'Potongan Absen'),
    ('koperasi', 'Koperasi'),
    ('pinjaman_perusahaan', 'Pinjaman Perusahaan'),
    ('potongan_lain', 'Potongan Lain'),
    ('jht', 'JHT'),
    ('bpjs_kesehatan', 'BPJS Kesehatan'),
  ];

  static const _keteranganKey = {
    'extra_job': 'extra_job_keterangan',
    'insentif': 'insentif_keterangan',
    'pinjaman_perusahaan': 'pinjaman_perusahaan_keterangan',
    'potongan_lain': 'potongan_lain_keterangan',
  };

  Map<String, dynamic> get _p => _freshPayroll ?? widget.payroll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initScreen();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _revalidate();
    }
  }

  Future<void> _initScreen() async {
    await _validateAndLoad(showLoading: true);
  }

  Future<void> _validateAndLoad({bool showLoading = false}) async {
    if (showLoading) setState(() => _isLoading = true);
    _isInvalid = false;

    final id = widget.payroll['id'] as int;
    final result = await PayrollService.getFinalPayrollById(
      payrollId: id,
      employeeId: widget.employeeId,
    );

    if (!mounted) return;

    if (result == null) {
      setState(() {
        _isInvalid = true;
        _isLoading = false;
        _errorMessage =
            'Slip gaji ini sedang dikoreksi oleh HR dan tidak dapat diakses untuk sementara.';
      });
      return;
    }

    _freshPayroll = result;
    await _loadDetails();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadDetails() async {
    final p = _p;
    final start = p['periode_mulai'] as String;
    final end = p['periode_selesai'] as String;

    final results = await Future.wait([
      PayrollService.getDeliveryPointDetails(
        employeeId: widget.employeeId,
        startDate: start,
        endDate: end,
      ),
      PayrollService.getOvertimeDetails(
        employeeId: widget.employeeId,
        startDate: start,
        endDate: end,
      ),
      PayrollService.getAttendanceDeductionDetails(
        employeeId: widget.employeeId,
        startDate: start,
        endDate: end,
      ),
    ]);

    if (mounted) {
      setState(() {
        _deliveryData = List<Map<String, dynamic>>.from(results[0] as List);
        _overtimeData = List<Map<String, dynamic>>.from(results[1] as List);
        _absenData = List<Map<String, dynamic>>.from(results[2] as List);
      });
    }
  }

  Future<void> _revalidate() async {
    if (_isInvalid) return;

    final id = widget.payroll['id'] as int;
    final result = await PayrollService.getFinalPayrollById(
      payrollId: id,
      employeeId: widget.employeeId,
    );

    if (!mounted) return;

    if (result == null) {
      setState(() {
        _isInvalid = true;
        _isLoading = false;
        _errorMessage =
            'Slip gaji ditarik kembali oleh HR saat Anda meninggalkan aplikasi.';
      });
    }
  }

  Future<void> _onRefresh() async {
    if (_isInvalid) return;
    await _validateAndLoad();
  }

  int _value(String key) => (_p[key] as int?) ?? 0;

  /// Snapshot Backup Libur tersimpan di baris payroll Final.
  /// Formula resmi: (driver_days × driver_rate) + (helper_days × helper_rate).
  /// Nilai dibaca apa adanya dari snapshot, TIDAK dihitung ulang dari
  /// delivery_points live agar konsisten dengan slip Final.
  BackupLiburSnapshot get _backupLibur =>
      BackupLiburSnapshot.fromPayroll(_p);

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? _buildLoadingState()
                  : _isInvalid
                  ? _buildInvalidState()
                  : RefreshIndicator(
                      onRefresh: _onRefresh,
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(
                          0,
                          0,
                          0,
                          MediaQuery.of(context).viewPadding.bottom + 16,
                        ),
                        children: [
                          _buildHeroCard(),
                          _buildSummaryRow(),
                          _buildPendapatanComponentsSection(),
                          _buildBackupLiburSection(),
                          _buildPotonganComponentsSection(),
                          _buildDeliverySection(),
                          _buildOvertimeSection(),
                          _buildPotonganAbsenSection(),
                          if (_p['catatan'] != null &&
                              (_p['catatan'] as String).isNotEmpty)
                            _buildCatatanSection(),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════
  // HEADER
  // ═════════════════════════════════════════════════════════
  Widget _buildHeader() {
    final mulai = DateTime.parse(_p['periode_mulai'] as String);
    final selesai = DateTime.parse(_p['periode_selesai'] as String);
    final periodeText =
        '${_dateFormat.format(mulai)} - ${_dateFormat.format(selesai)}';

    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 16, 20),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: Colors.white,
                    iconSize: 22,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Detail Slip Gaji',
                      style: AppTextStyles.onDarkTitle.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        periodeText,
                        style: AppTextStyles.onDarkCaption.copyWith(
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 10,
                            color: AppColors.successLight,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Final',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppColors.successLight,
                            ),
                          ),
                        ],
                      ),
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

  // ═════════════════════════════════════════════════════════
  // HERO CARD
  // ═════════════════════════════════════════════════════════
  Widget _buildHeroCard() {
    final netto = _value('netto');
    final lockedAt = _p['locked_at'] as String?;
    String? lockedAtText;
    if (lockedAt != null) {
      final dt = DateTime.tryParse(lockedAt);
      if (dt != null) {
        lockedAtText = 'Difinalkan ${_dateFormat.format(dt.toLocal())}';
      }
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        gradient: AppColors.tealGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D9488).withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.employeeName,
                        style: AppTextStyles.onDarkCaption.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Netto',
                        style: AppTextStyles.onDarkCaption.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _currencyFormat.format(netto),
              style: AppTextStyles.numericLg.copyWith(
                fontSize: 32,
                color: Colors.white,
              ),
            ),
            if (lockedAtText != null) ...[
              const SizedBox(height: 6),
              Text(
                lockedAtText,
                style: AppTextStyles.onDarkMuted.copyWith(fontSize: 9),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                _heroStat('Pendapatan', _value('total_pendapatan')),
                const SizedBox(width: 12),
                _heroStat('Potongan', _value('total_potongan')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroStat(String label, int value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _currencyFormat.format(value),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════
  // SUMMARY ROW
  // ═════════════════════════════════════════════════════════
  Widget _buildSummaryRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
        children: [
          _summaryCard(
            Icons.arrow_upward_rounded,
            'Pendapatan',
            _value('total_pendapatan'),
            AppColors.success,
          ),
          const SizedBox(width: 8),
          _summaryCard(
            Icons.arrow_downward_rounded,
            'Potongan',
            _value('total_potongan'),
            AppColors.error,
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(IconData icon, String label, int value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _currencyFormat.format(value),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════
  // SECTION: PENDAPATAN TITIK
  // ═════════════════════════════════════════════════════════
  Widget _buildDeliverySection() {
    final data = _deliveryData;
    final totalTitik = data.fold<int>(
      0,
      (s, d) => s + ((d['jumlah_titik'] as int?) ?? 0),
    );
    final totalRupiah = data.fold<int>(
      0,
      (s, d) => s + ((d['total'] as int?) ?? 0),
    );
    final uniqueDates = data.map((d) => d['tanggal'] as String).toSet();
    final drivers = data.where((d) => d['role'] == 'Driver').toList();
    final helpers = data.where((d) => d['role'] == 'Helper').toList();
    final driverTitik = drivers.fold<int>(
      0,
      (s, d) => s + ((d['jumlah_titik'] as int?) ?? 0),
    );
    final helperTitik = helpers.fold<int>(
      0,
      (s, d) => s + ((d['jumlah_titik'] as int?) ?? 0),
    );

    final summaryParts = <String>[];
    if (totalTitik > 0) summaryParts.add('$totalTitik titik');
    summaryParts.add('${uniqueDates.length} hari');
    if (drivers.isNotEmpty) summaryParts.add('Driver $driverTitik titik');
    if (helpers.isNotEmpty) summaryParts.add('Helper $helperTitik titik');

    return _buildSectionCard(
      icon: Icons.location_on_rounded,
      title: 'Detail Pendapatan Titik',
      color: AppColors.success,
      summary: _currencyFormat.format(totalRupiah),
      subtitle: summaryParts.join(' | '),
      expanded: _titikExpanded,
      onToggle: () => setState(() => _titikExpanded = !_titikExpanded),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.infoBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.info.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 14, color: AppColors.info),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Rincian di bawah adalah data titik terkini (live), bukan snapshot Final. Nominal resmi mengikuti Komponen Pendapatan di atas.',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildTitikRingkasan(
            data.length,
            drivers.length,
            helpers.length,
            totalTitik,
            totalRupiah,
          ),
          const SizedBox(height: 8),
          ..._buildGroupedDelivery(data),
        ],
      ),
    );
  }

  Widget _buildTitikRingkasan(
    int totalRows,
    int driverCount,
    int helperCount,
    int totalTitik,
    int totalRupiah,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 0),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.successBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _miniStat('Total Baris', '$totalRows'),
              _miniStat('Total Titik', '$totalTitik'),
              _miniStat('Total Rp', _currencyFormat.format(totalRupiah)),
            ],
          ),
          if (driverCount > 0 || helperCount > 0) ...[
            const SizedBox(height: 6),
            const Divider(height: 1, color: AppColors.successLight),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.local_shipping_rounded,
                        size: 12,
                        color: Color(0xFF2563EB),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Driver: $driverCount baris',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.person_rounded,
                        size: 12,
                        color: Color(0xFF7C3AED),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Helper: $helperCount baris',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF065F46),
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: Color(0xFF047857),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildGroupedDelivery(List<Map<String, dynamic>> data) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final d in data) {
      final tgl = d['tanggal'] as String;
      grouped.putIfAbsent(tgl, () => []).add(d);
    }
    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return sortedKeys.expand((tgl) {
      final items = grouped[tgl]!;
      final date = DateTime.parse(tgl);
      return [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
          child: Text(
            _shortDateFormat.format(date),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
              letterSpacing: 0.3,
            ),
          ),
        ),
        ...items.map((item) => _deliveryRow(item)),
        const SizedBox(height: 4),
      ];
    }).toList();
  }

  Widget _deliveryRow(Map<String, dynamic> point) {
    final jumlahTitik = point['jumlah_titik'] as int? ?? 0;
    final total = point['total'] as int? ?? 0;
    final rate = point['rate_per_point'] as int? ?? 0;
    final role = point['role'] as String? ?? '-';
    final catatan = point['catatan'] as String?;
    final isDriver = role == 'Driver';

    final zone = point['delivery_zones'] as Map<String, dynamic>?;
    final zoneName = zone?['nama'] as String? ?? '-';
    final zoneColorHex = zone?['color'] as String? ?? '#3b82f6';
    final zoneColor = _parseColor(zoneColorHex);

    final status = point['delivery_statuses'] as Map<String, dynamic>?;
    final statusNama = status?['nama'] as String?;
    final statusColorHex = status?['color'] as String?;
    final statusColor = statusColorHex != null
        ? _parseColor(statusColorHex)
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: zoneColor.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: zoneColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    isDriver
                        ? Icons.local_shipping_rounded
                        : Icons.person_rounded,
                    size: 14,
                    color: zoneColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        zoneName,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          _roleBadge(role, isDriver),
                          if (statusNama != null) ...[
                            const SizedBox(width: 4),
                            _statusBadge(statusNama, statusColor),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _currencyFormat.format(total),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    Text(
                      '$jumlahTitik titik',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calculate_outlined,
                    size: 10,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$jumlahTitik × ${_currencyFormat.format(rate)}',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '= ${_currencyFormat.format(total)}',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
            if (catatan != null && catatan.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.notes_rounded,
                    size: 10,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      catatan,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textMuted,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _roleBadge(String role, bool isDriver) {
    final color = isDriver ? const Color(0xFF2563EB) : const Color(0xFF7C3AED);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        role,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _statusBadge(String status, Color? color) {
    final c = color ?? AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        status,
        style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: c),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════
  // SECTION: LEMBUR
  // ═════════════════════════════════════════════════════════
  Widget _buildOvertimeSection() {
    final data = _overtimeData;
    final totalLembur = data.fold<int>(
      0,
      (s, d) => s + ((d['total_lembur'] as int?) ?? 0),
    );

    return _buildSectionCard(
      icon: Icons.access_time_rounded,
      title: 'Detail Lembur',
      color: const Color(0xFFD97706),
      summary: _currencyFormat.format(totalLembur),
      subtitle: '${data.length} pengajuan disetujui',
      expanded: _lemburExpanded,
      onToggle: () => setState(() => _lemburExpanded = !_lemburExpanded),
      child: data.isEmpty
          ? _sectionEmpty('Tidak ada lembur di periode ini.')
          : Column(children: data.map((item) => _overtimeRow(item)).toList()),
    );
  }

  Widget _overtimeRow(Map<String, dynamic> item) {
    final tanggal = DateTime.parse(item['tanggal'] as String);
    final jamMulai = item['jam_mulai'] as String;
    final jamSelesai = item['jam_selesai'] as String;
    final durasi = item['durasi_menit'] as int? ?? 0;
    final rate = item['rate_per_jam'] as int? ?? 0;
    final total = item['total_lembur'] as int? ?? 0;
    final alasan = item['alasan'] as String?;

    final jamText = jamMulai.length >= 5
        ? '${jamMulai.substring(0, 5)} - ${jamSelesai.substring(0, 5)}'
        : '$jamMulai - $jamSelesai';

    final durasiText = durasi >= 60
        ? '${durasi ~/ 60} jam ${durasi % 60} menit'
        : '$durasi menit';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.warningBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.warning.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.schedule_rounded,
                size: 16,
                color: AppColors.warning,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _shortDateFormat.format(tanggal),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$jamText · $durasiText',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'Rate ${_currencyFormat.format(rate)}/jam',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textMuted,
                    ),
                  ),
                  if (alasan != null && alasan.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 10,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            alasan,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w400,
                              color: AppColors.textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _currencyFormat.format(total),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF92400E),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════
  // SECTION: KOMPONEN PENDAPATAN
  // ═════════════════════════════════════════════════════════
  Widget _buildPendapatanComponentsSection() {
    final total = _value('total_pendapatan');
    final activeCount = _pendapatanFields
        .where((f) => _value(f.$1) != 0)
        .length;

    return _buildSectionCard(
      icon: Icons.account_balance_wallet_rounded,
      title: 'Komponen Pendapatan',
      color: AppColors.success,
      summary: _currencyFormat.format(total),
      subtitle: '$activeCount/${_pendapatanFields.length} komponen bernilai',
      expanded: _tambahanExpanded,
      onToggle: () => setState(() => _tambahanExpanded = !_tambahanExpanded),
      child: Column(
        children: [
          ..._pendapatanFields.map(
            (f) => _componentRow(
              f.$1,
              f.$2,
              color: AppColors.success,
              showZero: true,
            ),
          ),
          _totalRow('Total Pendapatan', total, AppColors.success),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════
  // SECTION: RINCIAN BACKUP LIBUR (dari snapshot payroll Final)
  // ═════════════════════════════════════════════════════════
  Widget _buildBackupLiburSection() {
    final snap = _backupLibur;

    // Tidak ada insentif backup libur pada slip ini: sembunyikan rincian
    // agar tampilan tetap ringkas (baris komponen tetap tampil Rp 0).
    if (!snap.hasData) {
      return const SizedBox.shrink();
    }

    final total = snap.total;
    final expected = snap.expectedTotal;
    final isConsistent = snap.isConsistent;

    final subtitleParts = <String>[];
    if (snap.driverDays > 0) subtitleParts.add('${snap.driverDays} hari Driver');
    if (snap.helperDays > 0) subtitleParts.add('${snap.helperDays} hari Helper');
    final subtitle = subtitleParts.isEmpty
        ? 'Snapshot Final tersimpan'
        : '${subtitleParts.join(' · ')} · snapshot Final';

    return _buildSectionCard(
      icon: Icons.event_available_rounded,
      title: 'Rincian Backup Libur',
      color: AppColors.success,
      summary: _currencyFormat.format(total),
      subtitle: subtitle,
      expanded: _tambahanExpanded,
      onToggle: () => setState(() => _tambahanExpanded = !_tambahanExpanded),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _backupLiburRow(
            role: 'Driver',
            days: snap.driverDays,
            rate: snap.driverRate,
            subtotal: snap.driverSubtotal,
            icon: Icons.local_shipping_rounded,
            color: const Color(0xFF2563EB),
          ),
          _backupLiburRow(
            role: 'Helper',
            days: snap.helperDays,
            rate: snap.helperRate,
            subtotal: snap.helperSubtotal,
            icon: Icons.person_rounded,
            color: const Color(0xFF7C3AED),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 2, 14, 0),
            child: Text(
              'Dihitung per hari unik (pegawai + tanggal + role), sesuai snapshot Final.',
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w400,
                color: AppColors.textMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          if (!isConsistent)
            Container(
              margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warningBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 14,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Rincian hari × rate (${_currencyFormat.format(expected)}) berbeda dari nominal tersimpan (${_currencyFormat.format(total)}). Nominal resmi mengikuti Komponen Pendapatan di atas.',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          _totalRow('Total Backup Libur', total, AppColors.success),
        ],
      ),
    );
  }

  Widget _backupLiburRow({
    required String role,
    required int days,
    required int rate,
    required int subtotal,
    required IconData icon,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.15), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, size: 14, color: color),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    role,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$days hari × ${_currencyFormat.format(rate)}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              _currencyFormat.format(subtotal),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════
  // SECTION: POTONGAN ABSEN
  // ═════════════════════════════════════════════════════════
  Widget _buildPotonganAbsenSection() {
    final data = _absenData;
    final totalDenda = data.fold<int>(
      0,
      (s, d) => s + ((d['denda'] as int?) ?? 0),
    );

    final alphaDenda = data
        .where((d) => (d['status'] as String?)?.toLowerCase() == 'alpha')
        .fold<int>(0, (s, d) => s + ((d['denda'] as int?) ?? 0));
    final alphaCount = data
        .where((d) => (d['status'] as String?)?.toLowerCase() == 'alpha')
        .length;
    final telatDenda = data
        .where(
          (d) =>
              (d['status'] as String?)?.toLowerCase() == 'terlambat' ||
              (d['status'] as String?)?.toLowerCase() == 'telat',
        )
        .fold<int>(0, (s, d) => s + ((d['denda'] as int?) ?? 0));
    final telatCount = data
        .where(
          (d) =>
              (d['status'] as String?)?.toLowerCase() == 'terlambat' ||
              (d['status'] as String?)?.toLowerCase() == 'telat',
        )
        .length;
    final lainnyaDenda = totalDenda - alphaDenda - telatDenda;
    final lainnyaCount = data.length - alphaCount - telatCount;

    return _buildSectionCard(
      icon: Icons.remove_circle_outline_rounded,
      title: 'Detail Potongan Absen',
      color: AppColors.error,
      summary: _currencyFormat.format(totalDenda),
      subtitle:
          '$alphaCount Alpha · $telatCount Terlambat${lainnyaCount > 0 ? ' · $lainnyaCount Lainnya' : ''}',
      expanded: _absenExpanded,
      onToggle: () => setState(() => _absenExpanded = !_absenExpanded),
      child: data.isEmpty
          ? _sectionEmpty('Tidak ada potongan absen di periode ini.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                  child: Row(
                    children: [
                      _absenSummaryBadge(
                        'Alpha',
                        alphaCount,
                        alphaDenda,
                        AppColors.error,
                      ),
                      const SizedBox(width: 6),
                      _absenSummaryBadge(
                        'Terlambat',
                        telatCount,
                        telatDenda,
                        AppColors.warning,
                      ),
                      if (lainnyaCount > 0) ...[
                        const SizedBox(width: 6),
                        _absenSummaryBadge(
                          'Lainnya',
                          lainnyaCount,
                          lainnyaDenda,
                          AppColors.textMuted,
                        ),
                      ],
                    ],
                  ),
                ),
                ...data.map((item) => _absenRow(item)),
              ],
            ),
    );
  }

  Widget _absenSummaryBadge(String label, int count, int total, Color color) {
    if (count == 0) return const SizedBox.shrink();
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.15), width: 1),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color: color.withValues(alpha: 0.7),
              ),
            ),
            Text(
              _currencyFormat.format(total),
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _absenRow(Map<String, dynamic> item) {
    final tanggal = DateTime.parse(item['tanggal'] as String);
    final status = item['status'] as String? ?? '-';
    final denda = item['denda'] as int? ?? 0;
    final durasiTelat = item['durasi_telat'] as int? ?? 0;
    final catatan = item['catatan'] as String?;
    final alasanManual = item['alasan_manual'] as String?;

    final isAlpha = status.toLowerCase() == 'alpha';
    final isTelat =
        status.toLowerCase() == 'terlambat' || status.toLowerCase() == 'telat';
    final color = isAlpha
        ? AppColors.error
        : (isTelat ? AppColors.warning : AppColors.textMuted);
    final icon = isAlpha
        ? Icons.cancel_rounded
        : (isTelat ? Icons.access_alarm_rounded : Icons.error_outline_rounded);

    final ket = catatan ?? alasanManual;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.1), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, size: 14, color: color),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_shortDateFormat.format(tanggal)} · $status',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  if (isTelat && durasiTelat > 0)
                    Text(
                      'Telat $durasiTelat menit',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  if (ket != null && ket.isNotEmpty)
                    Text(
                      ket,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textMuted,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Text(
              _currencyFormat.format(denda),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════
  // SECTION: KOMPONEN POTONGAN
  // ═════════════════════════════════════════════════════════
  Widget _buildPotonganComponentsSection() {
    final total = _value('total_potongan');
    final activeCount = _potonganFields.where((f) => _value(f.$1) != 0).length;

    return _buildSectionCard(
      icon: Icons.remove_circle_outline_rounded,
      title: 'Komponen Potongan',
      color: AppColors.error,
      summary: _currencyFormat.format(total),
      subtitle: '$activeCount/${_potonganFields.length} komponen bernilai',
      expanded: _potonganExpanded,
      onToggle: () => setState(() => _potonganExpanded = !_potonganExpanded),
      child: Column(
        children: [
          ..._potonganFields.map(
            (f) => _componentRow(
              f.$1,
              f.$2,
              color: AppColors.error,
              showZero: true,
            ),
          ),
          _totalRow('Total Potongan', total, AppColors.error),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════
  // CATATAN
  // ═════════════════════════════════════════════════════════
  Widget _buildCatatanSection() {
    final catatan = _p['catatan'] as String;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.infoBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.info.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.notes_rounded, size: 16, color: AppColors.info),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Catatan',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.info,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    catatan,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvalidState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                size: 32,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Slip Tidak Tersedia',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ??
                  'Slip ini sedang dikoreksi oleh HR dan tidak dapat diakses untuk sementara.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: const Text('Kembali ke Riwayat'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AppColors.primary.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Memuat detail slip...',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════
  // SECTION CARD WRAPPER
  // ═════════════════════════════════════════════════════════
  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required Color color,
    required String summary,
    required String subtitle,
    required bool expanded,
    required VoidCallback onToggle,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Column(
          children: [
            _sectionHeader(
              icon: icon,
              title: title,
              color: color,
              summary: summary,
              subtitle: subtitle,
              expanded: expanded,
              onTap: onToggle,
            ),
            if (expanded) ...[
              const Divider(height: 1, color: AppColors.divider),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: child,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader({
    required IconData icon,
    required String title,
    required Color color,
    required String summary,
    required String subtitle,
    required bool expanded,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              summary,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 20,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionEmpty(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.textMuted,
          ),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════
  // COMPONENT ROW (for manual fields)
  // ═════════════════════════════════════════════════════════
  Widget _componentRow(
    String key,
    String label, {
    required Color color,
    bool showZero = false,
  }) {
    final val = _value(key);
    if (!showZero && val == 0) return const SizedBox.shrink();

    final keterangan = _keteranganKey[key];
    final ket = keterangan != null ? (_p[keterangan] as String?) : null;
    final hasValue = val != 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: hasValue
                        ? color.withValues(alpha: 0.8)
                        : AppColors.textDisabled,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: hasValue ? FontWeight.w600 : FontWeight.w500,
                      color: hasValue
                          ? AppColors.textPrimary
                          : AppColors.textMuted,
                    ),
                  ),
                ),
                Text(
                  _currencyFormat.format(val),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: hasValue ? FontWeight.w800 : FontWeight.w600,
                    color: hasValue ? color : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (ket != null && ket.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                ket,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textMuted,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _totalRow(String label, int value, Color color) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
          ),
          Text(
            _currencyFormat.format(value),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════
  // UTILITY
  // ═════════════════════════════════════════════════════════
  Color _parseColor(String hex) {
    final h = hex.replaceFirst('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }
}
