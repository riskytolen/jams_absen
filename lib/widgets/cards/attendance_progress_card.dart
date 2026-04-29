import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';

/// Card yang menampilkan persentase kehadiran bulanan
/// dengan circular + linear progress indicator dan animasi.
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
  late final AnimationController _animCtrl;
  late final Animation<double> _progressAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _progressAnim = Tween(begin: 0.0, end: widget.percentage / 100).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic),
    );
    // Delay sedikit agar animasi terlihat saat scroll
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _animCtrl.forward();
    });
  }

  @override
  void didUpdateWidget(covariant AttendanceProgressCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.percentage != widget.percentage) {
      _progressAnim = Tween(
        begin: _progressAnim.value,
        end: widget.percentage / 100,
      ).animate(
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic),
      );
      _animCtrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return Container(
      margin: AppSpacing.screenH,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          _AnimatedCircularProgress(
            animation: _progressAnim,
            listenable: _animCtrl,
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tingkat Kehadiran', style: theme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  'Bulan ini: ${widget.totalPresent} dari ${widget.workingDays} hari kerja',
                  style: theme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.md),
                ListenableBuilder(
                  listenable: _animCtrl,
                  builder: (_, _) => ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: _progressAnim.value,
                      minHeight: 7,
                      backgroundColor: AppColors.primary100,
                      valueColor: AlwaysStoppedAnimation(
                        _getProgressColor(widget.percentage),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Warna progress berdasarkan persentase kehadiran.
  Color _getProgressColor(double pct) {
    if (pct >= 90) return AppColors.primary600;
    if (pct >= 75) return AppColors.success;
    if (pct >= 50) return AppColors.warning;
    return AppColors.error;
  }
}

class _AnimatedCircularProgress extends StatelessWidget {
  final Animation<double> animation;
  final Listenable listenable;

  const _AnimatedCircularProgress({
    required this.animation,
    required this.listenable,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 68,
      height: 68,
      child: ListenableBuilder(
        listenable: listenable,
        builder: (_, _) {
          final pct = (animation.value * 100).toInt();
          return Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: animation.value,
                  strokeWidth: 6,
                  strokeCap: StrokeCap.round,
                  backgroundColor: AppColors.primary100,
                  valueColor:
                      const AlwaysStoppedAnimation(AppColors.primary600),
                ),
              ),
              Text('$pct%', style: AppTextStyles.numericSm),
            ],
          );
        },
      ),
    );
  }
}
