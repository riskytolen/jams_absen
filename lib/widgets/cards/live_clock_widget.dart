import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/server_time_service.dart';

/// Widget jam digital live yang menampilkan waktu server.
///
/// Menggunakan [ServerTimeService.getEstimatedServerTime()] yang berbasis
/// offset dari waktu server, sehingga tidak bisa dimanipulasi via jam HP.
class LiveClockWidget extends StatefulWidget {
  const LiveClockWidget({super.key});

  @override
  State<LiveClockWidget> createState() => _LiveClockWidgetState();
}

class _LiveClockWidgetState extends State<LiveClockWidget> {
  late Timer _timer;
  late DateTime _currentTime;

  @override
  void initState() {
    super.initState();
    // Gunakan waktu server (offset-corrected) jika tersedia
    _currentTime = ServerTimeService.getEstimatedServerTime() ?? DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          // Selalu gunakan estimasi waktu server
          _currentTime =
              ServerTimeService.getEstimatedServerTime() ?? DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('HH:mm:ss').format(_currentTime);
    final dateStr = DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(_currentTime);

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
      ],
    );
  }
}
