// Model detail e-POD mobile: satu FO beserta daftar titiknya.
//
// Dipakai oleh layar detail FO dan form input loading/pengantaran. Bentuk
// data mengikuti kontrak RPC `tms_epod_mobile_detail`.

/// Satu barang pada bukti pengantaran.
class EpodItem {
  final String name;
  final double quantity;
  final String? unit;

  const EpodItem({
    required this.name,
    required this.quantity,
    required this.unit,
  });

  factory EpodItem.fromMap(Map<String, dynamic> map) {
    return EpodItem(
      name: _str(map['name']) ?? '-',
      quantity: _num(map['quantity']) ?? 0,
      unit: _str(map['unit']),
    );
  }

  /// Ringkasan singkat untuk ditampilkan, mis. `2 dus`.
  String get summary {
    final qty = quantity == quantity.roundToDouble()
        ? quantity.toStringAsFixed(0)
        : quantity.toString();
    return unit == null ? qty : '$qty $unit';
  }
}

/// Bukti yang sudah tersimpan untuk satu titik (versi terbaru/aktif).
class EpodSubmission {
  final String id;
  final int version;
  final String? result;
  final String? recipientName;
  final String? note;
  final List<EpodItem> items;
  final double? distanceMeters;
  final bool? geofenceOk;
  final String? outOfRadiusReason;
  final DateTime? capturedAtServer;
  final String? actorType;
  final String? source;
  final int evidenceCount;

  const EpodSubmission({
    required this.id,
    required this.version,
    required this.result,
    required this.recipientName,
    required this.note,
    required this.items,
    required this.distanceMeters,
    required this.geofenceOk,
    required this.outOfRadiusReason,
    required this.capturedAtServer,
    required this.actorType,
    required this.source,
    required this.evidenceCount,
  });

  factory EpodSubmission.fromMap(Map<String, dynamic> map) {
    return EpodSubmission(
      id: (map['id'] ?? '').toString(),
      version: _int(map['version'], 1),
      result: _str(map['result']),
      recipientName: _str(map['recipient_name']),
      note: _str(map['note']),
      items: _list(map['items']).map(EpodItem.fromMap).toList(),
      distanceMeters: _num(map['distance_meters']),
      geofenceOk: map['geofence_ok'] == true
          ? true
          : (map['geofence_ok'] == false ? false : null),
      outOfRadiusReason: _str(map['out_of_radius_reason']),
      capturedAtServer: _date(map['captured_at_server']),
      actorType: _str(map['actor_type']),
      source: _str(map['source']),
      evidenceCount: _int(map['evidence_count']),
    );
  }

  String get resultLabel {
    switch (result) {
      case 'DELIVERED':
        return 'Terkirim';
      case 'PARTIAL':
        return 'Parsial';
      case 'REJECTED':
        return 'Ditolak';
      default:
        return 'Selesai';
    }
  }
}

/// Satu titik pada rute FO (loading atau pengantaran).
class EpodStop {
  final String id;
  final int sequence;
  final String stopType;
  final String? pointName;
  final String? address;
  final double? latitude;
  final double? longitude;
  final EpodSubmission? current;

  const EpodStop({
    required this.id,
    required this.sequence,
    required this.stopType,
    required this.pointName,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.current,
  });

  factory EpodStop.fromMap(Map<String, dynamic> map) {
    final current = map['current'];
    return EpodStop(
      id: (map['id'] ?? '').toString(),
      sequence: _int(map['stop_sequence']),
      stopType: (_str(map['stop_type']) ?? 'DELIVERY').toUpperCase(),
      pointName: _str(map['point_name']),
      address: _str(map['address']),
      latitude: _num(map['latitude']),
      longitude: _num(map['longitude']),
      current: current is Map
          ? EpodSubmission.fromMap(current.cast<String, dynamic>())
          : null,
    );
  }

  bool get isLoading => stopType == 'LOADING';
  bool get isDone => current != null;

  /// Nama tampil: nama titik, atau label default berdasarkan tipe.
  String get title {
    final name = pointName;
    if (name != null && name.isNotEmpty) return name;
    return isLoading ? 'Titik Loading' : 'Titik Pengantaran';
  }
}

/// Detail satu FO beserta daftar titiknya.
class EpodDetail {
  final String id;
  final String? taskNumber;
  final String? licensePlate;
  final String? vendorDriverName;
  final String status;
  final String loadingStatus;
  final int deliveryDoneCount;
  final int deliveryTotalCount;
  final String? myRole;
  final List<EpodStop> stops;

  const EpodDetail({
    required this.id,
    required this.taskNumber,
    required this.licensePlate,
    required this.vendorDriverName,
    required this.status,
    required this.loadingStatus,
    required this.deliveryDoneCount,
    required this.deliveryTotalCount,
    required this.myRole,
    required this.stops,
  });

  factory EpodDetail.fromMap(Map<String, dynamic> map) {
    final assignment = map['assignment'] is Map
        ? (map['assignment'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    return EpodDetail(
      id: (assignment['id'] ?? '').toString(),
      taskNumber: _str(assignment['task_number']),
      licensePlate: _str(assignment['license_plate']),
      vendorDriverName: _str(assignment['vendor_driver_name']),
      status: _str(assignment['status']) ?? 'OPEN',
      loadingStatus: _str(assignment['loading_status']) ?? 'PENDING_LOADING',
      deliveryDoneCount: _int(assignment['delivery_done_count']),
      deliveryTotalCount: _int(assignment['delivery_total_count']),
      myRole: _str(assignment['my_role']),
      stops: _list(map['stops']).map(EpodStop.fromMap).toList(),
    );
  }

  bool get loadingCompleted => loadingStatus == 'LOADING_COMPLETED';

  String get title => taskNumber ?? (id.length > 8 ? id.substring(0, 8) : id);

  String get roleLabel {
    switch (myRole) {
      case 'DRIVER':
        return 'Driver';
      case 'HELPER':
        return 'Helper';
      default:
        return '-';
    }
  }

  /// Titik loading pertama (biasanya sequence 1).
  EpodStop? get loadingStop {
    for (final stop in stops) {
      if (stop.isLoading) return stop;
    }
    return null;
  }

  /// Titik pengantaran yang belum terisi.
  int get pendingDeliveryCount =>
      stops.where((s) => !s.isLoading && !s.isDone).length;
}

/// Input barang dari form (kuantitas masih berupa angka hasil parse).
class EpodItemInput {
  final String name;
  final double quantity;
  final String? unit;

  const EpodItemInput({
    required this.name,
    required this.quantity,
    required this.unit,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'quantity': quantity,
        if (unit != null && unit!.isNotEmpty) 'unit': unit,
      };
}

// ── Parsing helpers ───────────────────────────────────────

String? _str(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

double? _num(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

int _int(dynamic value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

DateTime? _date(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

List<Map<String, dynamic>> _list(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => item.cast<String, dynamic>())
      .toList();
}
