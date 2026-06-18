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
  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNub3Z2dWNzbWV3d2JybmdndmVrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY3NzU4MDYsImV4cCI6MjA5MjM1MTgwNn0.M6x1vcQKN_cJGM0B__2XE_ggcC8kro9Ch0r5qdyvW3k',
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
