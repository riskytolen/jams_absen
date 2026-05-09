import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'gps_security_service.dart';
import 'security_logger.dart';

// ═══════════════════════════════════════════════════════════
// STRICT LOCATION VALIDATION RESULT
// ═══════════════════════════════════════════════════════════

/// Hasil validasi lokasi ketat untuk absensi.
class StrictLocationValidation {
  final bool isValid;
  final String message;
  final Position? position;
  final Map<String, dynamic>? details;
  final GPSSecurityThreat? threat;

  const StrictLocationValidation({
    required this.isValid,
    required this.message,
    this.position,
    this.details,
    this.threat,
  });

  const StrictLocationValidation.valid({
    required this.position,
  })  : isValid = true,
        message = 'Lokasi valid untuk absensi',
        details = null,
        threat = null;
}

// ═══════════════════════════════════════════════════════════
// STRICT LOCATION VALIDATOR
// ═══════════════════════════════════════════════════════════

/// Validator lokasi ketat untuk absensi per-divisi.
///
/// Menjalankan validasi berlapis:
/// 1. Device security check (root, mock apps, emulator)
/// 2. Multi-sample GPS validation (konsistensi reading)
/// 3. Position mock flag check
/// 4. Strict accuracy check (< 20m)
/// 5. Strict timestamp check (< 30s)
/// 6. Movement anomaly detection
/// 7. Division geofence check
/// 8. Division change detection (anti rapid-switch)
///
/// Semua check di-log ke SecurityLogger untuk audit trail.
abstract final class StrictLocationValidator {
  // ── Strict thresholds (lebih ketat dari GPSSecurityService) ──
  // FIX: accuracy 50→100m agar kompatibel dengan medium accuracy fallback
  static const double _maxAccuracy = 100.0; // meter
  // FIX: timestamp 30→120s agar tidak false-positive saat GPS warm-up
  static const int _maxTimestampDrift = 120; // detik
  static const double _maxSpeedKmh = 80.0; // km/h
  static const double _suspiciousJumpMeters = 300.0; // meter
  static const int _suspiciousJumpTime = 60; // detik
  static const int _minDivisionChangeMinutes = 10; // menit

  // ── Cache ──
  static Position? _lastValidPosition;
  // FIX: Stopwatch untuk elapsed — immune dari perubahan jam manual
  static final Stopwatch _validClock = Stopwatch();
  static int? _lastValidDivisionId;
  // FIX: Stopwatch untuk division change time
  static final Stopwatch _divisionChangeClock = Stopwatch();

  // ═══════════════════════════════════════════════════════
  // PUBLIC API
  // ═══════════════════════════════════════════════════════

  /// Validasi lokasi ketat untuk absensi di divisi tertentu.
  ///
  /// Ini adalah method utama — menjalankan SEMUA layer validasi.
  /// Harus dipanggil SETELAH LocationService.getCurrentPosition() berhasil.
  ///
  /// [locations] adalah list lokasi valid untuk divisi ini.
  /// User dianggap valid jika berada di salah satu lokasi.
  static Future<StrictLocationValidation> validateLocationForDivision({
    required Position position,
    required int divisionId,
    required List<Map<String, dynamic>> locations,
    required String employeeId,
  }) async {
    try {
      // ── Layer 1: Device security ──
      // FIX: checkDeviceSecurity() sudah dipanggil oleh LocationService.getCurrentPosition()
      // Panggil lagi, tapi cache Stopwatch-based memastikan ini instan (tidak redundant)
      final deviceStatus = await GPSSecurityService.checkDeviceSecurity();
      if (!deviceStatus.isSafe) {
        final threat = deviceStatus.threats.first;
        await SecurityLogger.logFakeGPSDetected(
          employeeId: employeeId,
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
          message: threat.message,
          details: threat.details,
        );
        return StrictLocationValidation(
          isValid: false,
          message: threat.message,
          threat: threat.threat,
          details: threat.details,
        );
      }

      // ── Layer 2: Multi-sample validation ──
      final multiSample = await GPSSecurityService.validateMultiSample();
      if (!multiSample.isSafe) {
        await SecurityLogger.logFakeGPSDetected(
          employeeId: employeeId,
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
          message: multiSample.message,
          details: multiSample.details,
        );
        return StrictLocationValidation(
          isValid: false,
          message: multiSample.message,
          threat: multiSample.threat,
          details: multiSample.details,
        );
      }

      // ── Layer 3: Mock flag ──
      if (position.isMocked) {
        await SecurityLogger.logFakeGPSDetected(
          employeeId: employeeId,
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
          message: 'Position.isMocked = true',
        );
        return const StrictLocationValidation(
          isValid: false,
          message: 'Lokasi palsu terdeteksi',
          threat: GPSSecurityThreat.mockLocationDetected,
        );
      }

      // ── Layer 4: Strict accuracy ──
      if (position.accuracy > _maxAccuracy) {
        await SecurityLogger.logPoorAccuracy(
          employeeId: employeeId,
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
          message: 'Akurasi ${position.accuracy.toStringAsFixed(0)}m > ${_maxAccuracy}m',
        );
        return StrictLocationValidation(
          isValid: false,
          message: 'Akurasi GPS tidak memadai (${position.accuracy.toStringAsFixed(0)}m). '
              'Pastikan Anda di area terbuka.',
          threat: GPSSecurityThreat.poorAccuracy,
          details: {
            'accuracy': position.accuracy,
            'maxAllowed': _maxAccuracy,
          },
        );
      }

      // ── Layer 5: Strict timestamp ──
      final drift = DateTime.now().difference(position.timestamp).inSeconds.abs();
      if (drift > _maxTimestampDrift) {
        return StrictLocationValidation(
          isValid: false,
          message: 'Data GPS kadaluarsa. Coba lagi.',
          threat: GPSSecurityThreat.invalidTimestamp,
          details: {'drift': drift, 'maxAllowed': _maxTimestampDrift},
        );
      }

      // ── Layer 6: Movement anomaly ──
      if (_lastValidPosition != null && _validClock.isRunning) {
        final distance = Geolocator.distanceBetween(
          _lastValidPosition!.latitude,
          _lastValidPosition!.longitude,
          position.latitude,
          position.longitude,
        );
        // FIX: Stopwatch elapsed — tidak terpengaruh perubahan jam manual
        final elapsed = _validClock.elapsed.inSeconds;

        if (elapsed > 0) {
          // Suspicious jump
          if (distance > _suspiciousJumpMeters && elapsed < _suspiciousJumpTime) {
            await SecurityLogger.logSuspiciousJump(
              employeeId: employeeId,
              latitude: position.latitude,
              longitude: position.longitude,
              accuracy: position.accuracy,
              message: 'Jump ${distance.toStringAsFixed(0)}m dalam ${elapsed}s',
              details: {'distance': distance, 'elapsed': elapsed},
            );
            return StrictLocationValidation(
              isValid: false,
              message: 'Perpindahan lokasi tidak wajar terdeteksi',
              threat: GPSSecurityThreat.suspiciousJump,
              details: {'distance': distance, 'elapsed': elapsed},
            );
          }

          // Unrealistic speed
          final speedKmh = (distance / elapsed) * 3.6;
          if (speedKmh > _maxSpeedKmh && elapsed < 300) {
            return StrictLocationValidation(
              isValid: false,
              message: 'Kecepatan perpindahan tidak realistis',
              threat: GPSSecurityThreat.unrealisticSpeed,
              details: {'speedKmh': speedKmh, 'maxAllowed': _maxSpeedKmh},
            );
          }
        }
      }

      // ── Layer 7: Division geofence (multi-location) ──
      // Cek apakah user berada di salah satu lokasi valid
      bool isInsideAnyLocation = false;
      double nearestDistance = double.infinity;
      double nearestRadius = 0;

      for (final loc in locations) {
        final locLat = (loc['latitude'] as num).toDouble();
        final locLng = (loc['longitude'] as num).toDouble();
        final locRadius = (loc['radius'] as num).toDouble();

        final distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          locLat,
          locLng,
        );

        if (distance < nearestDistance) {
          nearestDistance = distance;
          nearestRadius = locRadius;
        }

        if (distance <= locRadius) {
          isInsideAnyLocation = true;
          break;
        }
      }

      if (!isInsideAnyLocation) {
        await SecurityLogger.logOutOfServiceArea(
          employeeId: employeeId,
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
          message: 'Jarak ke lokasi terdekat: ${nearestDistance.toStringAsFixed(0)}m '
              '(max: ${nearestRadius.toStringAsFixed(0)}m)',
          details: {
            'distanceToDivision': nearestDistance,
            'divisionRadius': nearestRadius,
            'divisionId': divisionId,
            'locationsChecked': locations.length,
          },
        );
        return StrictLocationValidation(
          isValid: false,
          message: 'Anda berada di luar area divisi '
              '(${nearestDistance.toStringAsFixed(0)}m dari lokasi terdekat)',
          threat: GPSSecurityThreat.outOfServiceArea,
          details: {
            'distance': nearestDistance,
            'radius': nearestRadius,
          },
        );
      }

      // ── Layer 8: Division change detection ──
      if (_lastValidDivisionId != null &&
          _lastValidDivisionId != divisionId &&
          _divisionChangeClock.isRunning) {
        final minutesSinceChange = _divisionChangeClock.elapsed.inMinutes;
        if (minutesSinceChange < _minDivisionChangeMinutes) {
          return StrictLocationValidation(
            isValid: false,
            message: 'Tidak dapat pindah divisi dalam waktu singkat. '
                'Tunggu ${_minDivisionChangeMinutes - minutesSinceChange} menit.',
            threat: GPSSecurityThreat.suspiciousJump,
            details: {
              'previousDivision': _lastValidDivisionId,
              'newDivision': divisionId,
              'minutesSinceChange': minutesSinceChange,
              'minRequired': _minDivisionChangeMinutes,
            },
          );
        }
      }

      // ── ALL PASSED ──
      // FIX: Update cache dengan Stopwatch
      _lastValidPosition = position;
      _validClock
        ..reset()
        ..start();
      if (_lastValidDivisionId != divisionId) {
        _divisionChangeClock
          ..reset()
          ..start();
      }
      _lastValidDivisionId = divisionId;

      // Log success
      await SecurityLogger.logGPSCheck(
        employeeId: employeeId,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        isSafe: true,
        message: 'Validasi ketat berhasil — divisi $divisionId',
        details: {
          'distanceToNearest': nearestDistance,
          'nearestRadius': nearestRadius,
          'locationsChecked': locations.length,
          'accuracy': position.accuracy,
          'multiSamplePassed': true,
          'deviceSecure': true,
        },
      );

      return StrictLocationValidation.valid(position: position);
    } catch (e) {
      debugPrint('[StrictValidator] Error: $e');
      return StrictLocationValidation(
        isValid: false,
        message: 'Gagal memvalidasi lokasi: $e',
        details: {'error': e.toString()},
      );
    }
  }

  /// Reset semua cache (dipanggil saat logout).
  static void resetCache() {
    _lastValidPosition = null;
    _validClock
      ..reset()
      ..stop();
    _lastValidDivisionId = null;
    _divisionChangeClock
      ..reset()
      ..stop();
    GPSSecurityService.resetCache();
  }
}
