import 'package:flutter_test/flutter_test.dart';
import 'package:jams_absen/core/services/attendance_service.dart';

void main() {
  group('calculateAttendanceStatus', () {
    test('Hadir: check-in jauh sebelum jam masuk (kasus ID46991)', () {
      // Skenario insiden: jadwal 04:30 + tol 5 menit, absen 03:18.
      final result = AttendanceService.calculateAttendanceStatus(
        checkInTime: DateTime(2026, 5, 15, 3, 18, 0),
        scheduleJamMasuk: '04:30:00',
        toleransiMenit: 5,
      );
      expect(result['status'], 'Hadir');
      expect(result['durasi_telat'], 0);
    });

    test('Hadir: check-in tepat di jam masuk', () {
      final result = AttendanceService.calculateAttendanceStatus(
        checkInTime: DateTime(2026, 5, 15, 9, 0, 0),
        scheduleJamMasuk: '09:00:00',
        toleransiMenit: 5,
      );
      expect(result['status'], 'Hadir');
      expect(result['durasi_telat'], 0);
    });

    test('Hadir: check-in tepat di batas toleransi', () {
      final result = AttendanceService.calculateAttendanceStatus(
        checkInTime: DateTime(2026, 5, 15, 9, 5, 0),
        scheduleJamMasuk: '09:00:00',
        toleransiMenit: 5,
      );
      expect(result['status'], 'Hadir');
      expect(result['durasi_telat'], 0);
    });

    test('Terlambat: 1 detik melewati batas toleransi', () {
      final result = AttendanceService.calculateAttendanceStatus(
        checkInTime: DateTime(2026, 5, 15, 9, 5, 1),
        scheduleJamMasuk: '09:00:00',
        toleransiMenit: 5,
      );
      expect(result['status'], 'Terlambat');
      // 5 menit 1 detik dari schedule → inMinutes = 5
      expect(result['durasi_telat'], 5);
    });

    test('Terlambat: 30 menit', () {
      final result = AttendanceService.calculateAttendanceStatus(
        checkInTime: DateTime(2026, 5, 15, 9, 30, 0),
        scheduleJamMasuk: '09:00:00',
        toleransiMenit: 5,
      );
      expect(result['status'], 'Terlambat');
      expect(result['durasi_telat'], 30);
    });

    test('Hadir: check-in jam 20:00 dengan jadwal 20:30 (shift malam)', () {
      // Cp Suka divisi yang masuk 04:30, atau shift malam div 3 (20:30).
      final result = AttendanceService.calculateAttendanceStatus(
        checkInTime: DateTime(2026, 5, 15, 20, 0, 0),
        scheduleJamMasuk: '20:30:00',
        toleransiMenit: 5,
      );
      expect(result['status'], 'Hadir');
      expect(result['durasi_telat'], 0);
    });

    test('Toleransi 0 menit: 1 menit telat = Terlambat', () {
      final result = AttendanceService.calculateAttendanceStatus(
        checkInTime: DateTime(2026, 5, 15, 9, 1, 0),
        scheduleJamMasuk: '09:00:00',
        toleransiMenit: 0,
      );
      expect(result['status'], 'Terlambat');
      expect(result['durasi_telat'], 1);
    });

    test('Format jam_masuk dengan 2 segmen (HH:mm) tanpa detik', () {
      final result = AttendanceService.calculateAttendanceStatus(
        checkInTime: DateTime(2026, 5, 15, 4, 28, 0),
        scheduleJamMasuk: '04:30',
        toleransiMenit: 5,
      );
      expect(result['status'], 'Hadir');
      expect(result['durasi_telat'], 0);
    });

    test('Regression: checkInTime dari UTC isUtc=true tidak boleh menyebabkan offset 7 jam', () {
      // Bug nyata 2026-05-15 ID57200: jam_masuk 10:36, schedule 10:00, tol 5
      // tercatat telat 456 menit (= 36 + 7*60 = ada offset 7 jam tersembunyi).
      // Penyebab: checkInTime dari ServerTimeService punya isUtc=true sehingga
      // .difference(scheduleTime-yang-naive) menambah 7 jam.
      // Setelah fix: checkInTime selalu naive (jam dinding WIB).
      final naiveWib = DateTime(2026, 5, 15, 10, 36, 33);
      expect(naiveWib.isUtc, false);

      final result = AttendanceService.calculateAttendanceStatus(
        checkInTime: naiveWib,
        scheduleJamMasuk: '10:00:00',
        toleransiMenit: 5,
      );
      expect(result['status'], 'Terlambat');
      expect(result['durasi_telat'], 36, reason: 'Harus 36 menit, BUKAN 456');
    });
  });

  group('AttendanceWindowResult', () {
    test('Konstruksi data class', () {
      const r = AttendanceWindowResult(
        allowed: false,
        earliestTime: '08:20',
        jamMasuk: '09:00',
        awalAbsenMenit: 40,
      );
      expect(r.allowed, false);
      expect(r.earliestTime, '08:20');
      expect(r.jamMasuk, '09:00');
      expect(r.awalAbsenMenit, 40);
    });

    test('Allowed=true bisa earliestTime null (fitur OFF)', () {
      const r = AttendanceWindowResult(
        allowed: true,
        earliestTime: null,
        jamMasuk: '09:00',
        awalAbsenMenit: 0,
      );
      expect(r.allowed, true);
      expect(r.earliestTime, null);
      expect(r.awalAbsenMenit, 0);
    });
  });
}
