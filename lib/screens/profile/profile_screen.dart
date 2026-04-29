import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/pegawai_model.dart';
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

  @override
  void initState() {
    super.initState();
    _pegawai = widget.pegawai;
  }

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

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            // ── Header ──
            SliverToBoxAdapter(
              child: _ProfileHeader(
                pegawai: _pegawai,
                onEdit: _openEdit,
              ),
            ),

            // ── Body ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
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
                        _InfoRow('Jenis Kelamin', _pegawai.jenisKelamin),
                        _InfoRow('Agama', _pegawai.agama),
                        _InfoRow('Tempat Lahir', _pegawai.tempatLahir),
                        _InfoRow('Tanggal Lahir', _formatDate(_pegawai.tanggalLahir)),
                        _InfoRow('No. KTP', _pegawai.noKtp),
                        _InfoRow('No. Telepon', _pegawai.noTelp),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.base),

                    // Alamat
                    _SectionCard(
                      title: 'Alamat',
                      icon: Icons.location_on_outlined,
                      children: [
                        _InfoRow('Alamat KTP', _pegawai.alamatKtp),
                        _InfoRow('Alamat Domisili', _pegawai.alamatDomisili),
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
                        _InfoRow('Tanggal Bergabung', _formatDate(_pegawai.tanggalBergabung)),
                        _InfoRow('Mulai PKWT', _formatDate(_pegawai.tanggalMulaiPkwt)),
                        _InfoRow('Berakhir PKWT', _formatDate(_pegawai.tanggalBerakhirPkwt)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.base),

                    // Keluarga
                    _SectionCard(
                      title: 'Keluarga',
                      icon: Icons.family_restroom_rounded,
                      children: [
                        _InfoRow('Status Pernikahan', _pegawai.statusPernikahan),
                        _InfoRow('Nama Pasangan', _pegawai.namaPasangan),
                        _InfoRow('Jumlah Anak', _pegawai.jumlahAnak.toString()),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.base),

                    // Keuangan & BPJS
                    _SectionCard(
                      title: 'Keuangan & BPJS',
                      icon: Icons.account_balance_outlined,
                      children: [
                        _InfoRow('Bank', _pegawai.bank),
                        _InfoRow('No. Rekening', _pegawai.noRekening),
                        _InfoRow('Nama Rekening', _pegawai.namaRekening),
                        _InfoRow('BPJS Kesehatan', _pegawai.noBpjsKesehatan),
                        _InfoRow('BPJS Ketenagakerjaan', _pegawai.noBpjsKetenagakerjaan),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.base),

                    // Dokumen Foto
                    if (_pegawai.dokumenFoto.isNotEmpty) ...[
                      _DokumenSection(pegawai: _pegawai),
                      const SizedBox(height: AppSpacing.base),
                    ],

                    const SizedBox(height: AppSpacing.huge),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _formatDate(DateTime? date) {
    if (date == null) return null;
    return DateFormat('dd MMMM yyyy', 'id_ID').format(date);
  }
}

// ═════════════════════════════════════════════════════════
// PROFILE HEADER
// ═════════════════════════════════════════════════════════
class _ProfileHeader extends StatelessWidget {
  final Pegawai pegawai;
  final VoidCallback? onEdit;

  const _ProfileHeader({required this.pegawai, this.onEdit});

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
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.20),
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                        size: AppSpacing.iconMd,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Profil Saya',
                    style: AppTextStyles.onDarkTitle.copyWith(fontSize: 18),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: onEdit,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.20),
                        ),
                      ),
                      child: const Icon(
                        Icons.edit_rounded,
                        color: Colors.white,
                        size: AppSpacing.iconMd,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),

              // ── Avatar ──
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: Colors.white.withValues(alpha: 0.20),
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
              const SizedBox(height: AppSpacing.base),

              // ── Nama ──
              Text(
                pegawai.nama,
                style: AppTextStyles.onDarkTitle.copyWith(fontSize: 20),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),

              // ── Jabatan & ID ──
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm - 2,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
                child: Text(
                  '${pegawai.jabatanNama ?? '-'}  \u2022  ${pegawai.id}',
                  style: AppTextStyles.onDarkCaption.copyWith(fontSize: 13),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // ── Status badge ──
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs + 2,
                ),
                decoration: BoxDecoration(
                  color: pegawai.isAktif
                      ? AppColors.success.withValues(alpha: 0.20)
                      : AppColors.error.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      pegawai.isAktif
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      color: pegawai.isAktif
                          ? AppColors.successLight
                          : AppColors.errorLight,
                      size: 14,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      pegawai.isAktif ? 'Aktif' : 'Non-Aktif',
                      style: TextStyle(
                        color: pegawai.isAktif
                            ? AppColors.successLight
                            : AppColors.errorLight,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
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
          // Header
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

          // Content
          ...children,
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════
// INFO ROW
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: AppTextStyles.labelSm.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              displayValue,
              style: AppTextStyles.bodySm.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
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
          // Header
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

          // Foto grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                onTap: () => _openFullImage(context, doc.label, doc.url),
              );
            },
          ),

          // Foto diri (jika ada)
          if (pegawai.fotoDiri != null) ...[
            const SizedBox(height: AppSpacing.md),
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
            // Image
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
                child: const Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: AppColors.textMuted,
                    size: 28,
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
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs + 2,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.70),
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
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.zoom_in_rounded,
                      color: Colors.white,
                      size: 14,
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
