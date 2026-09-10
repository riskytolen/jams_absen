import 'package:flutter_test/flutter_test.dart';
import 'package:jams_absen/core/utils/backup_libur_snapshot.dart';

void main() {
  group('BackupLiburSnapshot.fromPayroll', () {
    test('tanpa backup libur: semua nol dan tidak ada data', () {
      final snap = BackupLiburSnapshot.fromPayroll({});
      expect(snap.total, 0);
      expect(snap.driverDays, 0);
      expect(snap.helperDays, 0);
      expect(snap.hasData, isFalse);
      expect(snap.isConsistent, isTrue);
    });

    test('driver saja: 2 hari x 65000 = 130000', () {
      final snap = BackupLiburSnapshot.fromPayroll({
        'tambahan_backup_libur': 130000,
        'backup_libur_driver_days': 2,
        'backup_libur_helper_days': 0,
        'backup_libur_driver_rate': 65000,
        'backup_libur_helper_rate': 45000,
      });
      expect(snap.hasData, isTrue);
      expect(snap.driverSubtotal, 130000);
      expect(snap.helperSubtotal, 0);
      expect(snap.expectedTotal, 130000);
      expect(snap.isConsistent, isTrue);
    });

    test('helper saja: 3 hari x 45000 = 135000', () {
      final snap = BackupLiburSnapshot.fromPayroll({
        'tambahan_backup_libur': 135000,
        'backup_libur_driver_days': 0,
        'backup_libur_helper_days': 3,
        'backup_libur_driver_rate': 65000,
        'backup_libur_helper_rate': 45000,
      });
      expect(snap.driverSubtotal, 0);
      expect(snap.helperSubtotal, 135000);
      expect(snap.expectedTotal, 135000);
      expect(snap.isConsistent, isTrue);
    });

    test('kombinasi driver + helper sesuai formula resmi', () {
      final snap = BackupLiburSnapshot.fromPayroll({
        'tambahan_backup_libur': 110000,
        'backup_libur_driver_days': 1,
        'backup_libur_helper_days': 1,
        'backup_libur_driver_rate': 65000,
        'backup_libur_helper_rate': 45000,
      });
      expect(snap.driverSubtotal, 65000);
      expect(snap.helperSubtotal, 45000);
      expect(snap.expectedTotal, 110000);
      expect(snap.isConsistent, isTrue);
    });

    test('mendeteksi rincian yang tidak cocok dengan nominal tersimpan', () {
      final snap = BackupLiburSnapshot.fromPayroll({
        'tambahan_backup_libur': 99999,
        'backup_libur_driver_days': 1,
        'backup_libur_helper_days': 1,
        'backup_libur_driver_rate': 65000,
        'backup_libur_helper_rate': 45000,
      });
      expect(snap.hasData, isTrue);
      expect(snap.expectedTotal, 110000);
      expect(snap.isConsistent, isFalse);
    });

    test('nilai null diperlakukan sebagai nol', () {
      final snap = BackupLiburSnapshot.fromPayroll({
        'tambahan_backup_libur': null,
        'backup_libur_driver_days': null,
        'backup_libur_helper_days': null,
        'backup_libur_driver_rate': null,
        'backup_libur_helper_rate': null,
      });
      expect(snap.total, 0);
      expect(snap.hasData, isFalse);
      expect(snap.isConsistent, isTrue);
    });
  });

  group('parseSnapshotInt', () {
    test('int dipertahankan', () => expect(parseSnapshotInt(7), 7));
    test('num non-int dibulatkan ke bawah', () {
      expect(parseSnapshotInt(7.9), 7);
    });
    test('null dan tipe tak dikenal menjadi nol', () {
      expect(parseSnapshotInt(null), 0);
      expect(parseSnapshotInt('5'), 0);
    });
  });

  group('rekonsiliasi total pendapatan', () {
    test('kontrak mencakup tambahan_backup_libur', () {
      expect(pendapatanComponentKeys, contains('tambahan_backup_libur'));
      expect(pendapatanComponentKeys.length, 11);
    });

    test('penjumlahan 11 komponen sama dengan total_pendapatan', () {
      final payroll = {
        'gaji_pokok': 3000000,
        'pendapatan_titik': 500000,
        'tambahan_backup_libur': 110000,
        'lembur': 200000,
        'extra_job': 100000,
        'uang_makan': 150000,
        'insentif': 0,
        'tunjangan_jabatan': 250000,
        'transport': 100000,
        'tunjangan_lain': 0,
        'tambahan_lain': 50000,
        'total_pendapatan': 4460000,
      };
      expect(
        sumPendapatanComponents(payroll, pendapatanComponentKeys),
        payroll['total_pendapatan'],
      );
    });
  });
}
