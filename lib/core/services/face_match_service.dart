import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Size;
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart' as compress;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'supabase_service.dart';

/// Face matching via HeadlessInAppWebView (face-api.js) + Edge Function.
///
/// Menggunakan HeadlessInAppWebView yang bisa menjalankan JavaScript
/// tanpa perlu di-mount ke widget tree. Lebih reliable dari webview_flutter.
abstract final class FaceMatchService {
  static HeadlessInAppWebView? _headless;
  static InAppWebViewController? _webCtrl;
  static bool _modelsLoaded = false;
  static Completer<bool>? _initCompleter;
  static Completer<Map<String, dynamic>>? _resultCompleter;

  /// Initialize headless WebView dan load face-api.js models.
  /// Panggil sekali saat app start atau sebelum absen.
  static Future<bool> initialize() async {
    if (_modelsLoaded) return true;
    if (_initCompleter != null) return _initCompleter!.future;

    _initCompleter = Completer<bool>();

    _headless = HeadlessInAppWebView(
      initialSize: const Size(640, 480),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        domStorageEnabled: true,
        allowFileAccessFromFileURLs: true,
        allowUniversalAccessFromFileURLs: true,
      ),
      onWebViewCreated: (ctrl) {
        _webCtrl = ctrl;

        // Handler untuk menerima result dari JS
        ctrl.addJavaScriptHandler(
          handlerName: 'onResult',
          callback: (args) {
            if (args.isNotEmpty) {
              try {
                final data = args[0] is Map
                    ? Map<String, dynamic>.from(args[0])
                    : jsonDecode(args[0].toString()) as Map<String, dynamic>;
                _handleResult(data);
              } catch (e) {
                debugPrint('[FaceMatch] Parse result error: $e');
              }
            }
          },
        );
      },
      onLoadStop: (ctrl, url) async {
        debugPrint('[FaceMatch] Page loaded, initializing face-api...');
        // Inject face-api.js dan init
        await ctrl.evaluateJavascript(source: _initScript);
      },
    );

    await _headless!.run();

    // Load blank page, lalu inject script
    await _webCtrl?.loadData(
      data: _htmlPage,
      mimeType: 'text/html',
      encoding: 'utf-8',
    );

    // Tunggu models loaded (max 60 detik)
    return _initCompleter!.future.timeout(
      const Duration(seconds: 60),
      onTimeout: () {
        debugPrint('[FaceMatch] Init timeout');
        return false;
      },
    );
  }

  static void _handleResult(Map<String, dynamic> data) {
    final event = data['event'] as String?;
    debugPrint('[FaceMatch] Event: $event');

    if (event == 'models_loaded') {
      _modelsLoaded = true;
      if (_initCompleter != null && !_initCompleter!.isCompleted) {
        _initCompleter!.complete(true);
      }
      debugPrint('[FaceMatch] Models loaded OK');
    } else if (event == 'models_error') {
      debugPrint('[FaceMatch] Models error: ${data['detail']}');
      if (_initCompleter != null && !_initCompleter!.isCompleted) {
        _initCompleter!.complete(false);
      }
    } else if (event == 'descriptor') {
      if (_resultCompleter != null && !_resultCompleter!.isCompleted) {
        _resultCompleter!.complete(data);
      }
    } else if (event == 'extract_error') {
      debugPrint('[FaceMatch] Extract error: ${data['error']} ${data['detail'] ?? ''}');
      if (_resultCompleter != null && !_resultCompleter!.isCompleted) {
        _resultCompleter!.complete(data);
      }
    }
  }

  /// Extract 128-dim descriptor dari image bytes.
  static Future<List<double>?> extractDescriptor(Uint8List imageBytes) async {
    if (!_modelsLoaded || _webCtrl == null) {
      debugPrint('[FaceMatch] Not ready');
      return null;
    }

    try {
      // Compress image
      final compressed = await compress.FlutterImageCompress.compressWithList(
        imageBytes,
        minWidth: 480,
        minHeight: 480,
        quality: 75,
        format: compress.CompressFormat.jpeg,
      );
      debugPrint('[FaceMatch] Image: ${imageBytes.length} -> ${compressed.length} bytes');

      final b64 = base64Encode(compressed);

      _resultCompleter = Completer<Map<String, dynamic>>();

      // Kirim ke WebView via evaluateJavascript
      await _webCtrl!.evaluateJavascript(source: '''
        (async function() {
          try {
            var img = new Image();
            await new Promise(function(ok, fail) {
              img.onload = ok;
              img.onerror = fail;
              img.src = 'data:image/jpeg;base64,$b64';
            });
            
            var c = document.getElementById('faceCanvas');
            if (!c) {
              c = document.createElement('canvas');
              c.id = 'faceCanvas';
              document.body.appendChild(c);
            }
            c.width = img.naturalWidth;
            c.height = img.naturalHeight;
            c.getContext('2d').drawImage(img, 0, 0);
            
            var det = await faceapi
              .detectSingleFace(c, new faceapi.SsdMobilenetv1Options({minConfidence: 0.3}))
              .withFaceLandmarks()
              .withFaceDescriptor();
            
            if (!det) {
              window.flutter_inappwebview.callHandler('onResult', {event:'extract_error', error:'no_face'});
            } else {
              window.flutter_inappwebview.callHandler('onResult', {event:'descriptor', descriptor: Array.from(det.descriptor)});
            }
          } catch(e) {
            window.flutter_inappwebview.callHandler('onResult', {event:'extract_error', error:'exception', detail: ''+e});
          }
        })();
      ''');

      // Tunggu result
      final result = await _resultCompleter!.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () => {'event': 'extract_error', 'error': 'timeout'},
      );

      if (result['event'] == 'descriptor' && result['descriptor'] != null) {
        final list = (result['descriptor'] as List)
            .map((e) => (e as num).toDouble())
            .toList();
        if (list.length == 128) {
          debugPrint('[FaceMatch] Descriptor OK');
          return list;
        }
      }

      debugPrint('[FaceMatch] No descriptor: ${result['error']}');
      return null;
    } catch (e) {
      debugPrint('[FaceMatch] Extract exception: $e');
      return null;
    }
  }

  /// Compare descriptor dengan database via Edge Function.
  static Future<bool> compareWithServer({
    required List<double> descriptor,
    required String employeeId,
  }) async {
    await SupabaseService.ensureAuthenticated();

    final response = await SupabaseService.client.functions.invoke(
      'face-match',
      body: {
        'employee_id': employeeId,
        'descriptor': descriptor,
      },
    );

    debugPrint('[FaceMatch] Server: ${response.status}');

    if (response.status == 200) {
      final data = response.data as Map<String, dynamic>;
      final match = data['match'] as bool? ?? false;
      final distance = data['distance'];
      final error = data['error'] as String?;

      debugPrint('[FaceMatch] match=$match distance=$distance');

      if (error == 'no_profile') {
        throw Exception('Wajah belum terdaftar. Hubungi HRD.');
      }

      return match;
    }

    throw Exception('Server error (${response.status}). Coba lagi.');
  }

  /// Dispose headless WebView.
  static Future<void> dispose() async {
    await _headless?.dispose();
    _headless = null;
    _webCtrl = null;
    _modelsLoaded = false;
    _initCompleter = null;
  }

  // ── HTML & JS ──────────────────────────────────────────

  static const _htmlPage = '''
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"></head>
<body>
<canvas id="faceCanvas" style="display:none"></canvas>
<script src="https://cdn.jsdelivr.net/npm/@vladmandic/face-api@1.7.14/dist/face-api.min.js"></script>
</body>
</html>
''';

  static const _initScript = '''
    (async function() {
      try {
        var modelUrl = 'https://cdn.jsdelivr.net/npm/@vladmandic/face-api@1.7.14/model';
        await Promise.all([
          faceapi.nets.ssdMobilenetv1.loadFromUri(modelUrl),
          faceapi.nets.faceLandmark68Net.loadFromUri(modelUrl),
          faceapi.nets.faceRecognitionNet.loadFromUri(modelUrl)
        ]);
        window.flutter_inappwebview.callHandler('onResult', {event:'models_loaded'});
      } catch(e) {
        window.flutter_inappwebview.callHandler('onResult', {event:'models_error', detail:''+e});
      }
    })();
  ''';
}
