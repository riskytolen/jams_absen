import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/services/document_service.dart';

/// Screen dokumen legal — menampilkan PKWT & Surat Peringatan.
class DokumenScreen extends StatefulWidget {
  final String employeeId;
  final String employeeName;

  const DokumenScreen({
    super.key,
    required this.employeeId,
    required this.employeeName,
  });

  @override
  State<DokumenScreen> createState() => _DokumenScreenState();
}

class _DokumenScreenState extends State<DokumenScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  List<Map<String, dynamic>> _documents = [];
  Map<String, int> _summary = {};
  bool _isLoading = true;

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
      DocumentService.getDocuments(employeeId: widget.employeeId),
      DocumentService.getDocumentSummary(employeeId: widget.employeeId),
    ]);
    if (mounted) {
      setState(() {
        _documents = results[0] as List<Map<String, dynamic>>;
        _summary = results[1] as Map<String, int>;
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _filteredByTab(int tabIndex) {
    switch (tabIndex) {
      case 0:
        return _documents;
      case 1:
        return _documents.where((d) => d['kategori'] == 'PKWT').toList();
      case 2:
        return _documents.where((d) => d['kategori'] == 'SP').toList();
      default:
        return _documents;
    }
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
                      'Dokumen',
                      style: AppTextStyles.onDarkTitle.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Summary cards
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    _SummaryCard(
                      icon: Icons.description_rounded,
                      label: 'Kontrak',
                      value: '${_summary['totalPKWT'] ?? 0}',
                      color: const Color(0xFF60A5FA),
                    ),
                    const SizedBox(width: 8),
                    _SummaryCard(
                      icon: Icons.warning_amber_rounded,
                      label: 'SP',
                      value: '${_summary['totalSP'] ?? 0}',
                      color: const Color(0xFFF87171),
                    ),
                    const SizedBox(width: 8),
                    _SummaryCard(
                      icon: Icons.verified_rounded,
                      label: 'Aktif',
                      value: '${_summary['aktif'] ?? 0}',
                      color: const Color(0xFF34D399),
                    ),
                    const SizedBox(width: 8),
                    _SummaryCard(
                      icon: Icons.timer_rounded,
                      label: 'Segera',
                      value: '${_summary['segeraBerakhir'] ?? 0}',
                      color: const Color(0xFFFBBF24),
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
        unselectedLabelStyle:
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        indicator: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerHeight: 0,
        padding: const EdgeInsets.all(3),
        tabs: const [
          Tab(text: 'Semua', height: 34),
          Tab(text: 'Kontrak', height: 34),
          Tab(text: 'SP', height: 34),
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
                Icons.folder_off_rounded,
                size: 28,
                color: AppColors.textMuted.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Belum ada dokumen',
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
          MediaQuery.of(context).viewPadding.bottom + 16,
        ),
        itemCount: filtered.length,
        itemBuilder: (_, index) => _DocumentCard(doc: filtered[index]),
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
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
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
            Icon(icon, color: color, size: 18),
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
                fontSize: 9,
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
// DOCUMENT CARD
// ═════════════════════════════════════════════════════════
class _DocumentCard extends StatelessWidget {
  final Map<String, dynamic> doc;

  const _DocumentCard({required this.doc});

  @override
  Widget build(BuildContext context) {
    final kategori = doc['kategori'] as String;
    final status = doc['status'] as String;
    final nomorKontrak = doc['nomor_kontrak'] as String?;
    final kontrakKe = doc['kontrak_ke'] as int?;
    final tingkatSp = doc['tingkat_sp'] as String?;
    final pelanggaran = doc['pelanggaran'] as String?;
    final tanggalTerbit = DateTime.parse(doc['tanggal_terbit'] as String);
    final tanggalBerakhir = doc['tanggal_berakhir'] != null
        ? DateTime.parse(doc['tanggal_berakhir'] as String)
        : null;
    final catatan = doc['catatan'] as String?;
    final lampiranUrl = doc['lampiran_url'] as String?;

    final bool isPKWT = kategori == 'PKWT';

    // Kategori styling
    final Color kategoriColor;
    final IconData kategoriIcon;
    final String kategoriLabel;

    if (isPKWT) {
      kategoriColor = const Color(0xFF2563EB);
      kategoriIcon = Icons.description_rounded;
      kategoriLabel = kontrakKe != null ? 'PKWT ke-$kontrakKe' : 'PKWT';
    } else {
      kategoriColor = const Color(0xFFDC2626);
      kategoriIcon = Icons.warning_rounded;
      kategoriLabel = tingkatSp ?? 'SP';
    }

    // Status styling
    final Color statusColor;
    final IconData statusIcon;

    switch (status) {
      case 'Aktif':
        statusColor = const Color(0xFF059669);
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'Segera Berakhir':
        statusColor = const Color(0xFFD97706);
        statusIcon = Icons.timer_rounded;
        break;
      case 'Berakhir':
        statusColor = AppColors.textMuted;
        statusIcon = Icons.cancel_rounded;
        break;
      default:
        statusColor = AppColors.textMuted;
        statusIcon = Icons.circle_outlined;
    }

    // Hitung sisa hari
    String? sisaHari;
    if (tanggalBerakhir != null) {
      final diff = tanggalBerakhir.difference(DateTime.now()).inDays;
      if (diff > 0 && status != 'Berakhir') {
        sisaHari = '$diff hari lagi';
      } else if (diff <= 0) {
        sisaHari = 'Sudah berakhir';
      }
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
        children: [
          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                // Kategori icon
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: kategoriColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(kategoriIcon, color: kategoriColor, size: 20),
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            kategoriLabel,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Status badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color: statusColor.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(statusIcon, size: 10, color: statusColor),
                                const SizedBox(width: 3),
                                Text(
                                  status,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: statusColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      if (nomorKontrak != null && nomorKontrak.isNotEmpty)
                        Text(
                          'No. $nomorKontrak',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Detail rows ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  // Tanggal terbit
                  _DetailRow(
                    icon: Icons.event_rounded,
                    label: 'Terbit',
                    value: DateFormat('dd MMMM yyyy', 'id_ID')
                        .format(tanggalTerbit),
                  ),
                  // Tanggal berakhir
                  if (tanggalBerakhir != null) ...[
                    const SizedBox(height: 6),
                    _DetailRow(
                      icon: Icons.event_busy_rounded,
                      label: 'Berakhir',
                      value: DateFormat('dd MMMM yyyy', 'id_ID')
                          .format(tanggalBerakhir),
                      valueColor: status == 'Segera Berakhir'
                          ? const Color(0xFFD97706)
                          : null,
                    ),
                  ],
                  // Sisa hari
                  if (sisaHari != null) ...[
                    const SizedBox(height: 6),
                    _DetailRow(
                      icon: Icons.hourglass_bottom_rounded,
                      label: 'Sisa',
                      value: sisaHari,
                      valueColor: status == 'Segera Berakhir'
                          ? const Color(0xFFD97706)
                          : status == 'Berakhir'
                              ? AppColors.error
                              : const Color(0xFF059669),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── Pelanggaran (SP only) ──
          if (!isPKWT && pelanggaran != null && pelanggaran.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.errorBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.15),
                    width: 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.report_rounded,
                      size: 14,
                      color: AppColors.error,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Pelanggaran',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.error,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            pelanggaran,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Catatan ──
          if (catatan != null && catatan.isNotEmpty)
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
                    const Icon(
                      Icons.notes_rounded,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        catatan,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
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

          // ── Footer ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt.withValues(alpha: 0.4),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 12,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  'Dibuat ${DateFormat('dd MMM yyyy', 'id_ID').format(
                    DateTime.parse(doc['created_at'] as String),
                  )}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                  ),
                ),
                const Spacer(),
                // Lampiran button
                if (lampiranUrl != null && lampiranUrl.isNotEmpty)
                  GestureDetector(
                    onTap: () => _openAttachment(context, lampiranUrl),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.attach_file_rounded,
                            size: 12,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'Lampiran',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openAttachment(BuildContext context, String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal membuka lampiran')),
        );
      }
    }
  }
}

// ═════════════════════════════════════════════════════════
// DETAIL ROW
// ═════════════════════════════════════════════════════════
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: AppColors.textMuted),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.textMuted,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
