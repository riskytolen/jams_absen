import 'package:flutter/foundation.dart';
import 'supabase_service.dart';

/// Service untuk mengelola data dokumen legal (PKWT & SP).
abstract final class DocumentService {
  /// Ambil semua dokumen legal untuk pegawai.
  ///
  /// Diurutkan dari terbaru. Bisa difilter berdasarkan kategori.
  static Future<List<Map<String, dynamic>>> getDocuments({
    required String employeeId,
    String? kategori,
  }) async {
    try {
      await SupabaseService.ensureAuthenticated();

      var query = SupabaseService.client
          .from('legal_documents')
          .select()
          .eq('employee_id', employeeId)
          .eq('status_approval', 'Disetujui');

      if (kategori != null) {
        query = query.eq('kategori', kategori);
      }

      final response = await query.order('tanggal_terbit', ascending: false);
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('[DocumentService] getDocuments error: $e');
      return [];
    }
  }

  /// Hitung ringkasan dokumen untuk pegawai.
  ///
  /// Mengembalikan map:
  /// - `totalPKWT`: jumlah kontrak PKWT
  /// - `totalSP`: jumlah surat peringatan
  /// - `aktif`: jumlah dokumen aktif
  /// - `segeraBerakhir`: jumlah dokumen segera berakhir
  static Future<Map<String, int>> getDocumentSummary({
    required String employeeId,
  }) async {
    try {
      await SupabaseService.ensureAuthenticated();

      final response = await SupabaseService.client
          .from('legal_documents')
          .select('kategori, status')
          .eq('employee_id', employeeId)
          .eq('status_approval', 'Disetujui');

      final data = List<Map<String, dynamic>>.from(response as List);

      int totalPKWT = 0;
      int totalSP = 0;
      int aktif = 0;
      int segeraBerakhir = 0;

      for (final doc in data) {
        final kategori = doc['kategori'] as String;
        final status = doc['status'] as String;

        if (kategori == 'PKWT') totalPKWT++;
        if (kategori == 'SP') totalSP++;
        if (status == 'Aktif') aktif++;
        if (status == 'Segera Berakhir') segeraBerakhir++;
      }

      return {
        'totalPKWT': totalPKWT,
        'totalSP': totalSP,
        'aktif': aktif,
        'segeraBerakhir': segeraBerakhir,
      };
    } catch (e) {
      debugPrint('[DocumentService] getDocumentSummary error: $e');
      return {
        'totalPKWT': 0,
        'totalSP': 0,
        'aktif': 0,
        'segeraBerakhir': 0,
      };
    }
  }
}
