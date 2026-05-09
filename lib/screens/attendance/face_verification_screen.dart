import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/services/face_match_service.dart';
import '../../core/services/sound_service.dart';

/// Hasil verifikasi wajah.
class FaceVerificationResult {
  final bool success;
  final String? errorMessage;

  const FaceVerificationResult({required this.success, this.errorMessage});
}

/// Screen verifikasi wajah.
///
/// Flow:
/// 1. Liveness: kedipkan mata 2x
/// 2. Capture foto
/// 3. Extract descriptor via HeadlessInAppWebView (face-api.js)
/// 4. Compare via Edge Function
class FaceVerificationScreen extends StatefulWidget {
  final String employeeId;

  const FaceVerificationScreen({super.key, required this.employeeId});

  @override
  State<FaceVerificationScreen> createState() => _FaceVerificationScreenState();
}

class _FaceVerificationScreenState extends State<FaceVerificationScreen> {
  CameraController? _camera;
  FaceDetector? _detector;
  bool _processing = false;
  bool _cameraReady = false;

  // Liveness
  _Phase _phase = _Phase.init;
  int _blinks = 0;
  bool _eyesClosed = false;
  DateTime? _faceFoundAt;

  // Device orientation untuk rotasi ML Kit
  // Screen dikunci ke portraitUp, jadi selalu 0°
  // Dibiarkan sebagai metode agar mudah diubah jika butuh landscape di masa depan

  // Status
  String _message = 'Menyiapkan kamera...';
  String _sub = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Kunci orientasi ke portrait agar kalkulasi rotasi ML Kit konsisten
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    _setup();
  }

  Future<void> _setup() async {
    // Init face-api.js models di background
    FaceMatchService.initialize();

    // Init ML Kit — minFaceSize 0.15 agar deteksi lebih sensitif
    _detector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        performanceMode: FaceDetectorMode.fast,
        minFaceSize: 0.15, // FIX: 0.25→0.15 untuk kamera selfie kecil
      ),
    );

    // Init camera
    try {
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      // FIX: Pilih format berdasarkan platform.
      // nv21 = Android, bgra8888 = iOS
      // Jika nv21 tidak didukung device, _convert() akan fallback otomatis.
      _camera = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: defaultTargetPlatform == TargetPlatform.iOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.nv21,
      );
      await _camera!.initialize();
      if (!mounted) return;
      setState(() {
        _cameraReady = true;
        _phase = _Phase.detectFace;
        _message = 'Arahkan wajah ke kamera';
        _sub = 'Dekatkan wajah agar terlihat jelas';
      });
      _camera!.startImageStream(_onFrame);
    } catch (e) {
      // Jika gagal dengan nv21, coba lagi tanpa format khusus
      await _setupFallbackCamera();
    }
  }

  /// Fallback: inisialisasi kamera tanpa imageFormatGroup spesifik.
  /// Dipanggil jika setup pertama gagal (device tidak support nv21).
  Future<void> _setupFallbackCamera() async {
    try {
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _camera = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
        // Tanpa imageFormatGroup — Flutter pilih otomatis
      );
      await _camera!.initialize();
      if (!mounted) return;
      setState(() {
        _cameraReady = true;
        _phase = _Phase.detectFace;
        _message = 'Arahkan wajah ke kamera';
        _sub = 'Dekatkan wajah agar terlihat jelas';
      });
      _camera!.startImageStream(_onFrame);
    } catch (e) {
      _pop('Gagal membuka kamera: $e');
    }
  }

  @override
  void dispose() {
    // Kembalikan orientasi ke semua arah
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _camera?.dispose();
    _detector?.close();
    super.dispose();
  }

  void _pop(String? error) {
    if (!mounted) return;
    Navigator.of(context).pop(FaceVerificationResult(
      success: error == null,
      errorMessage: error,
    ));
  }

  void _onFrame(CameraImage img) {
    if (_processing || _detector == null || _phase == _Phase.done) return;
    _processing = true;
    _processFrame(img).then((_) => _processing = false);
  }

  Future<void> _processFrame(CameraImage img) async {
    try {
      final input = _convert(img);
      if (input == null) return;
      final faces = await _detector!.processImage(input);
      if (!mounted) return;

      if (faces.isEmpty) {
        if (_phase != _Phase.init) {
          setState(() {
            _phase = _Phase.detectFace;
            _message = 'Arahkan wajah ke kamera';
            _sub = 'Pastikan pencahayaan cukup';
            _faceFoundAt = null;
          });
        }
        return;
      }

      final face = faces.first;

      // ── Validasi ukuran wajah ──────────────────────────────────────────
      // Hitung seberapa besar wajah di frame (% area)
      // Tidak bergantung pada posisi oval, berlaku konsisten semua device
      final frameArea = img.width * img.height;
      final faceRect = face.boundingBox;
      final faceArea = faceRect.width * faceRect.height;
      final faceCoverage = faceArea / frameArea; // 0.0 – 1.0

      // Wajah harus menutupi minimal 8% area frame
      // (~25cm dari kamera, cukup untuk verifikasi akurat)
      const minCoverage = 0.08;
      if (faceCoverage < minCoverage) {
        setState(() {
          _message = 'Dekatkan wajah ke kamera';
          _sub = 'Wajah terlalu jauh atau kecil';
          _faceFoundAt = null;
        });
        return;
      }
      // ──────────────────────────────────────────────────────────────────

      final lo = face.leftEyeOpenProbability ?? 1;
      final ro = face.rightEyeOpenProbability ?? 1;
      final open = lo > 0.5 && ro > 0.5;
      final closed = lo < 0.3 && ro < 0.3;

      setState(() {
        switch (_phase) {
          case _Phase.detectFace:
            _faceFoundAt ??= DateTime.now();
            if (DateTime.now().difference(_faceFoundAt!).inMilliseconds > 600) {
              _phase = _Phase.blink;
              _message = 'Kedipkan mata Anda';
              _sub = 'Verifikasi bahwa Anda orang sungguhan';
            } else {
              _message = 'Wajah terdeteksi...';
              _sub = 'Tetap diam sebentar';
            }
            break;

          case _Phase.blink:
            if (closed && !_eyesClosed) _eyesClosed = true;
            if (open && _eyesClosed) {
              _eyesClosed = false;
              _blinks++;
              if (_blinks >= 2) {
                _phase = _Phase.done;
                _message = 'Mencocokkan wajah...';
                _sub = 'Mohon tunggu';
                _doVerify();
              } else {
                _message = 'Bagus! Kedipkan sekali lagi';
              }
            }
            break;

          default:
            break;
        }
      });
    } catch (_) {}
  }

  Future<void> _doVerify() async {
    if (_busy) return;
    _busy = true;

    try {
      // Stop stream & capture
      await _camera!.stopImageStream();
      final file = await _camera!.takePicture();
      final bytes = await file.readAsBytes();

      setState(() {
        _message = 'Menganalisis wajah...';
        _sub = 'Mencocokkan dengan data terdaftar';
      });

      // Tunggu face-api.js ready
      final ready = await FaceMatchService.initialize();
      if (!ready) {
        _fail('Sistem verifikasi gagal dimuat. Periksa koneksi internet.');
        return;
      }

      // Extract descriptor
      final descriptor = await FaceMatchService.extractDescriptor(bytes);
      if (descriptor == null) {
        _fail('Wajah tidak terdeteksi. Pastikan wajah terlihat jelas dan coba lagi.');
        return;
      }

      setState(() {
        _message = 'Memverifikasi...';
        _sub = '';
      });

      // Compare with server
      final match = await FaceMatchService.compareWithServer(
        descriptor: descriptor,
        employeeId: widget.employeeId,
      );

      if (!mounted) return;

      if (match) {
        HapticFeedback.mediumImpact();
        SoundService.playLoginSuccess();
        _pop(null); // success
      } else {
        _fail('Wajah tidak cocok dengan data terdaftar. Silakan coba lagi.');
      }
    } on Exception catch (e) {
      _fail(e.toString().replaceAll('Exception: ', ''));
    } catch (e) {
      _fail('Terjadi kesalahan. Coba lagi.');
    }
  }

  void _fail(String msg) {
    if (!mounted) return;
    
    // Haptic feedback untuk error
    HapticFeedback.heavyImpact();
    
    // Play error sound
    SoundService.playLoginError();
    
    // Show error dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.error_rounded,
                color: AppColors.error,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Verifikasi Gagal',
                style: AppTextStyles.h4.copyWith(
                  color: AppColors.error,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              msg,
              style: AppTextStyles.body.copyWith(
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    color: AppColors.warning,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pastikan pencahayaan cukup dan wajah terlihat jelas',
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.warning,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _pop('Dibatalkan');
            },
            child: Text(
              'Batal',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _resetAndRetry();
            },
            child: Text(
              'Coba Lagi',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
  
  void _resetAndRetry() {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _phase = _Phase.detectFace;
      _blinks = 0;
      _eyesClosed = false;
      _faceFoundAt = null;
      _message = 'Posisikan wajah di dalam frame';
      _sub = 'Pastikan pencahayaan cukup';
    });
    try {
      _camera?.startImageStream(_onFrame);
    } catch (_) {}
  }

  /// Konversi CameraImage ke InputImage untuk ML Kit.
  ///
  /// FIX v2: Beberapa device Realme/MediaTek mengirim frame dalam format
  /// yuv_420_888 (raw=35) yang tidak dikenali ML Kit via fromRawValue().
  /// Solusi: fallback ke nv21 + Y-plane saja (luminance) —
  /// cukup untuk face detection karena ML Kit menggunakan channel luminance.
  InputImage? _convert(CameraImage img) {
    try {
      // Coba deteksi format yang dikenal ML Kit (nv21=17, bgra8888=875704422)
      // yuv_420_888 (raw=35) akan return null → fallback ke nv21
      final fmt = InputImageFormatValue.fromRawValue(img.format.raw)
          ?? InputImageFormat.nv21; // fallback untuk yuv420

      // Rotasi: sensorOrientation langsung — screen sudah dikunci portrait
      final sensorDeg = _camera!.description.sensorOrientation;
      final rot = _degreesToRotation(sensorDeg);
      if (rot == null) return null;

      // Gunakan Y-plane (planes[0]) saja:
      // • NV21: planes[0] adalah NV21 data (Y + interleaved VU)
      // • YUV420: planes[0] adalah Y-plane (luminance) — cukup untuk ML Kit
      // JANGAN concatenate semua planes — merusak format NV21!
      final bytes = img.planes.first.bytes;

      return InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(img.width.toDouble(), img.height.toDouble()),
          rotation: rot,
          format: fmt,
          bytesPerRow: img.planes.first.bytesPerRow,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  InputImageRotation? _degreesToRotation(int degrees) {
    switch (degrees) {
      case 0:
        return InputImageRotation.rotation0deg;
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  Color get _borderColor {
    switch (_phase) {
      case _Phase.init:
      case _Phase.detectFace:
        return Colors.white.withValues(alpha: 0.4);
      case _Phase.blink:
        return AppColors.accentLight;
      case _Phase.done:
        return AppColors.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Camera
            if (_cameraReady && _camera != null) _CroppedCam(ctrl: _camera!),

            // Oval overlay
            CustomPaint(
              size: MediaQuery.of(context).size,
              painter: _OvalPainter(color: _borderColor),
            ),

            // Close button
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => _pop('Dibatalkan'),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 22),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom info
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 40, 24, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Blink dots
                        if (_phase == _Phase.blink)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(2, (i) {
                                final done = i < _blinks;
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: done ? 24 : 10,
                                  height: 10,
                                  margin: const EdgeInsets.symmetric(horizontal: 3),
                                  decoration: BoxDecoration(
                                    color: done
                                        ? AppColors.success
                                        : Colors.white.withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                );
                              }),
                            ),
                          ),

                        if (_phase == _Phase.done)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 10),
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                              ),
                            ),
                          ),

                        Text(
                          _message,
                          style: AppTextStyles.onDarkTitle.copyWith(fontSize: 15),
                          textAlign: TextAlign.center,
                        ),
                        if (_sub.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            _sub,
                            style: AppTextStyles.onDarkMuted.copyWith(fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════
enum _Phase { init, detectFace, blink, done }

// ═════════════════════════════════════════════════════════
class _CroppedCam extends StatelessWidget {
  final CameraController ctrl;
  const _CroppedCam({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.of(context).size;
    final sr = s.width / s.height;
    final cr = ctrl.value.aspectRatio;
    var scale = sr * cr;
    if (scale < 1) scale = 1 / scale;
    return ClipRect(
      child: Transform.scale(
        scale: scale,
        child: Center(child: CameraPreview(ctrl)),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════
class _OvalPainter extends CustomPainter {
  final Color color;
  _OvalPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // Oval besar dan adaptif — sebagai panduan visual saja
    // Validasi wajah dilakukan via face coverage (% area frame), bukan posisi oval
    final center = Offset(size.width / 2, size.height * 0.40);
    final w = size.width * 0.82; // 82% lebar layar — muat berbagai ukuran wajah
    final h = w * 1.28;          // Proporsional, tidak terlalu panjang
    final rect = Rect.fromCenter(center: center, width: w, height: h);

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(rect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, Paint()..color = Colors.black.withValues(alpha: 0.55));

    canvas.drawOval(
      rect,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Corner accents
    final a = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    const arc = 0.4;
    canvas.drawArc(rect, -math.pi / 2 - arc / 2, arc, false, a);
    canvas.drawArc(rect, math.pi / 2 - arc / 2, arc, false, a);
    canvas.drawArc(rect, math.pi - arc / 2, arc, false, a);
    canvas.drawArc(rect, -arc / 2, arc, false, a);
  }

  @override
  bool shouldRepaint(covariant _OvalPainter old) => old.color != color;
}
