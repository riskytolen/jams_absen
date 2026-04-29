import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';

/// Tipe notifikasi — menentukan warna, icon, dan style.
enum NotificationType { success, error, warning, info }

/// Custom overlay notification — modern, animated, profesional.
///
/// Muncul dari atas layar dengan animasi slide + fade,
/// otomatis hilang setelah [duration], bisa di-swipe untuk dismiss.
///
/// Cara pakai:
/// ```dart
/// AppNotification.show(
///   context,
///   type: NotificationType.error,
///   title: 'Login Gagal',
///   message: 'ID Pegawai tidak ditemukan dalam sistem.',
/// );
/// ```
class AppNotification {
  AppNotification._();

  /// Notifikasi aktif saat ini — dismiss otomatis sebelum show baru.
  static OverlayEntry? _activeEntry;

  /// Dismiss notifikasi yang sedang tampil (jika ada).
  static void dismiss() {
    if (_activeEntry != null && _activeEntry!.mounted) {
      _activeEntry!.remove();
    }
    _activeEntry = null;
  }

  static void show(
    BuildContext context, {
    required NotificationType type,
    required String title,
    required String message,
    Duration duration = const Duration(seconds: 4),
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    // Dismiss notifikasi sebelumnya agar tidak stack
    dismiss();

    // Haptic feedback sesuai tipe
    switch (type) {
      case NotificationType.error:
        HapticFeedback.heavyImpact();
      case NotificationType.warning:
        HapticFeedback.mediumImpact();
      case NotificationType.success:
      case NotificationType.info:
        HapticFeedback.lightImpact();
    }

    final overlay = Overlay.of(context);
    late final OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => _NotificationOverlay(
        type: type,
        title: title,
        message: message,
        duration: duration,
        onAction: onAction,
        actionLabel: actionLabel,
        onDismiss: () {
          if (entry.mounted) entry.remove();
          if (_activeEntry == entry) _activeEntry = null;
        },
      ),
    );

    _activeEntry = entry;
    overlay.insert(entry);
  }
}

// ═════════════════════════════════════════════════════════
// NOTIFICATION OVERLAY WIDGET
// ═════════════════════════════════════════════════════════
class _NotificationOverlay extends StatefulWidget {
  final NotificationType type;
  final String title;
  final String message;
  final Duration duration;
  final VoidCallback onDismiss;
  final VoidCallback? onAction;
  final String? actionLabel;

  const _NotificationOverlay({
    required this.type,
    required this.title,
    required this.message,
    required this.duration,
    required this.onDismiss,
    this.onAction,
    this.actionLabel,
  });

  @override
  State<_NotificationOverlay> createState() => _NotificationOverlayState();
}

class _NotificationOverlayState extends State<_NotificationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      reverseDuration: const Duration(milliseconds: 300),
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _ctrl,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );

    _ctrl.forward();

    // Auto dismiss
    Future.delayed(widget.duration, _dismiss);
  }

  void _dismiss() async {
    if (!mounted) return;
    await _ctrl.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = _NotifConfig.from(widget.type);
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slideAnim,
        child: FadeTransition(
          opacity: _fadeAnim,
          child: GestureDetector(
            onVerticalDragEnd: (details) {
              if (details.primaryVelocity != null &&
                  details.primaryVelocity! < -100) {
                _dismiss();
              }
            },
            child: Container(
              margin: EdgeInsets.fromLTRB(
                AppSpacing.base,
                topPadding + AppSpacing.sm,
                AppSpacing.base,
                0,
              ),
              padding: const EdgeInsets.all(AppSpacing.base),
              decoration: BoxDecoration(
                color: config.bgColor,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(color: config.borderColor),
                boxShadow: [
                  BoxShadow(
                    color: config.accentColor.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Icon ──
                  _NotifIcon(config: config),
                  const SizedBox(width: AppSpacing.md),

                  // ── Content ──
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: AppTextStyles.label.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: config.titleColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.message,
                          style: AppTextStyles.bodySm.copyWith(
                            color: config.messageColor,
                            height: 1.4,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        // Action button
                        if (widget.onAction != null &&
                            widget.actionLabel != null) ...[
                          const SizedBox(height: AppSpacing.sm),
                          GestureDetector(
                            onTap: () {
                              widget.onAction!();
                              _dismiss();
                            },
                            child: Text(
                              widget.actionLabel!,
                              style: AppTextStyles.buttonSm.copyWith(
                                color: config.accentColor,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // ── Close button ──
                  GestureDetector(
                    onTap: _dismiss,
                    child: Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.sm),
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: config.messageColor.withValues(alpha: 0.50),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════
// NOTIFICATION ICON
// ═════════════════════════════════════════════════════════
class _NotifIcon extends StatelessWidget {
  final _NotifConfig config;

  const _NotifIcon({required this.config});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: config.accentColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Icon(
        config.icon,
        color: config.accentColor,
        size: 22,
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════
// NOTIFICATION CONFIG — warna & icon per tipe
// ═════════════════════════════════════════════════════════
class _NotifConfig {
  final Color accentColor;
  final Color bgColor;
  final Color borderColor;
  final Color titleColor;
  final Color messageColor;
  final IconData icon;

  const _NotifConfig({
    required this.accentColor,
    required this.bgColor,
    required this.borderColor,
    required this.titleColor,
    required this.messageColor,
    required this.icon,
  });

  factory _NotifConfig.from(NotificationType type) {
    switch (type) {
      case NotificationType.error:
        return const _NotifConfig(
          accentColor: AppColors.error,
          bgColor: Color(0xFFFEF2F2),
          borderColor: Color(0xFFFECACA),
          titleColor: Color(0xFF991B1B),
          messageColor: Color(0xFFB91C1C),
          icon: Icons.error_rounded,
        );
      case NotificationType.warning:
        return const _NotifConfig(
          accentColor: AppColors.warning,
          bgColor: Color(0xFFFFFBEB),
          borderColor: Color(0xFFFDE68A),
          titleColor: Color(0xFF92400E),
          messageColor: Color(0xFFB45309),
          icon: Icons.warning_rounded,
        );
      case NotificationType.success:
        return const _NotifConfig(
          accentColor: AppColors.success,
          bgColor: Color(0xFFECFDF5),
          borderColor: Color(0xFFA7F3D0),
          titleColor: Color(0xFF065F46),
          messageColor: Color(0xFF047857),
          icon: Icons.check_circle_rounded,
        );
      case NotificationType.info:
        return const _NotifConfig(
          accentColor: AppColors.info,
          bgColor: Color(0xFFEFF6FF),
          borderColor: Color(0xFFBFDBFE),
          titleColor: Color(0xFF1E40AF),
          messageColor: Color(0xFF1D4ED8),
          icon: Icons.info_rounded,
        );
    }
  }
}
