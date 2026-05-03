import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/pegawai_model.dart';
import 'supabase_service.dart';

/// Jenis dokumen foto yang bisa diupload.
enum DocType {
  fotoDiri('foto', 'foto_diri'),
  fotoKtp('ktp', 'foto_ktp'),
  fotoSim('sim', 'foto_sim'),
  kartuKeluarga('kk', 'kartu_keluarga');

  final String fileName;
  final String dbColumn;
  const DocType(this.fileName, this.dbColumn);
}

/// Service untuk operasi data pegawai (update profil, upload foto).
abstract final class PegawaiService {
  static SupabaseClient get _client => SupabaseService.client;

  /// Target maksimal ukuran file foto: 300 KB.
  static const _maxSizeBytes = 300 * 1024;

  /// Update profil pegawai.
  ///
  /// Hanya field yang ada di [updates] yang dikirim ke server.
  /// Field null TIDAK dikirim → tidak menimpa data lama.
  static Future<Pegawai> updateProfile({
    required String employeeId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      // Pastikan auth aktif untuk melewati RLS
      await SupabaseService.ensureAuthenticated();

      if (updates.isEmpty) {
        // Tidak ada perubahan, fetch data terbaru saja
        final response = await _client
            .from('pegawai')
            .select('*, jabatan:jabatan_id(id, nama)')
            .eq('id', employeeId)
            .single();
        return Pegawai.fromMap(response);
      }

      updates['updated_at'] = DateTime.now().toIso8601String();

      await _client.from('pegawai').update(updates).eq('id', employeeId);

      final response = await _client
          .from('pegawai')
          .select('*, jabatan:jabatan_id(id, nama)')
          .eq('id', employeeId)
          .single();

      return Pegawai.fromMap(response);
    } on SocketException {
      throw const PegawaiException(
        'Tidak ada koneksi internet. Periksa jaringan Anda.',
      );
    } catch (e) {
      debugPrint('[PegawaiService] Update error: $e');
      throw const PegawaiException(
        'Gagal menyimpan perubahan. Silakan coba lagi.',
      );
    }
  }

  /// Upload foto dokumen ke Supabase Storage.
  ///
  /// Foto otomatis dikompres ke maksimal 300 KB.
  static Future<String> uploadPhoto({
    required String employeeId,
    required File imageFile,
    required DocType docType,
  }) async {
    try {
      // Pastikan auth aktif untuk melewati RLS
      await SupabaseService.ensureAuthenticated();

      final compressed = await _compressTo300KB(imageFile);

      await _deleteOldFiles(employeeId, docType.fileName);

      final storagePath = '$employeeId/${docType.fileName}.jpg';

      await _client.storage.from('pegawai-docs').uploadBinary(
            storagePath,
            compressed,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );

      final url =
          _client.storage.from('pegawai-docs').getPublicUrl(storagePath);
      final urlWithTimestamp =
          '$url?t=${DateTime.now().millisecondsSinceEpoch}';

      await _client.from('pegawai').update({
        docType.dbColumn: urlWithTimestamp,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', employeeId);

      final sizeKB = (compressed.length / 1024).toStringAsFixed(1);
      debugPrint(
          '[PegawaiService] Uploaded ${docType.fileName}: ${sizeKB}KB');

      return urlWithTimestamp;
    } on SocketException {
      throw PegawaiException(
        'Gagal mengunggah ${docType.fileName}. Periksa koneksi internet.',
      );
    } catch (e) {
      debugPrint('[PegawaiService] Upload ${docType.fileName} error: $e');
      throw PegawaiException(
        'Gagal mengunggah ${docType.fileName}. Silakan coba lagi.',
      );
    }
  }

  /// Hapus file lama di Storage.
  static Future<void> _deleteOldFiles(
    String employeeId,
    String fileName,
  ) async {
    final extensions = ['jpg', 'jpeg', 'png'];
    final paths = extensions.map((e) => '$employeeId/$fileName.$e').toList();
    try {
      await _client.storage.from('pegawai-docs').remove(paths);
    } catch (_) {}
  }

  /// Kompres gambar ke maksimal 300KB.
  static Future<Uint8List> _compressTo300KB(File file) async {
    final originalBytes = await file.readAsBytes();

    if (originalBytes.length <= _maxSizeBytes) {
      return await FlutterImageCompress.compressWithList(
        originalBytes,
        minWidth: 1200,
        minHeight: 1200,
        quality: 90,
        format: CompressFormat.jpeg,
      );
    }

    int quality = 85;
    Uint8List compressed = originalBytes;

    while (quality >= 20) {
      compressed = await FlutterImageCompress.compressWithList(
        originalBytes,
        minWidth: 1200,
        minHeight: 1200,
        quality: quality,
        format: CompressFormat.jpeg,
      );
      if (compressed.length <= _maxSizeBytes) break;
      quality -= 10;
    }

    if (compressed.length > _maxSizeBytes) {
      compressed = await FlutterImageCompress.compressWithList(
        originalBytes,
        minWidth: 800,
        minHeight: 800,
        quality: 60,
        format: CompressFormat.jpeg,
      );
    }

    return compressed;
  }

  /// Shortcut upload foto diri.
  static Future<String> uploadFotoDiri({
    required String employeeId,
    required File imageFile,
  }) {
    return uploadPhoto(
      employeeId: employeeId,
      imageFile: imageFile,
      docType: DocType.fotoDiri,
    );
  }
}

/// Exception khusus untuk error pegawai service.
class PegawaiException implements Exception {
  final String message;
  const PegawaiException(this.message);

  @override
  String toString() => message;
}
