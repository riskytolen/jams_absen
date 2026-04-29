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
        '[REDACTED]',
  );
}
