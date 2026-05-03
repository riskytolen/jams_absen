import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Card kehadiran — large circular progress, animated, bold.
class AttendanceProgressCard extends StatefulWidget {
  final double percentage;
  final int totalPresent;
  final int workingDays;

  const AttendanceProgressCard({
    super.key,
    required this.percentage,
    required this.totalPresent,
    required this.workingDays,
  });

  @override
  State<AttendanceProgressCard> createState() =>
      _AttendanceProgressCardState();
}

class _AttendanceProgressCardState extends State<AttendanceProgressCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _progress = Tween(begin: 0.0, end: widget.percentage / 100).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void didUpdateWidget(covariant AttendanceProgressCard old) {
    super.didUpdateWidget(old);
    if (old.percentage != widget.percentage) {
      _progress = Tween(
        begin: _progress.value,
        end: widget.percentage / 100,
      ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
      _ctrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color get _color {
    final pct = widget.percentage;
    if (pct >= 90) return AppColors.accent;
    if (pct >= 75) return AppColors.success;
    if (pct >= 50) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // ── Header (di luar card) ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Tingkat Kehadiran', style: AppTextStyles.h4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: AnimatedBuilder(
                  animation: _ctrl,
                  builder: (_, _) {
                    final pct = (_progress.value * 100).toInt();
                    return Text(
                      '$pct%',
                      style: AppTextStyles.label.copyWith(color: _color, fontSize: 12),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Card ──
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Circular progress
                SizedBox(
                  width: 120,
                  height: 120,
                  child: AnimatedBuilder(
                    animation: _ctrl,
                    builder: (_, _) {
                      final pct = (_progress.value * 100).toInt();
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox.expand(
                            child: CustomPaint(
                              painter: _RingPainter(
                                progress: _progress.value,
                                color: _color,
                                trackColor: AppColors.primary100,
                                strokeWidth: 10,
                              ),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$pct',
                                style: AppTextStyles.numericMd.copyWith(
                                  fontSize: 32,
                                  color: AppColors.textDark,
                                  height: 1,
                                ),
                              ),
                              Text(
                                'persen',
                                style: AppTextStyles.caption.copyWith(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),

                // Bottom info row
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _InfoItem(label: 'Hadir', value: '${widget.totalPresent}', color: AppColors.success),
                      _Dot(),
                      _InfoItem(label: 'Hari Kerja', value: '${widget.workingDays}', color: AppColors.primary),
                      _Dot(),
                      _InfoItem(label: 'Tidak Hadir', value: '${widget.workingDays - widget.totalPresent}', color: AppColors.error),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════
// INFO ITEM
// ═════════════════════════════════════════════════════════
class _InfoItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _InfoItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: AppTextStyles.label.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      height: 3,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.textMuted.withValues(alpha: 0.4),
        shape: BoxShape.circle,
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════
// RING PAINTER — custom circular progress with rounded caps
// ═════════════════════════════════════════════════════════
class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc
    if (progress > 0) {
      final progressPaint = Paint()
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: 3 * math.pi / 2,
          colors: [color.withValues(alpha: 0.6), color],
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.color != color;
}
