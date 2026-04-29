import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Info device saat ini.
class DeviceInfo {
  final String deviceId;
  final String deviceName;
  final String platform;

  const DeviceInfo({
    required this.deviceId,
    required this.deviceName,
    required this.platform,
  });

  /// Apakah info device valid.
  bool get isValid =>
      deviceId.isNotEmpty &&
      deviceId != 'error_device' &&
      deviceId != 'unknown_device';
}

/// Service untuk mengambil informasi device unik.
///
/// Android: menggunakan native method channel untuk ambil
/// `Settings.Secure.ANDROID_ID` — unik per device, persisten.
///
/// iOS: menggunakan `identifierForVendor` dari device_info_plus.
abstract final class DeviceService {
  static const _channel = MethodChannel('com.jamsabsen/device');
  static DeviceInfo? _cached;

  /// Reset cache.
  static void clearCache() => _cached = null;

  /// Ambil info device. Di-cache hanya jika valid.
  static Future<DeviceInfo> getDeviceInfo() async {
    if (_cached != null && _cached!.isValid) return _cached!;

    try {
      if (Platform.isAndroid) {
        _cached = await _getAndroidInfo();
      } else if (Platform.isIOS) {
        _cached = await _getIosInfo();
      } else {
        _cached = const DeviceInfo(
          deviceId: 'unknown_device',
          deviceName: 'Unknown Device',
          platform: 'Unknown',
        );
      }
    } catch (e) {
      debugPrint('[DeviceService] Error: $e');
      return const DeviceInfo(
        deviceId: 'error_device',
        deviceName: 'Unknown Device',
        platform: 'Unknown',
      );
    }

    return _cached!;
  }

  /// Android — ambil via native method channel.
  static Future<DeviceInfo> _getAndroidInfo() async {
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'getDeviceInfo',
    );

    if (result == null) {
      throw Exception('Native channel returned null');
    }

    final androidId = (result['androidId'] as String?) ?? '';
    final fingerprint = (result['fingerprint'] as String?) ?? '';
    final deviceName = (result['deviceName'] as String?) ?? 'Unknown Device';
    final platform = (result['platform'] as String?) ?? 'Android';

    // Android ID adalah prioritas utama, fingerprint sebagai fallback
    final deviceId = androidId.isNotEmpty ? androidId : fingerprint;

    if (deviceId.isEmpty) {
      throw Exception('Both androidId and fingerprint are empty');
    }

    return DeviceInfo(
      deviceId: deviceId,
      deviceName: deviceName,
      platform: platform,
    );
  }

  /// iOS — ambil via device_info_plus.
  static Future<DeviceInfo> _getIosInfo() async {
    final ios = await DeviceInfoPlugin().iosInfo;
    final deviceId = ios.identifierForVendor;

    if (deviceId == null || deviceId.isEmpty) {
      throw Exception('identifierForVendor is null');
    }

    return DeviceInfo(
      deviceId: deviceId,
      deviceName: ios.name,
      platform: '${ios.systemName} ${ios.systemVersion}',
    );
  }
}
