import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/pegawai_model.dart';
import '../../widgets/common/app_notification.dart';
import 'edit_profile_screen.dart';

/// Halaman profil pegawai — menampilkan data lengkap + foto dokumen.
///
/// Return [Pegawai] terbaru via `pop()` jika data diubah.
class ProfileScreen extends StatefulWidget {
  final Pegawai pegawai;

  const ProfileScreen({super.key, required this.pegawai});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Pegawai _pegawai;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _pegawai = widget.pegawai;
  }

  bool get _hasChanged => _pegawai != widget.pegawai;

  Future<void> _openEdit() async {
    final updated = await Navigator.of(context).push<Pegawai>(
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(pegawai: _pegawai),
      ),
    );
    if (updated != null && mounted) {
      setState(() => _pegawai = updated);
    }
  }

  /// Pull-to-refresh — ambil data terbaru dari server.
  Future<void> _refresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);

    try {
      await SupabaseService.ensureAuthenticated();
      final response = await SupabaseService.client
          .from('pegawai')
          .select('*, jabatan:jabatan_id(id, nama)')
          .eq('id', _pegawai.id)
          .single();

      if (!mounted) return;
      setState(() {
        _pegawai = Pegawai.fromMap(response);
        _isRefreshing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isRefreshing = false);
      AppNotification.show(
        context,
        type: NotificationType.warning,
        title: 'Gagal Memuat',
        message: 'Tidak dapat memperbarui data. Periksa koneksi internet.',
        duration: const Duration(seconds: 3),
      );
    }
  }

  void _onBack() {
    Navigator.of(context).pop(_hasChanged ? _pegawai : null);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
        ),
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: RefreshIndicator(
            onRefresh: _refresh,
            color: AppColors.primary600,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: _ProfileHeader(
                    pegawai: _pegawai,
                    onEdit: _openEdit,
                    onBack: _onBack,
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: AppSpacing.xl),

                        // Data Pribadi
                        _SectionCard(
                          title: 'Data Pribadi',
                          icon: Icons.person_outline_rounded,
                          children: [
                            _InfoRow('ID Pegawai', _pegawai.id),
                            _InfoRow('Nama Lengkap', _pegawai.nama),
                            _InfoRow(
                              'Jenis Kelamin',
                              _pegawai.jenisKelamin,
                            ),
                            _InfoRow('Agama', _pegawai.agama),
                            _InfoRow('Tempat Lahir', _pegawai.tempatLahir),
                            _InfoRow(
                              'Tanggal Lahir',
                              _formatDate(_pegawai.tanggalLahir),
                            ),
                            _InfoRow(
                              'No. KTP',
                              _maskKtp(_pegawai.noKtp),
                            ),
                            _InfoTap(
                              label: 'No. Telepon',
                              value: _pegawai.noTelp,
                              icon: Icons.phone_rounded,
                              onTap: _pegawai.noTelp != null
                                  ? () => _copyToClipboard(
                                        _pegawai.noTelp!,
                                        'No. Telepon',
                                      )
                                  : null,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.base),

                        // Alamat
                        _SectionCard(
                          title: 'Alamat',
                          icon: Icons.location_on_outlined,
                          children: [
                            _InfoRow('Alamat KTP', _pegawai.alamatKtp),
                            _InfoRow(
                              'Alamat Domisili',
                              _pegawai.alamatDomisili,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.base),

                        // Pekerjaan
                        _SectionCard(
                          title: 'Pekerjaan',
                          icon: Icons.work_outline_rounded,
                          children: [
                            _InfoRow('Jabatan', _pegawai.jabatanNama),
                            _InfoRow('Status', _pegawai.status),
                            _InfoRow(
                              'Tanggal Bergabung',
                              _formatDate(_pegawai.tanggalBergabung),
                            ),
                            if (_pegawai.tanggalMulaiPkwt != null)
                              _InfoRow(
                                'Mulai PKWT',
                                _formatDate(_pegawai.tanggalMulaiPkwt),
                              ),
                            if (_pegawai.tanggalBerakhirPkwt != null)
                              _InfoRow(
                                'Berakhir PKWT',
                                _formatDate(_pegawai.tanggalBerakhirPkwt),
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.base),

                        // Keluarga
                        _SectionCard(
                          title: 'Keluarga',
                          icon: Icons.family_restroom_rounded,
                          children: [
                            _InfoRow(
                              'Status Pernikahan',
                              _pegawai.statusPernikahan,
                            ),
                            if (_pegawai.namaPasangan != null &&
                                _pegawai.namaPasangan!.isNotEmpty)
                              _InfoRow(
                                'Nama Pasangan',
                                _pegawai.namaPasangan,
                              ),
                            _InfoRow(
                              'Jumlah Anak',
                              _pegawai.jumlahAnak.toString(),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.base),

                        // Keuangan & BPJS
                        _SectionCard(
                          title: 'Keuangan & BPJS',
                          icon: Icons.account_balance_outlined,
                          children: [
                            _InfoRow('Bank', _pegawai.bank),
                            _InfoRow(
                              'No. Rekening',
                              _maskRekening(_pegawai.noRekening),
                            ),
                            if (_pegawai.namaRekening != null)
                              _InfoRow(
                                'Nama Rekening',
                                _pegawai.namaRekening,
                              ),
                            if (_pegawai.noBpjsKesehatan != null)
                              _InfoRow(
                                'BPJS Kesehatan',
                                _pegawai.noBpjsKesehatan,
                              ),
                            if (_pegawai.noBpjsKetenagakerjaan != null)
                              _InfoRow(
                                'BPJS TK',
                                _pegawai.noBpjsKetenagakerjaan,
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.base),

                        // Dokumen Foto
                        _DokumenSection(pegawai: _pegawai),

                        const SizedBox(height: AppSpacing.huge),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────
  String? _formatDate(DateTime? date) {
    if (date == null) return null;
    return DateFormat('dd MMMM yyyy', 'id_ID').format(date);
  }

  /// Mask KTP: tampilkan 4 digit awal + **** + 4 digit akhir.
  String? _maskKtp(String? ktp) {
    if (ktp == null || ktp.length < 8) return ktp;
    final start = ktp.substring(0, 4);
    final end = ktp.substring(ktp.length - 4);
    return '$start${'*' * (ktp.length - 8)}$end';
  }

  /// Mask rekening: tampilkan 3 digit akhir saja.
  String? _maskRekening(String? rek) {
    if (rek == null || rek.length < 4) return rek;
    return '${'*' * (rek.length - 3)}${rek.substring(rek.length - 3)}';
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    AppNotification.show(
      context,
      type: NotificationType.info,
      title: '$label Disalin',
      message: '$text berhasil disalin ke clipboard.',
      duration: const Duration(seconds: 2),
    );
  }
}

// ═════════════════════════════════════════════════════════
// PROFILE HEADER
// ═════════════════════════════════════════════════════════
class _ProfileHeader extends StatelessWidget {
  final Pegawai pegawai;
  final VoidCallback? onEdit;
  final VoidCallback? onBack;

  const _ProfileHeader({required this.pegawai, this.onEdit, this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(AppSpacing.radiusXxl + 4),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xxl,
          ),
          child: Column(
            children: [
              // ── Top bar ──
              Row(
                children: [
                  _HeaderButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: onBack ?? () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  Text(
                    'Profil Saya',
                    style: AppTextStyles.onDarkTitle.copyWith(fontSize: 18),
                  ),
                  const Spacer(),
                  _HeaderButton(
                    icon: Icons.edit_rounded,
                    onTap: onEdit,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),

              // ── Avatar with status dot ──
              Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: CircleAvatar(
                      radius: 48,
                      backgroundColor:
                          Colors.white.withValues(alpha: 0.20),
                      backgroundImage: pegawai.fotoDiri != null
                          ? NetworkImage(pegawai.fotoDiri!)
                          : null,
                      child: pegawai.fotoDiri == null
                          ? Text(
                              pegawai.inisial,
                              style: AppTextStyles.h1.copyWith(
                                color: Colors.white,
                                fontSize: 32,
                              ),
                            )
                          : null,
                    ),
                  ),
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: pegawai.isAktif
                            ? AppColors.success
                            : AppColors.error,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.base),

              // ── Nama ──
              Text(
                pegawai.nama,
                style: AppTextStyles.onDarkTitle.copyWith(fontSize: 22),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),

              // ── Jabatan & ID chip ──
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md + 2,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusFull),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.work_rounded,
                      size: 14,
                      color: AppColors.primary600,
                    ),
                    const SizedBox(width: AppSpacing.sm - 2),
                    Text(
                      pegawai.jabatanNama ?? '-',
                      style: AppTextStyles.label.copyWith(
                        color: AppColors.primary800,
                        fontSize: 12,
                      ),
                    ),
                    Container(
                      width: 4,
                      height: 4,
                      margin: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                      ),
                      decoration: const BoxDecoration(
                        color: AppColors.textMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Text(
                      pegawai.id,
                      style: AppTextStyles.label.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12,
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
}

// ── Header glass button ──
class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _HeaderButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.20),
          ),
        ),
        child: Icon(icon, color: Colors.white, size: AppSpacing.iconMd),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════
// SECTION CARD
// ═════════════════════════════════════════════════════════
class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.primary50,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Icon(icon, color: AppColors.primary600, size: 18),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(title, style: AppTextStyles.h4),
            ],
          ),
          const SizedBox(height: AppSpacing.base),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════
// INFO ROW — label : value (responsive)
// ═════════════════════════════════════════════════════════
class _InfoRow extends StatelessWidget {
  final String label;
  final String? value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final displayValue = value ?? '-';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textMuted,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            displayValue,
            style: AppTextStyles.bodySm.copyWith(
              color: displayValue == '-'
                  ? AppColors.textMuted
                  : AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════
// INFO TAP — value yang bisa di-tap (copy, call, dll)
// ═════════════════════════════════════════════════════════
class _InfoTap extends StatelessWidget {
  final String label;
  final String? value;
  final IconData icon;
  final VoidCallback? onTap;

  const _InfoTap({
    required this.label,
    required this.value,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final displayValue = value ?? '-';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textMuted,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 3),
          GestureDetector(
            onTap: onTap,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    displayValue,
                    style: AppTextStyles.bodySm.copyWith(
                      color: onTap != null
                          ? AppColors.primary600
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (onTap != null)
                  Icon(
                    icon,
                    size: 16,
                    color: AppColors.primary600,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════
// DOKUMEN SECTION
// ═════════════════════════════════════════════════════════
class _DokumenSection extends StatelessWidget {
  final Pegawai pegawai;

  const _DokumenSection({required this.pegawai});

  @override
  Widget build(BuildContext context) {
    final docs = pegawai.dokumenFoto;
    final hasFotoDiri = pegawai.fotoDiri != null;
    final hasAny = docs.isNotEmpty || hasFotoDiri;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.primary50,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: const Icon(
                  Icons.photo_library_outlined,
                  color: AppColors.primary600,
                  size: 18,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text('Dokumen', style: AppTextStyles.h4),
            ],
          ),
          const SizedBox(height: AppSpacing.base),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.base),

          if (!hasAny)
            // Empty state
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.photo_outlined,
                      size: 36,
                      color: AppColors.textMuted.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Belum ada dokumen',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tap tombol edit untuk mengunggah',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // Foto grid
            if (docs.isNotEmpty)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.4,
                ),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  return _DokumenThumbnail(
                    label: doc.label,
                    url: doc.url,
                    onTap: () =>
                        _openFullImage(context, doc.label, doc.url),
                  );
                },
              ),

            // Foto diri
            if (hasFotoDiri) ...[
              if (docs.isNotEmpty) const SizedBox(height: AppSpacing.md),
              _DokumenThumbnail(
                label: 'Foto Diri',
                url: pegawai.fotoDiri!,
                fullWidth: true,
                onTap: () => _openFullImage(
                  context,
                  'Foto Diri',
                  pegawai.fotoDiri!,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  void _openFullImage(BuildContext context, String title, String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullImageScreen(title: title, url: url),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════
// DOKUMEN THUMBNAIL
// ═════════════════════════════════════════════════════════
class _DokumenThumbnail extends StatelessWidget {
  final String label;
  final String url;
  final bool fullWidth;
  final VoidCallback onTap;

  const _DokumenThumbnail({
    required this.label,
    required this.url,
    required this.onTap,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: fullWidth ? double.infinity : null,
        height: fullWidth ? 180 : null,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              url,
              fit: BoxFit.cover,
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return Container(
                  color: AppColors.surfaceAlt,
                  child: const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation(AppColors.primary400),
                      ),
                    ),
                  ),
                );
              },
              errorBuilder: (_, error, stackTrace) => Container(
                color: AppColors.surfaceAlt,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.broken_image_outlined,
                        color: AppColors.textMuted,
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Gagal memuat',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Label overlay
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.75),
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.zoom_in_rounded,
                      color: Colors.white70,
                      size: 16,
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
// FULL IMAGE SCREEN
// ═════════════════════════════════════════════════════════
class _FullImageScreen extends StatelessWidget {
  final String title;
  final String url;

  const _FullImageScreen({required this.title, required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title),
        centerTitle: true,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              );
            },
            errorBuilder: (_, error, stackTrace) => const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white54,
                    size: 48,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Gagal memuat gambar',
                    style: TextStyle(color: Colors.white54),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
