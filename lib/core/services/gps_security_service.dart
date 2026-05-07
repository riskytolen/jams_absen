import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

// ═══════════════════════════════════════════════════════════
// ENUMS & MODELS
// ═══════════════════════════════════════════════════════════

/// Tipe ancaman keamanan GPS yang terdeteksi.
enum GPSSecurityThreat {
  /// Mock location / fake GPS terdeteksi.
  mockLocationDetected,

  /// Aplikasi fake GPS terinstall di device.
  mockAppInstalled,

  /// Developer options aktif (bisa enable mock location).
  developerOptionsEnabled,

  /// Device di-root (bisa bypass semua security).
  deviceRooted,

  /// Berjalan di emulator.
  emulatorDetected,

  /// Akurasi GPS terlalu buruk.
  poorAccuracy,

  /// Kecepatan pergerakan tidak realistis.
  unrealisticSpeed,

  /// Perubahan lokasi tiba-tiba (teleportasi).
  suspiciousJump,

  /// Lokasi di luar area kerja yang diizinkan.
  outOfServiceArea,

  /// Timestamp lokasi tidak valid / stale.
  invalidTimestamp,

  /// Multi-sample GPS tidak konsisten.
  inconsistentReadings,

  /// Tidak ada threat.
  none,
}

/// Severity level dari threat.
enum ThreatSeverity {
  /// Langsung blokir — tidak bisa absen.
  critical,

  /// Warning — bisa absen tapi di-flag.
  warning,

  /// Informational — dicatat saja.
  info,
}

/// Result dari security check.
class GPSSecurityResult {
  final GPSSecurityThreat threat;
  final ThreatSeverity severity;
  final String message;
  final bool isSafe;
  final Map<String, dynamic> details;

  const GPSSecurityResult({
    required this.threat,
    required this.severity,
    required this.message,
    required this.isSafe,
    this.details = const {},
  });

  const GPSSecurityResult.safe()
      : threat = GPSSecurityThreat.none,
        severity = ThreatSeverity.info,
        message = 'Lokasi valid',
        isSafe = true,
        details = const {};
}

/// Status keamanan device secara keseluruhan.
class DeviceSecurityStatus {
  final bool developerOptionsEnabled;
  final bool isRooted;
  final bool isEmulator;
  final List<String> mockAppsInstalled;
  final bool isSafe;
  final List<GPSSecurityResult> threats;

  const DeviceSecurityStatus({
    required this.developerOptionsEnabled,
    required this.isRooted,
    required this.isEmulator,
    required this.mockAppsInstalled,
    required this.isSafe,
    required this.threats,
  });
}

// ═══════════════════════════════════════════════════════════
// GPS SECURITY SERVICE — Multi-layer anti-fake GPS
// ═══════════════════════════════════════════════════════════

/// Service keamanan GPS multi-layer.
///
/// Layer 1: Device integrity (root, emulator, developer options)
/// Layer 2: Mock app detection (scan installed fake GPS apps)
/// Layer 3: Position flag check (isMocked dari OS)
/// Layer 4: Multi-sample validation (ambil beberapa reading, cek konsistensi)
/// Layer 5: Movement analysis (speed, jump, accuracy, timestamp)
/// Layer 6: Geofence validation (area kerja)
abstract final class GPSSecurityService {
  // ── Thresholds ──
  static const double maxAccuracyMeters = 50.0;
  static const double maxSpeedKmh = 120.0;
  static const double _maxSpeedMs = maxSpeedKmh / 3.6;
  static const double suspiciousJumpMeters = 500.0;
  static const int suspiciousJumpTimeSeconds = 90;
  static const int maxTimestampDriftSeconds = 60;
  static const int multiSampleCount = 3;
  static const double multiSampleMaxVarianceMeters = 50.0;

  // ── Platform channel ──
  static const _securityChannel = MethodChannel('com.jamsabsen/security');

  // ── Position history cache ──
  static Position? _lastPosition;
  static DateTime? _lastPositionTime;
  static DeviceSecurityStatus? _cachedDeviceStatus;
  static DateTime? _lastDeviceCheckTime;

  // ═══════════════════════════════════════════════════════
  // PUBLIC API
  // ═══════════════════════════════════════════════════════

  /// Full security validation — semua layer.
  ///
  /// Ini adalah method utama yang dipanggil sebelum absensi.
  /// Menjalankan semua check secara berurutan (fail-fast).
  static Future<GPSSecurityResult> validatePosition(
    Position position, {
    List<Map<String, double>>? allowedAreas,
  }) async {
    // Layer 1: Device integrity
    final deviceStatus = await checkDeviceSecurity();
    if (!deviceStatus.isSafe) {
      return deviceStatus.threats.first;
    }

    // Layer 2: Position mock flag dari OS
    final mockCheck = _checkMockFlag(position);
    if (!mockCheck.isSafe) return mockCheck;

    // Layer 3: Accuracy check
    final accuracyCheck = _checkAccuracy(position);
    if (!accuracyCheck.isSafe) return accuracyCheck;

    // Layer 4: Timestamp freshness
    final timestampCheck = _checkTimestamp(position);
    if (!timestampCheck.isSafe) return timestampCheck;

    // Layer 5: Movement analysis (speed + jump)
    final movementCheck = _checkMovement(position);
    if (!movementCheck.isSafe) return movementCheck;

    // Layer 6: Geofence (jika ada area yang ditentukan)
    if (allowedAreas != null && allowedAreas.isNotEmpty) {
      final areaCheck = _checkServiceArea(position, allowedAreas);
      if (!areaCheck.isSafe) return areaCheck;
    }

    // All passed — update cache
    _lastPosition = position;
    _lastPositionTime = DateTime.now();

    return const GPSSecurityResult.safe();
  }

  /// Multi-sample validation — ambil beberapa GPS reading dan cek konsistensi.
  ///
  /// Fake GPS sering memberikan koordinat yang PERSIS sama (0 variance),
  /// atau sebaliknya sangat tidak konsisten.
  static Future<GPSSecurityResult> validateMultiSample() async {
    final positions = <Position>[];

    for (int i = 0; i < multiSampleCount; i++) {
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 5),
          ),
        );
        positions.add(pos);

        // Delay antar sample
        if (i < multiSampleCount - 1) {
          await Future.delayed(const Duration(milliseconds: 800));
        }
      } catch (e) {
        // Jika gagal ambil sample, skip
        debugPrint('[GPS Security] Multi-sample #$i failed: $e');
      }
    }

    if (positions.length < 2) {
      return const GPSSecurityResult(
        threat: GPSSecurityThreat.inconsistentReadings,
        severity: ThreatSeverity.warning,
        message: 'Tidak dapat mengambil multiple GPS reading',
        isSafe: false,
        details: {'reason': 'insufficient_samples'},
      );
    }

    // Cek konsistensi: semua sample harus dalam radius wajar
    final base = positions.first;
    double maxDistance = 0;
    bool allExactlySame = true;

    for (int i = 1; i < positions.length; i++) {
      final dist = Geolocator.distanceBetween(
        base.latitude,
        base.longitude,
        positions[i].latitude,
        positions[i].longitude,
      );
      if (dist > maxDistance) maxDistance = dist;
      if (dist > 0.01) allExactlySame = false; // > 1cm difference
    }

    // Warning: Semua reading PERSIS sama (fake GPS sering begini)
    // Tapi GPS asli di indoor juga bisa sangat stabil, jadi hanya warning.
    // Yang memblokir adalah Position.isMocked flag di bawah.
    if (allExactlySame && positions.length >= 3) {
      debugPrint('[GPS Security] Warning: All samples identical (may be indoor GPS)');
      // Tidak langsung blokir — biarkan isMocked check yang menentukan
    }

    // Red flag: Variance terlalu besar (GPS jumping)
    if (maxDistance > multiSampleMaxVarianceMeters) {
      return GPSSecurityResult(
        threat: GPSSecurityThreat.inconsistentReadings,
        severity: ThreatSeverity.critical,
        message: 'GPS tidak stabil — variance ${maxDistance.toStringAsFixed(0)}m',
        isSafe: false,
        details: {
          'sampleCount': positions.length,
          'maxVariance': maxDistance,
          'reason': 'high_variance',
        },
      );
    }

    // Cek mock flag di semua sample
    for (final pos in positions) {
      if (pos.isMocked) {
        return const GPSSecurityResult(
          threat: GPSSecurityThreat.mockLocationDetected,
          severity: ThreatSeverity.critical,
          message: 'Mock location terdeteksi pada GPS sample',
          isSafe: false,
          details: {'reason': 'mocked_sample'},
        );
      }
    }

    return const GPSSecurityResult.safe();
  }

  /// Check device security status (root, emulator, mock apps, dev options).
  ///
  /// Di-cache selama 1 menit untuk performa.
  /// Cache pendek agar perubahan status cepat terdeteksi.
  static Future<DeviceSecurityStatus> checkDeviceSecurity() async {
    // Return cache jika masih fresh (< 1 menit)
    if (_cachedDeviceStatus != null && _lastDeviceCheckTime != null) {
      final elapsed = DateTime.now().difference(_lastDeviceCheckTime!);
      if (elapsed.inSeconds < 60) return _cachedDeviceStatus!;
    }

    try {
      final result = await _securityChannel.invokeMethod('getSecurityStatus');
      final data = Map<String, dynamic>.from(result as Map);

      final devOptions = data['developerOptionsEnabled'] as bool? ?? false;
      final isRooted = data['isRooted'] as bool? ?? false;
      final isEmulator = data['isEmulator'] as bool? ?? false;
      final mockApps = List<String>.from(data['mockAppsInstalled'] as List? ?? []);

      final threats = <GPSSecurityResult>[];

      // Critical: Device rooted
      if (isRooted) {
        threats.add(const GPSSecurityResult(
          threat: GPSSecurityThreat.deviceRooted,
          severity: ThreatSeverity.critical,
          message: 'Device terdeteksi di-root — tidak dapat melakukan absensi',
          isSafe: false,
          details: {'check': 'root_detection'},
        ));
      }

      // Critical: Emulator
      if (isEmulator) {
        threats.add(const GPSSecurityResult(
          threat: GPSSecurityThreat.emulatorDetected,
          severity: ThreatSeverity.critical,
          message: 'Emulator terdeteksi — gunakan device fisik',
          isSafe: false,
          details: {'check': 'emulator_detection'},
        ));
      }

      // Warning: Mock apps installed (TIDAK blokir — hanya warning)
      // Yang memblokir adalah jika Position.isMocked = true (fake GPS aktif)
      if (mockApps.isNotEmpty) {
        threats.add(GPSSecurityResult(
          threat: GPSSecurityThreat.mockAppInstalled,
          severity: ThreatSeverity.warning,
          message: 'Aplikasi fake GPS terdeteksi (${mockApps.length} app). '
              'Disarankan untuk menghapus aplikasi tersebut.',
          isSafe: true, // Warning saja, tidak blokir
          details: {
            'check': 'mock_app_scan',
            'apps': mockApps,
            'count': mockApps.length,
          },
        ));
      }

      // Warning: Developer options
      if (devOptions && !isRooted) {
        threats.add(const GPSSecurityResult(
          threat: GPSSecurityThreat.developerOptionsEnabled,
          severity: ThreatSeverity.warning,
          message: 'Developer options aktif — harap nonaktifkan',
          isSafe: true, // Warning saja, tidak blokir
          details: {'check': 'developer_options'},
        ));
      }

      final isSafe = threats.isEmpty ||
          threats.every((t) => t.severity != ThreatSeverity.critical);

      final status = DeviceSecurityStatus(
        developerOptionsEnabled: devOptions,
        isRooted: isRooted,
        isEmulator: isEmulator,
        mockAppsInstalled: mockApps,
        isSafe: isSafe,
        threats: threats,
      );

      _cachedDeviceStatus = status;
      _lastDeviceCheckTime = DateTime.now();

      return status;
    } catch (e) {
      debugPrint('[GPS Security] Platform channel error: $e');
      // Jika platform channel gagal, anggap aman (graceful degradation)
      // tapi log sebagai warning
      const status = DeviceSecurityStatus(
        developerOptionsEnabled: false,
        isRooted: false,
        isEmulator: false,
        mockAppsInstalled: [],
        isSafe: true,
        threats: [],
      );
      _cachedDeviceStatus = status;
      _lastDeviceCheckTime = DateTime.now();
      return status;
    }
  }

  /// Reset semua cache (dipanggil saat logout).
  static void resetCache() {
    _lastPosition = null;
    _lastPositionTime = null;
    _cachedDeviceStatus = null;
    _lastDeviceCheckTime = null;
  }

  // ═══════════════════════════════════════════════════════
  // PRIVATE CHECKS
  // ═══════════════════════════════════════════════════════

  /// Check mock flag dari OS (Position.isMocked).
  static GPSSecurityResult _checkMockFlag(Position position) {
    if (position.isMocked) {
      return const GPSSecurityResult(
        threat: GPSSecurityThreat.mockLocationDetected,
        severity: ThreatSeverity.critical,
        message: 'Lokasi palsu terdeteksi oleh sistem',
        isSafe: false,
        details: {'check': 'os_mock_flag', 'isMocked': true},
      );
    }
    return const GPSSecurityResult.safe();
  }

  /// Check akurasi GPS.
  static GPSSecurityResult _checkAccuracy(Position position) {
    if (position.accuracy > maxAccuracyMeters) {
      return GPSSecurityResult(
        threat: GPSSecurityThreat.poorAccuracy,
        severity: ThreatSeverity.critical,
        message: 'Akurasi GPS terlalu rendah (${position.accuracy.toStringAsFixed(0)}m)',
        isSafe: false,
        details: {
          'check': 'accuracy',
          'accuracy': position.accuracy,
          'maxAllowed': maxAccuracyMeters,
        },
      );
    }
    return const GPSSecurityResult.safe();
  }

  /// Check timestamp freshness.
  static GPSSecurityResult _checkTimestamp(Position position) {
    final now = DateTime.now();
    final posTime = position.timestamp;
    final drift = now.difference(posTime).inSeconds.abs();

    if (drift > maxTimestampDriftSeconds) {
      return GPSSecurityResult(
        threat: GPSSecurityThreat.invalidTimestamp,
        severity: ThreatSeverity.critical,
        message: 'Data GPS kadaluarsa (${drift}s)',
        isSafe: false,
        details: {
          'check': 'timestamp',
          'driftSeconds': drift,
          'maxAllowed': maxTimestampDriftSeconds,
          'positionTime': posTime.toIso8601String(),
        },
      );
    }
    return const GPSSecurityResult.safe();
  }

  /// Check movement (speed + suspicious jump).
  static GPSSecurityResult _checkMovement(Position position) {
    if (_lastPosition == null || _lastPositionTime == null) {
      return const GPSSecurityResult.safe();
    }

    final distance = Geolocator.distanceBetween(
      _lastPosition!.latitude,
      _lastPosition!.longitude,
      position.latitude,
      position.longitude,
    );

    final elapsed = DateTime.now().difference(_lastPositionTime!).inSeconds;

    // Hindari division by zero
    if (elapsed <= 0) return const GPSSecurityResult.safe();

    // Check suspicious jump (teleportasi)
    if (distance > suspiciousJumpMeters && elapsed < suspiciousJumpTimeSeconds) {
      return GPSSecurityResult(
        threat: GPSSecurityThreat.suspiciousJump,
        severity: ThreatSeverity.critical,
        message: 'Perpindahan lokasi mencurigakan (${distance.toStringAsFixed(0)}m dalam ${elapsed}s)',
        isSafe: false,
        details: {
          'check': 'suspicious_jump',
          'distance': distance,
          'elapsed': elapsed,
          'maxDistance': suspiciousJumpMeters,
          'maxTime': suspiciousJumpTimeSeconds,
        },
      );
    }

    // Check unrealistic speed
    final speedMs = distance / elapsed;
    if (speedMs > _maxSpeedMs) {
      final speedKmh = speedMs * 3.6;
      return GPSSecurityResult(
        threat: GPSSecurityThreat.unrealisticSpeed,
        severity: ThreatSeverity.critical,
        message: 'Kecepatan tidak realistis (${speedKmh.toStringAsFixed(0)} km/h)',
        isSafe: false,
        details: {
          'check': 'speed',
          'speedKmh': speedKmh,
          'maxAllowed': maxSpeedKmh,
          'distance': distance,
          'elapsed': elapsed,
        },
      );
    }

    return const GPSSecurityResult.safe();
  }

  /// Check apakah posisi dalam area yang diizinkan.
  static GPSSecurityResult _checkServiceArea(
    Position position,
    List<Map<String, double>> allowedAreas,
  ) {
    for (final area in allowedAreas) {
      final lat = area['latitude'];
      final lng = area['longitude'];
      final radius = area['radius'];

      if (lat == null || lng == null || radius == null) continue;

      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        lat,
        lng,
      );

      if (distance <= radius) {
        return const GPSSecurityResult.safe();
      }
    }

    return GPSSecurityResult(
      threat: GPSSecurityThreat.outOfServiceArea,
      severity: ThreatSeverity.critical,
      message: 'Lokasi di luar area kerja yang diizinkan',
      isSafe: false,
      details: {
        'check': 'geofence',
        'latitude': position.latitude,
        'longitude': position.longitude,
        'areasChecked': allowedAreas.length,
      },
    );
  }
}
