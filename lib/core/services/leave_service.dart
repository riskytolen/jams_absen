import 'dart:io';

import 'package:flutter/foundation.dart';
import 'server_time_service.dart';
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

  /// Ambil pengaturan cuti dari tabel `leave_settings`.
  ///
  /// Mengembalikan map:
  /// - `kuota_cuti_tahunan`: kuota cuti per tahun
  /// - `maks_hari_per_pengajuan`: maks hari per satu pengajuan
  /// - `prorata`: apakah prorata untuk pegawai baru
  static Future<Map<String, dynamic>> getLeaveSettings() async {
    try {
      await SupabaseService.ensureAuthenticated();

      final serverTime = ServerTimeService.getEstimatedServerTime();
      final year = (serverTime ?? DateTime.now()).year;

      final response = await SupabaseService.client
          .from('leave_settings')
          .select()
          .eq('tahun_berlaku', year)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        return Map<String, dynamic>.from(response);
      }

      // Fallback: ambil setting terbaru jika tahun ini belum ada
      final fallback = await SupabaseService.client
          .from('leave_settings')
          .select()
          .order('tahun_berlaku', ascending: false)
          .limit(1)
          .maybeSingle();

      if (fallback != null) {
        return Map<String, dynamic>.from(fallback);
      }

      // Default jika tidak ada data sama sekali
      return {
        'kuota_cuti_tahunan': 12,
        'maks_hari_per_pengajuan': 3,
        'prorata': true,
      };
    } catch (e) {
      debugPrint('[LeaveService] getLeaveSettings error: $e');
      return {
        'kuota_cuti_tahunan': 12,
        'maks_hari_per_pengajuan': 3,
        'prorata': true,
      };
    }
  }

  /// Hitung detail sisa cuti dari database.
  ///
  /// Kuota diambil dari tabel `leave_settings`.
  /// Mengembalikan map:
  /// - `quota`: kuota tahunan dari settings
  /// - `used`: hari cuti yang sudah disetujui tahun ini
  /// - `pending`: hari cuti yang sedang menunggu approval
  /// - `remaining`: sisa cuti (quota - used)
  /// - `maksPerPengajuan`: maks hari per satu pengajuan
  static Future<Map<String, int>> getLeaveBalance({
    required String employeeId,
  }) async {
    try {
      await SupabaseService.ensureAuthenticated();

      final serverTime = ServerTimeService.getEstimatedServerTime();
      final year = (serverTime ?? DateTime.now()).year;

      // Fetch settings & leave data
      final settings = await getLeaveSettings();
      final leaveData = await SupabaseService.client
          .from('leave_requests')
          .select('tanggal_mulai, tanggal_selesai, status')
          .eq('employee_id', employeeId)
          .eq('jenis', 'Cuti')
          .inFilter('status', ['Disetujui', 'Menunggu'])
          .gte('tanggal_mulai', '$year-01-01')
          .lte('tanggal_selesai', '$year-12-31');

      final annualQuota = settings['kuota_cuti_tahunan'] as int? ?? 12;
      final maksPerPengajuan = settings['maks_hari_per_pengajuan'] as int? ?? 3;

      int usedDays = 0;
      int pendingDays = 0;

      for (final row in leaveData) {
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
        'maksPerPengajuan': maksPerPengajuan,
      };
    } catch (e) {
      debugPrint('[LeaveService] getLeaveBalance error: $e');
      return {
        'quota': 12,
        'used': 0,
        'pending': 0,
        'remaining': 12,
        'maksPerPengajuan': 3,
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
