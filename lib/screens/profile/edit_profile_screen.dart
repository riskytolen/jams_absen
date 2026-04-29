import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../core/services/pegawai_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/pegawai_model.dart';
import '../../widgets/common/app_notification.dart';

/// Halaman edit profil pegawai.
///
/// Return [Pegawai] terbaru jika berhasil simpan, null jika batal.
class EditProfileScreen extends StatefulWidget {
  final Pegawai pegawai;

  const EditProfileScreen({super.key, required this.pegawai});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  // ── Identitas ──
  late final TextEditingController _namaCtrl;
  late final TextEditingController _noKtpCtrl;
  late final TextEditingController _tempatLahirCtrl;
  late final TextEditingController _noTelpCtrl;
  String? _jenisKelamin;
  String? _agama;
  DateTime? _tanggalLahir;

  // ── Alamat ──
  late final TextEditingController _alamatKtpCtrl;
  late final TextEditingController _alamatDomisiliCtrl;

  // ── Keluarga ──
  late final TextEditingController _namaPasanganCtrl;
  late final TextEditingController _jumlahAnakCtrl;
  String? _statusPernikahan;

  // ── Keuangan ──
  late final TextEditingController _bankCtrl;
  late final TextEditingController _noRekeningCtrl;
  late final TextEditingController _namaRekeningCtrl;

  File? _newPhoto;
  bool _isSaving = false;

  static const _genderOptions = ['Laki-laki', 'Perempuan'];
  static const _agamaOptions = [
    'Islam',
    'Kristen',
    'Katolik',
    'Hindu',
    'Buddha',
    'Konghucu',
  ];
  static const _statusNikahOptions = [
    'Belum Menikah',
    'Menikah',
    'Cerai Hidup',
    'Cerai Mati',
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.pegawai;
    _namaCtrl = TextEditingController(text: p.nama);
    _noKtpCtrl = TextEditingController(text: p.noKtp ?? '');
    _tempatLahirCtrl = TextEditingController(text: p.tempatLahir ?? '');
    _noTelpCtrl = TextEditingController(text: p.noTelp ?? '');
    _jenisKelamin = p.jenisKelamin;
    _agama = p.agama;
    _tanggalLahir = p.tanggalLahir;

    _alamatKtpCtrl = TextEditingController(text: p.alamatKtp ?? '');
    _alamatDomisiliCtrl = TextEditingController(text: p.alamatDomisili ?? '');

    _namaPasanganCtrl = TextEditingController(text: p.namaPasangan ?? '');
    _jumlahAnakCtrl = TextEditingController(text: p.jumlahAnak.toString());
    _statusPernikahan = p.statusPernikahan;

    _bankCtrl = TextEditingController(text: p.bank ?? '');
    _noRekeningCtrl = TextEditingController(text: p.noRekening ?? '');
    _namaRekeningCtrl = TextEditingController(text: p.namaRekening ?? '');
  }

  @override
  void dispose() {
    _namaCtrl.dispose();
    _noKtpCtrl.dispose();
    _tempatLahirCtrl.dispose();
    _noTelpCtrl.dispose();
    _alamatKtpCtrl.dispose();
    _alamatDomisiliCtrl.dispose();
    _namaPasanganCtrl.dispose();
    _jumlahAnakCtrl.dispose();
    _bankCtrl.dispose();
    _noRekeningCtrl.dispose();
    _namaRekeningCtrl.dispose();
    super.dispose();
  }

  // ── Pick photo ────────────────────────────────────────
  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() => _newPhoto = File(picked.path));
    }
  }

  // ── Pick date ─────────────────────────────────────────
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _tanggalLahir ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1950),
      lastDate: now,
      locale: const Locale('id', 'ID'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primary600,
                  onPrimary: Colors.white,
                  surface: AppColors.surface,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _tanggalLahir = picked);
    }
  }

  // ── Save ──────────────────────────────────────────────
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      if (_newPhoto != null) {
        await PegawaiService.uploadFotoDiri(
          employeeId: widget.pegawai.id,
          imageFile: _newPhoto!,
        );
      }

      final updated = await PegawaiService.updateProfile(
        employeeId: widget.pegawai.id,
        nama: _namaCtrl.text.trim(),
        jenisKelamin: _jenisKelamin,
        agama: _agama,
        noKtp: _noKtpCtrl.text.trim(),
        tempatLahir: _tempatLahirCtrl.text.trim(),
        tanggalLahir: _tanggalLahir,
        noTelp: _noTelpCtrl.text.trim(),
        alamatKtp: _alamatKtpCtrl.text.trim(),
        alamatDomisili: _alamatDomisiliCtrl.text.trim(),
        statusPernikahan: _statusPernikahan,
        namaPasangan: _namaPasanganCtrl.text.trim(),
        jumlahAnak: int.tryParse(_jumlahAnakCtrl.text.trim()) ?? 0,
        bank: _bankCtrl.text.trim(),
        noRekening: _noRekeningCtrl.text.trim(),
        namaRekening: _namaRekeningCtrl.text.trim(),
      );

      if (!mounted) return;

      AppNotification.show(
        context,
        type: NotificationType.success,
        title: 'Profil Diperbarui',
        message: 'Data profil Anda berhasil disimpan.',
        duration: const Duration(seconds: 3),
      );

      Navigator.of(context).pop(updated);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      AppNotification.show(
        context,
        type: NotificationType.error,
        title: 'Gagal Menyimpan',
        message: e.toString(),
        duration: const Duration(seconds: 4),
      );
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
        body: Stack(
          children: [
            CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(child: _buildHeader()),
                SliverToBoxAdapter(
                  child: Form(
                    key: _formKey,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: AppSpacing.xl),
                          _buildIdentitasSection(),
                          const SizedBox(height: AppSpacing.base),
                          _buildAlamatSection(),
                          const SizedBox(height: AppSpacing.base),
                          _buildKeluargaSection(),
                          const SizedBox(height: AppSpacing.base),
                          _buildKeuanganSection(),
                          const SizedBox(height: 120),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildSaveBar(),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // HEADER
  // ═══════════════════════════════════════════════════════
  Widget _buildHeader() {
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
            AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xl,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
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
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                        size: AppSpacing.iconMd,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Edit Profil',
                    style: AppTextStyles.onDarkTitle.copyWith(fontSize: 18),
                  ),
                  const Spacer(),
                  const SizedBox(width: 44),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              GestureDetector(
                onTap: _pickPhoto,
                child: Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: CircleAvatar(
                        radius: 44,
                        backgroundColor:
                            Colors.white.withValues(alpha: 0.20),
                        backgroundImage: _newPhoto != null
                            ? FileImage(_newPhoto!)
                            : widget.pegawai.fotoDiri != null
                                ? NetworkImage(widget.pegawai.fotoDiri!)
                                : null,
                        child: (_newPhoto == null &&
                                widget.pegawai.fotoDiri == null)
                            ? Text(
                                widget.pegawai.inisial,
                                style: AppTextStyles.h1.copyWith(
                                  color: Colors.white,
                                  fontSize: 28,
                                ),
                              )
                            : null,
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary600,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Ketuk foto untuk mengganti',
                style: AppTextStyles.onDarkCaption,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // IDENTITAS
  // ═══════════════════════════════════════════════════════
  Widget _buildIdentitasSection() {
    final dateText = _tanggalLahir != null
        ? DateFormat('dd MMMM yyyy', 'id_ID').format(_tanggalLahir!)
        : 'Pilih tanggal';

    return _Section(
      title: 'Data Pribadi',
      icon: Icons.person_outline_rounded,
      children: [
        _Field(
          label: 'Nama Lengkap',
          controller: _namaCtrl,
          prefixIcon: Icons.badge_rounded,
          validator: (v) =>
              v == null || v.trim().isEmpty ? 'Nama wajib diisi' : null,
        ),
        _Dropdown(
          label: 'Jenis Kelamin',
          value: _jenisKelamin,
          items: _genderOptions,
          icon: Icons.wc_rounded,
          onChanged: (v) => setState(() => _jenisKelamin = v),
        ),
        _Dropdown(
          label: 'Agama',
          value: _agama,
          items: _agamaOptions,
          icon: Icons.auto_awesome_rounded,
          onChanged: (v) => setState(() => _agama = v),
        ),
        _Field(
          label: 'No. KTP',
          controller: _noKtpCtrl,
          prefixIcon: Icons.credit_card_rounded,
          keyboardType: TextInputType.number,
        ),
        _Field(
          label: 'Tempat Lahir',
          controller: _tempatLahirCtrl,
          prefixIcon: Icons.location_city_rounded,
        ),
        // Tanggal Lahir — date picker
        _buildDateField(dateText),
        _Field(
          label: 'No. Telepon',
          controller: _noTelpCtrl,
          prefixIcon: Icons.phone_rounded,
          keyboardType: TextInputType.phone,
          validator: (v) =>
              v == null || v.trim().isEmpty ? 'No. telepon wajib diisi' : null,
        ),
      ],
    );
  }

  Widget _buildDateField(String dateText) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tanggal Lahir',
            style: AppTextStyles.labelSm.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.base,
                vertical: AppSpacing.md + 2,
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    size: 20,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      dateText,
                      style: AppTextStyles.bodySm.copyWith(
                        color: _tanggalLahir != null
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.arrow_drop_down_rounded,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ALAMAT
  // ═══════════════════════════════════════════════════════
  Widget _buildAlamatSection() {
    return _Section(
      title: 'Alamat',
      icon: Icons.location_on_outlined,
      children: [
        _Field(
          label: 'Alamat KTP',
          controller: _alamatKtpCtrl,
          prefixIcon: Icons.home_rounded,
          maxLines: 3,
        ),
        _Field(
          label: 'Alamat Domisili',
          controller: _alamatDomisiliCtrl,
          prefixIcon: Icons.location_on_rounded,
          maxLines: 3,
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  // KELUARGA
  // ═══════════════════════════════════════════════════════
  Widget _buildKeluargaSection() {
    return _Section(
      title: 'Keluarga',
      icon: Icons.family_restroom_rounded,
      children: [
        _Dropdown(
          label: 'Status Pernikahan',
          value: _statusPernikahan,
          items: _statusNikahOptions,
          icon: Icons.favorite_outline_rounded,
          onChanged: (v) => setState(() => _statusPernikahan = v),
        ),
        _Field(
          label: 'Nama Pasangan',
          controller: _namaPasanganCtrl,
          prefixIcon: Icons.person_outline_rounded,
        ),
        _Field(
          label: 'Jumlah Anak',
          controller: _jumlahAnakCtrl,
          prefixIcon: Icons.child_care_rounded,
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  // KEUANGAN
  // ═══════════════════════════════════════════════════════
  Widget _buildKeuanganSection() {
    return _Section(
      title: 'Keuangan',
      icon: Icons.account_balance_outlined,
      children: [
        _Field(
          label: 'Nama Bank',
          controller: _bankCtrl,
          prefixIcon: Icons.account_balance_rounded,
        ),
        _Field(
          label: 'No. Rekening',
          controller: _noRekeningCtrl,
          prefixIcon: Icons.credit_card_rounded,
          keyboardType: TextInputType.number,
        ),
        _Field(
          label: 'Nama Pemilik Rekening',
          controller: _namaRekeningCtrl,
          prefixIcon: Icons.person_outline_rounded,
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  // SAVE BAR
  // ═══════════════════════════════════════════════════════
  Widget _buildSaveBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.base,
        AppSpacing.lg,
        MediaQuery.of(context).padding.bottom + AppSpacing.base,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: AnimatedContainer(
          duration: AppSpacing.durationNormal,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd + 2),
            gradient: _isSaving ? null : AppColors.primaryGradient,
            color: _isSaving ? AppColors.primary300 : null,
            boxShadow: _isSaving
                ? []
                : AppShadows.colored(AppColors.primary600, opacity: 0.30),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isSaving ? null : _save,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd + 2),
              splashColor: Colors.white.withValues(alpha: 0.15),
              child: Center(
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.save_rounded,
                            color: Colors.white,
                            size: AppSpacing.iconMd,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text('Simpan Perubahan', style: AppTextStyles.button),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════
// REUSABLE WIDGETS
// ═════════════════════════════════════════════════════════

/// Section card wrapper.
class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _Section({
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
          const SizedBox(height: AppSpacing.lg),
          ...children,
        ],
      ),
    );
  }
}

/// Text field.
class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData? prefixIcon;
  final TextInputType keyboardType;
  final int maxLines;
  final String? Function(String?)? validator;

  const _Field({
    required this.label,
    required this.controller,
    this.prefixIcon,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.labelSm.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            validator: validator,
            style: AppTextStyles.bodySm.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              prefixIcon: prefixIcon != null
                  ? Icon(prefixIcon, size: 20, color: AppColors.textMuted)
                  : null,
              hintText: label,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dropdown field.
class _Dropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final IconData icon;
  final ValueChanged<String?> onChanged;

  const _Dropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.icon,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.labelSm.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String>(
            initialValue: value,
            decoration: InputDecoration(
              prefixIcon: Icon(icon, size: 20, color: AppColors.textMuted),
            ),
            items: items
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: onChanged,
            style: AppTextStyles.bodySm.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
            dropdownColor: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
        ],
      ),
    );
  }
}
