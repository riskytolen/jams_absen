import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'gps_security_service.dart';
import 'security_logger.dart';

// ═══════════════════════════════════════════════════════════
// LOCATION ERROR TYPES
// ═══════════════════════════════════════════════════════════

/// Tipe error lokasi.
enum LocationErrorType {
  /// GPS/Location service tidak aktif.
  serviceDisabled,

  /// Permission ditolak.
  permissionDenied,

  /// Permission ditolak permanen.
  permissionDeniedForever,

  /// Timeout saat mengambil lokasi.
  timeout,

  /// Fake GPS / mock location terdeteksi.
  fakeGPSDetected,

  /// Akurasi GPS terlalu rendah.
  poorAccuracy,

  /// Aktivitas mencurigakan (speed, jump, dll).
  suspiciousActivity,

  /// Device tidak aman (root, emulator, mock apps).
  deviceCompromised,

  /// Error tidak diketahui.
  unknown,
}

/// Exception khusus untuk error lokasi.
class LocationException implements Exception {
  final LocationErrorType type;
  final String message;
  final Map<String, dynamic>? details;

  const LocationException({
    required this.type,
    required this.message,
    this.details,
  });

  @override
  String toString() => 'LocationException($type): $message';
}

// ═══════════════════════════════════════════════════════════
// LOCATION SERVICE
// ═══════════════════════════════════════════════════════════

/// Service untuk mengambil lokasi dengan validasi keamanan.
///
/// Flow:
/// 1. Cek GPS enabled + permission
/// 2. Cek device security (root, mock apps, emulator)
/// 3. Ambil posisi GPS — dengan smart fallback accuracy
/// 4. Validasi keamanan (mock flag, accuracy, timestamp, movement)
/// 5. Return posisi yang sudah tervalidasi
abstract final class LocationService {
  static String? _employeeId;

  /// Set employee ID untuk logging.
  static void setEmployeeId(String employeeId) {
    _employeeId = employeeId;
  }

  /// Pastikan GPS ready (service aktif + permission granted).
  ///
  /// Throws [LocationException] jika tidak ready.
  static Future<void> ensureReady() async {
    // Check service enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationException(
        type: LocationErrorType.serviceDisabled,
        message: 'Layanan lokasi tidak aktif. Aktifkan GPS Anda.',
      );
    }

    // Check permission
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const LocationException(
          type: LocationErrorType.permissionDenied,
          message: 'Izin lokasi ditolak. Aplikasi membutuhkan akses lokasi.',
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(
        type: LocationErrorType.permissionDeniedForever,
        message: 'Izin lokasi ditolak permanen. Buka pengaturan untuk mengizinkan.',
      );
    }
  }

  /// Ambil posisi GPS dengan validasi keamanan penuh.
  ///
  /// FIX v1.6.1:
  /// - checkDeviceSecurity() hanya dipanggil 1x (tidak redundant)
  /// - Smart fallback: high → medium accuracy jika timeout
  /// - validatePosition() menerima deviceStatus dari luar (no double call)
  ///
  /// Throws [LocationException] jika gagal atau terdeteksi ancaman.
  static Future<Position> getCurrentPosition({
    List<Map<String, double>>? allowedAreas,
  }) async {
    // ── Step 1: Device security check (1x saja) ──
    final deviceStatus = await GPSSecurityService.checkDeviceSecurity();
    if (!deviceStatus.isSafe) {
      final threat = deviceStatus.threats.first;
      _logThreat(threat);
      throw LocationException(
        type: _mapThreatToErrorType(threat.threat),
        message: threat.message,
        details: threat.details,
      );
    }

    // ── Step 2: Get GPS position (smart fallback) ──
    final Position position;
    try {
      position = await _getPositionWithFallback();
    } on TimeoutException {
      throw const LocationException(
        type: LocationErrorType.timeout,
        message: 'Timeout mengambil lokasi. Pastikan GPS aktif dan di area terbuka.',
      );
    } on LocationException {
      rethrow;
    } catch (e) {
      throw LocationException(
        type: LocationErrorType.unknown,
        message: 'Gagal mengambil lokasi: $e',
      );
    }

    // ── Step 3: Validate position (teruskan deviceStatus — TIDAK cek ulang) ──
    final result = await GPSSecurityService.validatePosition(
      position,
      allowedAreas: allowedAreas,
      cachedDeviceStatus: deviceStatus, // ← kirim hasil cek sebelumnya
    );

    // ── Step 4: Log & handle result ──
    if (!result.isSafe) {
      _logThreat(result);
      throw LocationException(
        type: _mapThreatToErrorType(result.threat),
        message: result.message,
        details: result.details,
      );
    }

    // Log success
    if (_employeeId != null) {
      SecurityLogger.logGPSCheck(
        employeeId: _employeeId!,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        isSafe: true,
        message: 'Position acquired & validated',
      );
    }

    return position;
  }

  /// Ambil posisi GPS.
  ///
  /// Strategy:
  /// 1. Coba `getLastKnownPosition()` — instan, untuk warm-up GPS chip
  /// 2. Panggil `getCurrentPosition()` 1x dengan HIGH accuracy, timeout 30s
  ///
  /// Catatan: Dua panggilan `getCurrentPosition()` berturut-turut (fallback)
  /// terbukti menyebabkan interference — request pertama tidak di-cleanup
  /// sempurna sehingga request kedua juga gagal. Gunakan SATU panggilan saja.
  static Future<Position> _getPositionWithFallback() async {
    // Warm-up: request last known position agar GPS chip mulai aktif
    // (tidak digunakan sebagai hasil, hanya untuk "wake up" hardware)
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        debugPrint('[LocationService] Last known: ±${last.accuracy.toStringAsFixed(0)}m '
            '(${DateTime.now().difference(last.timestamp).inSeconds}s ago)');
      }
    } catch (_) {
      // Abaikan — ini hanya warm-up, bukan hasil akhir
    }

    // Satu panggilan saja dengan timeout 30 detik
    debugPrint('[LocationService] Getting position (HIGH accuracy, timeout: 30s)...');
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 30),
        ),
      );
      debugPrint('[LocationService] OK: ±${pos.accuracy.toStringAsFixed(0)}m');
      return pos;
    } on TimeoutException {
      debugPrint('[LocationService] Timeout setelah 30s');
      throw const LocationException(
        type: LocationErrorType.timeout,
        message:
            'Gagal mendapatkan lokasi (timeout 30s). Pastikan GPS aktif '
            'dan coba di area terbuka atau dekat jendela.',
      );
    }
  }

  /// Buka settings lokasi device.
  static Future<bool> openLocationSettings() {
    return Geolocator.openLocationSettings();
  }

  /// Buka settings aplikasi.
  static Future<bool> openAppSettings() {
    return Geolocator.openAppSettings();
  }

  /// Reset security cache (panggil saat logout).
  static void resetSecurityCache() {
    GPSSecurityService.resetCache();
    _employeeId = null;
  }

  // ═══════════════════════════════════════════════════════
  // PRIVATE HELPERS
  // ═══════════════════════════════════════════════════════

  static LocationErrorType _mapThreatToErrorType(GPSSecurityThreat threat) {
    switch (threat) {
      case GPSSecurityThreat.mockLocationDetected:
      case GPSSecurityThreat.mockAppInstalled:
        return LocationErrorType.fakeGPSDetected;
      case GPSSecurityThreat.deviceRooted:
      case GPSSecurityThreat.emulatorDetected:
      case GPSSecurityThreat.developerOptionsEnabled:
        return LocationErrorType.deviceCompromised;
      case GPSSecurityThreat.poorAccuracy:
        return LocationErrorType.poorAccuracy;
      case GPSSecurityThreat.unrealisticSpeed:
      case GPSSecurityThreat.suspiciousJump:
      case GPSSecurityThreat.outOfServiceArea:
      case GPSSecurityThreat.invalidTimestamp:
      case GPSSecurityThreat.inconsistentReadings:
        return LocationErrorType.suspiciousActivity;
      case GPSSecurityThreat.none:
        return LocationErrorType.unknown;
    }
  }

  static void _logThreat(GPSSecurityResult result) {
    if (_employeeId == null) return;

    debugPrint('[LocationService] THREAT: ${result.threat} — ${result.message}');

    switch (result.threat) {
      case GPSSecurityThreat.mockLocationDetected:
      case GPSSecurityThreat.mockAppInstalled:
      case GPSSecurityThreat.deviceRooted:
      case GPSSecurityThreat.emulatorDetected:
        SecurityLogger.logFakeGPSDetected(
          employeeId: _employeeId!,
          latitude: 0,
          longitude: 0,
          accuracy: 0,
          message: result.message,
          details: result.details,
        );
        break;
      case GPSSecurityThreat.poorAccuracy:
        SecurityLogger.logPoorAccuracy(
          employeeId: _employeeId!,
          latitude: 0,
          longitude: 0,
          accuracy: result.details['accuracy'] as double? ?? 0,
          message: result.message,
        );
        break;
      case GPSSecurityThreat.suspiciousJump:
        SecurityLogger.logSuspiciousJump(
          employeeId: _employeeId!,
          latitude: 0,
          longitude: 0,
          accuracy: 0,
          message: result.message,
          details: result.details,
        );
        break;
      case GPSSecurityThreat.unrealisticSpeed:
        SecurityLogger.logUnrealisticSpeed(
          employeeId: _employeeId!,
          latitude: 0,
          longitude: 0,
          accuracy: 0,
          message: result.message,
          details: result.details,
        );
        break;
      case GPSSecurityThreat.outOfServiceArea:
        SecurityLogger.logOutOfServiceArea(
          employeeId: _employeeId!,
          latitude: 0,
          longitude: 0,
          accuracy: 0,
          message: result.message,
          details: result.details,
        );
        break;
      default:
        SecurityLogger.logGPSCheck(
          employeeId: _employeeId!,
          latitude: 0,
          longitude: 0,
          accuracy: 0,
          isSafe: false,
          message: result.message,
          details: result.details,
        );
    }
  }
}
