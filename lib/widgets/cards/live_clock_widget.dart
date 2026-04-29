import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_text_styles.dart';

/// Widget jam digital real-time dengan format Indonesia.
///
/// Menggunakan [RepaintBoundary] untuk mengisolasi rebuild
/// agar tidak mempengaruhi widget parent.
class LiveClockWidget extends StatefulWidget {
  const LiveClockWidget({super.key});

  @override
  State<LiveClockWidget> createState() => _LiveClockWidgetState();
}

class _LiveClockWidgetState extends State<LiveClockWidget> {
  late Timer _timer;
  DateTime _now = DateTime.now();

  static final _timeFormat = DateFormat('HH:mm:ss');
  static final _dateFormat = DateFormat('EEEE, dd MMMM yyyy', 'id_ID');

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (mounted) setState(() => _now = DateTime.now());
      },
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _timeFormat.format(_now),
            style: AppTextStyles.numericLg.copyWith(
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.20),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _dateFormat.format(_now),
            style: AppTextStyles.onDarkBody,
          ),
        ],
      ),
    );
  }
}
