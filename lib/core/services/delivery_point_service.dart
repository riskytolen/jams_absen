import 'package:flutter/foundation.dart';
import 'supabase_service.dart';

/// Service untuk mengelola data rekap titik pengiriman (delivery points).
abstract final class DeliveryPointService {
  /// Ambil semua delivery points untuk pegawai dalam periode tertentu.
  ///
  /// Diurutkan dari tanggal terbaru.
  static Future<List<Map<String, dynamic>>> getDeliveryPoints({
    required String employeeId,
    required String startDate,
    required String endDate,
  }) async {
    try {
      await SupabaseService.ensureAuthenticated();

      final response = await SupabaseService.client
          .from('delivery_points')
          .select('*, delivery_zones(nama, color)')
          .eq('employee_id', employeeId)
          .gte('tanggal', startDate)
          .lte('tanggal', endDate)
          .order('tanggal', ascending: false);

      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('[DeliveryPointService] getDeliveryPoints error: $e');
      return [];
    }
  }

  /// Hitung ringkasan rekap titik untuk periode tertentu.
  ///
  /// Mengembalikan map:
  /// - `totalTitik`: total jumlah titik
  /// - `totalPendapatan`: total rupiah dari titik
  /// - `totalHari`: jumlah hari kerja (distinct tanggal)
  /// - `rataPerHari`: rata-rata titik per hari
  static Future<Map<String, dynamic>> getPeriodSummary({
    required String employeeId,
    required String startDate,
    required String endDate,
  }) async {
    try {
      await SupabaseService.ensureAuthenticated();

      final response = await SupabaseService.client
          .from('delivery_points')
          .select('tanggal, jumlah_titik, total')
          .eq('employee_id', employeeId)
          .gte('tanggal', startDate)
          .lte('tanggal', endDate);

      final data = List<Map<String, dynamic>>.from(response as List);

      int totalTitik = 0;
      int totalPendapatan = 0;
      final Set<String> uniqueDates = {};

      for (final row in data) {
        totalTitik += (row['jumlah_titik'] as int?) ?? 0;
        totalPendapatan += (row['total'] as int?) ?? 0;
        uniqueDates.add(row['tanggal'] as String);
      }

      final totalHari = uniqueDates.length;
      final rataPerHari = totalHari > 0 ? (totalTitik / totalHari).round() : 0;

      return {
        'totalTitik': totalTitik,
        'totalPendapatan': totalPendapatan,
        'totalHari': totalHari,
        'rataPerHari': rataPerHari,
      };
    } catch (e) {
      debugPrint('[DeliveryPointService] getPeriodSummary error: $e');
      return {
        'totalTitik': 0,
        'totalPendapatan': 0,
        'totalHari': 0,
        'rataPerHari': 0,
      };
    }
  }
}
