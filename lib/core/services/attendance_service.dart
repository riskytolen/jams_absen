import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'location_service.dart';
import 'server_time_service.dart';
import 'session_service.dart';
import 'supabase_service.dart';

// ══════════════════════════════════════════════════════════════════════════════
// Exception khusus untuk error absensi
// ══════════════════════════════════════════════════════════════════════════════

/// Tipe error absensi.
enum AttendanceErrorType {
  /// Gagal autentikasi ke Supabase.
  authFailed,

  /// Tidak ada divisi aktif.
  noDivision,

  /// Tidak ada jadwal untuk divisi.
  noSchedule,

  /// Tidak ada lokasi yang di-assign ke divisi.
  noLocation,

  /// Posisi user di luar radius semua lokasi.
  outOfRange,

  /// Sudah absen hari ini (duplikat).
  alreadyCheckedIn,

  /// Belum waktunya absen (sebelum window mulai).
  tooEarly,

  /// Error database / network.
  databaseError,

  /// Error tidak diketahui.
  unknown,
}

/// Exception khusus untuk error absensi.
class AttendanceException implements Exception {
  final AttendanceErrorType type;
  final String message;

  const AttendanceException({
    required this.type,
    required this.message,
  });

  @override
  String toString() => message;
}

/// Hasil pengecekan window absen (boleh absen sekarang atau belum).
class AttendanceWindowResult {
  /// True jika sekarang sudah masuk window absen (boleh lanjut).
  final bool allowed;

  /// Format "HH:mm" jam mulai bisa absen. Null jika fitur OFF.
  final String? earliestTime;

  /// Format "HH:mm" jam masuk divisi.
  final String jamMasuk;

  /// Berapa menit sebelum jam_masuk pegawai bisa mulai absen.
  /// 0 = fitur tidak aktif untuk divisi ini.
  final int awalAbsenMenit;

  const AttendanceWindowResult({
    required this.allowed,
    required this.earliestTime,
    required this.jamMasuk,
    required this.awalAbsenMenit,
  });
}

// ══════════════════════════════════════════════════════════════════════════════
// Attendance Service
// ══════════════════════════════════════════════════════════════════════════════

/// Service untuk proses absensi — validasi lokasi, jadwal, dan insert record.
///
/// Semua method bersifat static. Gunakan:
/// ```dart
/// final divisions = await AttendanceService.getActiveDivisions();
/// await AttendanceService.submitAttendance(employeeId: '...', divisionId: 1);
/// ```
abstract final class AttendanceService {
  // ── Fetch Divisi Aktif ──────────────────────────────────────────────────

  /// Ambil daftar divisi yang statusnya 'Aktif'.
  ///
  /// Returns list of Map dengan keys: id, nama, color, status.
  /// Throws [AttendanceException] jika gagal.
  static Future<List<Map<String, dynamic>>> getActiveDivisions() async {
    try {
      await SupabaseService.ensureAuthenticated();

      final response = await SupabaseService.client
          .from('divisions')
          .select('id, nama, color, status')
          .eq('status', 'Aktif')
          .order('nama');

      final data = List<Map<String, dynamic>>.from(response);

      if (data.isEmpty) {
        throw const AttendanceException(
          type: AttendanceErrorType.noDivision,
          message: 'Tidak ada divisi aktif saat ini.',
        );
      }

      return data;
    } on AttendanceException {
      rethrow;
    } catch (e) {
      debugPrint('[AttendanceService] getActiveDivisions error: $e');
      throw AttendanceException(
        type: AttendanceErrorType.databaseError,
        message: 'Gagal mengambil data divisi: $e',
      );
    }
  }

  // ── Fetch Lokasi Divisi ─────────────────────────────────────────────────

  /// Ambil daftar lokasi yang di-assign ke divisi tertentu.
  ///
  /// Join `division_location_assignments` dengan `attendance_locations`.
  /// Hanya lokasi dengan status 'Aktif' yang dikembalikan.
  ///
  /// Returns list of Map dengan keys: id, nama, latitude, longitude, radius.
  /// Throws [AttendanceException] jika tidak ada lokasi.
  static Future<List<Map<String, dynamic>>> getDivisionLocations(
    int divisionId,
  ) async {
    try {
      await SupabaseService.ensureAuthenticated();

      // Query assignment dulu, lalu fetch lokasi terpisah
      // untuk menghindari masalah filter nested join di PostgREST
      final assignments = await SupabaseService.client
          .from('division_location_assignments')
          .select('location_id')
          .eq('division_id', divisionId);

      final assignmentList = List<Map<String, dynamic>>.from(assignments);

      if (assignmentList.isEmpty) {
        throw const AttendanceException(
          type: AttendanceErrorType.noLocation,
          message: 'Tidak ada lokasi absensi yang di-assign ke divisi ini.',
        );
      }

      final locationIds = assignmentList
          .map((a) => a['location_id'] as int)
          .toList();

      // Fetch lokasi aktif berdasarkan IDs
      final locResponse = await SupabaseService.client
          .from('attendance_locations')
          .select('id, nama, latitude, longitude, radius')
          .inFilter('id', locationIds)
          .eq('status', 'Aktif');

      final locations = List<Map<String, dynamic>>.from(locResponse)
          .map((loc) => {
                'id': loc['id'],
                'nama': loc['nama'],
                'latitude': (loc['latitude'] as num).toDouble(),
                'longitude': (loc['longitude'] as num).toDouble(),
                'radius': (loc['radius'] as num).toDouble(),
              })
          .toList();

      if (locations.isEmpty) {
        throw const AttendanceException(
          type: AttendanceErrorType.noLocation,
          message: 'Tidak ada lokasi absensi aktif untuk divisi ini.',
        );
      }

      debugPrint('[AttendanceService] Lokasi divisi $divisionId: $locations');
      return locations;
    } on AttendanceException {
      rethrow;
    } catch (e) {
      debugPrint('[AttendanceService] getDivisionLocations error: $e');
      throw AttendanceException(
        type: AttendanceErrorType.databaseError,
        message: 'Gagal mengambil data lokasi divisi: $e',
      );
    }
  }

  // ── Validasi Posisi User ────────────────────────────────────────────────

  /// Cek apakah posisi user berada dalam radius salah satu lokasi.
  ///
  /// Returns Map lokasi yang cocok (terdekat dalam radius), atau null.
  /// Menggunakan Geolocator.distanceBetween untuk kalkulasi jarak.
  static Map<String, dynamic>? findNearestValidLocation({
    required Position userPosition,
    required List<Map<String, dynamic>> locations,
  }) {
    Map<String, dynamic>? nearestLocation;
    double nearestDistance = double.infinity;

    debugPrint('[AttendanceService] User position: '
        '${userPosition.latitude}, ${userPosition.longitude} '
        '(accuracy: ${userPosition.accuracy}m)');

    for (final loc in locations) {
      final double locLat = loc['latitude'] as double;
      final double locLng = loc['longitude'] as double;
      final double radius = loc['radius'] as double;

      // Hitung jarak antara posisi user dan lokasi absensi
      final distance = Geolocator.distanceBetween(
        userPosition.latitude,
        userPosition.longitude,
        locLat,
        locLng,
      );

      debugPrint('[AttendanceService] Lokasi "${loc['nama']}": '
          'jarak ${distance.toStringAsFixed(1)}m, radius ${radius}m '
          '${distance <= radius ? "✓ DALAM" : "✗ LUAR"}');

      // Cek apakah dalam radius
      if (distance <= radius && distance < nearestDistance) {
        nearestDistance = distance;
        nearestLocation = {
          ...loc,
          'distance': distance,
        };
      }
    }

    return nearestLocation;
  }

  // ── Fetch Jadwal Divisi ─────────────────────────────────────────────────

  /// Ambil jadwal (schedule) untuk divisi tertentu.
  ///
  /// Returns Map dengan keys: id, division_id, jam_masuk, jam_pulang,
  /// toleransi_menit, awal_absen_menit, status.
  /// Throws [AttendanceException] jika tidak ada jadwal.
  static Future<Map<String, dynamic>> getDivisionSchedule(
    int divisionId,
  ) async {
    try {
      await SupabaseService.ensureAuthenticated();

      final response = await SupabaseService.client
          .from('division_schedules')
          .select(
              'id, division_id, jam_masuk, jam_pulang, toleransi_menit, awal_absen_menit, status')
          .eq('division_id', divisionId)
          .eq('status', 'Aktif')
          .maybeSingle();

      if (response == null) {
        throw const AttendanceException(
          type: AttendanceErrorType.noSchedule,
          message: 'Tidak ada jadwal aktif untuk divisi ini. '
              'Hubungi admin untuk mengatur jadwal.',
        );
      }

      return Map<String, dynamic>.from(response);
    } on AttendanceException {
      rethrow;
    } catch (e) {
      debugPrint('[AttendanceService] getDivisionSchedule error: $e');
      throw AttendanceException(
        type: AttendanceErrorType.databaseError,
        message: 'Gagal mengambil jadwal divisi: $e',
      );
    }
  }

  // ── Window Absen (anti-clock-in-too-early) ──────────────────────────────

  /// Cek apakah pegawai sudah boleh absen sekarang berdasarkan window divisi.
  ///
  /// Window: pegawai bisa mulai absen sejak `jam_masuk - awal_absen_menit`.
  /// Jika `awal_absen_menit = 0` → fitur OFF, selalu return allowed.
  ///
  /// Method ini dipanggil dari UI **setelah user pilih divisi** dan
  /// **sebelum** lanjut ke face verification & GPS, supaya pegawai cepat tahu
  /// kalau belum waktunya absen.
  ///
  /// Throws [AttendanceException] jika gagal ambil schedule atau server time.
  static Future<AttendanceWindowResult> checkAttendanceWindow({
    required int divisionId,
  }) async {
    final schedule = await getDivisionSchedule(divisionId);
    final jamMasukStr = schedule['jam_masuk'] as String;
    final awalAbsenMenit = (schedule['awal_absen_menit'] as int?) ?? 0;

    // Format jam_masuk -> "HH:mm" untuk tampilan
    final jamMasukDisplay = jamMasukStr.length >= 5
        ? jamMasukStr.substring(0, 5)
        : jamMasukStr;

    // Fitur OFF -> selalu allowed
    if (awalAbsenMenit <= 0) {
      return AttendanceWindowResult(
        allowed: true,
        earliestTime: null,
        jamMasuk: jamMasukDisplay,
        awalAbsenMenit: 0,
      );
    }

    // Ambil waktu server WIB fresh (selalu authoritative).
    final now = await ServerTimeService.getServerTimeForCriticalOps();

    // Hitung earliest = jam_masuk - awal_absen_menit (relative to today WIB)
    final parts = jamMasukStr.split(':');
    final scheduleHour = int.parse(parts[0]);
    final scheduleMinute = int.parse(parts[1]);
    final scheduleTime = DateTime(
      now.year, now.month, now.day,
      scheduleHour, scheduleMinute,
    );
    final earliest = scheduleTime.subtract(Duration(minutes: awalAbsenMenit));

    final earliestStr =
        '${earliest.hour.toString().padLeft(2, '0')}:${earliest.minute.toString().padLeft(2, '0')}';

    debugPrint('[AttendanceService] checkAttendanceWindow: '
        'now=$now schedule=$scheduleTime earliest=$earliest '
        'awalAbsen=$awalAbsenMenit menit allowed=${!now.isBefore(earliest)}');

    if (now.isBefore(earliest)) {
      return AttendanceWindowResult(
        allowed: false,
        earliestTime: earliestStr,
        jamMasuk: jamMasukDisplay,
        awalAbsenMenit: awalAbsenMenit,
      );
    }

    return AttendanceWindowResult(
      allowed: true,
      earliestTime: earliestStr,
      jamMasuk: jamMasukDisplay,
      awalAbsenMenit: awalAbsenMenit,
    );
  }

  // ── Fetch Record Hari Ini ─────────────────────────────────────────────

  /// Ambil record absensi hari ini untuk pegawai (jika ada).
  ///
  /// Returns Map record atau null jika belum absen.
  /// Digunakan untuk restore state dashboard setelah app restart.
  static Future<Map<String, dynamic>?> getTodayRecord(
    String employeeId,
  ) async {
    try {
      await SupabaseService.ensureAuthenticated();

      // Gunakan waktu server untuk mendapatkan tanggal hari ini
      final tanggal = await ServerTimeService.getServerDate();

      final response = await SupabaseService.client
          .from('attendance_records')
          .select('*, divisions:division_id(nama)')
          .eq('employee_id', employeeId)
          .eq('tanggal', tanggal)
          .maybeSingle();

      return response;
    } catch (e) {
      debugPrint('[AttendanceService] getTodayRecord error: $e');
      return null;
    }
  }

  // ── Cek Duplikat Absensi ────────────────────────────────────────────────

  /// Cek apakah pegawai sudah absen hari ini.
  ///
  /// Returns true jika sudah ada record untuk hari ini.
  static Future<bool> hasCheckedInToday({
    required String employeeId,
    required int divisionId,
  }) async {
    try {
      await SupabaseService.ensureAuthenticated();

      // Gunakan waktu server untuk mendapatkan tanggal hari ini
      final tanggal = await ServerTimeService.getServerDate();

      final response = await SupabaseService.client
          .from('attendance_records')
          .select('id')
          .eq('employee_id', employeeId)
          .eq('division_id', divisionId)
          .eq('tanggal', tanggal)
          .maybeSingle();

      return response != null;
    } catch (e) {
      debugPrint('[AttendanceService] hasCheckedInToday error: $e');
      throw AttendanceException(
        type: AttendanceErrorType.databaseError,
        message: 'Gagal memeriksa data absensi hari ini: $e',
      );
    }
  }

  /// Cek apakah pegawai sudah punya record absensi hari ini (tanpa filter divisi).
  ///
  /// Digunakan untuk validasi pengajuan izin/sakit/cuti.
  static Future<bool> hasAnyRecordToday(String employeeId) async {
    try {
      await SupabaseService.ensureAuthenticated();

      // Gunakan waktu server untuk mendapatkan tanggal hari ini
      final tanggal = await ServerTimeService.getServerDate();

      final response = await SupabaseService.client
          .from('attendance_records')
          .select('id')
          .eq('employee_id', employeeId)
          .eq('tanggal', tanggal)
          .maybeSingle();

      return response != null;
    } catch (e) {
      debugPrint('[AttendanceService] hasCheckedInToday (no div) error: $e');
      return false;
    }
  }

  // ── Hitung Status Kehadiran ─────────────────────────────────────────────

  /// Hitung status kehadiran berdasarkan jam masuk dan jadwal.
  ///
  /// **Penting:** [checkInTime] HARUS dalam zona waktu yang sama dengan
  /// [scheduleJamMasuk]. Untuk app ini, keduanya WAJIB WIB (UTC+7).
  /// Gunakan [ServerTimeService.getServerTime] / [getServerTimeForCriticalOps]
  /// yang sudah selalu mengembalikan DateTime WIB.
  ///
  /// Returns Map dengan keys:
  /// - `status`: 'Hadir' atau 'Terlambat'
  /// - `durasi_telat`: durasi keterlambatan dalam menit (0 jika tepat waktu)
  static Map<String, dynamic> calculateAttendanceStatus({
    required DateTime checkInTime,
    required String scheduleJamMasuk,
    required int toleransiMenit,
  }) {
    // Parse jam_masuk dari schedule (format: "HH:mm:ss" atau "HH:mm")
    final parts = scheduleJamMasuk.split(':');
    final scheduleHour = int.parse(parts[0]);
    final scheduleMinute = int.parse(parts[1]);

    // Buat DateTime untuk jadwal masuk hari ini.
    // checkInTime sudah dalam representasi WIB sehingga year/month/day
    // mengikuti tanggal WIB.
    final scheduleTime = DateTime(
      checkInTime.year,
      checkInTime.month,
      checkInTime.day,
      scheduleHour,
      scheduleMinute,
    );

    // Batas toleransi = jam_masuk + toleransi_menit
    final batasToleransi = scheduleTime.add(
      Duration(minutes: toleransiMenit),
    );

    // Defensive log untuk debugging insiden telat-padahal-tidak.
    debugPrint(
        '[AttendanceService] calc: checkIn=$checkInTime '
        'schedule=$scheduleTime batasToleransi=$batasToleransi '
        'isAfterBatas=${checkInTime.isAfter(batasToleransi)} '
        'isBeforeSchedule=${checkInTime.isBefore(scheduleTime)}');

    // Hitung selisih waktu
    if (checkInTime.isAfter(batasToleransi)) {
      // Terlambat — hitung durasi dari jam_masuk (bukan dari batas toleransi)
      final selisih = checkInTime.difference(scheduleTime);
      final durasiTelat = selisih.inMinutes;

      return {
        'status': 'Terlambat',
        'durasi_telat': durasiTelat,
      };
    }

    // Tepat waktu (dalam toleransi)
    return {
      'status': 'Hadir',
      'durasi_telat': 0,
    };
  }

  // ── Submit Absensi ──────────────────────────────────────────────────────

  /// Proses absensi lengkap: validasi lokasi, jadwal, dan insert record.
  ///
  /// PENTING: Lokasi HARUS sudah divalidasi ketat sebelum memanggil method ini!
  /// Gunakan StrictLocationValidator.validateLocationForDivision() terlebih dahulu.
  ///
  /// Flow:
  /// 1. Cek duplikat (sudah absen hari ini?)
  /// 2. Ambil jadwal divisi
  /// 3. Ambil waktu server WIB yang akurat (tidak bisa dimanipulasi!)
  /// 4. Hitung status kehadiran
  /// 5. Insert record ke database
  ///
  /// Returns Map berisi data record yang berhasil di-insert.
  /// Throws [AttendanceException] jika ada error di salah satu step.
  static Future<Map<String, dynamic>> submitAttendance({
    required String employeeId,
    required int divisionId,
    required Position validatedPosition, // HARUS sudah divalidasi!
    String? catatan,
  }) async {
    try {
      // Update session activity - ini operasi penting
      SessionService.updateActivity();
      
      // Force auth check SEKALI di awal — semua internal call skip auth
      await SupabaseService.forceEnsureAuthenticated();

      // Ambil waktu server WIB yang FRESH untuk operasi kritis
      final now = await ServerTimeService.getServerTimeForCriticalOps();
      debugPrint('[AttendanceService] Waktu server WIB untuk absensi: $now');

      // Sanity check: tolak waktu jelas-jelas invalid (mis. <2024 / >2040)
      // Mencegah edge case 1900 epoch / clock corruption merembet ke DB.
      if (now.year < 2024 || now.year > 2040) {
        throw AttendanceException(
          type: AttendanceErrorType.unknown,
          message:
              'Waktu server tidak valid ($now). Coba ulang beberapa saat lagi atau '
              'pastikan koneksi internet stabil.',
        );
      }

      final tanggal =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      // 1. Cek apakah sudah absen hari ini (gunakan tanggal dari server time WIB)
      final existingRecord = await SupabaseService.client
          .from('attendance_records')
          .select('id')
          .eq('employee_id', employeeId)
          .eq('division_id', divisionId)
          .eq('tanggal', tanggal)
          .maybeSingle();

      if (existingRecord != null) {
        throw const AttendanceException(
          type: AttendanceErrorType.alreadyCheckedIn,
          message: 'Anda sudah melakukan absensi hari ini.',
        );
      }

      // 2. Ambil jadwal divisi (langsung query, auth sudah cached)
      final schedule = await SupabaseService.client
          .from('division_schedules')
          .select(
              'id, division_id, jam_masuk, jam_pulang, toleransi_menit, awal_absen_menit, status')
          .eq('division_id', divisionId)
          .eq('status', 'Aktif')
          .maybeSingle();

      if (schedule == null) {
        throw const AttendanceException(
          type: AttendanceErrorType.noSchedule,
          message: 'Tidak ada jadwal aktif untuk divisi ini. '
              'Hubungi admin untuk mengatur jadwal.',
        );
      }

      // 3. Hitung status kehadiran menggunakan waktu WIB yang konsisten
      final jamMasukStr = schedule['jam_masuk'] as String;
      final toleransiMenit = schedule['toleransi_menit'] as int;
      final awalAbsenMenit = (schedule['awal_absen_menit'] as int?) ?? 0;

      // 3a. Defense kedua: cek window. UI seharusnya sudah cek duluan,
      // tapi tetap guard di sini agar tidak ada celah.
      if (awalAbsenMenit > 0) {
        final parts = jamMasukStr.split(':');
        final scheduleTime = DateTime(
          now.year, now.month, now.day,
          int.parse(parts[0]),
          int.parse(parts[1]),
        );
        final earliest = scheduleTime.subtract(Duration(minutes: awalAbsenMenit));
        if (now.isBefore(earliest)) {
          final earliestStr =
              '${earliest.hour.toString().padLeft(2, '0')}:${earliest.minute.toString().padLeft(2, '0')}';
          final jamMasukDisplay = jamMasukStr.length >= 5
              ? jamMasukStr.substring(0, 5)
              : jamMasukStr;
          throw AttendanceException(
            type: AttendanceErrorType.tooEarly,
            message:
                'Belum waktunya absen. Anda baru bisa absen mulai pukul $earliestStr WIB '
                '($awalAbsenMenit menit sebelum jam masuk $jamMasukDisplay).',
          );
        }
      }

      final statusResult = calculateAttendanceStatus(
        checkInTime: now, // Waktu WIB yang sudah konsisten
        scheduleJamMasuk: jamMasukStr,
        toleransiMenit: toleransiMenit,
      );

      debugPrint('[AttendanceService] Status calculation:');
      debugPrint('  - Check-in time (WIB): $now');
      debugPrint('  - Schedule jam masuk: $jamMasukStr');
      debugPrint('  - Toleransi: $toleransiMenit menit');
      debugPrint('  - Result status: ${statusResult['status']}');
      debugPrint('  - Durasi telat: ${statusResult['durasi_telat']} menit');

      // 4. Ambil lokasi divisi untuk mendapatkan location_id
      final locations = await getDivisionLocations(divisionId);
      final primaryLocation = locations.first;

      // 5. Siapkan data record
      final jamMasukRecord =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

      final record = {
        'employee_id': employeeId,
        'division_id': divisionId,
        'tanggal': tanggal,
        'jam_masuk': jamMasukRecord,
        'schedule_jam_masuk': jamMasukStr,
        'toleransi_menit': toleransiMenit,
        'status': statusResult['status'],
        'durasi_telat': statusResult['durasi_telat'],
        'denda': _calculateDenda(statusResult['durasi_telat'] as int),
        'location_id': primaryLocation['id'],
        'catatan': catatan,
      };

      debugPrint('[AttendanceService] Record to insert: $record');

      // 6. Insert ke database
      final response = await SupabaseService.client
          .from('attendance_records')
          .insert(record)
          .select()
          .single();

      debugPrint('[AttendanceService] Absensi berhasil: ${response['id']}');

      return Map<String, dynamic>.from(response);
    } on AttendanceException {
      rethrow;
    } on LocationException catch (e) {
      // Re-wrap LocationException agar caller cukup handle AttendanceException
      throw AttendanceException(
        type: AttendanceErrorType.unknown,
        message: e.message,
      );
    } catch (e) {
      debugPrint('[AttendanceService] submitAttendance error: $e');

      // Parse exception dari trigger DB enforce_server_timestamp.
      // Format pesan: "TOO_EARLY|HH:MM|HH:MM" (earliest|jam_masuk).
      final msg = e.toString();
      final tooEarlyIdx = msg.indexOf('TOO_EARLY|');
      if (tooEarlyIdx >= 0) {
        final fragment = msg.substring(tooEarlyIdx);
        final endIdx = fragment.indexOf('\n');
        final clean = endIdx >= 0 ? fragment.substring(0, endIdx) : fragment;
        final parts = clean.split('|');
        if (parts.length >= 3) {
          final earliest = parts[1].trim();
          final jamMasuk = parts[2].trim();
          throw AttendanceException(
            type: AttendanceErrorType.tooEarly,
            message:
                'Belum waktunya absen. Anda baru bisa absen mulai pukul $earliest WIB '
                '(jam masuk $jamMasuk).',
          );
        }
      }

      throw AttendanceException(
        type: AttendanceErrorType.databaseError,
        message: 'Gagal menyimpan data absensi: $e',
      );
    }
  }

  // ── Helper: Hitung Denda ────────────────────────────────────────────────

  /// Hitung denda berdasarkan durasi keterlambatan (dalam menit).
  ///
  /// Aturan default:
  /// - 0 menit terlambat = Rp 0
  /// - 1-30 menit = Rp 10.000
  /// - 31-60 menit = Rp 25.000
  /// - > 60 menit = Rp 50.000
  ///
  /// Bisa disesuaikan sesuai kebijakan perusahaan.
  static int _calculateDenda(int durasiTelat) {
    if (durasiTelat <= 0) return 0;
    if (durasiTelat <= 30) return 10000;
    if (durasiTelat <= 60) return 25000;
    return 50000;
  }

  // ── Riwayat Absensi ─────────────────────────────────────────────────

  /// Ambil riwayat absensi pegawai.
  ///
  /// [month] dan [year] untuk filter bulan/tahun.
  /// Jika tidak diisi, ambil bulan ini.
  static Future<List<Map<String, dynamic>>> getAttendanceHistory({
    required String employeeId,
    required String startDate,
    required String endDate,
  }) async {
    try {
      await SupabaseService.ensureAuthenticated();

      final response = await SupabaseService.client
          .from('attendance_records')
          .select('*, divisions:division_id(nama, color)')
          .eq('employee_id', employeeId)
          .gte('tanggal', startDate)
          .lte('tanggal', endDate)
          .order('tanggal', ascending: false);

      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('[AttendanceService] getAttendanceHistory error: $e');
      return [];
    }
  }

  // ── Statistik Kehadiran ─────────────────────────────────────────────

  /// Hitung statistik kehadiran untuk periode tertentu.
  ///
  /// Mengembalikan map:
  /// - `hadir`: jumlah hari hadir (tepat waktu)
  /// - `terlambat`: jumlah hari terlambat
  /// - `izin`: jumlah hari izin/sakit/cuti
  /// - `alpha`: jumlah hari alpha
  /// - `libur`: jumlah hari libur
  /// - `totalRecords`: total record
  static Future<Map<String, int>> getAttendanceStats({
    required String employeeId,
    required String startDate,
    required String endDate,
  }) async {
    try {
      await SupabaseService.ensureAuthenticated();

      final response = await SupabaseService.client
          .from('attendance_records')
          .select('status')
          .eq('employee_id', employeeId)
          .gte('tanggal', startDate)
          .lte('tanggal', endDate);

      final data = List<Map<String, dynamic>>.from(response as List);

      int hadir = 0;
      int terlambat = 0;
      int izin = 0;
      int alpha = 0;
      int libur = 0;

      for (final row in data) {
        switch (row['status'] as String) {
          case 'Hadir':
            hadir++;
            break;
          case 'Terlambat':
            terlambat++;
            break;
          case 'Izin':
          case 'Sakit':
          case 'Cuti':
            izin++;
            break;
          case 'Alpha':
            alpha++;
            break;
          case 'Libur':
            libur++;
            break;
        }
      }

      return {
        'hadir': hadir,
        'terlambat': terlambat,
        'izin': izin,
        'alpha': alpha,
        'libur': libur,
        'totalRecords': data.length,
      };
    } catch (e) {
      debugPrint('[AttendanceService] getAttendanceStats error: $e');
      return {
        'hadir': 0,
        'terlambat': 0,
        'izin': 0,
        'alpha': 0,
        'libur': 0,
        'totalRecords': 0,
      };
    }
  }

  /// Ambil aktivitas terbaru (5 record terakhir).
  static Future<List<Map<String, dynamic>>> getRecentActivity({
    required String employeeId,
    int limit = 5,
  }) async {
    try {
      await SupabaseService.ensureAuthenticated();

      final response = await SupabaseService.client
          .from('attendance_records')
          .select('tanggal, jam_masuk, status, durasi_telat, divisions:division_id(nama)')
          .eq('employee_id', employeeId)
          .order('tanggal', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('[AttendanceService] getRecentActivity error: $e');
      return [];
    }
  }
}
