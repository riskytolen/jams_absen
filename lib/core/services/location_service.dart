import 'package:geolocator/geolocator.dart';

/// Tipe error lokasi.
enum LocationErrorType {
  /// GPS / Location Service dimatikan di perangkat.
  serviceDisabled,

  /// Permission lokasi ditolak user.
  permissionDenied,

  /// Permission lokasi ditolak permanen (harus buka Settings).
  permissionDeniedForever,

  /// Timeout saat mengambil posisi.
  timeout,

  /// Error tidak diketahui.
  unknown,
}

/// Exception khusus untuk error lokasi.
class LocationException implements Exception {
  final LocationErrorType type;
  final String message;

  const LocationException({
    required this.type,
    required this.message,
  });

  @override
  String toString() => message;
}

/// Service lokasi — handle permission, GPS, dan akurasi tinggi.
///
/// Panggil [ensureReady] di awal untuk memastikan semua siap:
/// - Location service aktif (GPS on)
/// - Permission granted
///
/// Panggil [getCurrentPosition] untuk ambil posisi akurat.
abstract final class LocationService {
  /// Pastikan lokasi siap digunakan.
  ///
  /// Cek berurutan:
  /// 1. Apakah GPS / Location Service aktif?
  /// 2. Apakah permission sudah granted?
  /// 3. Jika belum → minta permission
  ///
  /// Throws [LocationException] jika gagal.
  static Future<void> ensureReady() async {
    // 1. Cek GPS aktif
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationException(
        type: LocationErrorType.serviceDisabled,
        message: 'GPS tidak aktif. '
            'Aktifkan GPS di pengaturan perangkat Anda untuk melanjutkan.',
      );
    }

    // 2. Cek & minta permission
    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(
        type: LocationErrorType.permissionDeniedForever,
        message: 'Izin lokasi ditolak secara permanen. '
            'Buka Pengaturan > Aplikasi > Jams Attendance > Izin, '
            'lalu aktifkan izin Lokasi.',
      );
    }

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();

      if (permission == LocationPermission.denied) {
        throw const LocationException(
          type: LocationErrorType.permissionDenied,
          message: 'Izin lokasi diperlukan untuk absensi. '
              'Berikan izin lokasi agar aplikasi dapat berfungsi.',
        );
      }

      if (permission == LocationPermission.deniedForever) {
        throw const LocationException(
          type: LocationErrorType.permissionDeniedForever,
          message: 'Izin lokasi ditolak secara permanen. '
              'Buka Pengaturan > Aplikasi > Jams Attendance > Izin, '
              'lalu aktifkan izin Lokasi.',
        );
      }
    }
  }

  /// Ambil posisi saat ini dengan akurasi tinggi.
  ///
  /// Timeout 10 detik. Throws [LocationException] jika gagal.
  static Future<Position> getCurrentPosition() async {
    try {
      // Pastikan ready dulu
      await ensureReady();

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } on LocationException {
      rethrow;
    } catch (e) {
      final msg = e.toString().toLowerCase();

      if (msg.contains('timeout') || msg.contains('timed out')) {
        throw const LocationException(
          type: LocationErrorType.timeout,
          message: 'Gagal mendapatkan lokasi. '
              'Pastikan Anda berada di area terbuka dan GPS aktif.',
        );
      }

      throw LocationException(
        type: LocationErrorType.unknown,
        message: 'Gagal mengakses lokasi: $e',
      );
    }
  }

  /// Buka pengaturan lokasi perangkat (untuk GPS off).
  static Future<bool> openLocationSettings() {
    return Geolocator.openLocationSettings();
  }

  /// Buka pengaturan aplikasi (untuk permission denied forever).
  static Future<bool> openAppSettings() {
    return Geolocator.openAppSettings();
  }
}
