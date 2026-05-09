import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

/// Service layer untuk Supabase — singleton access point.
///
/// Inisialisasi di `main.dart` sebelum `runApp()`:
/// ```dart
/// await SupabaseService.initialize();
/// ```
///
/// Akses client di mana saja:
/// ```dart
/// final client = SupabaseService.client;
/// final data = await client.from('employees').select();
/// ```
abstract final class SupabaseService {
  /// Inisialisasi Supabase + background auth untuk melewati RLS.
  ///
  /// Flow:
  /// 1. Initialize Supabase SDK
  /// 2. Cek apakah sudah ada session aktif (dari persistent storage)
  /// 3. Jika belum → sign in dengan service account
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
      realtimeClientOptions: const RealtimeClientOptions(
        logLevel: RealtimeLogLevel.info,
      ),
    );

    // Background auth — sign in agar request melewati RLS
    await _ensureAuthenticated();
  }

  /// Supabase client instance — shortcut ke `Supabase.instance.client`.
  static SupabaseClient get client => Supabase.instance.client;

  /// Auth instance — shortcut untuk operasi autentikasi.
  static GoTrueClient get auth => client.auth;

  /// Cek apakah sudah ter-autentikasi ke Supabase Auth.
  static bool get isAuthenticated => auth.currentSession != null;

  /// User yang sedang login, atau null.
  static User? get currentUser => auth.currentUser;

  /// Stopwatch monotonic untuk auth cache (anti-manipulasi jam HP).
  static final Stopwatch _authStopwatch = Stopwatch()..start();

  /// Elapsed saat auth terakhir berhasil.
  static Duration? _lastAuthElapsed;

  /// Durasi cache auth check (30 detik).
  static const _authCacheDuration = Duration(seconds: 30);

  /// Pastikan sudah ter-autentikasi. Panggil sebelum operasi database
  /// yang membutuhkan RLS.
  ///
  /// Jika session expired atau belum ada, otomatis sign in ulang.
  /// Menggunakan cache 30 detik (monotonic) untuk menghindari pengecekan berulang.
  static Future<void> ensureAuthenticated() async {
    // Skip jika baru saja dicek dan session masih ada
    if (_lastAuthElapsed != null &&
        auth.currentSession != null &&
        (_authStopwatch.elapsed - _lastAuthElapsed!) < _authCacheDuration) {
      return;
    }
    await _ensureAuthenticated();
    _lastAuthElapsed = _authStopwatch.elapsed;
  }

  /// Force re-check auth tanpa cache (untuk kasus penting seperti submit).
  static Future<void> forceEnsureAuthenticated() async {
    _lastAuthElapsed = null;
    await _ensureAuthenticated();
    _lastAuthElapsed = _authStopwatch.elapsed;
  }

  /// Sign out dari Supabase Auth.
  static Future<void> signOut() async {
    await auth.signOut();
  }

  // ── Internal: pastikan ada session aktif ──────────────
  static Future<void> _ensureAuthenticated() async {
    try {
      final session = auth.currentSession;

      if (session != null) {
        // Session ada — cek apakah expired
        final isExpired = session.isExpired;

        if (!isExpired) {
          debugPrint('[SupabaseService] Session aktif, skip sign-in.');
          return;
        }

        // Session expired → coba refresh dulu
        debugPrint('[SupabaseService] Session expired, refreshing...');
        try {
          await auth.refreshSession();
          debugPrint('[SupabaseService] Session refreshed.');
          return;
        } catch (e) {
          debugPrint('[SupabaseService] Refresh gagal, sign-in ulang...');
        }
      }

      // Belum ada session atau refresh gagal → sign in
      await _signInBackground();
    } catch (e) {
      debugPrint('[SupabaseService] Auth error: $e');
      // Jangan throw — biarkan app tetap jalan.
      // Query tanpa auth akan gagal karena RLS, tapi error
      // ditangani di masing-masing service.
    }
  }

  /// Sign in dengan service account di background.
  static Future<void> _signInBackground() async {
    debugPrint('[SupabaseService] Signing in background...');

    final response = await auth.signInWithPassword(
      email: SupabaseConfig.serviceEmail,
      password: SupabaseConfig.servicePassword,
    );

    if (response.session != null) {
      debugPrint('[SupabaseService] Background auth berhasil.');
    } else {
      debugPrint('[SupabaseService] Background auth gagal: no session.');
    }
  }
}
