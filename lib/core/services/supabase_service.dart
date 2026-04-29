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
  /// Inisialisasi Supabase. Panggil sekali di `main()`.
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
  }

  /// Supabase client instance — shortcut ke `Supabase.instance.client`.
  static SupabaseClient get client => Supabase.instance.client;

  /// Auth instance — shortcut untuk operasi autentikasi.
  static GoTrueClient get auth => client.auth;

  /// Cek apakah user sedang login.
  static bool get isAuthenticated => auth.currentSession != null;

  /// User yang sedang login, atau null.
  static User? get currentUser => auth.currentUser;

  /// Sign out user.
  static Future<void> signOut() async {
    await auth.signOut();
  }
}
