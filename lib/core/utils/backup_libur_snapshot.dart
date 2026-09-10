/// Logika murni snapshot Backup Libur dari baris payroll Final.
///
/// Formula resmi (sama dengan payroll web):
/// ```text
/// (driver_days × driver_rate) + (helper_days × helper_rate)
/// ```
///
/// Nilai dibaca apa adanya dari kolom snapshot payroll dan TIDAK dihitung
/// ulang dari `delivery_points` live, agar konsisten dengan slip Final.
class BackupLiburSnapshot {
  final int total;
  final int driverDays;
  final int helperDays;
  final int driverRate;
  final int helperRate;

  const BackupLiburSnapshot({
    required this.total,
    required this.driverDays,
    required this.helperDays,
    required this.driverRate,
    required this.helperRate,
  });

  /// Bangun dari map baris payroll Supabase.
  factory BackupLiburSnapshot.fromPayroll(Map<String, dynamic> payroll) {
    return BackupLiburSnapshot(
      total: parseSnapshotInt(payroll['tambahan_backup_libur']),
      driverDays: parseSnapshotInt(payroll['backup_libur_driver_days']),
      helperDays: parseSnapshotInt(payroll['backup_libur_helper_days']),
      driverRate: parseSnapshotInt(payroll['backup_libur_driver_rate']),
      helperRate: parseSnapshotInt(payroll['backup_libur_helper_rate']),
    );
  }

  int get driverSubtotal => driverDays * driverRate;
  int get helperSubtotal => helperDays * helperRate;

  /// Total hasil hari × rate; harus sama dengan [total] tersimpan.
  int get expectedTotal => driverSubtotal + helperSubtotal;

  /// True jika rincian hari × rate cocok dengan nominal tersimpan.
  bool get isConsistent => expectedTotal == total;

  /// True jika slip ini memiliki insentif backup libur.
  bool get hasData => total != 0 || driverDays != 0 || helperDays != 0;
}

/// Parse nilai snapshot Supabase yang bisa berupa int, num lain, atau null.
int parseSnapshotInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return 0;
}

/// Jumlahkan komponen pendapatan (termasuk Tambahan Backup Libur).
/// Dipakai untuk memastikan penjumlahan komponen sama dengan total_pendapatan.
int sumPendapatanComponents(
  Map<String, dynamic> payroll,
  List<String> keys,
) {
  var sum = 0;
  for (final key in keys) {
    sum += parseSnapshotInt(payroll[key]);
  }
  return sum;
}

/// Kunci komponen pendapatan sesuai kontrak payroll web (11 komponen).
const pendapatanComponentKeys = [
  'gaji_pokok',
  'pendapatan_titik',
  'tambahan_backup_libur',
  'lembur',
  'extra_job',
  'uang_makan',
  'insentif',
  'tunjangan_jabatan',
  'transport',
  'tunjangan_lain',
  'tambahan_lain',
];
