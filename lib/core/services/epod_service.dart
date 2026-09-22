import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/epod_assignment_model.dart';
import '../../models/epod_detail_model.dart';
import 'supabase_service.dart';

/// Ringkasan e-POD untuk satu pegawai: role, FO miliknya, dan FO tersedia.
class EpodOverview {
  final String? role;
  final List<EpodAssignment> mine;
  final List<EpodAssignment> available;

  const EpodOverview({
    required this.role,
    required this.mine,
    required this.available,
  });

  static const empty = EpodOverview(role: null, mine: [], available: []);

  bool get isDriver => role == 'DRIVER';
  bool get isHelper => role == 'HELPER';
  bool get isCoordinator => role == 'COORDINATOR';
  bool get isDeputyCoordinator => role == 'DEPUTY_COORDINATOR';
  bool get isEligible =>
      isDriver || isHelper || isCoordinator || isDeputyCoordinator;
  bool get hasActiveAssignment => mine.isNotEmpty;
}

/// Exception e-POD dengan pesan siap tampil ke pengguna.
class EpodException implements Exception {
  final String message;

  const EpodException(this.message);

  @override
  String toString() => message;
}

/// Satu foto bukti yang sudah terunggah ke Storage.
///
/// Bentuk ini adalah kontrak `p_evidence` pada RPC `tms_epod_mobile_submit`.
class EpodEvidenceUpload {
  final String path;
  final String mimeType;
  final int sizeBytes;
  final String? originalFilename;
  final int sortOrder;

  const EpodEvidenceUpload({
    required this.path,
    required this.mimeType,
    required this.sizeBytes,
    required this.originalFilename,
    required this.sortOrder,
  });

  Map<String, dynamic> toJson() => {
        'path': path,
        'bucket_id': EpodService.bucket,
        'mime_type': mimeType,
        'size_bytes': sizeBytes,
        'original_filename': originalFilename,
        'sort_order': sortOrder,
      };
}

/// Service e-POD mobile — memanggil RPC Supabase secara langsung.
///
/// RPC terkait: `tms_epod_mobile_overview`, `tms_epod_mobile_role`,
/// `tms_epod_mobile_claim`, `tms_epod_mobile_detail`, dan
/// `tms_epod_mobile_submit`. Otorisasi role dilakukan di server berdasarkan
/// jabatan pegawai; aplikasi tidak mengirim role.
abstract final class EpodService {
  /// Bucket privat bukti e-POD.
  static const String bucket = 'tms-epod-evidence';

  /// Batas jumlah foto bukti per titik.
  static const int maxPhotos = 5;

  /// Radius geofence (meter) sebelum alasan wajib diisi.
  static const double geofenceMeters = 500;

  /// Target ukuran foto setelah kompres.
  static const int _compressTargetBytes = 500 * 1024;
  /// Ambil ringkasan e-POD (role + daftar FO) untuk [employeeId].
  static Future<EpodOverview> getOverview(String employeeId) async {
    try {
      await SupabaseService.ensureAuthenticated();
      final data = await SupabaseService.client.rpc(
        'tms_epod_mobile_overview',
        params: {'p_employee_id': employeeId},
      );
      final map = _asMap(data);
      return EpodOverview(
        role: _asRole(map['role']),
        mine: _asList(map['mine']),
        available: _asList(map['available']),
      );
    } on PostgrestException catch (e) {
      throw EpodException(_friendlyMessage(e.message));
    } catch (e) {
      debugPrint('[EpodService] getOverview error: $e');
      throw const EpodException(
        'Gagal memuat data e-POD. Periksa koneksi lalu coba lagi.',
      );
    }
  }

  /// Ambil role mobile pegawai: 'DRIVER', 'HELPER', atau null.
  static Future<String?> getRole(String employeeId) async {
    try {
      await SupabaseService.ensureAuthenticated();
      final data = await SupabaseService.client.rpc(
        'tms_epod_mobile_role',
        params: {'p_employee_id': employeeId},
      );
      return _asRole(data);
    } catch (e) {
      debugPrint('[EpodService] getRole error: $e');
      return null;
    }
  }

  /// Klaim satu FO untuk pegawai. Role ditentukan server.
  static Future<EpodAssignment> claim({
    required String assignmentId,
    required String employeeId,
  }) async {
    try {
      await SupabaseService.forceEnsureAuthenticated();
      final data = await SupabaseService.client.rpc(
        'tms_epod_mobile_claim',
        params: {
          'p_assignment_id': assignmentId,
          'p_employee_id': employeeId,
        },
      );
      return EpodAssignment.fromMap(_asMap(data));
    } on PostgrestException catch (e) {
      throw EpodException(_friendlyMessage(e.message));
    } catch (e) {
      debugPrint('[EpodService] claim error: $e');
      throw const EpodException(
        'Gagal mengklaim FO. Periksa koneksi lalu coba lagi.',
      );
    }
  }

  /// Ambil detail satu FO: ringkasan + daftar titik + bukti aktif.
  static Future<EpodDetail> getDetail({
    required String assignmentId,
    required String employeeId,
  }) async {
    try {
      await SupabaseService.ensureAuthenticated();
      final data = await SupabaseService.client.rpc(
        'tms_epod_mobile_detail',
        params: {
          'p_assignment_id': assignmentId,
          'p_employee_id': employeeId,
        },
      );
      return EpodDetail.fromMap(_asMap(data));
    } on PostgrestException catch (e) {
      throw EpodException(_friendlyMessage(e.message));
    } catch (e) {
      debugPrint('[EpodService] getDetail error: $e');
      throw const EpodException(
        'Gagal memuat detail FO. Periksa koneksi lalu coba lagi.',
      );
    }
  }

  /// Kirim bukti loading/pengantaran untuk satu titik.
  ///
  /// [evidence] harus sudah terunggah lebih dulu via [uploadEvidence].
  static Future<EpodSubmission> submit({
    required String stopId,
    required String employeeId,
    required String? result,
    required String recipientName,
    required String note,
    required double latitude,
    required double longitude,
    required double? accuracyMeters,
    required DateTime capturedAtDevice,
    required String outOfRadiusReason,
    required List<EpodEvidenceUpload> evidence,
    required List<EpodItemInput> items,
  }) async {
    try {
      await SupabaseService.forceEnsureAuthenticated();
      final data = await SupabaseService.client.rpc(
        'tms_epod_mobile_submit',
        params: {
          'p_stop_id': stopId,
          'p_employee_id': employeeId,
          'p_result': result,
          'p_recipient_name': recipientName,
          'p_note': note,
          'p_latitude': latitude,
          'p_longitude': longitude,
          'p_accuracy_meters': accuracyMeters,
          'p_captured_at_device': capturedAtDevice.toUtc().toIso8601String(),
          'p_out_of_radius_reason': outOfRadiusReason,
          'p_evidence': evidence.map((item) => item.toJson()).toList(),
          'p_items': items.map((item) => item.toJson()).toList(),
        },
      );
      return EpodSubmission.fromMap(_asMap(data));
    } on PostgrestException catch (e) {
      throw EpodException(_friendlyMessage(e.message));
    } catch (e) {
      debugPrint('[EpodService] submit error: $e');
      throw const EpodException(
        'Gagal mengirim bukti. Periksa koneksi lalu coba lagi.',
      );
    }
  }

  /// Kompres lalu unggah satu foto bukti ke bucket privat.
  ///
  /// Path mengikuti pola yang diizinkan policy Storage mobile:
  /// `assignments/<assignmentId>/stops/<stopId>/<nama-file>`.
  static Future<EpodEvidenceUpload> uploadEvidence({
    required String assignmentId,
    required String stopId,
    required String sourcePath,
    required int sortOrder,
  }) async {
    try {
      await SupabaseService.forceEnsureAuthenticated();

      final bytes = await _compressToTarget(sourcePath);
      final objectPath =
          'assignments/$assignmentId/stops/$stopId/${_objectName()}.jpg';

      await SupabaseService.client.storage.from(bucket).uploadBinary(
            objectPath,
            bytes,
            fileOptions: const FileOptions(
              upsert: false,
              contentType: 'image/jpeg',
            ),
          );

      return EpodEvidenceUpload(
        path: objectPath,
        mimeType: 'image/jpeg',
        sizeBytes: bytes.length,
        originalFilename: _baseName(sourcePath),
        sortOrder: sortOrder,
      );
    } on PostgrestException catch (e) {
      throw EpodException(_friendlyMessage(e.message));
    } on StorageException catch (e) {
      debugPrint('[EpodService] uploadEvidence storage error: $e');
      throw const EpodException('Gagal mengunggah foto bukti. Coba lagi.');
    } catch (e) {
      debugPrint('[EpodService] uploadEvidence error: $e');
      throw const EpodException(
        'Gagal mengunggah foto bukti. Periksa koneksi lalu coba lagi.',
      );
    }
  }

  /// Jarak Haversine (meter) antara dua koordinat.
  static double haversineMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371000.0;
    double toRad(double deg) => deg * pi / 180;
    final dLat = toRad(lat2 - lat1);
    final dLon = toRad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(toRad(lat1)) * cos(toRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    return earthRadius * 2 * asin(sqrt(a));
  }

  // ── Internal upload helpers ──────────────────────────────

  static Future<Uint8List> _compressToTarget(String sourcePath) async {
    final original = await File(sourcePath).readAsBytes();
    final target = _compressTargetBytes;

    if (original.length <= target) {
      return FlutterImageCompress.compressWithList(
        original,
        minWidth: 1024,
        minHeight: 1024,
        quality: 88,
        format: CompressFormat.jpeg,
      );
    }

    int quality = ((target / original.length) * 100).clamp(20, 85).toInt();
    Uint8List result = original;
    for (int attempt = 0; attempt < 5; attempt++) {
      result = await FlutterImageCompress.compressWithList(
        original,
        minWidth: 1024,
        minHeight: 1024,
        quality: quality,
        format: CompressFormat.jpeg,
      );
      if (result.length <= target) break;
      quality = (quality * 0.7).toInt().clamp(15, 80);
    }
    return result;
  }

  static String _objectName() {
    final rand = Random();
    final suffix = List.generate(
      3,
      (_) => rand.nextInt(0x10000).toRadixString(16).padLeft(4, '0'),
    ).join();
    return '${DateTime.now().microsecondsSinceEpoch}_$suffix';
  }

  static String? _baseName(String path) {
    final normalized = path.replaceAll('\\', '/');
    final name = normalized.split('/').last;
    return name.isEmpty ? null : name;
  }

  // ── Parsing helpers ──────────────────────────────────────

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) return value.cast<String, dynamic>();
    return const {};
  }

  static String? _asRole(dynamic value) {
    final role = value?.toString();
    if (role == 'DRIVER' || role == 'HELPER') return role;
    return null;
  }

  static List<EpodAssignment> _asList(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => EpodAssignment.fromMap(item.cast<String, dynamic>()))
        .toList();
  }

  /// Terjemahkan pesan RPC menjadi kalimat yang ramah pengguna.
  static String _friendlyMessage(String raw) {
    final message = raw.trim();
    if (message.isEmpty) {
      return 'Terjadi kesalahan. Silakan coba lagi.';
    }
    if (message.toLowerCase().contains('unauthorized')) {
      return 'Sesi Anda tidak berhak mengakses e-POD. Silakan login ulang.';
    }
    return message;
  }
}
