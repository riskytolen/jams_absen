import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/services/epod_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/epod_assignment_model.dart';
import '../../widgets/common/app_notification.dart';
import 'epod_detail_screen.dart';

/// Layar e-POD mobile: daftar FO milik pegawai dan FO yang bisa diklaim.
///
/// Ketuk kartu FO untuk membuka detail titik dan mengisi bukti
/// loading/pengantaran.
class EpodHomeScreen extends StatefulWidget {
  final String employeeId;
  final String employeeName;

  const EpodHomeScreen({
    super.key,
    required this.employeeId,
    required this.employeeName,
  });

  @override
  State<EpodHomeScreen> createState() => _EpodHomeScreenState();
}

class _EpodHomeScreenState extends State<EpodHomeScreen> {
  bool _loading = true;
  String? _error;
  EpodOverview _overview = EpodOverview.empty;
  String? _claimingId;
  int _tabIndex = 0;

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
      final overview = await EpodService.getOverview(widget.employeeId);
      if (!mounted) return;
      setState(() {
        _overview = overview;
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

  Future<void> _claim(EpodAssignment assignment) async {
    final confirmed = await _confirmClaim(assignment);
    if (confirmed != true) return;

    setState(() => _claimingId = assignment.id);
    try {
      await EpodService.claim(
        assignmentId: assignment.id,
        employeeId: widget.employeeId,
      );
      if (!mounted) return;
      AppNotification.show(
        context,
        type: NotificationType.success,
        title: 'FO Diklaim',
        message: 'FO ${assignment.title} berhasil diklaim.',
      );
      setState(() => _tabIndex = 0);
      await _load();
    } on EpodException catch (e) {
      if (!mounted) return;
      AppNotification.show(
        context,
        type: NotificationType.error,
        title: 'Gagal Klaim',
        message: e.message,
      );
    } finally {
      if (mounted) setState(() => _claimingId = null);
    }
  }

  Future<bool?> _confirmClaim(EpodAssignment assignment) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        ),
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: const Icon(
                Icons.assignment_turned_in_rounded,
                color: AppColors.accent,
                size: 22,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'Klaim FO',
                style: AppTextStyles.h4,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Klaim FO ${assignment.title}?',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Anda akan terpasang sebagai ${_roleLabel(_overview.role)} pada FO ini. '
              'Satu pegawai hanya bisa terikat pada satu FO aktif.',
              style: AppTextStyles.bodySm,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Klaim',
              style: TextStyle(
                color: AppColors.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _roleLabel(String? role) => role == 'HELPER' ? 'Helper' : 'Driver';

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
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 16, 16),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'e-POD',
                          style: AppTextStyles.onDarkTitle.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.employeeName,
                          style: AppTextStyles.onDarkMuted.copyWith(fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (_overview.isEligible)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Text(
                        _roleLabel(_overview.role),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              _buildTabs(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            _tabButton(0, 'FO Saya', _overview.mine.length),
            _tabButton(1, 'Claim FO', _overview.available.length),
          ],
        ),
      ),
    );
  }

  Widget _tabButton(int index, String label, int count) {
    final active = _tabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tabIndex = index),
        child: AnimatedContainer(
          duration: AppSpacing.durationFast,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: active ? AppColors.primary800 : Colors.white,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.accent.withValues(alpha: 0.14)
                        : Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: active ? AppColors.accent : Colors.white,
                    ),
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
      return _buildMessage(
        icon: Icons.wifi_off_rounded,
        title: 'Gagal Memuat',
        message: _error!,
        onRetry: _load,
      );
    }

    if (!_overview.isEligible) {
      return _buildMessage(
        icon: Icons.badge_rounded,
        title: 'Bukan Driver/Helper',
        message:
            'Akun Anda belum terdaftar sebagai Driver atau Helper, sehingga '
            'e-POD tidak tersedia.',
        onRetry: _load,
      );
    }

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: _load,
      child: _tabIndex == 0 ? _buildMineList() : _buildAvailableList(),
    );
  }

  Widget _buildMineList() {
    if (_overview.mine.isEmpty) {
      return _buildScrollableMessage(
        icon: Icons.inbox_rounded,
        title: 'Belum ada FO',
        message: 'Anda belum mengklaim FO. Buka tab Claim FO untuk mengambil FO.',
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.base),
      itemCount: _overview.mine.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (_, index) {
        final assignment = _overview.mine[index];
        return _MineCard(
          assignment: assignment,
          onTap: () => _openDetail(assignment),
        );
      },
    );
  }

  Future<void> _openDetail(EpodAssignment assignment) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EpodDetailScreen(
          employeeId: widget.employeeId,
          employeeName: widget.employeeName,
          assignmentId: assignment.id,
          assignmentTitle: assignment.title,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Widget _buildAvailableList() {
    if (_overview.hasActiveAssignment) {
      return _buildScrollableMessage(
        icon: Icons.lock_clock_rounded,
        title: 'Sudah Ada FO Aktif',
        message:
            'Anda masih terikat FO aktif. Selesaikan atau batalkan dulu sebelum '
            'mengklaim FO baru.',
      );
    }
    if (_overview.available.isEmpty) {
      return _buildScrollableMessage(
        icon: Icons.search_off_rounded,
        title: 'Tidak Ada FO Tersedia',
        message: 'Belum ada FO yang bisa diklaim saat ini. Tarik untuk memuat ulang.',
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.base),
      itemCount: _overview.available.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (_, index) {
        final assignment = _overview.available[index];
        return _AvailableCard(
          assignment: assignment,
          claiming: _claimingId == assignment.id,
          disabled: _claimingId != null,
          onClaim: () => _claim(assignment),
        );
      },
    );
  }

  Widget _buildMessage({
    required IconData icon,
    required String title,
    required String message,
    required Future<void> Function() onRetry,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.base),
            Text(title, style: AppTextStyles.h4, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: AppTextStyles.bodySm,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              onPressed: () => onRetry(),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Muat Ulang'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accent,
                side: const BorderSide(color: AppColors.accent),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScrollableMessage({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: 80,
      ),
      children: [
        Icon(icon, size: 48, color: AppColors.textMuted),
        const SizedBox(height: AppSpacing.base),
        Text(title, style: AppTextStyles.h4, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.sm),
        Text(message, style: AppTextStyles.bodySm, textAlign: TextAlign.center),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════
// KARTU FO MILIK SAYA
// ═════════════════════════════════════════════════════════
class _MineCard extends StatelessWidget {
  final EpodAssignment assignment;
  final VoidCallback onTap;

  const _MineCard({required this.assignment, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tone = _statusTone(assignment.status);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(AppSpacing.base),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      assignment.title,
                      style: AppTextStyles.h4,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _Pill(label: assignment.statusLabel, color: tone),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _InfoRow(
                icon: Icons.local_shipping_rounded,
                label: 'Kendaraan',
                value: assignment.licensePlate ?? '-',
              ),
              const SizedBox(height: AppSpacing.sm),
              _InfoRow(
                icon: Icons.badge_rounded,
                label: 'Peran saya',
                value: assignment.roleLabel,
              ),
              const SizedBox(height: AppSpacing.sm),
              _InfoRow(
                icon: Icons.inventory_2_rounded,
                label: 'Loading',
                value:
                    assignment.loadingCompleted ? 'Selesai' : 'Belum selesai',
              ),
              const SizedBox(height: AppSpacing.sm),
              _InfoRow(
                icon: Icons.place_rounded,
                label: 'Pengantaran',
                value: assignment.deliveryProgress,
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  const Icon(Icons.touch_app_rounded,
                      size: 15, color: AppColors.accent),
                  const SizedBox(width: 6),
                  Text(
                    'Ketuk untuk isi bukti',
                    style: AppTextStyles.labelSm.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right_rounded,
                      size: 18, color: AppColors.accent),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════
// KARTU FO TERSEDIA
// ═════════════════════════════════════════════════════════
class _AvailableCard extends StatelessWidget {
  final EpodAssignment assignment;
  final bool claiming;
  final bool disabled;
  final VoidCallback onClaim;

  const _AvailableCard({
    required this.assignment,
    required this.claiming,
    required this.disabled,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  assignment.title,
                  style: AppTextStyles.h4,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _SlotBadge(
                label: 'Driver',
                filled: assignment.driverFilled,
              ),
              const SizedBox(width: 6),
              _SlotBadge(
                label: 'Helper',
                filled: assignment.helperFilled,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _InfoRow(
            icon: Icons.local_shipping_rounded,
            label: 'Kendaraan',
            value: assignment.licensePlate ?? '-',
          ),
          const SizedBox(height: AppSpacing.sm),
          _InfoRow(
            icon: Icons.person_rounded,
            label: 'Driver vendor',
            value: assignment.vendorDriverName ?? '-',
          ),
          const SizedBox(height: AppSpacing.sm),
          _InfoRow(
            icon: Icons.place_rounded,
            label: 'Jumlah titik',
            value: '${assignment.deliveryTotalCount} titik',
          ),
          const SizedBox(height: AppSpacing.base),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppColors.accentGradient,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  onTap: disabled ? null : onClaim,
                  child: Center(
                    child: claiming
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Klaim FO Ini',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
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
// WIDGET KECIL
// ═════════════════════════════════════════════════════════
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(width: AppSpacing.sm),
        Text(label, style: AppTextStyles.labelSm),
        const Spacer(),
        Text(
          value,
          style: AppTextStyles.label.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;

  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
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

class _SlotBadge extends StatelessWidget {
  final String label;
  final bool filled;

  const _SlotBadge({required this.label, required this.filled});

  @override
  Widget build(BuildContext context) {
    final color = filled ? AppColors.error : AppColors.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        filled ? '$label terisi' : '$label kosong',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

Color _statusTone(String status) {
  switch (status) {
    case 'COMPLETED':
      return AppColors.success;
    case 'CANCELLED':
      return AppColors.error;
    case 'IN_PROGRESS':
    case 'CLAIMED':
      return AppColors.accent;
    default:
      return AppColors.textSecondary;
  }
}
