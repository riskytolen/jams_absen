import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// Model untuk informasi update.
class UpdateInfo {
  final String latestVersion;
  final String currentVersion;
  final String? releaseNotes;
  final String? downloadUrl;
  final String? publishedAt;
  final String? fileSize;
  final bool hasUpdate;

  const UpdateInfo({
    required this.latestVersion,
    required this.currentVersion,
    this.releaseNotes,
    this.downloadUrl,
    this.publishedAt,
    this.fileSize,
    required this.hasUpdate,
  });
}

/// Status proses download.
enum DownloadStatus {
  idle,
  preparing,
  downloading,
  installing,
  completed,
  failed,
}

/// Service untuk cek update dan download APK dari GitHub Releases.
abstract final class UpdateService {
  static const _repoOwner = 'riskytolen';
  static const _repoName = 'absen';

  /// Ambil versi aplikasi saat ini.
  static Future<String> getCurrentVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  /// Cek apakah ada update terbaru di GitHub Releases.
  static Future<UpdateInfo> checkForUpdate() async {
    try {
      final currentVersion = await getCurrentVersion();

      final dio = Dio();
      final response = await dio.get(
        'https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest',
        options: Options(
          headers: {'Accept': 'application/vnd.github.v3+json'},
          receiveTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.statusCode != 200) {
        return UpdateInfo(
          latestVersion: currentVersion,
          currentVersion: currentVersion,
          hasUpdate: false,
        );
      }

      final data = response.data as Map<String, dynamic>;
      final tagName =
          (data['tag_name'] as String?)?.replaceFirst('v', '') ?? currentVersion;
      final body = data['body'] as String?;
      final publishedAt = data['published_at'] as String?;

      // Cari APK di assets
      String? apkUrl;
      String? fileSize;
      final assets = data['assets'] as List? ?? [];
      for (final asset in assets) {
        final name = (asset['name'] as String?)?.toLowerCase() ?? '';
        if (name.endsWith('.apk')) {
          apkUrl = asset['browser_download_url'] as String?;
          final size = asset['size'] as int? ?? 0;
          fileSize = _formatFileSize(size);
          break;
        }
      }

      final hasUpdate = _compareVersions(tagName, currentVersion) > 0;

      return UpdateInfo(
        latestVersion: tagName,
        currentVersion: currentVersion,
        releaseNotes: body,
        downloadUrl: apkUrl,
        publishedAt: publishedAt,
        fileSize: fileSize,
        hasUpdate: hasUpdate,
      );
    } catch (e) {
      debugPrint('[UpdateService] checkForUpdate error: $e');
      final currentVersion = await getCurrentVersion();
      return UpdateInfo(
        latestVersion: currentVersion,
        currentVersion: currentVersion,
        hasUpdate: false,
      );
    }
  }

  static const _channel = MethodChannel('com.jamsabsen.jams_absen/installer');

  /// Download APK. Jika sudah pernah download, langsung install.
  ///
  /// Callbacks:
  /// - [onProgress]: progress 0.0 - 1.0
  /// - [onStatusChanged]: status proses download
  static Future<void> downloadAndInstall({
    required String downloadUrl,
    required void Function(double progress) onProgress,
    required void Function(DownloadStatus status) onStatusChanged,
  }) async {
    try {
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/jams_absen_update.apk';

      // ── Step 1: Preparing ──
      onStatusChanged(DownloadStatus.preparing);

      // Selalu hapus file lama agar tidak install versi lama
      final oldFile = File(filePath);
      if (await oldFile.exists()) {
        await oldFile.delete();
        debugPrint('[UpdateService] File lama dihapus');
      }

      // ── Step 2: Downloading ──
      onStatusChanged(DownloadStatus.downloading);
      final dio = Dio();
      dio.options.followRedirects = true;
      dio.options.maxRedirects = 5;
      await dio.download(
        downloadUrl,
        filePath,
        options: Options(
          receiveTimeout: const Duration(minutes: 10),
          followRedirects: true,
          maxRedirects: 5,
        ),
        onReceiveProgress: (received, total) {
          if (total > 0) {
            onProgress(received / total);
          }
        },
      );

      // Verifikasi file terdownload
      final downloadedFile = File(filePath);
      if (!await downloadedFile.exists()) {
        throw Exception('File APK tidak ditemukan setelah download');
      }
      final fileSize = await downloadedFile.length();
      if (fileSize < 1024 * 500) {
        // APK biasanya > 500KB. Jika lebih kecil, kemungkinan HTML/error
        final firstBytes = await downloadedFile.openRead(0, 20).first;
        final header = String.fromCharCodes(firstBytes);
        await downloadedFile.delete();
        if (header.contains('<!') || header.contains('<html')) {
          throw Exception('Download gagal: server mengembalikan halaman HTML, bukan file APK');
        }
        throw Exception('File APK terlalu kecil ($fileSize bytes), kemungkinan corrupt');
      }

      debugPrint('[UpdateService] Downloaded: ${_formatFileSize(fileSize)}');

      // ── Step 3: Installing ──
      onStatusChanged(DownloadStatus.installing);
      await _installApk(filePath);
      onStatusChanged(DownloadStatus.completed);
    } catch (e) {
      debugPrint('[UpdateService] downloadAndInstall error: $e');
      onStatusChanged(DownloadStatus.failed);
      rethrow;
    }
  }

  /// Install APK via native method channel.
  static Future<void> _installApk(String filePath) async {
    try {
      await _channel.invokeMethod('installApk', {'filePath': filePath});
      debugPrint('[UpdateService] Install APK invoked');
    } on PlatformException catch (e) {
      debugPrint('[UpdateService] Install APK error: ${e.message}');
      // Fallback: coba buka dengan intent biasa
      throw Exception('Gagal membuka installer: ${e.message}');
    }
  }

  /// Bandingkan versi (semver). Return > 0 jika a > b.
  static int _compareVersions(String a, String b) {
    final aParts = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final bParts = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    for (int i = 0; i < 3; i++) {
      final aVal = i < aParts.length ? aParts[i] : 0;
      final bVal = i < bParts.length ? bParts[i] : 0;
      if (aVal != bVal) return aVal - bVal;
    }
    return 0;
  }

  static String _formatFileSize(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '$bytes B';
  }
}
