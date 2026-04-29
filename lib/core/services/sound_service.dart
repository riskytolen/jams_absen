import 'package:audioplayers/audioplayers.dart';

/// Service untuk memainkan sound effect di aplikasi.
abstract final class SoundService {
  static AudioPlayer? _player;

  static AudioPlayer get _instance {
    _player ??= AudioPlayer();
    return _player!;
  }

  /// Suara beep pendek saat QR Code terdeteksi kamera.
  static Future<void> playScanBeep() =>
      _play('sounds/scan_beep.wav');

  /// Suara nada naik (bip-bip) saat login berhasil.
  static Future<void> playLoginSuccess() =>
      _play('sounds/login_success.wav');

  /// Suara nada rendah turun saat login gagal.
  static Future<void> playLoginError() =>
      _play('sounds/login_error.wav');

  static Future<void> _play(String asset) async {
    try {
      await _instance.stop();
      await _instance.play(AssetSource(asset));
    } catch (_) {
      // Abaikan error sound — jangan ganggu flow utama
    }
  }

  /// Bersihkan resource audio.
  static Future<void> dispose() async {
    await _player?.dispose();
    _player = null;
  }
}
