import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/services/overtime_service.dart';
import '../../core/services/server_time_service.dart';
import '../../widgets/common/app_notification.dart';

/// Screen pengajuan & riwayat lembur.
class OvertimeScreen extends StatefulWidget {
  final String employeeId;
  final String employeeName;

  const OvertimeScreen({
    super.key,
    required this.employeeId,
    required this.employeeName,
  });

  @override
  State<OvertimeScreen> createState() => _OvertimeScreenState();
}

class _OvertimeScreenState extends State<OvertimeScreen> {
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;
  Map<String, int> _summary = {
    'count': 0,
    'total_lembur': 0,
    'total_durasi_menit': 0,
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        OvertimeService.getOvertimeRequests(employeeId: widget.employeeId),
        OvertimeService.getApprovedSummary(employeeId: widget.employeeId),
      ]);
      if (!mounted) return;
      setState(() {
        _requests = results[0] as List<Map<String, dynamic>>;
        _summary = results[1] as Map<String, int>;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              onBack: () => Navigator.of(context).pop(),
              onAdd: () => _openForm(),
            ),
            _SummaryCard(summary: _summary),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _requests.isEmpty
                      ? const _EmptyState()
                      : RefreshIndicator(
                          onRefresh: _loadData,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: _requests.length,
                            itemBuilder: (_, i) => _OvertimeCard(
                              request: _requests[i],
                              onCancel: _requests[i]['status'] == 'Menunggu'
                                  ? () => _cancelRequest(_requests[i]['id'] as int)
                                  : null,
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openForm() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OvertimeForm(employeeId: widget.employeeId),
    );
    if (result == true) _loadData();
  }

  Future<void> _cancelRequest(int requestId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan Pengajuan?'),
        content: const Text('Pengajuan lembur ini akan dihapus permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Tidak'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Batalkan'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await OvertimeService.cancelOvertimeRequest(requestId);
      if (!mounted) return;
      AppNotification.show(
        context,
        type: NotificationType.success,
        title: 'Pengajuan Dibatalkan',
        message: 'Pengajuan lembur telah dihapus.',
      );
      _loadData();
    } catch (e) {
      if (!mounted) return;
      AppNotification.show(
        context,
        type: NotificationType.error,
        title: 'Gagal Membatalkan',
        message: '$e',
      );
    }
  }
}

// ═════════════════════════════════════════════════════════
// HEADER
// ═════════════════════════════════════════════════════════
class _Header extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onAdd;

  const _Header({required this.onBack, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
              const Expanded(
                child: Text(
                  'Lembur',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton.filled(
                onPressed: onAdd,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.18),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Pengajuan & riwayat lembur Anda',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
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
// SUMMARY CARD — total lembur disetujui bulan ini
// ═════════════════════════════════════════════════════════
class _SummaryCard extends StatelessWidget {
  final Map<String, int> summary;

  const _SummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final count = summary['count'] ?? 0;
    final total = summary['total_lembur'] ?? 0;
    final menit = summary['total_durasi_menit'] ?? 0;

    final formatRp = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.access_time_filled_rounded,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lembur Disetujui Bulan Ini',
                  style: AppTextStyles.label.copyWith(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  count == 0
                      ? 'Belum ada'
                      : '$count pengajuan • ${_formatDurasi(menit)}',
                  style: AppTextStyles.body.copyWith(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (total > 0)
            Text(
              formatRp.format(total),
              style: const TextStyle(
                color: AppColors.success,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }

  static String _formatDurasi(int menit) {
    if (menit <= 0) return '0 menit';
    final jam = menit ~/ 60;
    final sisa = menit % 60;
    if (jam == 0) return '$sisa menit';
    if (sisa == 0) return '$jam jam';
    return '$jam jam $sisa menit';
  }
}

// ═════════════════════════════════════════════════════════
// EMPTY STATE
// ═════════════════════════════════════════════════════════
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.access_time_rounded,
            size: 64,
            color: AppColors.textMuted.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'Belum ada pengajuan lembur',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap tombol + di atas untuk ajukan',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════
// REQUEST CARD
// ═════════════════════════════════════════════════════════
class _OvertimeCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final VoidCallback? onCancel;

  const _OvertimeCard({required this.request, this.onCancel});

  @override
  Widget build(BuildContext context) {
    final status = request['status'] as String? ?? 'Menunggu';
    final tanggal = request['tanggal'] as String? ?? '';
    final jamMulai = (request['jam_mulai'] as String? ?? '00:00').substring(0, 5);
    final jamSelesai = (request['jam_selesai'] as String? ?? '00:00').substring(0, 5);
    final durasi = request['durasi_menit'] as int? ?? 0;
    final total = request['total_lembur'] as int? ?? 0;
    final alasan = request['alasan'] as String?;
    final catatan = request['catatan_approval'] as String?;

    final statusColor = _statusColor(status);

    final tanggalDt = DateTime.tryParse(tanggal);
    final tanggalLabel = tanggalDt != null
        ? DateFormat('EEEE, d MMM yyyy', 'id_ID').format(tanggalDt)
        : tanggal;

    final formatRp = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  tanggalLabel,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 10,
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.access_time_rounded,
                        size: 13, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      '$jamMulai – $jamSelesai',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatDurasi(durasi),
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              if (status == 'Disetujui' && total > 0)
                Text(
                  formatRp.format(total),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          if (alasan != null && alasan.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                alasan,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
          if (catatan != null && catatan.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.message_rounded,
                    size: 14, color: statusColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    catatan,
                    style: TextStyle(
                      fontSize: 11,
                      color: statusColor,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (onCancel != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onCancel,
                icon: Icon(Icons.delete_outline_rounded,
                    size: 16, color: AppColors.error),
                label: Text(
                  'Batalkan',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Disetujui':
        return AppColors.success;
      case 'Ditolak':
        return AppColors.error;
      case 'Menunggu':
      default:
        return const Color(0xFFF59E0B);
    }
  }

  static String _formatDurasi(int menit) {
    if (menit <= 0) return '0 menit';
    final jam = menit ~/ 60;
    final sisa = menit % 60;
    if (jam == 0) return '$sisa menit';
    if (sisa == 0) return '$jam jam';
    return '$jam jam $sisa menit';
  }
}

// ═════════════════════════════════════════════════════════
// FORM — bottom sheet pengajuan baru
// ═════════════════════════════════════════════════════════
class _OvertimeForm extends StatefulWidget {
  final String employeeId;

  const _OvertimeForm({required this.employeeId});

  @override
  State<_OvertimeForm> createState() => _OvertimeFormState();
}

class _OvertimeFormState extends State<_OvertimeForm> {
  DateTime? _tanggal;
  TimeOfDay? _jamMulai;
  TimeOfDay? _jamSelesai;
  final _alasanCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tanggal = ServerTimeService.getEstimatedServerTime() ?? DateTime.now();
  }

  @override
  void dispose() {
    _alasanCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTanggal() async {
    final now = ServerTimeService.getEstimatedServerTime() ?? DateTime.now();
    // Boleh retroaktif maks 30 hari ke belakang
    final picked = await showDatePicker(
      context: context,
      initialDate: _tanggal ?? now,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) setState(() => _tanggal = picked);
  }

  Future<void> _pickJam({required bool isMulai}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isMulai
          ? (_jamMulai ?? const TimeOfDay(hour: 17, minute: 0))
          : (_jamSelesai ?? const TimeOfDay(hour: 19, minute: 0)),
    );
    if (picked != null) {
      setState(() {
        if (isMulai) {
          _jamMulai = picked;
        } else {
          _jamSelesai = picked;
        }
      });
    }
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  int _diffMinutes(TimeOfDay a, TimeOfDay b) {
    return (b.hour * 60 + b.minute) - (a.hour * 60 + a.minute);
  }

  Future<void> _submit() async {
    if (_tanggal == null) {
      _showError('Pilih tanggal lembur');
      return;
    }
    if (_jamMulai == null || _jamSelesai == null) {
      _showError('Lengkapi jam mulai dan selesai');
      return;
    }
    final menit = _diffMinutes(_jamMulai!, _jamSelesai!);
    if (menit <= 0) {
      _showError('Jam selesai harus setelah jam mulai');
      return;
    }

    setState(() => _saving = true);
    try {
      await OvertimeService.submitOvertimeRequest(
        employeeId: widget.employeeId,
        tanggal: _tanggal!,
        jamMulai: _formatTime(_jamMulai!),
        jamSelesai: _formatTime(_jamSelesai!),
        alasan: _alasanCtrl.text.trim().isEmpty ? null : _alasanCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      AppNotification.show(
        context,
        type: NotificationType.success,
        title: 'Pengajuan Terkirim',
        message: 'Menunggu persetujuan admin.',
      );
    } catch (e) {
      if (!mounted) return;
      _showError('$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String msg) {
    AppNotification.show(
      context,
      type: NotificationType.warning,
      title: 'Lengkapi Data',
      message: msg,
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final safeBottom = MediaQuery.of(context).viewPadding.bottom;
    final menit = (_jamMulai != null && _jamSelesai != null)
        ? _diffMinutes(_jamMulai!, _jamSelesai!)
        : 0;

    return Padding(
      // Saat keyboard terbuka, pakai keyboardInset.
      // Saat keyboard tertutup, pakai safeBottom (gesture bar HP).
      padding: EdgeInsets.only(bottom: keyboardInset > 0 ? keyboardInset : safeBottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.access_time_filled_rounded,
                        color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Ajukan Lembur',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tanggal
                  Text('Tanggal Lembur',
                      style: AppTextStyles.label.copyWith(fontSize: 12)),
                  const SizedBox(height: 8),
                  _PickerField(
                    icon: Icons.calendar_today_rounded,
                    text: _tanggal != null
                        ? DateFormat('EEEE, d MMM yyyy', 'id_ID').format(_tanggal!)
                        : 'Pilih tanggal',
                    onTap: _pickTanggal,
                  ),
                  const SizedBox(height: 16),

                  // Jam mulai & selesai
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Jam Mulai',
                                style: AppTextStyles.label.copyWith(fontSize: 12)),
                            const SizedBox(height: 8),
                            _PickerField(
                              icon: Icons.login_rounded,
                              text: _jamMulai != null
                                  ? _formatTime(_jamMulai!)
                                  : '--:--',
                              onTap: () => _pickJam(isMulai: true),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Jam Selesai',
                                style: AppTextStyles.label.copyWith(fontSize: 12)),
                            const SizedBox(height: 8),
                            _PickerField(
                              icon: Icons.logout_rounded,
                              text: _jamSelesai != null
                                  ? _formatTime(_jamSelesai!)
                                  : '--:--',
                              onTap: () => _pickJam(isMulai: false),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  if (menit > 0) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.18),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.timer_rounded,
                              size: 14, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(
                            'Total ${_formatDurasi(menit)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Alasan
                  Text('Alasan (opsional)',
                      style: AppTextStyles.label.copyWith(fontSize: 12)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _alasanCtrl,
                    maxLines: 3,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Jelaskan keperluan lembur...',
                      hintStyle: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                      filled: true,
                      fillColor: AppColors.surfaceAlt,
                      contentPadding: const EdgeInsets.all(14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: AppColors.border, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Submit
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _submit,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send_rounded, size: 18),
                      label: Text(_saving ? 'Mengirim...' : 'Ajukan'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
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

  static String _formatDurasi(int menit) {
    if (menit <= 0) return '0 menit';
    final jam = menit ~/ 60;
    final sisa = menit % 60;
    if (jam == 0) return '$sisa menit';
    if (sisa == 0) return '$jam jam';
    return '$jam jam $sisa menit';
  }
}

class _PickerField extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  const _PickerField({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
