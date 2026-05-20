import 'package:flutter/foundation.dart';

import 'server_time_service.dart';
import 'supabase_service.dart';

/// Service untuk mengelola pengajuan lembur.
abstract final class OvertimeService {
  /// Ambil semua pengajuan lembur untuk pegawai.
  ///
  /// Diurutkan dari terbaru.
  static Future<List<Map<String, dynamic>>> getOvertimeRequests({
    required String employeeId,
    String? statusFilter,
  }) async {
    try {
      await SupabaseService.ensureAuthenticated();

      final response = await SupabaseService.client
          .from('overtime_requests')
          .select()
          .eq('employee_id', employeeId)
          .order('created_at', ascending: false);

      var results = List<Map<String, dynamic>>.from(response as List);

      if (statusFilter != null) {
        results = results.where((r) => r['status'] == statusFilter).toList();
      }

      return results;
    } catch (e) {
      debugPrint('[OvertimeService] getOvertimeRequests error: $e');
      return [];
    }
  }

  /// Ajukan lembur baru.
  ///
  /// `tanggal` boleh hari ini atau hari yang sudah lewat (retroaktif).
  /// `jamMulai` < `jamSelesai`.
  static Future<Map<String, dynamic>> submitOvertimeRequest({
    required String employeeId,
    required DateTime tanggal,
    required String jamMulai,    // format HH:mm
    required String jamSelesai,  // format HH:mm
    String? alasan,
  }) async {
    try {
      await SupabaseService.ensureAuthenticated();

      final data = {
        'employee_id': employeeId,
        'tanggal': _formatDate(tanggal),
        'jam_mulai': jamMulai,
        'jam_selesai': jamSelesai,
        'alasan': alasan,
        'status': 'Menunggu',
      };

      final response = await SupabaseService.client
          .from('overtime_requests')
          .insert(data)
          .select()
          .single();

      return Map<String, dynamic>.from(response);
    } catch (e) {
      debugPrint('[OvertimeService] submitOvertimeRequest error: $e');
      throw OvertimeException('Gagal mengajukan lembur: $e');
    }
  }

  /// Batalkan pengajuan lembur (hanya jika status masih 'Menunggu').
  static Future<void> cancelOvertimeRequest(int requestId) async {
    try {
      await SupabaseService.ensureAuthenticated();

      await SupabaseService.client
          .from('overtime_requests')
          .delete()
          .eq('id', requestId)
          .eq('status', 'Menunggu');
    } catch (e) {
      debugPrint('[OvertimeService] cancelOvertimeRequest error: $e');
      throw OvertimeException('Gagal membatalkan pengajuan: $e');
    }
  }

  /// Hitung jumlah pengajuan yang masih berstatus 'Menunggu'.
  ///
  /// Digunakan untuk badge di menu dashboard.
  static Future<int> getPendingCount({
    required String employeeId,
  }) async {
    try {
      await SupabaseService.ensureAuthenticated();

      final response = await SupabaseService.client
          .from('overtime_requests')
          .select('id')
          .eq('employee_id', employeeId)
          .eq('status', 'Menunggu');

      return (response as List).length;
    } catch (e) {
      debugPrint('[OvertimeService] getPendingCount error: $e');
      return 0;
    }
  }

  /// Ringkasan total lembur disetujui untuk periode tertentu (mis. bulan ini).
  ///
  /// Returns map: { count, total_lembur, total_durasi_menit }
  static Future<Map<String, int>> getApprovedSummary({
    required String employeeId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      await SupabaseService.ensureAuthenticated();

      final serverTime = ServerTimeService.getEstimatedServerTime();
      final now = serverTime ?? DateTime.now();
      final start = startDate ?? DateTime(now.year, now.month, 1);
      final end = endDate ?? DateTime(now.year, now.month + 1, 0);

      final response = await SupabaseService.client
          .from('overtime_requests')
          .select('total_lembur, durasi_menit')
          .eq('employee_id', employeeId)
          .eq('status', 'Disetujui')
          .gte('tanggal', _formatDate(start))
          .lte('tanggal', _formatDate(end));

      final list = List<Map<String, dynamic>>.from(response as List);

      int totalLembur = 0;
      int totalMenit = 0;
      for (final row in list) {
        totalLembur += (row['total_lembur'] as int?) ?? 0;
        totalMenit += (row['durasi_menit'] as int?) ?? 0;
      }

      return {
        'count': list.length,
        'total_lembur': totalLembur,
        'total_durasi_menit': totalMenit,
      };
    } catch (e) {
      debugPrint('[OvertimeService] getApprovedSummary error: $e');
      return {'count': 0, 'total_lembur': 0, 'total_durasi_menit': 0};
    }
  }

  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

/// Exception untuk overtime service.
class OvertimeException implements Exception {
  final String message;
  const OvertimeException(this.message);

  @override
  String toString() => 'OvertimeException: $message';
}
