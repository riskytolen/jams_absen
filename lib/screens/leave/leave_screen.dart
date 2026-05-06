import 'dart:io';

import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/services/leave_service.dart';
import '../../widgets/common/app_notification.dart';

/// Screen pengajuan & riwayat cuti/izin/sakit.
class LeaveScreen extends StatefulWidget {
  final String employeeId;
  final String employeeName;

  const LeaveScreen({
    super.key,
    required this.employeeId,
    required this.employeeName,
  });

  @override
  State<LeaveScreen> createState() => _LeaveScreenState();
}

class _LeaveScreenState extends State<LeaveScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;
  Map<String, int> _leaveBalance = {
    'quota': 12,
    'used': 0,
    'pending': 0,
    'remaining': 12,
  };

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      LeaveService.getLeaveRequests(employeeId: widget.employeeId),
      LeaveService.getLeaveBalance(employeeId: widget.employeeId),
    ]);
    if (mounted) {
      setState(() {
        _requests = results[0] as List<Map<String, dynamic>>;
        _leaveBalance = results[1] as Map<String, int>;
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _filteredByTab(int tabIndex) {
    switch (tabIndex) {
      case 0:
        return _requests; // Semua
      case 1:
        return _requests.where((r) => r['status'] == 'Menunggu').toList();
      case 2:
        return _requests.where((r) =>
            r['status'] == 'Disetujui' || r['status'] == 'Ditolak').toList();
      default:
        return _requests;
    }
  }

  void _openForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LeaveFormSheet(
        employeeId: widget.employeeId,
        onSubmitted: () {
          _loadData();
          if (mounted) {
            AppNotification.show(
              context,
              type: NotificationType.success,
              title: 'Berhasil',
              message: 'Permohonan berhasil diajukan',
            );
          }
        },
      ),
    );
  }

  Future<void> _cancelRequest(int id) async {
    try {
      await LeaveService.cancelLeaveRequest(id);
      _loadData();
      if (mounted) {
        AppNotification.show(
          context,
          type: NotificationType.success,
          title: 'Dibatalkan',
          message: 'Permohonan berhasil dibatalkan',
        );
      }
    } on LeaveException catch (e) {
      if (mounted) {
        AppNotification.show(
          context,
          type: NotificationType.error,
          title: 'Gagal',
          message: e.message,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.background,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _openForm,
          backgroundColor: AppColors.primary,
          icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
          label: Text(
            'Ajukan',
            style: AppTextStyles.button.copyWith(fontSize: 13),
          ),
          elevation: 4,
        ),
        body: Column(
          children: [
            _buildHeader(),
            _buildTabs(),
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
          padding: const EdgeInsets.fromLTRB(4, 4, 16, 18),
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
                      'Cuti & Izin',
                      style: AppTextStyles.onDarkTitle.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Summary cards — data real dari database
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    _SummaryCard(
                      icon: Icons.beach_access_rounded,
                      label: 'Sisa Cuti',
                      value: '${_leaveBalance['remaining']}/${_leaveBalance['quota']}',
                      color: const Color(0xFF34D399),
                    ),
                    const SizedBox(width: 10),
                    _SummaryCard(
                      icon: Icons.hourglass_top_rounded,
                      label: 'Pending',
                      value: '${_leaveBalance['pending']} hari',
                      color: const Color(0xFFFBBF24),
                    ),
                    const SizedBox(width: 10),
                    _SummaryCard(
                      icon: Icons.event_available_rounded,
                      label: 'Terpakai',
                      value: '${_leaveBalance['used']} hari',
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

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
      ),
      child: TabBar(
        controller: _tabCtrl,
        onTap: (_) => setState(() {}),
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        indicator: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerHeight: 0,
        padding: const EdgeInsets.all(3),
        tabs: const [
          Tab(text: 'Semua', height: 34),
          Tab(text: 'Menunggu', height: 34),
          Tab(text: 'Selesai', height: 34),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2.5),
      );
    }

    final filtered = _filteredByTab(_tabCtrl.index);

    if (filtered.isEmpty) {
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
                Icons.inbox_rounded,
                size: 28,
                color: AppColors.textMuted.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Belum ada permohonan',
              style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(
          16, 12, 16,
          MediaQuery.of(context).viewPadding.bottom + 80,
        ),
        itemCount: filtered.length,
        itemBuilder: (_, index) => _LeaveCard(
          request: filtered[index],
          onCancel: () => _cancelRequest(filtered[index]['id'] as int),
        ),
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
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
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
              style: TextStyle(
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
// LEAVE CARD — With progress timeline
// ═════════════════════════════════════════════════════════
class _LeaveCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final VoidCallback onCancel;

  const _LeaveCard({required this.request, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final jenis = request['jenis'] as String;
    final status = request['status'] as String;
    final tanggalMulai = DateTime.parse(request['tanggal_mulai'] as String);
    final tanggalSelesai = DateTime.parse(request['tanggal_selesai'] as String);
    final alasan = request['alasan'] as String?;
    final createdAt = DateTime.parse(request['created_at'] as String);
    final approvedAt = request['approved_at'] != null
        ? DateTime.parse(request['approved_at'] as String)
        : null;
    final durasi = tanggalSelesai.difference(tanggalMulai).inDays + 1;

    final IconData jenisIcon;
    final Color jenisColor;

    switch (jenis) {
      case 'Cuti':
        jenisIcon = Icons.beach_access_rounded;
        jenisColor = const Color(0xFF0891B2);
        break;
      case 'Sakit':
        jenisIcon = Icons.local_hospital_rounded;
        jenisColor = const Color(0xFFDC2626);
        break;
      case 'Izin':
        jenisIcon = Icons.mail_rounded;
        jenisColor = const Color(0xFFD97706);
        break;
      default:
        jenisIcon = Icons.event_note_rounded;
        jenisColor = AppColors.textMuted;
    }

    final dateRange =
        '${DateFormat('dd MMM', 'id_ID').format(tanggalMulai)} - ${DateFormat('dd MMM yyyy', 'id_ID').format(tanggalSelesai)}';

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
        children: [
          // ── Header: Jenis + info + cancel ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: jenisColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(jenisIcon, color: jenisColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        jenis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$dateRange ($durasi hari)',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (status == 'Menunggu')
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _showCancelDialog(context);
                    },
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFFDC2626),
                        size: 16,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Alasan ──
          if (alasan != null && alasan.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.format_quote_rounded,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        alasan,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Progress Timeline ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt.withValues(alpha: 0.4),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(16),
              ),
            ),
            child: _ProgressTimeline(
              status: status,
              createdAt: createdAt,
              approvedAt: approvedAt,
            ),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Batalkan Permohonan?'),
        content: const Text('Permohonan yang dibatalkan tidak dapat dikembalikan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Tidak'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              onCancel();
            },
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
            child: const Text('Ya, Batalkan'),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════
// PROGRESS TIMELINE — Diajukan → Menunggu → Hasil
// ═════════════════════════════════════════════════════════
class _ProgressTimeline extends StatelessWidget {
  final String status;
  final DateTime createdAt;
  final DateTime? approvedAt;

  const _ProgressTimeline({
    required this.status,
    required this.createdAt,
    this.approvedAt,
  });

  @override
  Widget build(BuildContext context) {
    // Determine step states
    // Step 1: Diajukan (always completed)
    // Step 2: Menunggu (completed if status != Menunggu, active if Menunggu)
    // Step 3: Disetujui/Ditolak (completed if final, inactive if Menunggu)

    final bool step1Done = true;
    final bool step2Active = status == 'Menunggu';
    final bool step2Done = status == 'Disetujui' || status == 'Ditolak';
    final bool step3Done = status == 'Disetujui' || status == 'Ditolak';

    final String step3Label;
    final Color step3Color;
    final IconData step3Icon;

    if (status == 'Disetujui') {
      step3Label = 'Disetujui';
      step3Color = const Color(0xFF059669);
      step3Icon = Icons.check_circle_rounded;
    } else if (status == 'Ditolak') {
      step3Label = 'Ditolak';
      step3Color = const Color(0xFFDC2626);
      step3Icon = Icons.cancel_rounded;
    } else {
      step3Label = 'Keputusan';
      step3Color = AppColors.textMuted;
      step3Icon = Icons.help_outline_rounded;
    }

    return Row(
      children: [
        // Step 1: Diajukan
        _TimelineStep(
          icon: Icons.send_rounded,
          label: 'Diajukan',
          subtitle: DateFormat('dd/MM', 'id_ID').format(createdAt),
          color: const Color(0xFF2563EB),
          isCompleted: step1Done,
          isActive: false,
        ),

        // Connector 1→2
        Expanded(
          child: _TimelineConnector(
            isCompleted: step2Done || step2Active,
            isActive: step2Active,
          ),
        ),

        // Step 2: Menunggu
        _TimelineStep(
          icon: Icons.hourglass_top_rounded,
          label: 'Diproses',
          subtitle: step2Active ? 'Menunggu' : (step2Done ? 'Selesai' : '-'),
          color: const Color(0xFFD97706),
          isCompleted: step2Done,
          isActive: step2Active,
        ),

        // Connector 2→3
        Expanded(
          child: _TimelineConnector(
            isCompleted: step3Done,
            isActive: false,
          ),
        ),

        // Step 3: Hasil
        _TimelineStep(
          icon: step3Icon,
          label: step3Label,
          subtitle: approvedAt != null
              ? DateFormat('dd/MM', 'id_ID').format(approvedAt!)
              : '-',
          color: step3Color,
          isCompleted: step3Done,
          isActive: false,
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════
// TIMELINE STEP — Single dot/step
// ═════════════════════════════════════════════════════════
class _TimelineStep extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final bool isCompleted;
  final bool isActive;

  const _TimelineStep({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.isCompleted,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDone = isCompleted || isActive;
    final Color dotColor = isDone ? color : AppColors.textMuted.withValues(alpha: 0.3);
    final Color textColor = isDone ? color : AppColors.textMuted;

    return Column(
      children: [
        // Dot with icon
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isDone ? dotColor.withValues(alpha: 0.12) : AppColors.surfaceAlt,
            shape: BoxShape.circle,
            border: Border.all(
              color: isDone ? dotColor : AppColors.border,
              width: isActive ? 2 : 1.5,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: dotColor.withValues(alpha: 0.25),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            size: 14,
            color: isDone ? dotColor : AppColors.textMuted.withValues(alpha: 0.4),
          ),
        ),
        const SizedBox(height: 5),
        // Label
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isDone ? FontWeight.w700 : FontWeight.w500,
            color: textColor,
          ),
        ),
        // Subtitle (date)
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w500,
            color: textColor.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════
// TIMELINE CONNECTOR — Line between steps
// ═════════════════════════════════════════════════════════
class _TimelineConnector extends StatelessWidget {
  final bool isCompleted;
  final bool isActive;

  const _TimelineConnector({
    required this.isCompleted,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(1),
          color: isCompleted
              ? const Color(0xFF059669).withValues(alpha: 0.4)
              : isActive
                  ? const Color(0xFFD97706).withValues(alpha: 0.4)
                  : AppColors.border,
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════
// LEAVE FORM SHEET — Bottom sheet for new request
// ═════════════════════════════════════════════════════════
class _LeaveFormSheet extends StatefulWidget {
  final String employeeId;
  final VoidCallback onSubmitted;

  const _LeaveFormSheet({
    required this.employeeId,
    required this.onSubmitted,
  });

  @override
  State<_LeaveFormSheet> createState() => _LeaveFormSheetState();
}

class _LeaveFormSheetState extends State<_LeaveFormSheet> {
  String _selectedJenis = 'Izin';
  DateTime? _tanggalMulai;
  DateTime? _tanggalSelesai;
  final _alasanCtrl = TextEditingController();
  bool _isSubmitting = false;
  String? _lampiranPath;
  String? _lampiranName;

  bool get _requiresAttachment =>
      _selectedJenis == 'Izin' || _selectedJenis == 'Sakit';

  @override
  void dispose() {
    _alasanCtrl.dispose();
    super.dispose();
  }

  void _removeAttachment() {
    setState(() {
      _lampiranPath = null;
      _lampiranName = null;
    });
  }

  Future<void> _pickAttachment() async {
    // Gunakan image_picker untuk ambil foto bukti
    try {
      final picker = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewPadding.bottom + 12,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text('Pilih Sumber', style: AppTextStyles.h4),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.camera_alt_rounded,
                      color: AppColors.primary, size: 20),
                ),
                title: const Text('Kamera'),
                subtitle: const Text('Ambil foto langsung'),
                onTap: () => Navigator.pop(context, 'camera'),
              ),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.photo_library_rounded,
                      color: AppColors.primary, size: 20),
                ),
                title: const Text('Galeri'),
                subtitle: const Text('Pilih dari galeri foto'),
                onTap: () => Navigator.pop(context, 'gallery'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );

      if (picker == null || !mounted) return;

      final imagePicker = ImagePicker();
      final XFile? file = await imagePicker.pickImage(
        source: picker == 'camera' ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1600,
      );

      if (file == null || !mounted) return;

      // Kompres file agar maksimal 500KB
      final compressed = await _compressTo500KB(file.path);

      if (compressed != null && mounted) {
        setState(() {
          _lampiranPath = compressed;
          _lampiranName = file.name;
        });
      }
    } catch (e) {
      debugPrint('[LeaveForm] Pick attachment error: $e');
    }
  }

  /// Kompres gambar secara bertahap hingga <= 500KB.
  Future<String?> _compressTo500KB(String sourcePath) async {
    const int maxBytes = 500 * 1024; // 500KB

    // Cek ukuran asli
    final originalFile = File(sourcePath);
    final originalSize = await originalFile.length();

    // Jika sudah <= 500KB, langsung return
    if (originalSize <= maxBytes) return sourcePath;

    // Hitung quality awal berdasarkan rasio
    int quality = ((maxBytes / originalSize) * 100).clamp(20, 85).toInt();

    final targetPath =
        '${Directory.systemTemp.path}/leave_compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';

    // Kompres bertahap — turunkan quality sampai <= 500KB
    for (int attempt = 0; attempt < 5; attempt++) {
      final result = await FlutterImageCompress.compressAndGetFile(
        sourcePath,
        targetPath,
        quality: quality,
        minWidth: 1024,
        minHeight: 1024,
        format: CompressFormat.jpeg,
      );

      if (result == null) return sourcePath; // Fallback ke original

      final compressedSize = await result.length();

      if (compressedSize <= maxBytes) {
        debugPrint(
          '[LeaveForm] Compressed: ${(originalSize / 1024).toStringAsFixed(0)}KB '
          '→ ${(compressedSize / 1024).toStringAsFixed(0)}KB (q=$quality)',
        );
        return result.path;
      }

      // Turunkan quality untuk attempt berikutnya
      quality = (quality * 0.7).toInt().clamp(15, 80);
    }

    // Jika masih > 500KB setelah 5 attempt, return hasil terakhir
    return targetPath;
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart
          ? (_tanggalMulai ?? now)
          : (_tanggalSelesai ?? _tanggalMulai ?? now),
      firstDate: now,
      lastDate: DateTime(now.year + 1),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _tanggalMulai = picked;
          if (_tanggalSelesai != null && _tanggalSelesai!.isBefore(picked)) {
            _tanggalSelesai = picked;
          }
        } else {
          _tanggalSelesai = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    DateTime? finalMulai = _tanggalMulai;
    DateTime? finalSelesai = _tanggalSelesai;

    if (_selectedJenis == 'Sakit') {
      final now = DateTime.now();
      finalMulai = now;
      finalSelesai = now;
    }

    if (finalMulai == null || finalSelesai == null) {
      AppNotification.show(
        context,
        type: NotificationType.warning,
        title: 'Lengkapi Data',
        message: 'Pilih tanggal mulai dan selesai',
      );
      return;
    }

    // Validasi: Izin & Sakit wajib lampiran bukti
    if (_requiresAttachment && _lampiranPath == null) {
      AppNotification.show(
        context,
        type: NotificationType.warning,
        title: 'Bukti Diperlukan',
        message: _selectedJenis == 'Sakit'
            ? 'Lampirkan surat dokter atau bukti sakit'
            : 'Lampirkan bukti pendukung izin',
      );
      return;
    }

    // Validasi: Alasan wajib untuk Izin & Sakit
    if (_requiresAttachment && _alasanCtrl.text.trim().isEmpty) {
      AppNotification.show(
        context,
        type: NotificationType.warning,
        title: 'Alasan Diperlukan',
        message: 'Tulis alasan permohonan $_selectedJenis',
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Upload lampiran jika ada
      String? lampiranUrl;
      if (_lampiranPath != null) {
        lampiranUrl = await LeaveService.uploadAttachment(
          employeeId: widget.employeeId,
          filePath: _lampiranPath!,
        );
      }

      await LeaveService.submitLeaveRequest(
        employeeId: widget.employeeId,
        jenis: _selectedJenis,
        tanggalMulai: finalMulai,
        tanggalSelesai: finalSelesai,
        alasan: _alasanCtrl.text.trim().isEmpty ? null : _alasanCtrl.text.trim(),
        lampiranUrl: lampiranUrl,
      );
      if (mounted) {
        Navigator.of(context).pop();
        widget.onSubmitted();
      }
    } on LeaveException catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        AppNotification.show(
          context,
          type: NotificationType.error,
          title: 'Gagal',
          message: e.message,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final safePadding = MediaQuery.of(context).viewPadding.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomPadding > 0 ? bottomPadding : safePadding + 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Ajukan Permohonan',
                    style: AppTextStyles.h3.copyWith(fontSize: 16),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Jenis selector
              Text('Jenis', style: AppTextStyles.label.copyWith(fontSize: 12)),
              const SizedBox(height: 8),
              Row(
                children: [
                  {'label': 'Izin', 'icon': Icons.mail_rounded},
                  {'label': 'Sakit', 'icon': Icons.local_hospital_rounded},
                  {'label': 'Cuti', 'icon': Icons.beach_access_rounded},
                ].map((item) {
                  final jenis = item['label'] as String;
                  final icon = item['icon'] as IconData;
                  final isSelected = _selectedJenis == jenis;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedJenis = jenis),
                      child: Container(
                        margin: EdgeInsets.only(
                          right: jenis != 'Cuti' ? 8 : 0,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.border,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              icon,
                              size: 16,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              jenis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),

              // Date pickers (Sembunyikan jika 'Sakit')
              if (_selectedJenis != 'Sakit') ...[
                Row(
                  children: [
                    Expanded(
                      child: _DateField(
                        label: 'Mulai',
                        date: _tanggalMulai,
                        onTap: () => _pickDate(isStart: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DateField(
                        label: 'Selesai',
                        date: _tanggalSelesai,
                        onTap: () => _pickDate(isStart: false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFDC2626).withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: Color(0xFFDC2626),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Pengajuan sakit berlaku untuk 1 hari (hari ini). Jika besok masih sakit, harap ajukan kembali.',
                          style: TextStyle(
                            fontSize: 12,
                            color: const Color(0xFFDC2626),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
              ],

              // Alasan
              Text(
                _requiresAttachment ? 'Alasan *' : 'Alasan (opsional)',
                style: AppTextStyles.label.copyWith(fontSize: 12),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _alasanCtrl,
                maxLines: 3,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                ),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.edit_note_rounded, size: 20, color: AppColors.textMuted),
                  hintText: _selectedJenis == 'Sakit'
                      ? 'Jelaskan keluhan / diagnosa...'
                      : 'Tulis alasan permohonan...',
                  hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  filled: true,
                  fillColor: AppColors.surfaceAlt,
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border, width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Lampiran bukti (hanya untuk Izin & Sakit)
              if (_requiresAttachment) ...[
                Row(
                  children: [
                    Text(
                      'Bukti Lampiran *',
                      style: AppTextStyles.label.copyWith(fontSize: 12),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Wajib',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _pickAttachment,
                  child: _lampiranPath != null
                      ? Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border, width: 1),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(_lampiranPath!),
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _lampiranName ?? 'Foto bukti',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textDark,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Tap untuk mengganti file',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: _removeAttachment,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.errorBg,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: AppColors.error,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : DottedBorder(
                          options: RoundedRectDottedBorderOptions(
                            radius: const Radius.circular(12),
                            color: AppColors.primary,
                            strokeWidth: 1.5,
                            dashPattern: const [6, 4],
                            padding: const EdgeInsets.all(16),
                          ),
                          child: SizedBox(
                            width: double.infinity,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary50,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.cloud_upload_rounded,
                                    color: AppColors.primary,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _selectedJenis == 'Sakit'
                                      ? 'Tap untuk upload surat dokter / bukti'
                                      : 'Tap untuk upload bukti pendukung',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Maks 500KB (JPG/PNG)',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 18),
              ],
              const SizedBox(height: 6),

              // Submit button
              Container(
                width: double.infinity,
                height: 48,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isSubmitting ? null : _submit,
                    borderRadius: BorderRadius.circular(12),
                    child: Center(
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Ajukan Permohonan',
                              style: AppTextStyles.button.copyWith(
                                fontSize: 14,
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════
// DATE FIELD
// ═════════════════════════════════════════════════════════
class _DateField extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;

  const _DateField({
    required this.label,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label.copyWith(fontSize: 12)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 16,
                  color: date != null ? AppColors.primary : AppColors.textMuted,
                ),
                const SizedBox(width: 8),
                Text(
                  date != null
                      ? DateFormat('dd MMM yyyy', 'id_ID').format(date!)
                      : 'Pilih tanggal',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: date != null
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
