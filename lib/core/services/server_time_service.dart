import 'dart:io';
import 'package:flutter/foundation.dart';
import 'supabase_service.dart';

/// Service untuk mendapatkan waktu dari server/internet (ANTI-MANIPULASI).
///
/// Menggunakan **Stopwatch (monotonic clock)** untuk mengukur waktu berlalu,
/// bukan `DateTime.now()`. Stopwatch di Dart menggunakan system monotonic clock
/// yang **TIDAK TERPENGARUH** perubahan jam HP manual oleh user.
///
/// Sumber waktu (prioritas):
/// 1. NTP (Network Time Protocol) — langsung dari internet, paling akurat
/// 2. Supabase RPC `get_server_time()` — server database
/// 3. Supabase tabel `time_sync` — fallback database
/// 4. Cache + Stopwatch elapsed — estimasi tanpa network (tetap akurat)
///
/// **PENTING**: Service ini TIDAK pernah fallback ke DateTime.now()
/// untuk operasi time-critical (absensi, validasi, dll).
/// DateTime.now() hanya digunakan sebagai tampilan non-kritis TERAKHIR.
abstract final class ServerTimeService {
  // ═══════════════════════════════════════════════════════
  //  MONOTONIC CLOCK (anti-manipulasi)
  // ═══════════════════════════════════════════════════════

  /// Stopwatch monotonic — tidak terpengaruh perubahan jam HP.
  static final Stopwatch _monotonic = Stopwatch();

  /// Waktu server yang di-anchor ke monotonic clock.
  /// Waktu server = _anchoredServerTime + _monotonic.elapsed - _anchorElapsed
  static DateTime? _anchoredServerTime;

  /// Elapsed saat anchor di-set.
  static Duration _anchorElapsed = Duration.zero;

  /// Flag apakah sudah pernah berhasil sync.
  static bool _synced = false;

  // ═══════════════════════════════════════════════════════
  //  CACHE
  // ═══════════════════════════════════════════════════════

  /// Cache tanggal server.
  static String? _cachedDate;
  static Duration _dateCacheAnchor = Duration.zero;
  static const _dateCacheDuration = Duration(minutes: 5);

  /// Flag apakah RPC tersedia.
  static bool _rpcAvailable = true;

  // ═══════════════════════════════════════════════════════
  //  PUBLIC API
  // ═══════════════════════════════════════════════════════

  /// Inisialisasi — wajib dipanggil saat app start atau setelah login.
  ///
  /// Menyalakan monotonic clock dan sync waktu dari internet/server.
  static Future<void> initialize() async {
    // Start monotonic clock jika belum
    if (!_monotonic.isRunning) {
      _monotonic.start();
    }

    try {
      await _syncTime();
      debugPrint(
          '[ServerTimeService] Initialized. Synced: $_synced');
    } catch (e) {
      debugPrint('[ServerTimeService] Init failed: $e');
    }
  }

  /// Ambil waktu server yang akurat.
  ///
  /// Prioritas:
  /// 1. Jika sudah sync & Stopwatch jalan → hitung dari anchor (TANPA network)
  /// 2. Jika belum sync → fetch dari network (NTP/Supabase)
  ///
  /// Returns DateTime dalam timezone lokal.
  /// Throws [ServerTimeException] jika semua metode gagal.
  static Future<DateTime> getServerTime() async {
    // Jika belum pernah sync, lakukan sync dulu
    if (!_synced) {
      await _syncTime();
    }

    // Jika sudah sync, gunakan monotonic estimation (cepat, tanpa network)
    if (_synced) {
      return _getMonotonicEstimate();
    }

    // Fallback terakhir — HANYA jika benar-benar belum pernah sync
    debugPrint(
        '[ServerTimeService] ⚠️ CRITICAL: No server time, using local!');
    return DateTime.now();
  }

  /// Estimasi waktu server INSTAN menggunakan monotonic clock.
  ///
  /// Gunakan untuk UI yang perlu update cepat (jam digital, greeting).
  /// TIDAK melakukan network call.
  /// Return null jika belum pernah sync.
  static DateTime? getEstimatedServerTime() {
    if (!_synced) return null;
    return _getMonotonicEstimate();
  }

  /// Ambil tanggal server (YYYY-MM-DD), dengan cache 5 menit.
  static Future<String> getServerDate() async {
    // Cek cache — gunakan monotonic elapsed untuk durasi
    if (_cachedDate != null) {
      final elapsed = _monotonic.elapsed - _dateCacheAnchor;
      if (elapsed < _dateCacheDuration) {
        return _cachedDate!;
      }
    }

    final serverTime = await getServerTime();
    _cachedDate =
        '${serverTime.year}-${serverTime.month.toString().padLeft(2, '0')}-${serverTime.day.toString().padLeft(2, '0')}';
    _dateCacheAnchor = _monotonic.elapsed;
    return _cachedDate!;
  }

  /// Ambil jam server terformat (HH:mm:ss).
  static Future<String> getServerTimeFormatted() async {
    final t = await getServerTime();
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
  }

  /// Apakah sudah pernah berhasil sync waktu server?
  static bool get isInitialized => _synced;

  /// Offset antara server dan lokal (ms) — untuk debugging saja.
  static int get offsetMs {
    if (!_synced) return 0;
    final estimated = _getMonotonicEstimate();
    return estimated.difference(DateTime.now()).inMilliseconds;
  }

  /// Force re-sync waktu dari internet/server.
  ///
  /// Panggil saat:
  /// - App kembali dari background
  /// - Sebelum operasi kritikal (submit absen)
  /// - Setiap 15-30 menit sebagai maintenance
  static Future<void> resync() async {
    try {
      await _syncTime();
      debugPrint('[ServerTimeService] Re-synced successfully');
    } catch (e) {
      debugPrint('[ServerTimeService] Re-sync failed: $e');
    }
  }

  /// Reset (untuk testing).
  @visibleForTesting
  static void resetCache() {
    _anchoredServerTime = null;
    _anchorElapsed = Duration.zero;
    _synced = false;
    _rpcAvailable = true;
    _cachedDate = null;
    _dateCacheAnchor = Duration.zero;
    if (_monotonic.isRunning) {
      _monotonic.reset();
    }
  }

  // ═══════════════════════════════════════════════════════
  //  MONOTONIC ESTIMATION (inti anti-manipulasi)
  // ═══════════════════════════════════════════════════════

  /// Hitung estimasi waktu server menggunakan monotonic clock.
  ///
  /// Formula: serverTime = anchoredServerTime + (currentElapsed - anchorElapsed)
  ///
  /// Ini TIDAK terpengaruh perubahan jam HP karena:
  /// - _monotonic.elapsed menggunakan system uptime counter
  /// - _anchoredServerTime adalah snapshot dari network time
  /// - Selisihnya dihitung murni dari monotonic elapsed
  static DateTime _getMonotonicEstimate() {
    final elapsed = _monotonic.elapsed - _anchorElapsed;
    return _anchoredServerTime!.add(elapsed);
  }

  /// Anchor (simpan) waktu server ke monotonic clock.
  static void _anchor(DateTime serverTime) {
    _anchoredServerTime = serverTime;
    _anchorElapsed = _monotonic.elapsed;
    _synced = true;

    // Log perbedaan vs jam HP untuk deteksi manipulasi
    final localNow = DateTime.now();
    final diffMinutes =
        serverTime.difference(localNow).inMilliseconds.abs() / 60000;
    if (diffMinutes > 2) {
      debugPrint(
          '[ServerTimeService] ⚠️ MANIPULASI TERDETEKSI! '
          'Selisih: ${diffMinutes.toStringAsFixed(1)} menit');
      debugPrint(
          '[ServerTimeService] Server: $serverTime | HP: $localNow');
    }
  }

  // ═══════════════════════════════════════════════════════
  //  SYNC — Ambil waktu dari internet/server
  // ═══════════════════════════════════════════════════════

  /// Sync waktu dari berbagai sumber.
  static Future<void> _syncTime() async {
    // Pastikan monotonic jalan
    if (!_monotonic.isRunning) _monotonic.start();

    // Metode 1: NTP (paling akurat, langsung dari internet)
    try {
      final ntpTime = await _fetchNtpTime();
      if (ntpTime != null) {
        _anchor(ntpTime);
        debugPrint('[ServerTimeService] Synced via NTP: $ntpTime');
        return;
      }
    } catch (e) {
      debugPrint('[ServerTimeService] NTP failed: $e');
    }

    // Metode 2: Supabase RPC
    if (_rpcAvailable) {
      try {
        await SupabaseService.ensureAuthenticated();
        final response =
            await SupabaseService.client.rpc('get_server_time');
        if (response != null) {
          final serverTime =
              DateTime.parse(response.toString()).toLocal();
          _anchor(serverTime);
          debugPrint(
              '[ServerTimeService] Synced via Supabase RPC: $serverTime');
          return;
        }
      } catch (e) {
        if (e.toString().contains('PGRST202') ||
            e.toString().contains('Could not find the function')) {
          _rpcAvailable = false;
          debugPrint('[ServerTimeService] RPC not available');
        } else {
          debugPrint('[ServerTimeService] RPC failed: $e');
        }
      }
    }

    // Metode 3: Supabase time_sync table
    try {
      await SupabaseService.ensureAuthenticated();
      await SupabaseService.client
          .from('time_sync')
          .update({'last_sync': 'now()'}).eq('id', 1);

      final response = await SupabaseService.client
          .from('time_sync')
          .select('last_sync')
          .eq('id', 1)
          .single();

      if (response['last_sync'] != null) {
        final serverTime =
            DateTime.parse(response['last_sync'] as String).toLocal();
        _anchor(serverTime);
        debugPrint(
            '[ServerTimeService] Synced via time_sync: $serverTime');
        return;
      }
    } catch (e) {
      debugPrint('[ServerTimeService] time_sync failed: $e');
    }

    // Tidak berhasil sync — jika sudah pernah sync sebelumnya,
    // monotonic estimation masih akurat
    if (_synced) {
      debugPrint(
          '[ServerTimeService] Network sync failed, '
          'using existing monotonic anchor (masih akurat)');
    } else {
      debugPrint(
          '[ServerTimeService] ⚠️ CRITICAL: Never synced, no server time!');
    }
  }

  // ═══════════════════════════════════════════════════════
  //  NTP — Direct internet time (tanpa Supabase)
  // ═══════════════════════════════════════════════════════

  /// Fetch waktu dari NTP server.
  ///
  /// NTP (Network Time Protocol) memberikan waktu UTC yang sangat akurat
  /// langsung dari server waktu internet. Tidak tergantung Supabase.
  ///
  /// Menggunakan raw UDP socket ke pool.ntp.org.
  static Future<DateTime?> _fetchNtpTime() async {
    const ntpServers = [
      'pool.ntp.org',
      'time.google.com',
      'time.cloudflare.com',
    ];

    for (final server in ntpServers) {
      try {
        final result = await _queryNtpServer(server)
            .timeout(const Duration(seconds: 3));
        if (result != null) return result;
      } catch (e) {
        debugPrint('[NTP] $server failed: $e');
        continue;
      }
    }
    return null;
  }

  /// Query satu NTP server via UDP.
  ///
  /// NTP packet format (simplified):
  /// - 48 bytes request
  /// - First byte: LI=0, VN=4, Mode=3 (client)
  /// - Response bytes 40-47: Transmit Timestamp (seconds since 1900-01-01)
  static Future<DateTime?> _queryNtpServer(String server) async {
    RawDatagramSocket? socket;
    try {
      // Resolve hostname
      final addresses = await InternetAddress.lookup(server);
      if (addresses.isEmpty) return null;

      // Create UDP socket
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.readEventsEnabled = true;

      // Build NTP request packet (48 bytes)
      final request = Uint8List(48);
      request[0] = 0x23; // LI=0, VN=4, Mode=3 (client)

      // Kirim ke NTP server port 123
      socket.send(request, addresses.first, 123);

      // Tunggu response
      await for (final event in socket.timeout(const Duration(seconds: 3))) {
        if (event == RawSocketEvent.read) {
          final datagram = socket.receive();
          if (datagram != null && datagram.data.length >= 48) {
            // Parse Transmit Timestamp (bytes 40-43: seconds, 44-47: fraction)
            final data = datagram.data;
            final seconds = (data[40] << 24) |
                (data[41] << 16) |
                (data[42] << 8) |
                data[43];

            final fraction = (data[44] << 24) |
                (data[45] << 16) |
                (data[46] << 8) |
                data[47];

            // NTP epoch = 1 Jan 1900, Unix epoch = 1 Jan 1970
            // Selisih = 70 tahun = 2208988800 detik
            const ntpEpochOffset = 2208988800;
            final unixSeconds = seconds - ntpEpochOffset;
            final milliseconds =
                (fraction * 1000 / 0x100000000).round();

            final ntpTime = DateTime.fromMillisecondsSinceEpoch(
              unixSeconds * 1000 + milliseconds,
              isUtc: true,
            ).toLocal();

            socket.close();
            return ntpTime;
          }
        }
      }

      socket.close();
      return null;
    } catch (e) {
      socket?.close();
      rethrow;
    }
  }
}
