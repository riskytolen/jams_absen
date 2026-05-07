import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../models/pegawai_model.dart';
import 'device_service.dart';
import 'supabase_service.dart';

/// Tipe error autentikasi.
enum AuthErrorType {
  /// QR Code kosong atau tidak valid.
  invalidQr,

  /// ID Pegawai tidak ditemukan di database.
  notFound,

  /// Pegawai ditemukan tapi status tidak aktif.
  inactive,

  /// Pegawai sudah terdaftar di device lain.
  deviceBoundToOther,

  /// Device ini sudah dipakai pegawai lain.
  deviceUsedByOther,

  /// Tidak ada koneksi internet.
  noConnection,

  /// Server Supabase tidak merespons / timeout.
  serverError,

  /// Error tidak diketahui.
  unknown,
}

/// Service autentikasi pegawai via ID (dari QR Code ID Card).
///
/// Flow login:
/// 1. Validasi format QR Code
/// 2. Query pegawai dari database
/// 3. Cek status pegawai aktif
/// 4. Cek device binding:
///    - Belum ada record → register device baru (first login)
///    - Record ada & device cocok → lanjut login
///    - Record ada & device beda → tolak (bound to other device)
///    - Device ini sudah dipakai pegawai lain → tolak
/// 5. Update last_seen_at
/// 6. Return Pegawai
abstract final class AuthService {
  static Pegawai? _currentPegawai;

  static Pegawai? get currentPegawai => _currentPegawai;
  static bool get isLoggedIn => _currentPegawai != null;

  /// Update data pegawai di session (setelah edit profil).
  static void updateCurrentPegawai(Pegawai pegawai) {
    _currentPegawai = pegawai;
  }

  /// Refresh data pegawai dari database (sync jabatan, status, dll).
  static Future<Pegawai?> refreshPegawai(String employeeId) async {
    try {
      await SupabaseService.ensureAuthenticated();

      final response = await SupabaseService.client
          .from('pegawai')
          .select('*, jabatan:jabatan_id(id, nama)')
          .eq('id', employeeId)
          .maybeSingle();

      if (response != null) {
        final pegawai = Pegawai.fromMap(response);
        _currentPegawai = pegawai;
        return pegawai;
      }
      return null;
    } catch (e) {
      debugPrint('[AuthService] refreshPegawai error: $e');
      return null;
    }
  }

  /// Login dengan ID pegawai (dari QR Code) + device binding.
  static Future<Pegawai> loginWithId(String employeeId) async {
    final trimmedId = employeeId.trim().toUpperCase();

    // ── 1. Validasi format ID ──
    if (trimmedId.isEmpty) {
      throw const AuthException(
        type: AuthErrorType.invalidQr,
        message: 'QR Code tidak mengandung data yang valid.',
      );
    }

    if (!RegExp(r'^ID\d+$').hasMatch(trimmedId)) {
      throw AuthException(
        type: AuthErrorType.invalidQr,
        message: 'Format QR Code tidak dikenali: "$trimmedId". '
            'Pastikan Anda scan QR Code pada ID Card resmi.',
      );
    }

    try {
      // ── 2. Pastikan Supabase Auth aktif (untuk RLS) ──
      await SupabaseService.ensureAuthenticated();

      // ── 3. Query pegawai ──
      final response = await SupabaseService.client
          .from('pegawai')
          .select('*, jabatan:jabatan_id(id, nama)')
          .eq('id', trimmedId)
          .maybeSingle();

      if (response == null) {
        throw AuthException(
          type: AuthErrorType.notFound,
          message: 'ID "$trimmedId" tidak terdaftar dalam sistem. '
              'Hubungi HRD jika Anda merasa ini kesalahan.',
        );
      }

      final pegawai = Pegawai.fromMap(response);

      // ── 4. Cek status aktif ──
      if (!pegawai.isAktif) {
        throw AuthException(
          type: AuthErrorType.inactive,
          message: 'Akun ${pegawai.nama} berstatus "${pegawai.status}". '
              'Hubungi HRD untuk mengaktifkan kembali.',
        );
      }

      // ── 5. Device binding ──
      await _verifyDeviceBinding(pegawai);

      _currentPegawai = pegawai;
      return pegawai;
    } on AuthException {
      rethrow;
    } on SocketException {
      throw const AuthException(
        type: AuthErrorType.noConnection,
        message: 'Tidak ada koneksi internet. '
            'Periksa WiFi atau data seluler Anda, lalu coba lagi.',
      );
    } catch (e) {
      final msg = e.toString().toLowerCase();

      if (msg.contains('timeout') || msg.contains('timed out')) {
        throw const AuthException(
          type: AuthErrorType.serverError,
          message: 'Server tidak merespons. '
              'Coba lagi dalam beberapa saat.',
        );
      }

      if (msg.contains('socketexception') ||
          msg.contains('network') ||
          msg.contains('connection')) {
        throw const AuthException(
          type: AuthErrorType.noConnection,
          message: 'Koneksi terputus. '
              'Periksa jaringan internet Anda, lalu coba lagi.',
        );
      }

      throw AuthException(
        type: AuthErrorType.unknown,
        message: 'Terjadi kesalahan yang tidak terduga. '
            'Silakan coba lagi.',
      );
    }
  }

  /// Verifikasi & register device binding.
  static Future<void> _verifyDeviceBinding(Pegawai pegawai) async {
    try {
      final device = await DeviceService.getDeviceInfo();

      // Jangan register jika device info gagal diambil
      if (!device.isValid) {
        throw const AuthException(
          type: AuthErrorType.unknown,
          message: 'Gagal membaca informasi perangkat. '
              'Pastikan aplikasi memiliki izin yang diperlukan, lalu coba lagi.',
        );
      }

      // Pastikan auth aktif untuk melewati RLS pada employee_devices
      await SupabaseService.ensureAuthenticated();

      final client = SupabaseService.client;

      // Cek apakah device ini sudah dipakai pegawai LAIN yang aktif
      final deviceUsed = await client
          .from('employee_devices')
          .select('employee_id')
          .eq('device_id', device.deviceId)
          .neq('employee_id', pegawai.id)
          .eq('status', 'Aktif')
          .maybeSingle();

      if (deviceUsed != null) {
        final otherId = deviceUsed['employee_id'] as String;
        throw AuthException(
          type: AuthErrorType.deviceUsedByOther,
          message:
              'Perangkat ini sudah terdaftar untuk pegawai lain ($otherId). '
              'Satu perangkat hanya bisa digunakan oleh satu pegawai. '
              'Hubungi HRD untuk reset perangkat.',
        );
      }

      // Cek record device untuk pegawai ini
      final existing = await client
          .from('employee_devices')
          .select('id, device_id, status')
          .eq('employee_id', pegawai.id)
          .maybeSingle();

      if (existing == null) {
        // ── Belum pernah login → register device baru ──
        await client.from('employee_devices').insert({
          'employee_id': pegawai.id,
          'device_id': device.deviceId,
          'device_name': device.deviceName,
          'platform': device.platform,
          'status': 'Aktif',
          'last_seen_at': DateTime.now().toIso8601String(),
        });
        return;
      }

      // ── Sudah ada record ──
      final boundDeviceId = existing['device_id'] as String;
      final status = existing['status'] as String;
      final recordId = existing['id'] as int;

      // Cek apakah device binding non-aktif (di-reset admin via web)
      if (status != 'Aktif') {
        // Admin sudah reset → update dengan device baru
        await client.from('employee_devices').update({
          'device_id': device.deviceId,
          'device_name': device.deviceName,
          'platform': device.platform,
          'status': 'Aktif',
          'last_seen_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', recordId);
        return;
      }

      // Cek apakah device cocok
      if (boundDeviceId != device.deviceId) {
        throw AuthException(
          type: AuthErrorType.deviceBoundToOther,
          message: 'Akun ${pegawai.nama} sudah terdaftar di perangkat lain. '
              'Satu akun hanya bisa digunakan di satu perangkat. '
              'Hubungi HRD untuk reset perangkat.',
        );
      }

      // ── Device cocok → update last_seen & info device ──
      await client.from('employee_devices').update({
        'last_seen_at': DateTime.now().toIso8601String(),
        'device_name': device.deviceName,
        'platform': device.platform,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', recordId);
    } on AuthException {
      rethrow;
    } catch (e, stack) {
      debugPrint('[DeviceBinding] Error: $e');
      debugPrint('[DeviceBinding] Stack: $stack');
      throw AuthException(
        type: AuthErrorType.unknown,
        message: 'Gagal memverifikasi perangkat. Silakan coba lagi.',
      );
    }
  }

  /// Logout — hapus data pegawai dari memory.
  static void logout() {
    _currentPegawai = null;
  }
}

/// Exception khusus untuk error autentikasi.
class AuthException implements Exception {
  final AuthErrorType type;
  final String message;

  const AuthException({
    required this.type,
    required this.message,
  });

  @override
  String toString() => message;
}
