import 'dart:io';

import 'package:flutter/foundation.dart';
import 'supabase_service.dart';

/// Service untuk mengelola pengajuan cuti/izin/sakit.
abstract final class LeaveService {
  /// Ambil semua leave requests untuk pegawai.
  ///
  /// Diurutkan dari terbaru.
  static Future<List<Map<String, dynamic>>> getLeaveRequests({
    required String employeeId,
    String? statusFilter,
  }) async {
    try {
      await SupabaseService.ensureAuthenticated();

      var query = SupabaseService.client
          .from('leave_requests')
          .select()
          .eq('employee_id', employeeId)
          .order('created_at', ascending: false);

      final response = await query;
      var results = List<Map<String, dynamic>>.from(response as List);

      if (statusFilter != null) {
        results = results.where((r) => r['status'] == statusFilter).toList();
      }

      return results;
    } catch (e) {
      debugPrint('[LeaveService] getLeaveRequests error: $e');
      return [];
    }
  }

  /// Ajukan leave request baru (cuti/izin/sakit).
  static Future<Map<String, dynamic>> submitLeaveRequest({
    required String employeeId,
    required String jenis, // 'Izin', 'Sakit', 'Cuti'
    required DateTime tanggalMulai,
    required DateTime tanggalSelesai,
    String? alasan,
    String? lampiranUrl,
  }) async {
    try {
      await SupabaseService.ensureAuthenticated();

      final data = {
        'employee_id': employeeId,
        'jenis': jenis,
        'tanggal_mulai': _formatDate(tanggalMulai),
        'tanggal_selesai': _formatDate(tanggalSelesai),
        'alasan': alasan,
        'lampiran_url': lampiranUrl,
        'status': 'Menunggu',
      };

      final response = await SupabaseService.client
          .from('leave_requests')
          .insert(data)
          .select()
          .single();

      return Map<String, dynamic>.from(response);
    } catch (e) {
      debugPrint('[LeaveService] submitLeaveRequest error: $e');
      throw LeaveException('Gagal mengajukan permohonan: $e');
    }
  }

  /// Batalkan leave request (hanya jika status masih 'Menunggu').
  static Future<void> cancelLeaveRequest(int requestId) async {
    try {
      await SupabaseService.ensureAuthenticated();

      await SupabaseService.client
          .from('leave_requests')
          .delete()
          .eq('id', requestId)
          .eq('status', 'Menunggu');
    } catch (e) {
      debugPrint('[LeaveService] cancelLeaveRequest error: $e');
      throw LeaveException('Gagal membatalkan permohonan: $e');
    }
  }

  /// Hitung jumlah permohonan yang masih berstatus 'Menunggu'.
  ///
  /// Digunakan untuk badge di menu dashboard.
  static Future<int> getPendingCount({
    required String employeeId,
  }) async {
    try {
      await SupabaseService.ensureAuthenticated();

      final response = await SupabaseService.client
          .from('leave_requests')
          .select('id')
          .eq('employee_id', employeeId)
          .eq('status', 'Menunggu');

      return (response as List).length;
    } catch (e) {
      debugPrint('[LeaveService] getPendingCount error: $e');
      return 0;
    }
  }

  /// Hitung detail sisa cuti dari database.
  ///
  /// Mengembalikan map:
  /// - `quota`: kuota tahunan (default 12)
  /// - `used`: hari cuti yang sudah disetujui tahun ini
  /// - `pending`: hari cuti yang sedang menunggu approval
  /// - `remaining`: sisa cuti (quota - used)
  static Future<Map<String, int>> getLeaveBalance({
    required String employeeId,
    int annualQuota = 12,
  }) async {
    try {
      await SupabaseService.ensureAuthenticated();

      final year = DateTime.now().year;

      // Ambil semua cuti tahun ini (Disetujui + Menunggu)
      final response = await SupabaseService.client
          .from('leave_requests')
          .select('tanggal_mulai, tanggal_selesai, status')
          .eq('employee_id', employeeId)
          .eq('jenis', 'Cuti')
          .inFilter('status', ['Disetujui', 'Menunggu'])
          .gte('tanggal_mulai', '$year-01-01')
          .lte('tanggal_selesai', '$year-12-31');

      int usedDays = 0;
      int pendingDays = 0;

      for (final row in response as List) {
        final start = DateTime.parse(row['tanggal_mulai'] as String);
        final end = DateTime.parse(row['tanggal_selesai'] as String);
        final days = end.difference(start).inDays + 1;
        final status = row['status'] as String;

        if (status == 'Disetujui') {
          usedDays += days;
        } else {
          pendingDays += days;
        }
      }

      return {
        'quota': annualQuota,
        'used': usedDays,
        'pending': pendingDays,
        'remaining': annualQuota - usedDays,
      };
    } catch (e) {
      debugPrint('[LeaveService] getLeaveBalance error: $e');
      return {
        'quota': annualQuota,
        'used': 0,
        'pending': 0,
        'remaining': annualQuota,
      };
    }
  }

  /// Upload lampiran bukti ke Supabase Storage.
  ///
  /// Returns public URL dari file yang diupload.
  static Future<String> uploadAttachment({
    required String employeeId,
    required String filePath,
  }) async {
    try {
      await SupabaseService.ensureAuthenticated();

      final file = File(filePath);
      final ext = filePath.split('.').last.toLowerCase();
      final fileName =
          'leave_${employeeId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final storagePath = '$employeeId/$fileName';

      await SupabaseService.client.storage
          .from('leave-attachments')
          .upload(storagePath, file);

      final url = SupabaseService.client.storage
          .from('leave-attachments')
          .getPublicUrl(storagePath);

      return url;
    } catch (e) {
      debugPrint('[LeaveService] uploadAttachment error: $e');
      throw LeaveException('Gagal mengupload lampiran: $e');
    }
  }

  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

/// Exception untuk leave service.
class LeaveException implements Exception {
  final String message;
  const LeaveException(this.message);

  @override
  String toString() => 'LeaveException: $message';
}
