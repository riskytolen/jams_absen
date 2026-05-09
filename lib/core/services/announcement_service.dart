import 'package:flutter/foundation.dart';
import 'server_time_service.dart';
import 'supabase_service.dart';

/// Service untuk mengelola data pengumuman perusahaan.
abstract final class AnnouncementService {
  /// Ambil semua pengumuman aktif yang berlaku saat ini,
  /// difilter berdasarkan jabatan pegawai.
  ///
  /// Pengumuman ditampilkan jika:
  /// - target = 'Semua', atau
  /// - target = 'Jabatan' dan jabatanId ada di target_ids
  ///
  /// Filter tambahan: status Aktif, tanggal_mulai <= hari ini,
  /// tanggal_berakhir null atau >= hari ini.
  /// Pinned di atas, lalu urutkan dari terbaru.
  static Future<List<Map<String, dynamic>>> getAnnouncements({
    int? jabatanId,
  }) async {
    try {
      await SupabaseService.ensureAuthenticated();

      final todayStr = await ServerTimeService.getServerDate();

      final response = await SupabaseService.client
          .from('announcements')
          .select()
          .eq('status', 'Aktif')
          .lte('tanggal_mulai', todayStr)
          .order('is_pinned', ascending: false)
          .order('created_at', ascending: false);

      final data = List<Map<String, dynamic>>.from(response as List);

      return data.where((a) {
        // Filter tanggal berakhir
        final berakhir = a['tanggal_berakhir'] as String?;
        if (berakhir != null && berakhir.compareTo(todayStr) < 0) {
          return false;
        }

        // Filter target jabatan
        final target = a['target'] as String? ?? 'Semua';
        if (target == 'Semua') return true;

        if (target == 'Jabatan' && jabatanId != null) {
          final targetIds = a['target_ids'] as List?;
          if (targetIds == null || targetIds.isEmpty) return false;
          // target_ids bisa berisi String atau int
          return targetIds.any((id) => id.toString() == jabatanId.toString());
        }

        return false;
      }).toList();
    } catch (e) {
      debugPrint('[AnnouncementService] getAnnouncements error: $e');
      return [];
    }
  }

  /// Hitung jumlah pengumuman aktif untuk jabatan tertentu (untuk badge).
  static Future<int> getActiveCount({int? jabatanId}) async {
    try {
      final announcements = await getAnnouncements(jabatanId: jabatanId);
      return announcements.length;
    } catch (e) {
      debugPrint('[AnnouncementService] getActiveCount error: $e');
      return 0;
    }
  }
}
