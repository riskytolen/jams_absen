import 'package:flutter/foundation.dart';

import 'supabase_service.dart';

abstract final class PayrollService {
  static Future<List<Map<String, dynamic>>> getFinalPayrolls({
    required String employeeId,
  }) async {
    try {
      await SupabaseService.ensureAuthenticated();
      final response = await SupabaseService.client
          .from('payrolls')
          .select()
          .eq('employee_id', employeeId)
          .eq('status', 'Final')
          .order('periode_mulai', ascending: false);
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('[PayrollService] getFinalPayrolls error: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getDeliveryPointDetails({
    required String employeeId,
    required String startDate,
    required String endDate,
  }) async {
    try {
      await SupabaseService.ensureAuthenticated();
      final response = await SupabaseService.client
          .from('delivery_points')
          .select(
            '*, delivery_zones(nama, color), delivery_statuses(nama, kode, color)',
          )
          .eq('employee_id', employeeId)
          .gte('tanggal', startDate)
          .lte('tanggal', endDate)
          .order('tanggal', ascending: false);
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('[PayrollService] getDeliveryPointDetails error: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getOvertimeDetails({
    required String employeeId,
    required String startDate,
    required String endDate,
  }) async {
    try {
      await SupabaseService.ensureAuthenticated();
      final response = await SupabaseService.client
          .from('overtime_requests')
          .select(
            'tanggal, jam_mulai, jam_selesai, durasi_menit, rate_per_jam, total_lembur, alasan',
          )
          .eq('employee_id', employeeId)
          .eq('status', 'Disetujui')
          .gte('tanggal', startDate)
          .lte('tanggal', endDate)
          .order('tanggal', ascending: false);
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('[PayrollService] getOvertimeDetails error: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getAttendanceDeductionDetails({
    required String employeeId,
    required String startDate,
    required String endDate,
  }) async {
    try {
      await SupabaseService.ensureAuthenticated();
      final response = await SupabaseService.client
          .from('attendance_records')
          .select(
            'tanggal, status, durasi_telat, denda, catatan, alasan_manual',
          )
          .eq('employee_id', employeeId)
          .gte('tanggal', startDate)
          .lte('tanggal', endDate)
          .gt('denda', 0)
          .order('tanggal', ascending: false);
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('[PayrollService] getAttendanceDeductionDetails error: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getFinalPayrollById({
    required int payrollId,
    required String employeeId,
  }) async {
    try {
      await SupabaseService.ensureAuthenticated();
      final response = await SupabaseService.client
          .from('payrolls')
          .select()
          .eq('id', payrollId)
          .eq('employee_id', employeeId)
          .eq('status', 'Final')
          .maybeSingle();
      if (response == null) return null;
      return Map<String, dynamic>.from(response);
    } catch (e) {
      debugPrint('[PayrollService] getFinalPayrollById error: $e');
      return null;
    }
  }
}
