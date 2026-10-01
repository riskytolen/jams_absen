import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

/// Recognizer khusus kanvas tanda tangan.
///
/// Masalah yang diatasi: kanvas tanda tangan e-POD tinggal di dalam
/// `ListView`, dan `GestureDetector.onPan*` biasa beradu dengan scroll di
/// gesture arena. Gerakan yang dominan vertikal kadang dimenangkan scroll
/// sehingga halaman bergulir alih-alih menggambar garis (gejala: kadang bisa,
/// kadang scroll).
///
/// Recognizer ini memakai pola yang sama dengan `EagerGestureRecognizer`:
/// langsung `resolve(accepted)` saat pointer down, sehingga scroll induk
/// gugur sebelum sempat berebut dan seluruh gerakan jari menjadi garis
/// sampai jari diangkat. Hanya satu pointer aktif yang dilacak agar
/// sentuhan jari kedua tidak mencampuri goresan yang sedang berjalan.
class SignatureGestureRecognizer extends OneSequenceGestureRecognizer {
  /// Posisi global saat jari menyentuh kanvas.
  ValueChanged<Offset>? onDrawStart;

  /// Posisi global setiap gerakan jari di atas kanvas.
  ValueChanged<Offset>? onDrawUpdate;

  /// Jari diangkat atau gerakan dibatalkan sistem (telepon masuk, dsb).
  VoidCallback? onDrawEnd;

  int? _activePointer;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    // Abaikan jari kedua dan seterusnya selama satu goresan berjalan.
    if (_activePointer != null) return;
    _activePointer = event.pointer;
    startTrackingPointer(event.pointer, event.transform);
    // Menang segera: scroll induk tidak ikut berebut gerakan ini.
    resolve(GestureDisposition.accepted);
    if (onDrawStart != null) {
      invokeCallback<void>(
        'onDrawStart',
        () => onDrawStart!(event.position),
      );
    }
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event.pointer != _activePointer) return;
    if (event is PointerMoveEvent) {
      if (onDrawUpdate != null) {
        invokeCallback<void>(
          'onDrawUpdate',
          () => onDrawUpdate!(event.position),
        );
      }
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      stopTrackingPointer(event.pointer);
      _activePointer = null;
      if (onDrawEnd != null) {
        invokeCallback<void>('onDrawEnd', onDrawEnd!);
      }
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  String get debugDescription => 'signaturePad';
}
