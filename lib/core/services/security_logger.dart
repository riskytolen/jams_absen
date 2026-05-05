import 'package:flutter/foundation.dart';
import 'supabase_service.dart';

/// Model untuk security log.
class SecurityLog {
  final String employeeId;
  final String eventType;
  final String status; // 'success', 'warning', 'threat'
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final String? threatType;
  final String? message;
  final Map<String, dynamic>? details;
  final DateTime timestamp;

  SecurityLog({
    required this.employeeId,
    required this.eventType,
    required this.status,
    this.latitude,
    this.longitude,
    this.accuracy,
    this.threatType,
    this.message,
    this.details,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'employee_id': employeeId,
      'event_type': eventType,
      'status': status,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'threat_type': threatType,
      'message': message,
      'details': details,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

/// Service untuk logging keamanan GPS ke Supabase.
///
/// Semua method bersifat fire-and-forget — tidak pernah throw.
/// Logging error tidak boleh mengganggu flow utama aplikasi.
abstract final class SecurityLogger {
  // ═══════════════════════════════════════════════════════
  // LOG METHODS
  // ═══════════════════════════════════════════════════════

  /// Log GPS check (success atau threat).
  static Future<void> logGPSCheck({
    required String employeeId,
    required double latitude,
    required double longitude,
    required double accuracy,
    required bool isSafe,
    String? message,
    Map<String, dynamic>? details,
  }) async {
    await _save(SecurityLog(
      employeeId: employeeId,
      eventType: 'gps_check',
      status: isSafe ? 'success' : 'threat',
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      message: message,
      details: details,
    ));
  }

  /// Log deteksi fake GPS / mock location.
  static Future<void> logFakeGPSDetected({
    required String employeeId,
    required double latitude,
    required double longitude,
    required double accuracy,
    required String message,
    Map<String, dynamic>? details,
  }) async {
    await _save(SecurityLog(
      employeeId: employeeId,
      eventType: 'fake_gps_detected',
      status: 'threat',
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      threatType: 'mock_location',
      message: message,
      details: details,
    ));
  }

  /// Log poor accuracy.
  static Future<void> logPoorAccuracy({
    required String employeeId,
    required double latitude,
    required double longitude,
    required double accuracy,
    required String message,
  }) async {
    await _save(SecurityLog(
      employeeId: employeeId,
      eventType: 'poor_accuracy',
      status: 'warning',
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      threatType: 'poor_accuracy',
      message: message,
      details: {'accuracy': accuracy},
    ));
  }

  /// Log suspicious jump (teleportasi).
  static Future<void> logSuspiciousJump({
    required String employeeId,
    required double latitude,
    required double longitude,
    required double accuracy,
    required String message,
    Map<String, dynamic>? details,
  }) async {
    await _save(SecurityLog(
      employeeId: employeeId,
      eventType: 'suspicious_jump',
      status: 'threat',
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      threatType: 'suspicious_jump',
      message: message,
      details: details,
    ));
  }

  /// Log unrealistic speed.
  static Future<void> logUnrealisticSpeed({
    required String employeeId,
    required double latitude,
    required double longitude,
    required double accuracy,
    required String message,
    Map<String, dynamic>? details,
  }) async {
    await _save(SecurityLog(
      employeeId: employeeId,
      eventType: 'unrealistic_speed',
      status: 'threat',
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      threatType: 'unrealistic_speed',
      message: message,
      details: details,
    ));
  }

  /// Log out of service area.
  static Future<void> logOutOfServiceArea({
    required String employeeId,
    required double latitude,
    required double longitude,
    required double accuracy,
    required String message,
    Map<String, dynamic>? details,
  }) async {
    await _save(SecurityLog(
      employeeId: employeeId,
      eventType: 'out_of_service_area',
      status: 'threat',
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      threatType: 'out_of_service_area',
      message: message,
      details: details,
    ));
  }

  /// Log device compromised (root, emulator, mock apps).
  static Future<void> logDeviceCompromised({
    required String employeeId,
    required String threatType,
    required String message,
    Map<String, dynamic>? details,
  }) async {
    await _save(SecurityLog(
      employeeId: employeeId,
      eventType: 'device_compromised',
      status: 'threat',
      threatType: threatType,
      message: message,
      details: details,
    ));
  }

  // ═══════════════════════════════════════════════════════
  // QUERY METHODS (untuk admin)
  // ═══════════════════════════════════════════════════════

  /// Get security logs untuk employee.
  static Future<List<SecurityLog>> getEmployeeLogs(
    String employeeId, {
    int limit = 100,
    String? threatType,
  }) async {
    try {
      await SupabaseService.ensureAuthenticated();

      var query = SupabaseService.client
          .from('security_logs')
          .select()
          .eq('employee_id', employeeId)
          .order('timestamp', ascending: false)
          .limit(limit);

      final response = await query;

      var logs = (response as List)
          .map((e) => _fromMap(e as Map<String, dynamic>))
          .toList();

      if (threatType != null) {
        logs = logs.where((log) => log.threatType == threatType).toList();
      }

      return logs;
    } catch (e) {
      debugPrint('[SecurityLogger] Error getting logs: $e');
      return [];
    }
  }

  /// Get threat summary (count per threat type).
  static Future<Map<String, int>> getThreatSummary(String employeeId) async {
    try {
      await SupabaseService.ensureAuthenticated();

      final response = await SupabaseService.client
          .from('security_logs')
          .select('threat_type')
          .eq('employee_id', employeeId)
          .eq('status', 'threat');

      final summary = <String, int>{};
      for (final row in response as List) {
        final type = row['threat_type'] as String?;
        if (type != null) {
          summary[type] = (summary[type] ?? 0) + 1;
        }
      }
      return summary;
    } catch (e) {
      debugPrint('[SecurityLogger] Error getting summary: $e');
      return {};
    }
  }

  // ═══════════════════════════════════════════════════════
  // PRIVATE
  // ═══════════════════════════════════════════════════════

  static Future<void> _save(SecurityLog log) async {
    try {
      await SupabaseService.ensureAuthenticated();
      await SupabaseService.client.from('security_logs').insert(log.toMap());
      debugPrint('[SecurityLogger] ${log.eventType} logged (${log.status})');
    } catch (e) {
      debugPrint('[SecurityLogger] Error saving: $e');
      // Never throw — logging must not break main flow
    }
  }

  static SecurityLog _fromMap(Map<String, dynamic> map) {
    return SecurityLog(
      employeeId: map['employee_id'] as String,
      eventType: map['event_type'] as String,
      status: map['status'] as String,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      accuracy: (map['accuracy'] as num?)?.toDouble(),
      threatType: map['threat_type'] as String?,
      message: map['message'] as String?,
      details: map['details'] as Map<String, dynamic>?,
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }
}
