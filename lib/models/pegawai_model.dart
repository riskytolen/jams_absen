/// Model data pegawai lengkap dari tabel `pegawai` + relasi `jabatan`.
class Pegawai {
  // ── Identitas ──
  final String id;
  final String nama;
  final String status;
  final String? jenisKelamin;
  final String? agama;
  final String? noKtp;
  final String? tempatLahir;
  final DateTime? tanggalLahir;
  final String? noTelp;

  // ── Alamat ──
  final String? alamatKtp;
  final String? alamatDomisili;

  // ── Pekerjaan ──
  final int? jabatanId;
  final String? jabatanNama;
  final DateTime? tanggalBergabung;
  final DateTime? tanggalMulaiPkwt;
  final DateTime? tanggalBerakhirPkwt;

  // ── Keluarga ──
  final String? statusPernikahan;
  final String? namaPasangan;
  final int jumlahAnak;

  // ── Keuangan ──
  final String? bank;
  final String? noRekening;
  final String? namaRekening;
  final String? noBpjsKesehatan;
  final String? noBpjsKetenagakerjaan;

  // ── Foto / Dokumen ──
  final String? fotoDiri;
  final String? fotoKtp;
  final String? fotoSim;
  final String? kartuKeluarga;

  const Pegawai({
    required this.id,
    required this.nama,
    required this.status,
    this.jenisKelamin,
    this.agama,
    this.noKtp,
    this.tempatLahir,
    this.tanggalLahir,
    this.noTelp,
    this.alamatKtp,
    this.alamatDomisili,
    this.jabatanId,
    this.jabatanNama,
    this.tanggalBergabung,
    this.tanggalMulaiPkwt,
    this.tanggalBerakhirPkwt,
    this.statusPernikahan,
    this.namaPasangan,
    this.jumlahAnak = 0,
    this.bank,
    this.noRekening,
    this.namaRekening,
    this.noBpjsKesehatan,
    this.noBpjsKetenagakerjaan,
    this.fotoDiri,
    this.fotoKtp,
    this.fotoSim,
    this.kartuKeluarga,
  });

  /// Parse dari response Supabase (select * + join jabatan).
  factory Pegawai.fromMap(Map<String, dynamic> map) {
    final jabatan = map['jabatan'] as Map<String, dynamic>?;

    return Pegawai(
      id: map['id'] as String,
      nama: map['nama'] as String,
      status: map['status'] as String? ?? 'Aktif',
      jenisKelamin: map['jenis_kelamin'] as String?,
      agama: map['agama'] as String?,
      noKtp: map['no_ktp'] as String?,
      tempatLahir: map['tempat_lahir'] as String?,
      tanggalLahir: _parseDate(map['tanggal_lahir']),
      noTelp: map['no_telp'] as String?,
      alamatKtp: map['alamat_ktp'] as String?,
      alamatDomisili: map['alamat_domisili'] as String?,
      jabatanId: jabatan?['id'] as int?,
      jabatanNama: jabatan?['nama'] as String?,
      tanggalBergabung: _parseDate(map['tanggal_bergabung']),
      tanggalMulaiPkwt: _parseDate(map['tanggal_mulai_pkwt']),
      tanggalBerakhirPkwt: _parseDate(map['tanggal_berakhir_pkwt']),
      statusPernikahan: map['status_pernikahan'] as String?,
      namaPasangan: map['nama_pasangan'] as String?,
      jumlahAnak: map['jumlah_anak'] as int? ?? 0,
      bank: map['bank'] as String?,
      noRekening: _nonEmpty(map['no_rekening'] as String?),
      namaRekening: _nonEmpty(map['nama_rekening'] as String?),
      noBpjsKesehatan: map['no_bpjs_kesehatan'] as String?,
      noBpjsKetenagakerjaan: map['no_bpjs_ketenagakerjaan'] as String?,
      fotoDiri: map['foto_diri'] as String?,
      fotoKtp: map['foto_ktp'] as String?,
      fotoSim: map['foto_sim'] as String?,
      kartuKeluarga: map['kartu_keluarga'] as String?,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  static String? _nonEmpty(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }

  bool get isAktif => status == 'Aktif';

  String get inisial {
    final parts = nama.split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return nama.substring(0, nama.length >= 2 ? 2 : 1).toUpperCase();
  }

  /// Daftar foto dokumen yang tersedia.
  List<({String label, String url})> get dokumenFoto {
    final list = <({String label, String url})>[];
    if (fotoKtp != null) list.add((label: 'KTP', url: fotoKtp!));
    if (fotoSim != null) list.add((label: 'SIM', url: fotoSim!));
    if (kartuKeluarga != null) list.add((label: 'Kartu Keluarga', url: kartuKeluarga!));
    return list;
  }

  @override
  String toString() => 'Pegawai($id, $nama, $jabatanNama)';
}
