import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/pegawai_model.dart';
import 'supabase_service.dart';

/// Service untuk operasi data pegawai (update profil, upload foto).
///
/// Field yang TIDAK boleh diedit pegawai (hanya admin via web):
/// - ID Pegawai, Jabatan, Status kepegawaian
/// - Tanggal Bergabung, PKWT
/// - BPJS Kesehatan & Ketenagakerjaan
/// - Gaji Pokok
abstract final class PegawaiService {
  static SupabaseClient get _client => SupabaseService.client;

  /// Update profil pegawai.
  /// Return [Pegawai] terbaru setelah update.
  static Future<Pegawai> updateProfile({
    required String employeeId,
    // Identitas
    String? nama,
    String? jenisKelamin,
    String? agama,
    String? noKtp,
    String? tempatLahir,
    DateTime? tanggalLahir,
    String? noTelp,
    // Alamat
    String? alamatKtp,
    String? alamatDomisili,
    // Keluarga
    String? statusPernikahan,
    String? namaPasangan,
    int? jumlahAnak,
    // Keuangan
    String? bank,
    String? noRekening,
    String? namaRekening,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (nama != null) updates['nama'] = nama;
      if (jenisKelamin != null) updates['jenis_kelamin'] = jenisKelamin;
      if (agama != null) updates['agama'] = agama;
      if (noKtp != null) updates['no_ktp'] = noKtp;
      if (tempatLahir != null) updates['tempat_lahir'] = tempatLahir;
      if (tanggalLahir != null) {
        updates['tanggal_lahir'] = tanggalLahir.toIso8601String().split('T')[0];
      }
      if (noTelp != null) updates['no_telp'] = noTelp;
      if (alamatKtp != null) updates['alamat_ktp'] = alamatKtp;
      if (alamatDomisili != null) updates['alamat_domisili'] = alamatDomisili;
      if (statusPernikahan != null) {
        updates['status_pernikahan'] = statusPernikahan;
      }
      if (namaPasangan != null) updates['nama_pasangan'] = namaPasangan;
      if (jumlahAnak != null) updates['jumlah_anak'] = jumlahAnak;
      if (bank != null) updates['bank'] = bank;
      if (noRekening != null) updates['no_rekening'] = noRekening;
      if (namaRekening != null) updates['nama_rekening'] = namaRekening;

      await _client.from('pegawai').update(updates).eq('id', employeeId);

      // Fetch ulang data terbaru
      final response = await _client
          .from('pegawai')
          .select('*, jabatan:jabatan_id(id, nama)')
          .eq('id', employeeId)
          .single();

      return Pegawai.fromMap(response);
    } catch (e) {
      debugPrint('[PegawaiService] Update error: $e');
      throw Exception('Gagal menyimpan perubahan. Silakan coba lagi.');
    }
  }

  /// Upload foto diri ke Supabase Storage.
  static Future<String> uploadFotoDiri({
    required String employeeId,
    required File imageFile,
  }) async {
    try {
      final storagePath = '$employeeId/foto.png';
      final bytes = await imageFile.readAsBytes();

      await _client.storage.from('pegawai-docs').uploadBinary(
            storagePath,
            bytes,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/png',
            ),
          );

      final url =
          _client.storage.from('pegawai-docs').getPublicUrl(storagePath);

      final urlWithTimestamp =
          '$url?t=${DateTime.now().millisecondsSinceEpoch}';
      await _client.from('pegawai').update({
        'foto_diri': urlWithTimestamp,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', employeeId);

      return urlWithTimestamp;
    } catch (e) {
      debugPrint('[PegawaiService] Upload foto error: $e');
      throw Exception('Gagal mengunggah foto. Silakan coba lagi.');
    }
  }
}
