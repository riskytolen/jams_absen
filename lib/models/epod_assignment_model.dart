/// Model satu FO (Fleet Order) pada modul e-POD mobile.
///
/// Dipakai untuk dua daftar pada layar e-POD: FO yang sudah diklaim pegawai
/// (`mine`) dan FO yang masih tersedia untuk diklaim (`available`).
class EpodAssignment {
  final String id;
  final String? taskNumber;
  final String? licensePlate;
  final String? vendorDriverName;
  final String status;
  final String loadingStatus;
  final int deliveryDoneCount;
  final int deliveryTotalCount;
  final DateTime? snapshotAt;
  final String? myRole;

  const EpodAssignment({
    required this.id,
    required this.taskNumber,
    required this.licensePlate,
    required this.vendorDriverName,
    required this.status,
    required this.loadingStatus,
    required this.deliveryDoneCount,
    required this.deliveryTotalCount,
    required this.snapshotAt,
    required this.myRole,
  });

  factory EpodAssignment.fromMap(Map<String, dynamic> map) {
    return EpodAssignment(
      id: (map['id'] ?? '').toString(),
      taskNumber: _str(map['task_number']),
      licensePlate: _str(map['license_plate']),
      vendorDriverName: _str(map['vendor_driver_name']),
      status: _str(map['status']) ?? 'OPEN',
      loadingStatus: _str(map['loading_status']) ?? 'PENDING_LOADING',
      deliveryDoneCount: _int(map['delivery_done_count']),
      deliveryTotalCount: _int(map['delivery_total_count']),
      snapshotAt: _date(map['snapshot_at']),
      myRole: _str(map['my_role']),
    );
  }

  static String? _str(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static int _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _date(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  /// Label status FO untuk ditampilkan.
  String get statusLabel {
    switch (status) {
      case 'CLAIMED':
        return 'Sudah diklaim';
      case 'IN_PROGRESS':
        return 'Berjalan';
      case 'COMPLETED':
        return 'Selesai';
      case 'CANCELLED':
        return 'Dibatalkan';
      default:
        return 'Belum diklaim';
    }
  }

  /// Label peran pegawai pada FO ini.
  String get roleLabel {
    switch (myRole) {
      case 'DRIVER':
        return 'Driver';
      case 'HELPER':
        return 'Helper';
      case 'COORDINATOR':
        return 'Koordinator';
      case 'DEPUTY_COORDINATOR':
        return 'Wakil Koordinator';
      case 'OTHER':
        return 'Petugas';
      default:
        return '-';
    }
  }

  bool get loadingCompleted => loadingStatus == 'LOADING_COMPLETED';

  /// Judul utama kartu: nomor FO bila ada, jika tidak potongan ID.
  String get title => taskNumber ?? (id.length > 8 ? id.substring(0, 8) : id);

  /// Ringkasan progres pengantaran.
  String get deliveryProgress => '$deliveryDoneCount/$deliveryTotalCount titik';
}
