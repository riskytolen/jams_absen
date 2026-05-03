import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../core/services/pegawai_service.dart';
import '../../core/services/supabase_service.dart';
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
  String? _selectedBank;
  late final TextEditingController _noRekeningCtrl;
  late final TextEditingController _namaRekeningCtrl;
  List<String> _bankList = [];
  bool _isBankLoading = true;

  // ── Foto ──
  File? _newFotoDiri;
  File? _newFotoKtp;
  File? _newFotoSim;
  File? _newFotoKK;
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
    'Cerai',
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

    _selectedBank = p.bank;
    _noRekeningCtrl = TextEditingController(text: p.noRekening ?? '');
    _namaRekeningCtrl = TextEditingController(text: p.namaRekening ?? '');

    _loadBanks();
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
    _noRekeningCtrl.dispose();
    _namaRekeningCtrl.dispose();
    super.dispose();
  }

  // ── Pick photo ────────────────────────────────────────
  Future<File?> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (picked != null) return File(picked.path);
    return null;
  }

  Future<void> _pickFotoDiri() async {
    final file = await _pickImage();
    if (file != null) setState(() => _newFotoDiri = file);
  }

  Future<void> _pickFotoKtp() async {
    final file = await _pickImage();
    if (file != null) setState(() => _newFotoKtp = file);
  }

  Future<void> _pickFotoSim() async {
    final file = await _pickImage();
    if (file != null) setState(() => _newFotoSim = file);
  }

  Future<void> _pickFotoKK() async {
    final file = await _pickImage();
    if (file != null) setState(() => _newFotoKK = file);
  }

  // ── Load banks from database ───────────────────────────
  Future<void> _loadBanks() async {
    try {
      await SupabaseService.ensureAuthenticated();
      final response = await SupabaseService.client
          .from('banks')
          .select('nama')
          .eq('status', 'Aktif')
          .order('nama');

      final names = (response as List)
          .map((e) => e['nama'] as String)
          .toList();

      if (!mounted) return;
      setState(() {
        _bankList = names;
        // Jika bank pegawai saat ini tidak ada di list, tambahkan
        if (_selectedBank != null &&
            _selectedBank!.isNotEmpty &&
            !names.contains(_selectedBank)) {
          _bankList.insert(0, _selectedBank!);
        }
        _isBankLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isBankLoading = false);
      AppNotification.show(
        context,
        type: NotificationType.warning,
        title: 'Gagal Memuat Bank',
        message: 'Daftar bank tidak tersedia. Anda bisa simpan data lain terlebih dahulu.',
        duration: const Duration(seconds: 4),
      );
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

  // ── Build updates map — hanya field yang berubah ─────
  Map<String, dynamic> _buildUpdates() {
    final p = widget.pegawai;
    final updates = <String, dynamic>{};

    void check(String key, String? newVal, String? oldVal) {
      final nv = newVal?.trim() ?? '';
      final ov = oldVal?.trim() ?? '';
      if (nv != ov) updates[key] = nv.isEmpty ? null : nv;
    }

    check('nama', _namaCtrl.text, p.nama);
    check('no_ktp', _noKtpCtrl.text, p.noKtp);
    check('tempat_lahir', _tempatLahirCtrl.text, p.tempatLahir);
    check('no_telp', _noTelpCtrl.text, p.noTelp);
    check('alamat_ktp', _alamatKtpCtrl.text, p.alamatKtp);
    check('alamat_domisili', _alamatDomisiliCtrl.text, p.alamatDomisili);
    check('nama_pasangan', _namaPasanganCtrl.text, p.namaPasangan);
    check('no_rekening', _noRekeningCtrl.text, p.noRekening);
    check('nama_rekening', _namaRekeningCtrl.text, p.namaRekening);

    if (_jenisKelamin != p.jenisKelamin) {
      updates['jenis_kelamin'] = _jenisKelamin;
    }
    if (_agama != p.agama) {
      updates['agama'] = _agama;
    }
    if (_statusPernikahan != p.statusPernikahan) {
      updates['status_pernikahan'] = _statusPernikahan;
    }
    if (_selectedBank != p.bank) {
      updates['bank'] = _selectedBank;
    }

    final newAnak = int.tryParse(_jumlahAnakCtrl.text.trim()) ?? 0;
    if (newAnak != p.jumlahAnak) {
      updates['jumlah_anak'] = newAnak;
    }

    if (_tanggalLahir != p.tanggalLahir) {
      updates['tanggal_lahir'] = _tanggalLahir != null
          ? _tanggalLahir!.toIso8601String().split('T')[0]
          : null;
    }

    return updates;
  }

  bool get _hasPhotoChanges =>
      _newFotoDiri != null ||
      _newFotoKtp != null ||
      _newFotoSim != null ||
      _newFotoKK != null;

  // ── Save ──────────────────────────────────────────────
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;

    final updates = _buildUpdates();

    // Cek apakah ada perubahan
    if (updates.isEmpty && !_hasPhotoChanges) {
      AppNotification.show(
        context,
        type: NotificationType.info,
        title: 'Tidak Ada Perubahan',
        message: 'Belum ada data yang diubah.',
        duration: const Duration(seconds: 2),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final eid = widget.pegawai.id;

      // 1. Upload foto yang diubah (dikompres ke ≤ 300KB)
      final photoUploads = <(File, DocType)>[
        if (_newFotoDiri != null) (_newFotoDiri!, DocType.fotoDiri),
        if (_newFotoKtp != null) (_newFotoKtp!, DocType.fotoKtp),
        if (_newFotoSim != null) (_newFotoSim!, DocType.fotoSim),
        if (_newFotoKK != null) (_newFotoKK!, DocType.kartuKeluarga),
      ];

      for (final (file, docType) in photoUploads) {
        await PegawaiService.uploadPhoto(
          employeeId: eid,
          imageFile: file,
          docType: docType,
        );
      }

      // 2. Update data profil
      final updated = await PegawaiService.updateProfile(
        employeeId: eid,
        updates: updates,
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
    } on PegawaiException catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      AppNotification.show(
        context,
        type: NotificationType.error,
        title: 'Gagal Menyimpan',
        message: e.message,
        actionLabel: 'Coba Lagi',
        onAction: _save,
        duration: const Duration(seconds: 5),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      AppNotification.show(
        context,
        type: NotificationType.error,
        title: 'Terjadi Kesalahan',
        message: 'Gagal menyimpan perubahan. Silakan coba lagi.',
        actionLabel: 'Coba Lagi',
        onAction: _save,
        duration: const Duration(seconds: 5),
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
                          const SizedBox(height: AppSpacing.base),
                          _buildDokumenSection(),
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
                onTap: _pickFotoDiri,
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
                        backgroundImage: _newFotoDiri != null
                            ? FileImage(_newFotoDiri!)
                            : widget.pegawai.fotoDiri != null
                                ? NetworkImage(widget.pegawai.fotoDiri!)
                                : null,
                        child: (_newFotoDiri == null &&
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
        // Bank dropdown dari database
        _isBankLoading
            ? Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.base),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nama Bank',
                      style: AppTextStyles.labelSm.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.base,
                        vertical: AppSpacing.md + 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.account_balance_rounded,
                            size: 20,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Text(
                            'Memuat daftar bank...',
                            style: AppTextStyles.bodySm.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            : _Dropdown(
                label: 'Nama Bank',
                value: _selectedBank,
                items: _bankList,
                icon: Icons.account_balance_rounded,
                searchable: true,
                onChanged: (v) => setState(() => _selectedBank = v),
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
  // DOKUMEN
  // ═══════════════════════════════════════════════════════
  Widget _buildDokumenSection() {
    return _Section(
      title: 'Dokumen',
      icon: Icons.photo_library_outlined,
      children: [
        _PhotoPicker(
          label: 'Foto KTP',
          currentUrl: widget.pegawai.fotoKtp,
          newFile: _newFotoKtp,
          onPick: _pickFotoKtp,
        ),
        _PhotoPicker(
          label: 'Foto SIM',
          currentUrl: widget.pegawai.fotoSim,
          newFile: _newFotoSim,
          onPick: _pickFotoSim,
        ),
        _PhotoPicker(
          label: 'Kartu Keluarga',
          currentUrl: widget.pegawai.kartuKeluarga,
          newFile: _newFotoKK,
          onPick: _pickFotoKK,
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

/// Dropdown field — tap membuka bottom sheet picker.
class _Dropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final IconData icon;
  final ValueChanged<String?> onChanged;
  final bool searchable;

  const _Dropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.icon,
    required this.onChanged,
    this.searchable = false,
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
          GestureDetector(
            onTap: () => _showPicker(context),
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
                  Icon(icon, size: 20, color: AppColors.textMuted),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      value ?? 'Pilih $label',
                      style: AppTextStyles.bodySm.copyWith(
                        color: value != null
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textMuted,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PickerSheet(
        title: label,
        items: items,
        selected: value,
        searchable: searchable,
        onSelected: (v) {
          onChanged(v);
          Navigator.of(context).pop();
        },
      ),
    );
  }
}

/// Bottom sheet picker — modern, searchable, responsive.
class _PickerSheet extends StatefulWidget {
  final String title;
  final List<String> items;
  final String? selected;
  final bool searchable;
  final ValueChanged<String> onSelected;

  const _PickerSheet({
    required this.title,
    required this.items,
    required this.selected,
    required this.searchable,
    required this.onSelected,
  });

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  final _searchCtrl = TextEditingController();
  late List<String> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.items;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    setState(() {
      if (query.isEmpty) {
        _filtered = widget.items;
      } else {
        _filtered = widget.items
            .where((e) => e.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.6;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXxl),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle bar ──
          const SizedBox(height: AppSpacing.md),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.surfaceDim,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppSpacing.base),

          // ── Title ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: [
                Text('Pilih ${widget.title}', style: AppTextStyles.h3),
                const Spacer(),
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
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Search (jika searchable) ──
          if (widget.searchable) ...[
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearch,
                style: AppTextStyles.bodySm.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: 'Cari ${widget.title.toLowerCase()}...',
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: AppColors.textMuted,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.md,
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1),

          // ── Items ──
          Flexible(
            child: _filtered.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 36,
                          color: AppColors.textMuted.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Tidak ditemukan',
                          style: AppTextStyles.body
                              .copyWith(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.only(
                      bottom: bottomPadding + AppSpacing.base,
                    ),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final item = _filtered[i];
                      final isSelected = item == widget.selected;

                      return InkWell(
                        onTap: () => widget.onSelected(item),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: AppSpacing.md + 2,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary50
                                : Colors.transparent,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item,
                                  style: AppTextStyles.bodySm.copyWith(
                                    color: isSelected
                                        ? AppColors.primary600
                                        : AppColors.textPrimary,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.primary600,
                                  size: 20,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Photo picker — preview + tap to change.
class _PhotoPicker extends StatelessWidget {
  final String label;
  final String? currentUrl;
  final File? newFile;
  final VoidCallback onPick;

  const _PhotoPicker({
    required this.label,
    required this.currentUrl,
    required this.newFile,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = newFile != null || currentUrl != null;

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
          GestureDetector(
            onTap: onPick,
            child: Container(
              width: double.infinity,
              height: 160,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: AppColors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: hasImage
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        // Image preview
                        if (newFile != null)
                          Image.file(newFile!, fit: BoxFit.cover)
                        else if (currentUrl != null)
                          Image.network(
                            currentUrl!,
                            fit: BoxFit.cover,
                            loadingBuilder: (_, child, progress) {
                              if (progress == null) return child;
                              return const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(
                                      AppColors.primary400,
                                    ),
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (_, error, stackTrace) =>
                                _emptyState(),
                          ),

                        // Change overlay
                        Positioned(
                          right: AppSpacing.sm,
                          bottom: AppSpacing.sm,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.xs + 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusFull,
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.camera_alt_rounded,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Ganti',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // New badge
                        if (newFile != null)
                          Positioned(
                            left: AppSpacing.sm,
                            top: AppSpacing.sm,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.success,
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusFull,
                                ),
                              ),
                              child: const Text(
                                'Baru',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                      ],
                    )
                  : _emptyState(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.add_photo_alternate_outlined,
            size: 32,
            color: AppColors.textMuted.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Ketuk untuk upload $label',
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}
