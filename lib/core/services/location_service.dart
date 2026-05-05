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
/// 3. Ambil posisi GPS
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
  /// Flow:
  /// 1. Device security check
  /// 2. Get GPS position
  /// 3. Validate position (mock, accuracy, timestamp, movement)
  /// 4. Log result
  ///
  /// Throws [LocationException] jika gagal atau terdeteksi ancaman.
  static Future<Position> getCurrentPosition({
    List<Map<String, double>>? allowedAreas,
  }) async {
    // ── Step 1: Device security pre-check ──
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

    // ── Step 2: Get GPS position ──
    final Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } on TimeoutException {
      throw const LocationException(
        type: LocationErrorType.timeout,
        message: 'Timeout mengambil lokasi. Pastikan GPS aktif dan di area terbuka.',
      );
    } catch (e) {
      throw LocationException(
        type: LocationErrorType.unknown,
        message: 'Gagal mengambil lokasi: $e',
      );
    }

    // ── Step 3: Validate position ──
    final result = await GPSSecurityService.validatePosition(
      position,
      allowedAreas: allowedAreas,
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
