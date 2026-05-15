import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../models/pegawai_model.dart';

/// Service untuk mengelola session dengan timeout otomatis
abstract final class SessionService {
  static Pegawai? _currentPegawai;
  static DateTime? _loginTime;
  static DateTime? _lastActivity;
  static Timer? _sessionTimer;
  static Timer? _warningTimer;
  
  // Konfigurasi timeout
  static const Duration sessionTimeout = Duration(hours: 8);      // 8 jam kerja
  static const Duration inactivityTimeout = Duration(hours: 2);   // 2 jam tidak aktif
  static const Duration warningBefore = Duration(minutes: 5);     // Warning 5 menit sebelum timeout
  
  // Callbacks untuk UI
  static VoidCallback? onSessionExpired;
  static VoidCallback? onSessionWarning;
  static Function(Duration)? onSessionTimeUpdate;
  
  /// Get current pegawai dengan timeout check
  static Pegawai? get currentPegawai {
    if (_currentPegawai == null) return null;
    
    // Auto-check timeout setiap kali akses
    if (_isSessionExpired()) {
      _expireSession();
      return null;
    }
    
    return _currentPegawai;
  }
  
  /// Check apakah user sedang login dan session valid
  static bool get isLoggedIn {
    return currentPegawai != null; // Akan auto-check timeout
  }
  
  /// Login dengan session tracking
  static void startSession(Pegawai pegawai) {
    final now = DateTime.now();
    
    _currentPegawai = pegawai;
    _loginTime = now;
    _lastActivity = now;
    
    _startSessionTimers();
    
    debugPrint('[Session] Started for ${pegawai.id} at $now');
    debugPrint('[Session] Will expire at ${now.add(sessionTimeout)}');
  }
  
  /// Update last activity (panggil setiap user interaction)
  static void updateActivity() {
    if (_currentPegawai == null) return;
    
    final now = DateTime.now();
    _lastActivity = now;
    
    debugPrint('[Session] Activity updated at $now');
    
    // Notify UI tentang session time remaining
    final remaining = getSessionTimeRemaining();
    if (remaining != null && onSessionTimeUpdate != null) {
      onSessionTimeUpdate!(remaining);
    }
  }
  
  /// Manual logout
  static void endSession() {
    if (_currentPegawai != null) {
      debugPrint('[Session] Manual logout for ${_currentPegawai!.id}');
    }
    
    _clearSession();
  }
  
  /// Get remaining session time
  static Duration? getSessionTimeRemaining() {
    if (_loginTime == null) return null;
    
    final sessionEnd = _loginTime!.add(sessionTimeout);
    final now = DateTime.now();
    
    if (now.isAfter(sessionEnd)) return Duration.zero;
    return sessionEnd.difference(now);
  }
  
  /// Get remaining inactivity time
  static Duration? getInactivityTimeRemaining() {
    if (_lastActivity == null) return null;
    
    final inactivityEnd = _lastActivity!.add(inactivityTimeout);
    final now = DateTime.now();
    
    if (now.isAfter(inactivityEnd)) return Duration.zero;
    return inactivityEnd.difference(now);
  }
  
  /// Get session info untuk debugging
  static Map<String, dynamic> getSessionInfo() {
    return {
      'isLoggedIn': _currentPegawai != null,
      'employeeId': _currentPegawai?.id,
      'loginTime': _loginTime?.toIso8601String(),
      'lastActivity': _lastActivity?.toIso8601String(),
      'sessionTimeRemaining': getSessionTimeRemaining()?.inMinutes,
      'inactivityTimeRemaining': getInactivityTimeRemaining()?.inMinutes,
    };
  }
  
  /// Force check session validity (untuk manual refresh)
  static bool checkSessionValidity() {
    if (_currentPegawai == null) return false;
    
    if (_isSessionExpired()) {
      _expireSession();
      return false;
    }
    
    return true;
  }
  
  // ═══════════════════════════════════════════════════════
  // PRIVATE METHODS
  // ═══════════════════════════════════════════════════════
  
  static bool _isSessionExpired() {
    if (_loginTime == null || _lastActivity == null) return true;
    
    final now = DateTime.now();
    
    // Check session timeout (8 jam dari login)
    final sessionExpired = now.isAfter(_loginTime!.add(sessionTimeout));
    
    // Check inactivity timeout (2 jam tidak aktif)
    final inactivityExpired = now.isAfter(_lastActivity!.add(inactivityTimeout));
    
    return sessionExpired || inactivityExpired;
  }
  
  static void _expireSession() {
    final reason = _getExpirationReason();
    debugPrint('[Session] Session expired for ${_currentPegawai?.id}: $reason');
    
    _clearSession();
    
    // Trigger callback
    onSessionExpired?.call();
  }
  
  static String _getExpirationReason() {
    if (_loginTime == null || _lastActivity == null) return 'No session data';
    
    final now = DateTime.now();
    final sessionExpired = now.isAfter(_loginTime!.add(sessionTimeout));
    final inactivityExpired = now.isAfter(_lastActivity!.add(inactivityTimeout));
    
    if (sessionExpired && inactivityExpired) {
      return 'Session timeout and inactivity timeout';
    } else if (sessionExpired) {
      return 'Session timeout (8 hours)';
    } else if (inactivityExpired) {
      return 'Inactivity timeout (2 hours)';
    }
    
    return 'Unknown';
  }
  
  static void _clearSession() {
    _currentPegawai = null;
    _loginTime = null;
    _lastActivity = null;
    
    _sessionTimer?.cancel();
    _warningTimer?.cancel();
    _sessionTimer = null;
    _warningTimer = null;
  }
  
  static void _startSessionTimers() {
    _sessionTimer?.cancel();
    _warningTimer?.cancel();
    
    // Timer untuk session timeout (8 jam)
    _sessionTimer = Timer(sessionTimeout, () {
      debugPrint('[Session] Session timeout reached');
      _expireSession();
    });
    
    // Timer untuk warning (5 menit sebelum timeout)
    final warningTime = sessionTimeout - warningBefore;
    _warningTimer = Timer(warningTime, () {
      debugPrint('[Session] Session warning - 5 minutes remaining');
      onSessionWarning?.call();
    });
    
    debugPrint('[Session] Timers started - timeout in ${sessionTimeout.inHours}h, warning in ${warningTime.inHours}h ${warningTime.inMinutes % 60}m');
  }
}

/// Exception untuk session expired
class SessionExpiredException implements Exception {
  final String message;
  final String reason;
  
  const SessionExpiredException({
    required this.message,
    required this.reason,
  });
  
  @override
  String toString() => message;
}