import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/services/schedule_service.dart';

/// Screen jadwal kerja — menampilkan kalender bulanan
/// dengan hari kerja dan hari libur karyawan.
class JadwalScreen extends StatefulWidget {
  final String employeeId;
  final String employeeName;

  const JadwalScreen({
    super.key,
    required this.employeeId,
    required this.employeeName,
  });

  @override
  State<JadwalScreen> createState() => _JadwalScreenState();
}

class _JadwalScreenState extends State<JadwalScreen> {
  List<int> _offDays = [];
  List<Map<String, dynamic>> _overrides = [];
  Map<String, int> _monthlyStats = {};
  bool _isLoading = true;

  late int _selectedMonth;
  late int _selectedYear;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final results = await Future.wait([
      ScheduleService.getOffDays(employeeId: widget.employeeId),
      ScheduleService.getLeaveOverrides(
        employeeId: widget.employeeId,
        month: _selectedMonth,
        year: _selectedYear,
      ),
    ]);

    if (mounted) {
      final offDays = results[0] as List<int>;
      final overrides = results[1] as List<Map<String, dynamic>>;
      final stats = ScheduleService.calculateMonthlySchedule(
        month: _selectedMonth,
        year: _selectedYear,
        offDays: offDays,
        overrides: overrides,
      );

      setState(() {
        _offDays = offDays;
        _overrides = overrides;
        _monthlyStats = stats;
        _isLoading = false;
      });
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth += delta;
      if (_selectedMonth > 12) {
        _selectedMonth = 1;
        _selectedYear++;
      } else if (_selectedMonth < 1) {
        _selectedMonth = 12;
        _selectedYear--;
      }
    });
    _loadData();
  }

  String get _monthLabel {
    final date = DateTime(_selectedYear, _selectedMonth);
    return DateFormat('MMMM yyyy', 'id_ID').format(date);
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
                      'Jadwal Kerja',
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
                      _ArrowButton(
                        icon: Icons.chevron_left_rounded,
                        onTap: () => _changeMonth(-1),
                      ),
                      Text(
                        _monthLabel,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      _ArrowButton(
                        icon: Icons.chevron_right_rounded,
                        onTap: () => _changeMonth(1),
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
                      icon: Icons.work_rounded,
                      label: 'Hari Kerja',
                      value: '${_monthlyStats['hariKerja'] ?? 0}',
                      color: const Color(0xFF34D399),
                    ),
                    const SizedBox(width: 8),
                    _SummaryCard(
                      icon: Icons.weekend_rounded,
                      label: 'Hari Libur',
                      value: '${_monthlyStats['hariLibur'] ?? 0}',
                      color: const Color(0xFFF87171),
                    ),
                    const SizedBox(width: 8),
                    _SummaryCard(
                      icon: Icons.calendar_month_rounded,
                      label: 'Total Hari',
                      value: '${_monthlyStats['totalHari'] ?? 0}',
                      color: const Color(0xFF60A5FA),
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

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2.5),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16, 16, 16,
        MediaQuery.of(context).viewPadding.bottom + 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hari libur mingguan
          _buildOffDaysCard(),
          const SizedBox(height: 16),
          // Kalender bulanan
          _buildCalendar(),
          const SizedBox(height: 16),
          // Legenda
          _buildLegend(),
        ],
      ),
    );
  }

  Widget _buildOffDaysCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.event_busy_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Hari Libur Mingguan',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(7, (index) {
              final isOff = _offDays.contains(index);
              return Container(
                width: 42,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isOff
                      ? AppColors.error.withValues(alpha: 0.1)
                      : AppColors.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isOff
                        ? AppColors.error.withValues(alpha: 0.3)
                        : AppColors.success.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      isOff ? Icons.close_rounded : Icons.check_rounded,
                      size: 12,
                      color: isOff ? AppColors.error : AppColors.success,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ScheduleService.dayNamesShort[index],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isOff ? AppColors.error : AppColors.success,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    final daysInMonth = DateTime(_selectedYear, _selectedMonth + 1, 0).day;
    final firstDayOfMonth = DateTime(_selectedYear, _selectedMonth, 1);
    // weekday: 1=Mon..7=Sun → convert to 0=Sun..6=Sat
    final startWeekday = firstDayOfMonth.weekday % 7;

    // Build override map
    final overrideMap = <String, String>{};
    for (final o in _overrides) {
      overrideMap[o['tanggal'] as String] = o['type'] as String;
    }

    final today = DateTime.now();
    final isCurrentMonth =
        today.month == _selectedMonth && today.year == _selectedYear;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
        children: [
          // Day headers
          Row(
            children: List.generate(7, (index) {
              final isOff = _offDays.contains(index);
              return Expanded(
                child: Center(
                  child: Text(
                    ScheduleService.dayNamesShort[index],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isOff ? AppColors.error : AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),

          // Calendar grid
          ...List.generate(_getWeekCount(daysInMonth, startWeekday), (week) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: List.generate(7, (dayIndex) {
                  final dayNumber = week * 7 + dayIndex - startWeekday + 1;

                  if (dayNumber < 1 || dayNumber > daysInMonth) {
                    return const Expanded(child: SizedBox(height: 38));
                  }

                  final date = DateTime(_selectedYear, _selectedMonth, dayNumber);
                  final dayOfWeek = date.weekday % 7;
                  final dateStr =
                      '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}-${dayNumber.toString().padLeft(2, '0')}';

                  final override = overrideMap[dateStr];
                  final bool isOff;
                  if (override == 'libur') {
                    isOff = true;
                  } else if (override == 'masuk') {
                    isOff = false;
                  } else {
                    isOff = _offDays.contains(dayOfWeek);
                  }

                  final isToday = isCurrentMonth && today.day == dayNumber;

                  return Expanded(
                    child: _CalendarDay(
                      day: dayNumber,
                      isOff: isOff,
                      isToday: isToday,
                      hasOverride: override != null,
                    ),
                  );
                }),
              ),
            );
          }),
        ],
      ),
    );
  }

  int _getWeekCount(int daysInMonth, int startWeekday) {
    return ((daysInMonth + startWeekday) / 7).ceil();
  }

  Widget _buildLegend() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _LegendItem(
            color: AppColors.success,
            label: 'Masuk',
          ),
          _LegendItem(
            color: AppColors.error,
            label: 'Libur',
          ),
          _LegendItem(
            color: AppColors.primary,
            label: 'Hari Ini',
            isBordered: true,
          ),
          _LegendItem(
            color: AppColors.warning,
            label: 'Override',
            isDotted: true,
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════
// ARROW BUTTON
// ═════════════════════════════════════════════════════════
class _ArrowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ArrowButton({required this.icon, required this.onTap});

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

// ═════════════════════════════════════════════════════════
// SUMMARY CARD
// ═════════════════════════════════════════════════════════
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

// ═════════════════════════════════════════════════════════
// CALENDAR DAY
// ═════════════════════════════════════════════════════════
class _CalendarDay extends StatelessWidget {
  final int day;
  final bool isOff;
  final bool isToday;
  final bool hasOverride;

  const _CalendarDay({
    required this.day,
    required this.isOff,
    required this.isToday,
    required this.hasOverride,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    BoxBorder? border;

    if (isToday) {
      bgColor = AppColors.primary;
      textColor = Colors.white;
      border = null;
    } else if (isOff) {
      bgColor = AppColors.error.withValues(alpha: 0.08);
      textColor = AppColors.error;
      border = hasOverride
          ? Border.all(color: AppColors.warning, width: 1.5)
          : null;
    } else {
      bgColor = AppColors.success.withValues(alpha: 0.06);
      textColor = AppColors.success;
      border = hasOverride
          ? Border.all(color: AppColors.warning, width: 1.5)
          : null;
    }

    return Container(
      height: 38,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: border,
      ),
      child: Center(
        child: Text(
          '$day',
          style: TextStyle(
            fontSize: 12,
            fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════
// LEGEND ITEM
// ═════════════════════════════════════════════════════════
class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final bool isBordered;
  final bool isDotted;

  const _LegendItem({
    required this.color,
    required this.label,
    this.isBordered = false,
    this.isDotted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: isBordered ? color : color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
            border: isDotted
                ? Border.all(color: color, width: 1.5)
                : isBordered
                    ? null
                    : Border.all(color: color.withValues(alpha: 0.3), width: 1),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
