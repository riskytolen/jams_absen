/// Konfigurasi koneksi Supabase.
///
/// Satu database dengan HR Web (`hr_web/.env.local`):
/// project `snovvucsmewwbrnggvek`. Publishable key di bawah aman untuk
/// client-side dan boleh dioverride via `--dart-define` saat build.
///
/// Build command (override opsional):
/// ```
/// flutter build apk --release \
///   --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_... \
///   --dart-define=SUPABASE_SERVICE_EMAIL=... \
///   --dart-define=SUPABASE_SERVICE_PASSWORD=...
/// ```
abstract final class SupabaseConfig {
  /// Supabase project URL.
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://snovvucsmewwbrnggvek.supabase.co',
  );

  /// Supabase publishable key — aman untuk client-side.
  /// Legacy anon JWT tidak dipakai lagi (dinonaktifkan server-side).
  /// Default sama dengan `NEXT_PUBLIC_SUPABASE_ANON_KEY` pada `hr_web/.env.local`.
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_8bUgVQs3Wwj1H-fSVsQAQw_wDXDVgQk',
  );

  /// True jika key tersedia (wajib untuk build release yang valid).
  static bool get hasPublishableKey => supabasePublishableKey.isNotEmpty;

  /// True jika kredensial background auth tersedia.
  static bool get hasServiceCredentials =>
      serviceEmail.trim().isNotEmpty && servicePassword.isNotEmpty;

  /// Email untuk autentikasi background (melewati RLS).
  /// Default dari file kredensial operasional; dapat dioverride via --dart-define.
  static const serviceEmail = String.fromEnvironment(
    'SUPABASE_SERVICE_EMAIL',
    defaultValue: 'pegawai@jamslogistic.com',
  );

  /// Password untuk autentikasi background.
  /// Default dari file kredensial operasional; dapat dioverride via --dart-define.
  static const servicePassword = String.fromEnvironment(
    'SUPABASE_SERVICE_PASSWORD',
    defaultValue: 'Admin123!',
  );
}
