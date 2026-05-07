import 'package:flutter/foundation.dart';
import 'supabase_service.dart';

/// Service untuk mengelola jadwal kerja & hari libur karyawan.
abstract final class ScheduleService {
  /// Nama hari dalam Bahasa Indonesia (index 0 = Minggu).
  static const dayNames = [
    'Minggu',
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
  ];

  /// Nama hari singkat.
  static const dayNamesShort = [
    'Min',
    'Sen',
    'Sel',
    'Rab',
    'Kam',
    'Jum',
    'Sab',
  ];

  /// Ambil daftar hari libur mingguan untuk pegawai.
  ///
  /// Mengembalikan list `day_of_week` (0=Minggu, 1=Senin, ..., 6=Sabtu).
  static Future<List<int>> getOffDays({
    required String employeeId,
  }) async {
    try {
      await SupabaseService.ensureAuthenticated();

      final response = await SupabaseService.client
          .from('employee_off_days')
          .select('day_of_week')
          .eq('employee_id', employeeId);

      final data = List<Map<String, dynamic>>.from(response as List);
      return data.map((row) => row['day_of_week'] as int).toList();
    } catch (e) {
      debugPrint('[ScheduleService] getOffDays error: $e');
      return [];
    }
  }

  /// Ambil override hari libur/masuk khusus untuk pegawai pada bulan tertentu.
  ///
  /// Override bisa berupa:
  /// - `libur`: hari yang seharusnya masuk tapi dijadikan libur
  /// - `masuk`: hari yang seharusnya libur tapi dijadikan masuk
  static Future<List<Map<String, dynamic>>> getLeaveOverrides({
    required String employeeId,
    required int month,
    required int year,
  }) async {
    try {
      await SupabaseService.ensureAuthenticated();

      final startDate = '$year-${month.toString().padLeft(2, '0')}-01';
      final endMonth = month == 12 ? 1 : month + 1;
      final endYear = month == 12 ? year + 1 : year;
      final endDate = '$endYear-${endMonth.toString().padLeft(2, '0')}-01';

      final response = await SupabaseService.client
          .from('employee_leave_overrides')
          .select()
          .eq('employee_id', employeeId)
          .gte('tanggal', startDate)
          .lt('tanggal', endDate)
          .order('tanggal');

      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('[ScheduleService] getLeaveOverrides error: $e');
      return [];
    }
  }

  /// Hitung jumlah hari kerja dan hari libur dalam satu bulan.
  ///
  /// Mengembalikan map:
  /// - `totalHari`: total hari dalam bulan
  /// - `hariKerja`: jumlah hari kerja
  /// - `hariLibur`: jumlah hari libur
  static Map<String, int> calculateMonthlySchedule({
    required int month,
    required int year,
    required List<int> offDays,
    List<Map<String, dynamic>> overrides = const [],
  }) {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    int hariKerja = 0;
    int hariLibur = 0;

    // Set tanggal override
    final overrideMap = <String, String>{};
    for (final o in overrides) {
      overrideMap[o['tanggal'] as String] = o['type'] as String;
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(year, month, day);
      final dayOfWeek = date.weekday % 7; // Convert: Mon=1..Sun=7 → Sun=0..Sat=6
      final dateStr =
          '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

      final override = overrideMap[dateStr];

      if (override == 'libur') {
        hariLibur++;
      } else if (override == 'masuk') {
        hariKerja++;
      } else if (offDays.contains(dayOfWeek)) {
        hariLibur++;
      } else {
        hariKerja++;
      }
    }

    return {
      'totalHari': daysInMonth,
      'hariKerja': hariKerja,
      'hariLibur': hariLibur,
    };
  }
}
