import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/server_time_service.dart';

/// Widget jam digital live yang menampilkan waktu server WIB.
///
/// Menggunakan [ServerTimeService.getEstimatedServerTime] yang berbasis
/// monotonic clock + offset dari waktu server, sehingga tidak bisa
/// dimanipulasi via jam HP. Selalu menampilkan jam WIB tidak peduli
/// timezone HP user.
class LiveClockWidget extends StatefulWidget {
  const LiveClockWidget({super.key});

  @override
  State<LiveClockWidget> createState() => _LiveClockWidgetState();
}

class _LiveClockWidgetState extends State<LiveClockWidget> {
  late Timer _timer;
  DateTime? _currentTime;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _updateTime();
        });
      }
    });
  }

  void _updateTime() {
    // Hanya gunakan waktu server. Jika belum sync atau invalid → null
    // sehingga UI menampilkan placeholder, BUKAN DateTime.now() HP yang
    // bisa di-set ke 1900 atau timezone aneh.
    final serverTime = ServerTimeService.getEstimatedServerTime();
    if (serverTime != null && _isSane(serverTime)) {
      _currentTime = serverTime;
    } else {
      _currentTime = null;
      // Trigger background re-sync supaya UI cepat balik normal.
      // Tidak await — ini fire-and-forget.
      // ignore: discarded_futures
      ServerTimeService.resync();
    }
  }

  bool _isSane(DateTime t) {
    // Reject 1900 / 1970 / future >10 tahun.
    return t.year >= 2024 && t.year <= 2040;
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = _currentTime;
    final timeStr = t != null ? DateFormat('HH:mm:ss').format(t) : '--:--:--';
    final dateStr = t != null
        ? DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(t)
        : 'Menyinkronkan waktu...';

    return Column(
      children: [
        Text(
          timeStr,
          style: const TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 2,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          dateStr,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
        // Debug indicator (hanya tampil di debug mode saat fallback)
        if (kDebugMode && t == null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Sync...',
              style: TextStyle(
                fontSize: 10,
                color: Colors.orange.withValues(alpha: 0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}
