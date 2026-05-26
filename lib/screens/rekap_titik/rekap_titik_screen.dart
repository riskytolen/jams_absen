import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/services/delivery_point_service.dart';
import '../../core/services/server_time_service.dart';

/// Screen rekap titik pengiriman s/d menampilkan data delivery points
/// per bulan dengan ringkasan dan daftar detail.
class RekapTitikScreen extends StatefulWidget {
  final String employeeId;
  final String employeeName;

  const RekapTitikScreen({
    super.key,
    required this.employeeId,
    required this.employeeName,
  });

  @override
  State<RekapTitikScreen> createState() => _RekapTitikScreenState();
}

class _RekapTitikScreenState extends State<RekapTitikScreen> {
  List<Map<String, dynamic>> _points = [];
  Map<String, dynamic> _summary = {};
  bool _isLoading = true;

  late DateTime _periodStart;
  late DateTime _periodEnd;

  final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _initPeriod();
    _loadData();
  }

  /// Hitung periode aktif berdasarkan tanggal hari ini.
  /// Periode: tanggal 8 bulan ini s/d tanggal 7 bulan depan.
  void _initPeriod() {
    final now = ServerTimeService.getEstimatedServerTime() ?? DateTime.now();
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

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final start = _formatDate(_periodStart);
    final end = _formatDate(_periodEnd);
    final results = await Future.wait([
      DeliveryPointService.getDeliveryPoints(
        employeeId: widget.employeeId,
        startDate: start,
        endDate: end,
      ),
      DeliveryPointService.getPeriodSummary(
        employeeId: widget.employeeId,
        startDate: start,
        endDate: end,
      ),
    ]);
    if (mounted) {
      setState(() {
        _points = results[0] as List<Map<String, dynamic>>;
        _summary = results[1] as Map<String, dynamic>;
        _isLoading = false;
      });
    }
  }

  void _changePeriod(int delta) {
    setState(() {
      _periodStart = DateTime(_periodStart.year, _periodStart.month + delta, 8);
      _periodEnd = DateTime(_periodStart.year, _periodStart.month + 1, 7);
    });
    _loadData();
  }

  String get _periodLabel {
    final startLabel = DateFormat('dd MMM', 'id_ID').format(_periodStart);
    final endLabel = DateFormat('dd MMM yyyy', 'id_ID').format(_periodEnd);
    return '$startLabel s/d $endLabel';
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
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
              // App bar
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
                      'Rekap Titik',
                      style: AppTextStyles.onDarkTitle.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Month selector
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _MonthArrowButton(
                        icon: Icons.chevron_left_rounded,
                        onTap: () => _changePeriod(-1),
                      ),
                      Text(
                        _periodLabel,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      _MonthArrowButton(
                        icon: Icons.chevron_right_rounded,
                        onTap: () => _changePeriod(1),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Summary cards
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    _SummaryCard(
                      icon: Icons.location_on_rounded,
                      label: 'Total Titik',
                      value: '${_summary['totalTitik'] ?? 0}',
                      color: const Color(0xFF34D399),
                    ),
                    const SizedBox(width: 8),
                    _SummaryCard(
                      icon: Icons.calendar_today_rounded,
                      label: 'Hari Kerja',
                      value: '${_summary['totalHari'] ?? 0}',
                      color: const Color(0xFF60A5FA),
                    ),
                    const SizedBox(width: 8),
                    _SummaryCard(
                      icon: Icons.trending_up_rounded,
                      label: 'Rata-rata',
                      value: '${_summary['rataPerHari'] ?? 0}/hari',
                      color: const Color(0xFFFBBF24),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Total pendapatan
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.12),
                        Colors.white.withValues(alpha: 0.06),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF34D399).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_rounded,
                          color: Color(0xFF34D399),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Pendapatan Titik',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _currencyFormat.format(_summary['totalPendapatan'] ?? 0),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
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

  /// Kelompokkan data per tanggal.
  Map<String, List<Map<String, dynamic>>> get _groupedByDate {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final point in _points) {
      final tanggal = point['tanggal'] as String;
      grouped.putIfAbsent(tanggal, () => []).add(point);
    }
    return grouped;
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2.5),
      );
    }

    if (_points.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.location_off_rounded,
                size: 28,
                color: AppColors.textMuted.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Belum ada data titik',
              style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 4),
            Text(
              'Data titik bulan ini belum tersedia',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    final grouped = _groupedByDate;
    final dates = grouped.keys.toList();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(
          16, 16, 16,
          MediaQuery.of(context).viewPadding.bottom + 16,
        ),
        itemCount: dates.length,
        itemBuilder: (_, index) {
          final dateStr = dates[index];
          final items = grouped[dateStr]!;
          return _DateGroupCard(
            dateStr: dateStr,
            items: items,
            currencyFormat: _currencyFormat,
          );
        },
      ),
    );
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// MONTH ARROW BUTTON
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
class _MonthArrowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MonthArrowButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// SUMMARY CARD
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
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
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Colors.white,
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
      ),
    );
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// DATE GROUP CARD s/d Kelompok per tanggal (expandable)
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
class _DateGroupCard extends StatefulWidget {
  final String dateStr;
  final List<Map<String, dynamic>> items;
  final NumberFormat currencyFormat;

  const _DateGroupCard({
    required this.dateStr,
    required this.items,
    required this.currencyFormat,
  });

  @override
  State<_DateGroupCard> createState() => _DateGroupCardState();
}

class _DateGroupCardState extends State<_DateGroupCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final tanggal = DateTime.parse(widget.dateStr);

    // Hitung total per hari
    int totalTitikHari = 0;
    int totalPendapatanHari = 0;
    for (final item in widget.items) {
      totalTitikHari += (item['jumlah_titik'] as int?) ?? 0;
      totalPendapatanHari += (item['total'] as int?) ?? 0;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
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
          // â”€â”€ Date Header (Tap to expand) â”€â”€
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _isExpanded = !_isExpanded);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: _isExpanded
                    ? AppColors.primary.withValues(alpha: 0.06)
                    : AppColors.primary.withValues(alpha: 0.02),
                borderRadius: _isExpanded
                    ? const BorderRadius.vertical(top: Radius.circular(16))
                    : BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('dd').format(tanggal),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.1,
                          ),
                        ),
                        Text(
                          DateFormat('MMM', 'id_ID').format(tanggal),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('EEEE', 'id_ID').format(tanggal),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(
                              Icons.grid_view_rounded,
                              size: 12,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${widget.items.length} titik',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Icon(
                              Icons.account_balance_wallet_rounded,
                              size: 12,
                              color: const Color(0xFF059669),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              widget.currencyFormat.format(totalPendapatanHari),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF059669),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Total titik badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          size: 16,
                          color: Color(0xFF059669),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$totalTitikHari',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF059669),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Expand/collapse icon
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 24,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // â”€â”€ Expandable detail â”€â”€
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              children: [
                // List items per nama titik
                ...widget.items.asMap().entries.map((entry) {
                  final index = entry.key;
                  final point = entry.value;
                  final isLast = index == widget.items.length - 1;
                  return _PointItemRow(
                    point: point,
                    currencyFormat: widget.currencyFormat,
                    showDivider: !isLast,
                  );
                }),

                // Footer s/d total pendapatan hari
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt.withValues(alpha: 0.5),
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Hari Ini',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        widget.currencyFormat.format(totalPendapatanHari),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// POINT ITEM ROW s/d Satu baris per nama titik dalam group
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
class _PointItemRow extends StatelessWidget {
  final Map<String, dynamic> point;
  final NumberFormat currencyFormat;
  final bool showDivider;

  const _PointItemRow({
    required this.point,
    required this.currencyFormat,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    final jumlahTitik = point['jumlah_titik'] as int? ?? 0;
    final total = point['total'] as int? ?? 0;
    final role = point['role'] as String? ?? '-';
    final ratePerPoint = point['rate_per_point'] as int? ?? 0;
    final catatan = point['catatan'] as String?;

    // Zone (nama titik) info
    final zone = point['delivery_zones'] as Map<String, dynamic>?;
    final zoneName = zone?['nama'] as String? ?? 'Unknown';
    final zoneColorHex = zone?['color'] as String? ?? '#3b82f6';
    final zoneColor = _hexToColor(zoneColorHex);

    // Role styling
    final bool isDriver = role == 'Driver';
    final Color roleColor = isDriver
        ? const Color(0xFF2563EB)
        : const Color(0xFF7C3AED);
    final IconData roleIcon = isDriver
        ? Icons.local_shipping_rounded
        : Icons.person_rounded;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: zoneColor.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: zoneColor.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                // Top row: Zone name + role + total
                Row(
                  children: [
                    // Zone color dot
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: zoneColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.local_shipping_rounded,
                        size: 14,
                        color: zoneColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Zone name + role badge
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            zoneName,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: roleColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(roleIcon, size: 9, color: roleColor),
                                const SizedBox(width: 2),
                                Text(
                                  role,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: roleColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Total amount
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          currencyFormat.format(total),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF059669),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$jumlahTitik titik',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Bottom row: Calculation breakdown
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calculate_outlined,
                        size: 11,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '$jumlahTitik',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          Icons.close_rounded,
                          size: 10,
                          color: AppColors.textMuted,
                        ),
                      ),
                      Text(
                        currencyFormat.format(ratePerPoint),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          '=',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                      Text(
                        currencyFormat.format(total),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                ),

                // Catatan (if any)
                if (catatan != null && catatan.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.warningBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.sticky_note_2_rounded,
                          size: 11,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            catatan,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: AppColors.warning,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Divider(
              height: 1,
              color: AppColors.border.withValues(alpha: 0.3),
            ),
          ),
      ],
    );
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }
}
