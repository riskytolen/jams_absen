import 'package:flutter/widgets.dart';

/// Satu goresan tanda tangan: rangkaian titik dari jari menyentuh sampai
/// diangkat. Goresan terpisah tidak pernah disambung garis.
@immutable
class SignatureStroke {
  final List<Offset> points;

  const SignatureStroke(this.points);
}

/// Status dan data goresan kanvas tanda tangan e-POD.
///
/// Controller adalah `Listenable` sehingga `SignaturePainter` menggambar
/// ulang dirinya sendiri tanpa `setState` seluruh form pada setiap gerakan
/// jari — inilah yang membuat input terasa responsif. Form hanya perlu
/// mendengarkan perubahan boolean `hasSignature` untuk teks validasi.
class SignaturePadController extends ChangeNotifier {
  /// Jarak minimum antar-sampel (logical px). Titik yang lebih rapat dari
  /// ini adalah jitter/duplikat event pointer dan dibuang agar path bersih.
  static const double minPointDistance = 1.5;

  final List<SignatureStroke> _strokes = [];
  List<Offset>? _current;

  /// Goresan yang sudah selesai (jari sudah diangkat).
  List<SignatureStroke> get strokes => List.unmodifiable(_strokes);

  /// Titik goresan yang sedang berjalan, kosong bila tidak ada.
  List<Offset> get currentPoints =>
      _current == null ? const [] : List.unmodifiable(_current!);

  /// True bila ada minimal satu titik (termasuk goresan berjalan).
  bool get hasSignature =>
      _strokes.isNotEmpty || (_current?.isNotEmpty ?? false);

  /// Mulai goresan baru. Bila goresan sebelumnya belum ditutup (mis. event
  /// terlewat), goresan itu difinalisasi dulu agar tidak tercampur.
  void startStroke(Offset point) {
    if (_current != null) endStroke();
    _current = [point];
    notifyListeners();
  }

  /// Tambah sampel ke goresan berjalan; jitter di bawah [minPointDistance]
  /// dibuang tanpa notifikasi.
  void appendPoint(Offset point) {
    final current = _current;
    if (current == null || current.isEmpty) return;
    final last = current.last;
    final dx = point.dx - last.dx;
    final dy = point.dy - last.dy;
    if (dx * dx + dy * dy <
        minPointDistance * minPointDistance) {
      return;
    }
    current.add(point);
    notifyListeners();
  }

  /// Tutup goresan berjalan. Ketukan tunggal (satu titik) tetap disimpan
  /// agar dirender sebagai dot, bukan hilang.
  void endStroke() {
    final current = _current;
    if (current == null) return;
    _current = null;
    if (current.isNotEmpty) {
      _strokes.add(SignatureStroke(List.of(current)));
    }
    notifyListeners();
  }

  /// Hapus seluruh goresan (tombol Hapus/Ulangi).
  void clear() {
    if (_strokes.isEmpty && _current == null) return;
    _strokes.clear();
    _current = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _strokes.clear();
    _current = null;
    super.dispose();
  }
}

/// Bangun path halus dari sampel titik memakai kurva quadratic Bézier
/// lewat titik tengah (midpoint technique).
///
/// Garis lurus antar-sampel (`drawLine`) terlihat patah karena event pointer
/// datang kasar terhadap gerakan jari; kurva ini menghaluskan sudut tanpa
/// mengubah bentuk tanda tangan. Daftar kosong menghasilkan path kosong,
/// satu titik dirender pemanggil sebagai dot.
Path buildSmoothStrokePath(List<Offset> points) {
  final path = Path();
  if (points.isEmpty) return path;
  if (points.length == 1) {
    path.moveTo(points.first.dx, points.first.dy);
    path.lineTo(points.first.dx, points.first.dy);
    return path;
  }
  if (points.length == 2) {
    path.moveTo(points[0].dx, points[0].dy);
    path.lineTo(points[1].dx, points[1].dy);
    return path;
  }
  path.moveTo(points[0].dx, points[0].dy);
  for (var i = 1; i < points.length - 1; i++) {
    final mid = Offset(
      (points[i].dx + points[i + 1].dx) / 2,
      (points[i].dy + points[i + 1].dy) / 2,
    );
    path.quadraticBezierTo(points[i].dx, points[i].dy, mid.dx, mid.dy);
  }
  path.lineTo(points.last.dx, points.last.dy);
  return path;
}

/// Pelukis kanvas tanda tangan: goresan halus anti-alias, ujung membulat.
///
/// Mendaftar ke [controller] sebagai `repaint` listenable sehingga hanya
/// kanvas yang digambar ulang saat jari bergerak — bukan seluruh form.
class SignaturePainter extends CustomPainter {
  final SignaturePadController controller;
  final Color color;
  final double strokeWidth;

  SignaturePainter({
    required this.controller,
    this.color = const Color(0xFF0F172A),
    this.strokeWidth = 2.8,
  }) : super(repaint: controller);

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    for (final stroke in controller.strokes) {
      _paintPoints(canvas, stroke.points, strokePaint, dotPaint);
    }
    _paintPoints(canvas, controller.currentPoints, strokePaint, dotPaint);
  }

  void _paintPoints(
    Canvas canvas,
    List<Offset> points,
    Paint strokePaint,
    Paint dotPaint,
  ) {
    if (points.isEmpty) return;
    if (points.length == 1) {
      canvas.drawCircle(points.first, strokeWidth / 2, dotPaint);
      return;
    }
    canvas.drawPath(buildSmoothStrokePath(points), strokePaint);
  }

  @override
  bool shouldRepaint(covariant SignaturePainter oldDelegate) =>
      oldDelegate.controller != controller ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth;
}
