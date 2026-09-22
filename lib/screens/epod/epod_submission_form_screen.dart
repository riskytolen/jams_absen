import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/services/epod_service.dart';
import '../../core/services/location_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/epod_detail_model.dart';
import '../../widgets/common/app_notification.dart';
import 'epod_evidence_viewer.dart';

/// Form input bukti e-POD untuk satu titik (loading atau pengantaran).
///
/// Validasi di sini mencerminkan aturan server; server tetap penentu akhir.
class EpodSubmissionFormScreen extends StatefulWidget {
  final String employeeId;
  final String assignmentId;
  final String assignmentTitle;
  final EpodStop stop;

  /// Foto bukti tersimpan (signed URL) untuk mode lihat bukti.
  ///
  /// Disediakan layar detail via Edge Function `epod-evidence-urls`.
  final List<EpodEvidenceView> existingEvidence;

  const EpodSubmissionFormScreen({
    super.key,
    required this.employeeId,
    required this.assignmentId,
    required this.assignmentTitle,
    required this.stop,
    this.existingEvidence = const [],
  });

  @override
  State<EpodSubmissionFormScreen> createState() =>
      _EpodSubmissionFormScreenState();
}

class _EpodSubmissionFormScreenState extends State<EpodSubmissionFormScreen> {
  final List<String> _photos = [];
  final TextEditingController _recipientCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();
  final TextEditingController _reasonCtrl = TextEditingController();
  final List<_ItemRow> _items = [];

  String? _result;
  double? _latitude;
  double? _longitude;
  double? _accuracy;
  bool _locating = false;
  String? _locationError;

  bool _submitting = false;
  String _progress = '';

  /// Mode lihat bukti untuk titik yang sudah selesai.
  ///
  /// GPS tidak diambil dalam mode ini; lokasi baru diambil saat pengguna
  /// memilih kirim ulang bukti.
  bool _reviewing = false;

  bool get _isLoading => widget.stop.isLoading;
  bool get _isCorrection => widget.stop.isDone;

  @override
  void initState() {
    super.initState();
    if (!_isLoading) _items.add(_ItemRow());
    _prefillFromExisting();
    _reviewing = _isCorrection;
    if (!_reviewing) _fetchLocation();
  }

  /// Masuk ke mode isi/kirim ulang: tampilkan form lalu ambil lokasi.
  void _enterEdit() {
    setState(() => _reviewing = false);
    _fetchLocation();
  }

  void _prefillFromExisting() {
    final current = widget.stop.current;
    if (current == null) return;
    _recipientCtrl.text = current.recipientName ?? '';
    _noteCtrl.text = current.note ?? '';
    _reasonCtrl.text = current.outOfRadiusReason ?? '';
    _result = current.result;
    if (!_isLoading && current.items.isNotEmpty) {
      _items
        ..clear()
        ..addAll(current.items.map((item) => _ItemRow.fromItem(item)));
    }
  }

  @override
  void dispose() {
    _recipientCtrl.dispose();
    _noteCtrl.dispose();
    _reasonCtrl.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  // ── Lokasi ───────────────────────────────────────────────

  Future<void> _fetchLocation() async {
    setState(() {
      _locating = true;
      _locationError = null;
    });
    try {
      await LocationService.ensureReady();
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 30),
        ),
      );
      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _accuracy = position.accuracy;
        _locating = false;
      });
    } on LocationException catch (e) {
      if (!mounted) return;
      setState(() {
        _locationError = e.message;
        _locating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _locationError = 'Gagal mengambil lokasi. Aktifkan GPS lalu coba lagi.';
        _locating = false;
      });
    }
  }

  double? get _distanceMeters {
    final lat = _latitude;
    final lng = _longitude;
    final stopLat = widget.stop.latitude;
    final stopLng = widget.stop.longitude;
    if (lat == null || lng == null || stopLat == null || stopLng == null) {
      return null;
    }
    return EpodService.haversineMeters(lat, lng, stopLat, stopLng);
  }

  bool get _outOfRadius {
    final distance = _distanceMeters;
    return distance != null && distance > EpodService.geofenceMeters;
  }

  // ── Foto ─────────────────────────────────────────────────

  Future<void> _pickPhoto() async {
    if (_photos.length >= EpodService.maxPhotos) {
      _notify(NotificationType.warning, 'Batas Foto',
          'Maksimal ${EpodService.maxPhotos} foto per titik.');
      return;
    }

    final source = await _chooseSource();
    if (source == null || !mounted) return;

    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: source, maxWidth: 1600);
      if (file == null || !mounted) return;
      setState(() => _photos.add(file.path));
    } catch (e) {
      debugPrint('[EpodForm] pick photo error: $e');
      _notify(NotificationType.error, 'Gagal', 'Tidak bisa mengambil foto.');
    }
  }

  Future<ImageSource?> _chooseSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text('Pilih Sumber Foto', style: AppTextStyles.h4),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded,
                  color: AppColors.accent),
              title: const Text('Kamera'),
              subtitle: const Text('Ambil foto langsung'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded,
                  color: AppColors.accent),
              title: const Text('Galeri'),
              subtitle: const Text('Pilih dari galeri'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Barang ───────────────────────────────────────────────

  void _addItem() {
    setState(() => _items.add(_ItemRow()));
  }

  void _removeItem(int index) {
    setState(() {
      _items[index].dispose();
      _items.removeAt(index);
    });
  }

  // ── Submit ───────────────────────────────────────────────

  Future<void> _submit() async {
    final error = _validate();
    if (error != null) {
      _notify(NotificationType.warning, 'Lengkapi Data', error);
      return;
    }

    if (_isCorrection) {
      final confirmed = await _confirmCorrection();
      if (confirmed != true) return;
    }

    setState(() {
      _submitting = true;
      _progress = 'Mengunggah foto...';
    });

    try {
      final evidence = <EpodEvidenceUpload>[];
      for (int i = 0; i < _photos.length; i++) {
        if (!mounted) return;
        setState(() => _progress = 'Mengunggah foto ${i + 1}/${_photos.length}...');
        final upload = await EpodService.uploadEvidence(
          assignmentId: widget.assignmentId,
          stopId: widget.stop.id,
          sourcePath: _photos[i],
          sortOrder: i,
        );
        evidence.add(upload);
      }

      if (!mounted) return;
      setState(() => _progress = 'Mengirim bukti...');

      await EpodService.submit(
        stopId: widget.stop.id,
        employeeId: widget.employeeId,
        result: _isLoading ? null : _result,
        recipientName: _isLoading ? '' : _recipientCtrl.text.trim(),
        note: _isLoading ? '' : _noteCtrl.text.trim(),
        latitude: _latitude!,
        longitude: _longitude!,
        accuracyMeters: _accuracy,
        capturedAtDevice: DateTime.now(),
        outOfRadiusReason: _outOfRadius ? _reasonCtrl.text.trim() : '',
        evidence: evidence,
        items: _isLoading ? const [] : _collectItems(),
      );

      if (!mounted) return;
      AppNotification.show(
        context,
        type: NotificationType.success,
        title: 'Bukti Terkirim',
        message: _isLoading
            ? 'Bukti loading berhasil disimpan.'
            : 'Bukti pengantaran berhasil disimpan.',
      );
      Navigator.of(context).pop(true);
    } on EpodException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _notify(NotificationType.error, 'Gagal Kirim', e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _notify(NotificationType.error, 'Gagal Kirim',
          'Terjadi kesalahan. Silakan coba lagi.');
    }
  }

  String? _validate() {
    if (_photos.isEmpty) return 'Minimal satu foto bukti wajib dilampirkan.';
    if (_latitude == null || _longitude == null) {
      return 'Lokasi GPS belum didapat. Ambil lokasi terlebih dahulu.';
    }
    if (_outOfRadius && _reasonCtrl.text.trim().isEmpty) {
      return 'Alasan wajib diisi karena lokasi lebih dari '
          '${EpodService.geofenceMeters.toStringAsFixed(0)} meter dari titik.';
    }
    if (_isLoading) return null;

    if (_result == null) return 'Hasil pengiriman wajib dipilih.';
    final items = _collectItems();
    if (items.isEmpty) return 'Minimal satu barang wajib diisi.';
    for (final item in items) {
      if (item.name.isEmpty) return 'Nama barang wajib diisi.';
      if (item.quantity <= 0) {
        return 'Kuantitas barang "${item.name}" harus lebih dari 0.';
      }
    }
    if (_result != 'REJECTED' && _recipientCtrl.text.trim().isEmpty) {
      return 'Nama penerima wajib diisi.';
    }
    if (_result != 'DELIVERED' && _noteCtrl.text.trim().isEmpty) {
      return _result == 'PARTIAL'
          ? 'Catatan wajib diisi untuk pengiriman parsial.'
          : 'Alasan wajib diisi untuk pengiriman yang ditolak.';
    }
    return null;
  }

  List<EpodItemInput> _collectItems() {
    final result = <EpodItemInput>[];
    for (final row in _items) {
      final name = row.nameCtrl.text.trim();
      final qtyText = row.qtyCtrl.text.trim().replaceAll(',', '.');
      final unit = row.unitCtrl.text.trim();
      final isEmpty = name.isEmpty && qtyText.isEmpty && unit.isEmpty;
      if (isEmpty) continue;
      result.add(EpodItemInput(
        name: name,
        quantity: double.tryParse(qtyText) ?? 0,
        unit: unit.isEmpty ? null : unit,
      ));
    }
    return result;
  }

  Future<bool?> _confirmCorrection() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        ),
        backgroundColor: AppColors.surface,
        title: const Text('Kirim Ulang Bukti?'),
        content: const Text(
          'Bukti sebelumnya akan digantikan oleh versi baru. '
          'Foto perlu dilampirkan ulang.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Kirim Ulang',
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

  void _notify(NotificationType type, String title, String message) {
    AppNotification.show(context, type: type, title: title, message: message);
  }

  // ── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: AbsorbPointer(
                absorbing: _submitting,
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.base),
                  children: [
                    if (_reviewing && _isCorrection) ...[
                      _buildReviewSection(),
                    ] else ...[
                      _buildPhotoSection(),
                      const SizedBox(height: AppSpacing.base),
                      _buildLocationSection(),
                      if (_outOfRadius) ...[
                        const SizedBox(height: AppSpacing.base),
                        _buildOutOfRadiusField(),
                      ],
                      if (!_isLoading) ...[
                        const SizedBox(height: AppSpacing.base),
                        _buildItemsSection(),
                        const SizedBox(height: AppSpacing.base),
                        _buildResultSection(),
                        const SizedBox(height: AppSpacing.base),
                        _buildRecipientField(),
                        const SizedBox(height: AppSpacing.base),
                        _buildNoteField(),
                      ],
                    ],
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),
            _buildSubmitBar(),
          ],
        ),
      ),
    );
  }

  /// Ringkasan bukti tersimpan untuk titik yang sudah selesai.
  ///
  /// Tidak mengambil GPS; hanya menampilkan data versi aktif.
  Widget _buildReviewSection() {
    final current = widget.stop.current;
    final photos = widget.existingEvidence;
    final outOfRadius = current?.geofenceOk == false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Status hero ──
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.base),
          decoration: BoxDecoration(
            color: AppColors.successBg,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(
              color: AppColors.success.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded,
                    size: 24, color: Colors.white),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      current?.resultLabel ?? 'Selesai',
                      style: AppTextStyles.h4.copyWith(
                        fontSize: 16,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Bukti v${current?.version ?? 1}'
                      '${current?.capturedAtServer != null ? ' • ${_formatReviewDateTime(current!.capturedAtServer!)}' : ''}',
                      style: AppTextStyles.labelSm,
                    ),
                  ],
                ),
              ),
              if (outOfRadius)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.warningBg,
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusFull),
                    border: Border.all(
                      color:
                          AppColors.warning.withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Text(
                    'Di luar radius',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.warning,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.base),
        // ── Foto bukti ──
        _Section(
          title: 'Foto Bukti',
          subtitle: photos.isEmpty
              ? 'Foto tidak tersedia'
              : '${photos.length} foto',
          child: photos.isEmpty
              ? Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceDim,
                        borderRadius: BorderRadius.circular(
                            AppSpacing.radiusMd),
                      ),
                      child: const Icon(Icons.image_not_supported_rounded,
                          color: AppColors.textMuted),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Foto tersimpan tidak dapat dimuat saat ini.',
                        style: AppTextStyles.bodySm,
                      ),
                    ),
                  ],
                )
              : photos.length == 1
                  ? _TappableEvidencePhoto(
                      url: photos.first.url,
                      width: double.infinity,
                      height: 220,
                      onTap: () => _openEvidenceViewer(photos, 0),
                    )
                  : SizedBox(
                      height: 96,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: photos.length,
                        separatorBuilder: (_, _) => const SizedBox(
                            width: AppSpacing.sm),
                        itemBuilder: (_, index) => _TappableEvidencePhoto(
                          url: photos[index].url,
                          width: 96,
                          height: 96,
                          onTap: () =>
                              _openEvidenceViewer(photos, index),
                        ),
                      ),
                    ),
        ),
        const SizedBox(height: AppSpacing.base),
        // ── Detail pengiriman ──
        _Section(
          title: 'Detail Pengiriman',
          child: Column(
            children: [
              if (current?.recipientName != null)
                _ReviewInfoTile(
                  icon: Icons.person_rounded,
                  label: 'Penerima',
                  value: current!.recipientName!,
                ),
              if ((current?.note ?? '').isNotEmpty)
                _ReviewInfoTile(
                  icon: Icons.note_rounded,
                  label: 'Catatan',
                  value: current!.note!,
                ),
              if (current?.distanceMeters != null)
                _ReviewInfoTile(
                  icon: Icons.place_rounded,
                  label: 'Jarak saat kirim',
                  value: _formatHumanDistance(
                      current!.distanceMeters!),
                ),
              if (current != null && current.items.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                const Divider(height: 1),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    const Icon(Icons.inventory_2_rounded,
                        size: 16, color: AppColors.textMuted),
                    const SizedBox(width: 6),
                    Text(
                      'Barang (${current.items.length})',
                      style: AppTextStyles.label.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final item in current.items) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMd),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: AppTextStyles.label.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.accentBg,
                            borderRadius: BorderRadius.circular(
                                AppSpacing.radiusFull),
                          ),
                          child: Text(
                            item.summary,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.base),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: AppColors.warningBg,
            borderRadius:
                BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
                color: AppColors.warning.withValues(alpha: 0.3)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 15, color: AppColors.warning),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Kirim ulang mengganti bukti ini. Foto dan lokasi wajib diambil ulang.',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.warning),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Jarak ramah baca: meter di bawah 1 km, kilometer di atasnya.
  String _formatHumanDistance(double meters) {
    if (meters < 1000) return '${meters.toStringAsFixed(0)} m';
    final km = meters / 1000;
    final text = km >= 100
        ? km.toStringAsFixed(0)
        : km.toStringAsFixed(1).replaceAll('.', ',');
    return '$text km';
  }

  void _openEvidenceViewer(
      List<EpodEvidenceView> photos, int initialIndex) {
    final urls = photos.map((item) => item.url).toList();
    if (urls.isEmpty) return;
    showEpodEvidenceViewer(
      context,
      urls: urls,
      initialIndex: initialIndex.clamp(0, urls.length - 1),
    );
  }

  String _formatReviewDateTime(DateTime value) {
    final local = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
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
          child: Row(
            children: [
              IconButton(
                onPressed: _submitting ? null : () => Navigator.of(context).pop(),
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
                      _reviewing && _isCorrection
                          ? 'Detail Bukti'
                          : (_isLoading ? 'Bukti Loading' : 'Bukti Pengantaran'),
                      style: AppTextStyles.onDarkTitle.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.assignmentTitle} • ${widget.stop.title}',
                      style: AppTextStyles.onDarkMuted.copyWith(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

  Widget _buildPhotoSection() {
    return _Section(
      title: 'Foto Bukti',
      subtitle: '${_photos.length}/${EpodService.maxPhotos} foto • maksimal 5 MB',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_photos.isNotEmpty)
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (int i = 0; i < _photos.length; i++)
                  _PhotoThumb(
                    path: _photos[i],
                    onRemove: _submitting
                        ? null
                        : () => setState(() => _photos.removeAt(i)),
                  ),
              ],
            ),
          if (_photos.isNotEmpty) const SizedBox(height: AppSpacing.md),
          if (_photos.length < EpodService.maxPhotos)
            OutlinedButton.icon(
              onPressed: _submitting ? null : _pickPhoto,
              icon: const Icon(Icons.add_a_photo_rounded, size: 18),
              label: const Text('Tambah Foto'),
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
    );
  }

  Widget _buildLocationSection() {
    final distance = _distanceMeters;
    final statusColor = _outOfRadius ? AppColors.error : AppColors.success;
    return _Section(
      title: 'Lokasi GPS',
      subtitle: 'Diambil otomatis saat bukti dikirim',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_locating)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.accentBg,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: const Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.accent,
                    ),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Text('Mengambil lokasi...',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accent)),
                ],
              ),
            )
          else if (_locationError != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.errorBg,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_off_rounded,
                      size: 16, color: AppColors.error),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _locationError!,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.error),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: _outOfRadius
                    ? AppColors.errorBg
                    : AppColors.successBg,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(
                  color: statusColor.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _outOfRadius
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle_rounded,
                    size: 16,
                    color: statusColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _outOfRadius ? 'Di luar radius titik' : 'Lokasi valid',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Koordinat', style: AppTextStyles.caption),
                  const SizedBox(height: 1),
                  Text(
                    '${_latitude!.toStringAsFixed(6)}, '
                    '${_longitude!.toStringAsFixed(6)}',
                    style: AppTextStyles.label.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Akurasi',
                                style: AppTextStyles.caption),
                            const SizedBox(height: 1),
                            Text(
                              _accuracy == null
                                  ? '-'
                                  : '±${_accuracy!.toStringAsFixed(0)} m',
                              style: AppTextStyles.label.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Jarak ke titik',
                                style: AppTextStyles.caption),
                            const SizedBox(height: 1),
                            Text(
                              distance == null
                                  ? 'Tanpa koordinat titik'
                                  : _formatHumanDistance(distance),
                              style: AppTextStyles.label.copyWith(
                                fontWeight: FontWeight.w700,
                                color: _outOfRadius
                                    ? AppColors.error
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: OutlinedButton.icon(
              onPressed:
                  (_submitting || _locating) ? null : _fetchLocation,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text(
                'Ambil Ulang Lokasi',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accent,
                side: const BorderSide(color: AppColors.accent),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutOfRadiusField() {
    return _Section(
      title: 'Alasan Di Luar Radius',
      subtitle: 'Wajib karena lokasi di luar '
          '${EpodService.geofenceMeters.toStringAsFixed(0)} m dari titik',
      child: TextField(
        controller: _reasonCtrl,
        maxLines: 2,
        enabled: !_submitting,
        decoration: const InputDecoration(
          hintText: 'Contoh: akses jalan ditutup, GPS meleset',
        ),
      ),
    );
  }

  Widget _buildItemsSection() {
    return _Section(
      title: 'Barang',
      subtitle: 'Minimal 1 barang, maksimal 20',
      child: Column(
        children: [
          for (int i = 0; i < _items.length; i++) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Barang ${i + 1}',
                        style: AppTextStyles.label.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      if (_items.length > 1)
                        IconButton(
                          onPressed:
                              _submitting ? null : () => _removeItem(i),
                          icon: const Icon(Icons.delete_outline_rounded,
                              size: 18),
                          color: AppColors.error,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                              minWidth: 32, minHeight: 32),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _items[i].nameCtrl,
                    enabled: !_submitting,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nama barang',
                      hintText: 'Contoh: Kopi Tubruk',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _items[i].qtyCtrl,
                          enabled: !_submitting,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Jumlah',
                            hintText: 'Contoh: 2',
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: TextField(
                          controller: _items[i].unitCtrl,
                          enabled: !_submitting,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Satuan',
                            hintText: 'Contoh: dus',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (i != _items.length - 1)
              const SizedBox(height: AppSpacing.sm),
          ],
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed:
                  _submitting || _items.length >= 20 ? null : _addItem,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text('Tambah Barang (${_items.length}/20)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accent,
                side: const BorderSide(color: AppColors.accent),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultSection() {
    return _Section(
      title: 'Hasil Pengiriman',
      subtitle: 'Wajib dipilih',
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final entry in _resultOptions.entries)
            ChoiceChip(
              label: Text(entry.value),
              selected: _result == entry.key,
              onSelected: _submitting
                  ? null
                  : (_) => setState(() => _result = entry.key),
              selectedColor: AppColors.accent.withValues(alpha: 0.14),
              labelStyle: TextStyle(
                fontWeight: FontWeight.w700,
                color: _result == entry.key
                    ? AppColors.accent
                    : AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRecipientField() {
    return _Section(
      title: 'Nama Penerima',
      subtitle: 'Wajib kecuali pengiriman ditolak',
      child: TextField(
        controller: _recipientCtrl,
        enabled: !_submitting,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(hintText: 'Nama penerima'),
      ),
    );
  }

  Widget _buildNoteField() {
    return _Section(
      title: 'Catatan / Alasan',
      subtitle: 'Wajib untuk hasil parsial atau ditolak',
      child: TextField(
        controller: _noteCtrl,
        enabled: !_submitting,
        maxLines: 3,
        decoration: const InputDecoration(hintText: 'Catatan tambahan'),
      ),
    );
  }

  /// Bar bawah: dalam mode lihat bukti hanya menawarkan kirim ulang
  /// (yang sekaligus mengaktifkan GPS); selain itu tombol kirim biasa.
  Widget _buildSubmitBar() {
    if (_reviewing && _isCorrection) {
      return Container(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.base,
          AppSpacing.md,
          AppSpacing.base,
          AppSpacing.base + MediaQuery.of(context).padding.bottom,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: const Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: _enterEdit,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text(
              'Kirim Ulang Bukti',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accent,
              side: const BorderSide(color: AppColors.accent, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
            ),
          ),
        ),
      );
    }
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.base,
        AppSpacing.md,
        AppSpacing.base,
        AppSpacing.base + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: AppColors.accentGradient,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              onTap: _submitting ? null : _submit,
              child: Center(
                child: _submitting
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            _progress,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        _isCorrection ? 'Kirim Ulang Bukti' : 'Kirim Bukti',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static const Map<String, String> _resultOptions = {
    'DELIVERED': 'Terkirim',
    'PARTIAL': 'Parsial',
    'REJECTED': 'Ditolak',
  };
}

// ═════════════════════════════════════════════════════════
// WIDGET PENDUKUNG
// ═════════════════════════════════════════════════════════
class _ItemRow {
  final TextEditingController nameCtrl;
  final TextEditingController qtyCtrl;
  final TextEditingController unitCtrl;

  _ItemRow()
      : nameCtrl = TextEditingController(),
        qtyCtrl = TextEditingController(),
        unitCtrl = TextEditingController();

  _ItemRow.fromItem(EpodItem item)
      : nameCtrl = TextEditingController(text: item.name),
        qtyCtrl = TextEditingController(
          text: item.quantity == item.quantity.roundToDouble()
              ? item.quantity.toStringAsFixed(0)
              : item.quantity.toString(),
        ),
        unitCtrl = TextEditingController(text: item.unit ?? '');

  void dispose() {
    nameCtrl.dispose();
    qtyCtrl.dispose();
    unitCtrl.dispose();
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _Section({required this.title, this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.h4.copyWith(fontSize: 14)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: AppTextStyles.labelSm),
          ],
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

/// Foto evidence yang bisa diketuk untuk dibuka fullscreen.
class _TappableEvidencePhoto extends StatelessWidget {
  final String url;
  final double width;
  final double height;
  final VoidCallback onTap;

  const _TappableEvidencePhoto({
    required this.url,
    required this.width,
    required this.height,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            child: Image.network(
              url,
              width: width,
              height: height,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: width,
                height: height,
                color: AppColors.surfaceDim,
                child: const Icon(Icons.broken_image_rounded,
                    color: AppColors.textMuted),
              ),
            ),
          ),
          Positioned(
            right: 6,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.zoom_in_rounded,
                  size: 14, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// Baris info mode lihat bukti: ikon + label kecil di atas value tebal.
class _ReviewInfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ReviewInfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accentBg,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Icon(icon, size: 15, color: AppColors.accent),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.caption),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: AppTextStyles.label.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  final String path;
  final VoidCallback? onRemove;

  const _PhotoThumb({required this.path, this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: Image.file(
            File(path),
            width: 84,
            height: 84,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              width: 84,
              height: 84,
              color: AppColors.background,
              child: const Icon(Icons.broken_image_rounded,
                  color: AppColors.textMuted),
            ),
          ),
        ),
        if (onRemove != null)
          Positioned(
            top: -6,
            right: -6,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded,
                    size: 14, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}
