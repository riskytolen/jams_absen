import 'package:package_info_plus/package_info_plus.dart';

/// Helper terpusat untuk versi aplikasi.
///
/// Membaca versi dari pubspec.yaml via [PackageInfo] sehingga
/// TIDAK perlu hardcode versi di banyak tempat.
///
/// Cara pakai:
/// ```dart
/// // Di initState atau setelah app start:
/// await AppVersion.init();
///
/// // Di mana saja:
/// Text('v${AppVersion.version}');  // "1.6.0"
/// Text('v${AppVersion.fullVersion}');  // "1.6.0+7"
/// ```
abstract final class AppVersion {
  static String _version = '';
  static String _buildNumber = '';

  /// Inisialisasi — panggil 1x saat app start (di main.dart).
  static Future<void> init() async {
    final info = await PackageInfo.fromPlatform();
    _version = info.version;
    _buildNumber = info.buildNumber;
  }

  /// Versi aplikasi (contoh: "1.6.0").
  /// Ini yang ditampilkan ke user.
  static String get version => _version;

  /// Build number (contoh: "7").
  static String get buildNumber => _buildNumber;

  /// Versi lengkap (contoh: "1.6.0+7").
  static String get fullVersion =>
      _buildNumber.isNotEmpty ? '$_version+$_buildNumber' : _version;

  /// Label untuk tampilan UI (contoh: "v1.6.0").
  static String get label => 'v$_version';
}
