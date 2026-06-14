/// Konfigurasi koneksi Supabase.
///
/// Nilai diambil dari `--dart-define` saat build, atau fallback ke
/// default development values.
///
/// Build command:
/// ```
/// flutter run \
///   --dart-define=SUPABASE_URL=https://snovvucsmewwbrnggvek.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=your_anon_key
/// ```
abstract final class SupabaseConfig {
  /// Supabase project URL.
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://snovvucsmewwbrnggvek.supabase.co',
  );

  /// Supabase anon (public) key — aman untuk client-side.
  /// Gunakan publishable key baru (--dart-define saat build).
  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'sb_publishable_m299cjH9UFkF0J429f8Xew_jOk2pahO',
  );

  /// Email untuk autentikasi background (melewati RLS).
  /// HARUS di-pass via --dart-define saat build, jangan hardcode.
  static const serviceEmail = String.fromEnvironment(
    'SUPABASE_SERVICE_EMAIL',
    defaultValue: '',
  );

  /// Password untuk autentikasi background.
  /// HARUS di-pass via --dart-define saat build, jangan hardcode.
  static const servicePassword = String.fromEnvironment(
    'SUPABASE_SERVICE_PASSWORD',
    defaultValue: '',
  );
}
