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
  });
}
