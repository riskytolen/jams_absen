/// Helper untuk menentukan sapaan berdasarkan waktu.
abstract final class GreetingHelper {
  static String get greeting {
    final h = DateTime.now().hour;
    if (h >= 4 && h < 11) return 'Selamat Pagi';
    if (h >= 11 && h < 15) return 'Selamat Siang';
    if (h >= 15 && h < 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  static String get emoji {
    final h = DateTime.now().hour;
    if (h >= 4 && h < 11) return '☀️';
    if (h >= 11 && h < 15) return '🌤️';
    if (h >= 15 && h < 18) return '🌅';
    return '🌙';
  }
}
