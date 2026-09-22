import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/services/epod_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/epod_detail_model.dart';
import '../../widgets/common/app_notification.dart';
import 'epod_evidence_viewer.dart';
import 'epod_submission_form_screen.dart';

/// Layar detail satu FO: daftar titik loading & pengantaran.
///
/// Setiap titik bisa dibuka untuk mengisi bukti. Titik pengantaran hanya
/// bisa diisi setelah bukti loading selesai (aturan juga ditegakkan server).
class EpodDetailScreen extends StatefulWidget {
  final String employeeId;
  final String employeeName;
  final String assignmentId;
  final String assignmentTitle;

  const EpodDetailScreen({
    super.key,
    required this.employeeId,
    required this.employeeName,
    required this.assignmentId,
    required this.assignmentTitle,
  });

  @override
  State<EpodDetailScreen> createState() => _EpodDetailScreenState();
}

class _EpodDetailScreenState extends State<EpodDetailScreen> {
  bool _loading = true;
  String? _error;
  EpodDetail? _detail;
  Map<String, List<EpodEvidenceView>> _evidenceUrls = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await EpodService.getDetail(
        assignmentId: widget.assignmentId,
        employeeId: widget.employeeId,
      );
      // URL foto bersifat pelengkap: kegagalan tidak menggagalkan layar.
      final urls = await EpodService.getEvidenceUrls(
        assignmentId: widget.assignmentId,
        employeeId: widget.employeeId,
      );
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _evidenceUrls = urls;
        _loading = false;
      });
    } on EpodException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _openForm(EpodStop stop) async {
    final detail = _detail;
    if (detail == null) return;

    if (!stop.isLoading && !detail.loadingCompleted) {
      AppNotification.show(
        context,
        type: NotificationType.warning,
        title: 'Loading Belum Selesai',
        message: 'Selesaikan bukti loading sebelum mengisi pengantaran.',
      );
      return;
    }

    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EpodSubmissionFormScreen(
          employeeId: widget.employeeId,
          assignmentId: detail.id,
          assignmentTitle: detail.title,
          stop: stop,
          existingEvidence: _evidenceUrls[stop.current?.id] ?? const [],
        ),
      ),
    );

    if (saved == true) await _load();
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
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final detail = _detail;
    final done = detail?.deliveryDoneCount ?? 0;
    final total = detail?.deliveryTotalCount ?? 0;
    final progress = total > 0 ? (done / total).clamp(0.0, 1.0) : 0.0;
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
            crossAxisAlignment: CrossAxisAlignment.start,
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          detail?.title ?? widget.assignmentTitle,
                          style: AppTextStyles.onDarkTitle.copyWith(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.employeeName} • ${detail?.roleLabel ?? '-'}',
                          style: AppTextStyles.onDarkMuted.copyWith(fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _loading ? null : _load,
                    icon: const Icon(Icons.refresh_rounded),
                    color: Colors.white,
                    iconSize: 20,
                  ),
                ],
              ),
              if (detail != null) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.only(left: 12, right: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _HeaderChip(
                            icon: Icons.local_shipping_rounded,
                            label: detail.licensePlate ?? '-',
                          ),
                          _HeaderChip(
                            icon: detail.loadingCompleted
                                ? Icons.check_circle_rounded
                                : Icons.hourglass_bottom_rounded,
                            label: detail.loadingCompleted
                                ? 'Loading selesai'
                                : 'Loading belum',
                            tone: detail.loadingCompleted
                                ? AppColors.successLight
                                : AppColors.warningLight,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.place_rounded,
                              size: 13, color: Colors.white70),
                          const SizedBox(width: 5),
                          Text(
                            'Pengantaran $done/$total titik',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor:
                              Colors.white.withValues(alpha: 0.22),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.successLight,
                          ),
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
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded,
                  size: 48, color: AppColors.textMuted),
              const SizedBox(height: AppSpacing.base),
              Text('Gagal Memuat', style: AppTextStyles.h4),
              const SizedBox(height: AppSpacing.sm),
              Text(_error!, style: AppTextStyles.bodySm, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Muat Ulang'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  side: const BorderSide(color: AppColors.accent),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final stops = _detail?.stops ?? const <EpodStop>[];
    if (stops.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text(
            'FO ini belum memiliki titik rute.',
            style: AppTextStyles.bodySm,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.base),
        itemCount: stops.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (_, index) {
          final stop = stops[index];
          final blocked = !stop.isLoading && !(_detail?.loadingCompleted ?? false);
          return _StopCard(
            stop: stop,
            blocked: blocked,
            evidence: _evidenceUrls[stop.current?.id] ?? const [],
            onTap: () => _openForm(stop),
          );
        },
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════
// KARTU TITIK
// ═════════════════════════════════════════════════════════
class _StopCard extends StatelessWidget {
  final EpodStop stop;
  final bool blocked;
  final List<EpodEvidenceView> evidence;
  final VoidCallback onTap;

  const _StopCard({
    required this.stop,
    required this.blocked,
    required this.evidence,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final done = stop.isDone;
    final tone = done
        ? AppColors.success
        : (blocked ? AppColors.textMuted : AppColors.accent);
    final borderColor = done
        ? AppColors.success
        : (blocked ? AppColors.border : AppColors.accent);
    final cardTint = done
        ? AppColors.successBg
        : (blocked ? AppColors.surfaceAlt : AppColors.accentBg);

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        onTap: blocked ? null : onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.base),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(color: borderColor, width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: done ? tone : tone.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: done
                        ? const Icon(Icons.check_rounded,
                            size: 20, color: Colors.white)
                        : Text(
                            '${stop.sequence}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: tone,
                            ),
                          ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stop.title,
                          style: AppTextStyles.h4.copyWith(fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          stop.isLoading ? 'Loading' : 'Pengantaran',
                          style: AppTextStyles.labelSm,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _StatusPill(stop: stop, blocked: blocked),
                ],
              ),
              if (stop.address != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.place_rounded,
                        size: 15, color: AppColors.textMuted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        stop.address!,
                        style: AppTextStyles.bodySm,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              if (done && stop.current != null) ...[
                const SizedBox(height: AppSpacing.sm),
                _SubmissionSummary(
                  submission: stop.current!,
                  evidence: evidence,
                  tint: cardTint,
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                height: 42,
                child: blocked
                    ? OutlinedButton(
                        onPressed: null,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textMuted,
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusMd),
                          ),
                        ),
                        child: const Text(
                          'Selesaikan Loading Dulu',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : OutlinedButton.icon(
                        onPressed: onTap,
                        icon: Icon(
                          done
                              ? Icons.visibility_rounded
                              : Icons.edit_note_rounded,
                          size: 18,
                        ),
                        label: Text(
                          done ? 'Lihat Bukti' : 'Isi Bukti',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: tone,
                          side: BorderSide(color: tone),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusMd),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubmissionSummary extends StatelessWidget {
  final EpodSubmission submission;
  final List<EpodEvidenceView> evidence;
  final Color tint;

  const _SubmissionSummary({
    required this.submission,
    required this.evidence,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final items = submission.items;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.success,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
                child: Text(
                  'Bukti v${submission.version} • ${submission.resultLabel}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${submission.evidenceCount} foto',
                style: AppTextStyles.labelSm,
              ),
            ],
          ),
          if (evidence.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: evidence.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (_, index) => GestureDetector(
                  onTap: () => showEpodEvidenceViewer(
                    context,
                    urls: evidence.map((item) => item.url).toList(),
                    initialIndex: index,
                  ),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                        child: Image.network(
                          evidence[index].url,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            width: 64,
                            height: 64,
                            color: AppColors.surfaceDim,
                            child: const Icon(Icons.broken_image_rounded,
                                size: 20, color: AppColors.textMuted),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.zoom_in_rounded,
                              size: 12, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (submission.recipientName != null) ...[
            const SizedBox(height: 6),
            Text(
              'Penerima: ${submission.recipientName}',
              style: AppTextStyles.bodySm,
            ),
          ],
          if (items.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              items.map((item) => '${item.name} (${item.summary})').join(', '),
              style: AppTextStyles.bodySm,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (submission.capturedAtServer != null) ...[
            const SizedBox(height: 4),
            Text(
              'Dikirim: ${_formatDateTime(submission.capturedAtServer!)}',
              style: AppTextStyles.labelSm,
            ),
          ],
        ],
      ),
    );
  }
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}

class _StatusPill extends StatelessWidget {
  final EpodStop stop;
  final bool blocked;

  const _StatusPill({required this.stop, required this.blocked});

  @override
  Widget build(BuildContext context) {
    final done = stop.isDone;
    final color = done
        ? AppColors.success
        : (blocked ? AppColors.textMuted : AppColors.warning);
    final label = done ? 'Selesai' : (blocked ? 'Terkunci' : 'Belum');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? tone;

  const _HeaderChip({required this.icon, required this.label, this.tone});

  @override
  Widget build(BuildContext context) {
    final accent = tone ?? Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: accent),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
