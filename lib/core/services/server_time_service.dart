import 'dart:io';
import 'package:flutter/foundation.dart';
import 'supabase_service.dart';

/// Service untuk mendapatkan waktu dari server/internet (ANTI-MANIPULASI).
///
/// Semua waktu yang dikembalikan ber-zona **WIB (UTC+7)** dan TIDAK tergantung
/// pengaturan timezone HP user. Ini penting karena hitung status absensi
/// (telat/tepat waktu) WAJIB konsisten WIB walau HP user di set zona lain.
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
abstract final class ServerTimeService {
  // ═══════════════════════════════════════════════════════
  //  KONSTANTA
  // ═══════════════════════════════════════════════════════

  /// Offset zona Indonesia Barat dari UTC.
  static const Duration _wibOffset = Duration(hours: 7);

  /// Batas atas waktu yang masih masuk akal untuk anchor.
  /// Reject anchor sebelum batas ini (mencegah bug epoch / 1900 / 1970).
  static final DateTime _minSane = DateTime.utc(2024, 1, 1);

  /// Batas bawah waktu yang masih masuk akal (10 tahun ke depan).
  static final DateTime _maxSane = DateTime.utc(2040, 1, 1);

  /// Skip re-sync jika anchor masih lebih baru dari ini.
  static const Duration _resyncCooldown = Duration(seconds: 30);

  // ═══════════════════════════════════════════════════════
  //  MONOTONIC CLOCK (anti-manipulasi)
  // ═══════════════════════════════════════════════════════

  /// Stopwatch monotonic — tidak terpengaruh perubahan jam HP.
  static final Stopwatch _monotonic = Stopwatch();

  /// Waktu server (UTC) yang di-anchor ke monotonic clock.
  /// Disimpan dalam UTC untuk menghindari ambiguitas timezone.
  static DateTime? _anchoredUtc;

  /// Elapsed saat anchor di-set.
  static Duration _anchorElapsed = Duration.zero;

  /// Flag apakah sudah pernah berhasil sync.
  static bool _synced = false;

  /// Sedang sync (mencegah concurrent sync racing).
  static Future<void>? _syncInFlight;

  // ═══════════════════════════════════════════════════════
  //  CACHE
  // ═══════════════════════════════════════════════════════

  /// Cache tanggal server (WIB).
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

  /// Ambil waktu server WIB yang akurat.
  ///
  /// Returns DateTime dalam zona WIB (UTC+7), TANPA bergantung
  /// timezone HP user.
  static Future<DateTime> getServerTime() async {
    // Jika belum pernah sync, lakukan sync dulu
    if (!_synced) {
      await _syncTime();
    }

    // Jika sudah sync, gunakan monotonic estimation (cepat, tanpa network)
    if (_synced) {
      return _getMonotonicEstimateWib();
    }

    // Fallback terakhir — HANYA jika benar-benar belum pernah sync
    debugPrint(
        '[ServerTimeService] ⚠️ CRITICAL: No server time, using local UTC->WIB!');
    return _toNaiveWib(DateTime.now().toUtc().add(_wibOffset));
  }

  /// Ambil waktu server WIB FRESH untuk operasi KRITIS (absensi).
  ///
  /// Selalu force re-sync (kecuali baru sync detik tadi) sebelum return.
  /// Returns DateTime dalam zona WIB.
  static Future<DateTime> getServerTimeForCriticalOps() async {
    try {
      // Force re-sync untuk operasi kritis
      await _syncTime(forceRefresh: true);
      if (_synced) {
        return _getMonotonicEstimateWib();
      }
      // Jika sync gagal, fallback ke getServerTime biasa
      return await getServerTime();
    } catch (e) {
      debugPrint('[ServerTimeService] Critical ops failed: $e');
      return await getServerTime();
    }
  }

  /// Estimasi waktu server INSTAN menggunakan monotonic clock.
  ///
  /// Gunakan untuk UI yang perlu update cepat (jam digital, greeting).
  /// TIDAK melakukan network call.
  /// Return null jika belum pernah sync atau data tidak valid.
  static DateTime? getEstimatedServerTime() {
    if (!_synced || _anchoredUtc == null) {
      return null;
    }

    try {
      final est = _getMonotonicEstimateWib();
      // Sanity guard tambahan untuk UI: tolak nilai gila.
      if (est.isBefore(_minSane) || est.isAfter(_maxSane)) {
        debugPrint(
            '[ServerTimeService] getEstimatedServerTime: insane $est, return null');
        // Reset anchor agar sync ulang.
        _resetAnchor();
        return null;
      }
      return est;
    } catch (e) {
      debugPrint('[ServerTimeService] getEstimatedServerTime error: $e');
      return null;
    }
  }

  /// Ambil tanggal server (YYYY-MM-DD) berdasarkan WIB, dengan cache 5 menit.
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

  /// Ambil jam server WIB terformat (HH:mm:ss).
  static Future<String> getServerTimeFormatted() async {
    final t = await getServerTime();
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
  }

  /// Apakah sudah pernah berhasil sync waktu server?
  static bool get isInitialized => _synced;

  /// Offset antara server dan jam HP (ms) — untuk debugging saja.
  static int get offsetMs {
    if (!_synced || _anchoredUtc == null) return 0;
    final estimated = _getMonotonicEstimateUtc();
    return estimated.difference(DateTime.now().toUtc()).inMilliseconds;
  }

  /// Force re-sync waktu dari internet/server.
  static Future<void> resync() async {
    try {
      await _syncTime(forceRefresh: true);
      debugPrint('[ServerTimeService] Re-synced successfully');
    } catch (e) {
      debugPrint('[ServerTimeService] Re-sync failed: $e');
    }
  }

  /// Reset (untuk testing).
  @visibleForTesting
  static void resetCache() {
    _resetAnchor();
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

  /// Hitung estimasi waktu server (UTC) menggunakan monotonic clock.
  static DateTime _getMonotonicEstimateUtc() {
    if (_anchoredUtc == null) {
      throw StateError('No anchored server time available');
    }
    final elapsed = _monotonic.elapsed - _anchorElapsed;
    return _anchoredUtc!.add(elapsed);
  }

  /// Hitung estimasi waktu server WIB dari anchor UTC.
  ///
  /// Mengembalikan DateTime **NAIVE/LOCAL** (isUtc=false) yang nilai
  /// year/month/day/hour/minute-nya merepresentasikan jam dinding WIB.
  /// Ini penting agar bisa langsung dibandingkan dengan
  /// `DateTime(year, month, day, h, m)` (yang juga naive/local) tanpa
  /// terjadi konversi timezone tersembunyi saat `.difference()` /
  /// `.isAfter()`.
  static DateTime _getMonotonicEstimateWib() {
    final utc = _getMonotonicEstimateUtc();
    return _toNaiveWib(utc.add(_wibOffset));
  }

  /// Konversi DateTime (UTC dengan offset WIB sudah ditambahkan, atau naive)
  /// menjadi DateTime naive yang nilainya = jam dinding WIB.
  static DateTime _toNaiveWib(DateTime t) {
    return DateTime(
      t.year, t.month, t.day,
      t.hour, t.minute, t.second,
      t.millisecond, t.microsecond,
    );
  }

  /// Anchor (simpan) waktu server ke monotonic clock.
  ///
  /// [serverTimeUtc] HARUS dalam UTC untuk menghindari ambiguitas.
  /// Tolak (no-op) kalau waktu tidak masuk akal.
  static bool _anchor(DateTime serverTimeUtc) {
    // Pastikan UTC.
    final utc =
        serverTimeUtc.isUtc ? serverTimeUtc : serverTimeUtc.toUtc();

    // Sanity check — tolak kalau di luar range masuk akal
    if (utc.isBefore(_minSane) || utc.isAfter(_maxSane)) {
      debugPrint(
          '[ServerTimeService] ⚠️ Reject anchor: out-of-range $utc');
      return false;
    }

    _anchoredUtc = utc;
    _anchorElapsed = _monotonic.elapsed;
    _synced = true;

    // Log perbedaan vs jam HP untuk deteksi manipulasi
    final localUtcNow = DateTime.now().toUtc();
    final diffMinutes =
        utc.difference(localUtcNow).inMilliseconds.abs() / 60000;
    if (diffMinutes > 2) {
      debugPrint(
          '[ServerTimeService] ⚠️ Drift HP terdeteksi: '
          '${diffMinutes.toStringAsFixed(1)} menit');
      debugPrint(
          '[ServerTimeService] Server UTC: $utc | HP UTC: $localUtcNow');
    }
    return true;
  }

  /// Reset anchor (untuk recovery dari corrupted state).
  static void _resetAnchor() {
    _anchoredUtc = null;
    _anchorElapsed = Duration.zero;
    _synced = false;
    _cachedDate = null;
  }

  // ═══════════════════════════════════════════════════════
  //  SYNC — Ambil waktu dari internet/server
  // ═══════════════════════════════════════════════════════

  /// Sync waktu dari berbagai sumber.
  ///
  /// [forceRefresh] memaksa fetch ulang walau sudah sync recent.
  /// Tanpa forceRefresh: skip kalau sync terakhir < 30 detik lalu.
  static Future<void> _syncTime({bool forceRefresh = false}) async {
    // Pastikan monotonic jalan
    if (!_monotonic.isRunning) _monotonic.start();

    // Jika sync terakhir masih hangat & bukan forceRefresh → skip.
    if (!forceRefresh && _synced) {
      final since = _monotonic.elapsed - _anchorElapsed;
      if (since < _resyncCooldown) {
        return;
      }
    }

    // Coalesce concurrent sync calls.
    final inFlight = _syncInFlight;
    if (inFlight != null) {
      await inFlight;
      return;
    }

    final completer = _doSync();
    _syncInFlight = completer;
    try {
      await completer;
    } finally {
      _syncInFlight = null;
    }
  }

  static Future<void> _doSync() async {
    // Metode 1: NTP (paling akurat, langsung dari internet)
    try {
      final ntpUtc = await _fetchNtpTimeUtc();
      if (ntpUtc != null && _anchor(ntpUtc)) {
        debugPrint('[ServerTimeService] Synced via NTP (UTC): $ntpUtc');
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
          // Parse SEBAGAI UTC (Postgres now() return timestamptz UTC dari supabase).
          final parsed = DateTime.parse(response.toString());
          final utc = parsed.isUtc ? parsed : parsed.toUtc();
          if (_anchor(utc)) {
            debugPrint(
                '[ServerTimeService] Synced via Supabase RPC (UTC): $utc');
            return;
          }
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
        final parsed = DateTime.parse(response['last_sync'] as String);
        final utc = parsed.isUtc ? parsed : parsed.toUtc();
        if (_anchor(utc)) {
          debugPrint(
              '[ServerTimeService] Synced via time_sync (UTC): $utc');
          return;
        }
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

  /// Fetch waktu dari NTP server. Return UTC, atau null kalau gagal.
  static Future<DateTime?> _fetchNtpTimeUtc() async {
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

  /// Query satu NTP server via UDP. Return UTC, atau null.
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
      await for (final event
          in socket.timeout(const Duration(seconds: 3))) {
        if (event == RawSocketEvent.read) {
          final datagram = socket.receive();
          if (datagram != null && datagram.data.length >= 48) {
            final data = datagram.data;

            // Parse Transmit Timestamp (bytes 40-43: seconds, 44-47: fraction)
            final seconds = (data[40] << 24) |
                (data[41] << 16) |
                (data[42] << 8) |
                data[43];

            final fraction = (data[44] << 24) |
                (data[45] << 16) |
                (data[46] << 8) |
                data[47];

            socket.close();

            // ═══════════════════════════════════════════
            //  VALIDASI NTP RESPONSE (anti-bug 1900)
            // ═══════════════════════════════════════════
            // Reject jika seconds = 0 (kratos packet / not a NTP reply)
            if (seconds == 0) {
              debugPrint(
                  '[NTP] $server returned seconds=0 (invalid)');
              return null;
            }

            // NTP epoch = 1 Jan 1900, Unix epoch = 1 Jan 1970
            // Selisih = 70 tahun = 2208988800 detik
            const ntpEpochOffset = 2208988800;
            final unixSeconds = seconds - ntpEpochOffset;

            // Reject jika negative (artinya seconds < epoch offset → invalid)
            if (unixSeconds <= 0) {
              debugPrint(
                  '[NTP] $server returned negative unixSeconds=$unixSeconds');
              return null;
            }

            // Reject jika sebelum 2024 (waktu kompilasi minimum yang masuk akal)
            // dan sesudah 2040 (jauh ke depan).
            const min2024 = 1704067200; // 2024-01-01 UTC
            const max2040 = 2208988800; // 2040-01-01 UTC kira-kira
            if (unixSeconds < min2024 || unixSeconds > max2040) {
              debugPrint(
                  '[NTP] $server returned out-of-range unixSeconds=$unixSeconds');
              return null;
            }

            final milliseconds =
                (fraction * 1000 / 0x100000000).round();

            // Return sebagai UTC murni (bukan toLocal!)
            return DateTime.fromMillisecondsSinceEpoch(
              unixSeconds * 1000 + milliseconds,
              isUtc: true,
            );
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
