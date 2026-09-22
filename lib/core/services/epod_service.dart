import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/epod_assignment_model.dart';
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
  bool get isEligible => isDriver || isHelper;
  bool get hasActiveAssignment => mine.isNotEmpty;
}

/// Exception e-POD dengan pesan siap tampil ke pengguna.
class EpodException implements Exception {
  final String message;

  const EpodException(this.message);

  @override
  String toString() => message;
}

/// Service e-POD mobile — memanggil RPC Supabase secara langsung.
///
/// RPC terkait: `tms_epod_mobile_overview`, `tms_epod_mobile_role`, dan
/// `tms_epod_mobile_claim`. Otorisasi role dilakukan di server berdasarkan
/// jabatan pegawai; aplikasi tidak mengirim role.
abstract final class EpodService {
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
