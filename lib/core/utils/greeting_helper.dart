import '../services/server_time_service.dart';

/// Helper untuk menentukan sapaan berdasarkan waktu server.
abstract final class GreetingHelper {
  /// Sapaan berdasarkan waktu server (menggunakan offset yang sudah di-cache).
  static String get greeting {
    final serverTime = ServerTimeService.getEstimatedServerTime();
    final h = (serverTime ?? DateTime.now()).hour;
    if (h >= 4 && h < 11) return 'Selamat Pagi';
    if (h >= 11 && h < 15) return 'Selamat Siang';
    if (h >= 15 && h < 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  static String get emoji {
    final serverTime = ServerTimeService.getEstimatedServerTime();
    final h = (serverTime ?? DateTime.now()).hour;
    if (h >= 4 && h < 11) return '☀️';
    if (h >= 11 && h < 15) return '🌤️';
    if (h >= 15 && h < 18) return '🌅';
    return '🌙';
  }
}
