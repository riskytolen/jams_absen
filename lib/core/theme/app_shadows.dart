import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Reusable shadow presets — disesuaikan dengan palet sky blue.
///
/// Hierarki elevasi:
/// [subtle] → [card] → [cardHover] → [elevated] → [modal]
abstract final class AppShadows {
  /// Shadow sangat ringan — untuk elemen yang sedikit terangkat.
  static final subtle = [
    BoxShadow(
      color: AppColors.primary900.withValues(alpha: 0.03),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  /// Shadow default untuk card — elevasi standar.
  static final card = [
    BoxShadow(
      color: AppColors.primary900.withValues(alpha: 0.06),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  /// Shadow card saat hover/pressed — elevasi lebih tinggi.
  static final cardHover = [
    BoxShadow(
      color: AppColors.primary900.withValues(alpha: 0.10),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  /// Shadow untuk elemen yang sangat terangkat (FAB, dropdown, dll).
  static final elevated = [
    BoxShadow(
      color: AppColors.primary900.withValues(alpha: 0.08),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: AppColors.primary900.withValues(alpha: 0.04),
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
  ];

  /// Shadow untuk modal/dialog — elevasi tertinggi.
  static final modal = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.12),
      blurRadius: 32,
      offset: const Offset(0, 16),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];

  /// Shadow untuk bottom navigation bar.
  static final bottomNav = [
    BoxShadow(
      color: AppColors.primary900.withValues(alpha: 0.08),
      blurRadius: 20,
      offset: const Offset(0, -4),
    ),
  ];

  /// Shadow berwarna — untuk icon box, badge, dll.
  /// [color] warna dasar shadow, [opacity] intensitas (default 0.25).
  static List<BoxShadow> colored(Color color, {double opacity = 0.25}) => [
        BoxShadow(
          color: color.withValues(alpha: opacity),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  /// Shadow berwarna yang lebih besar — untuk tombol utama.
  static List<BoxShadow> coloredLg(Color color, {double opacity = 0.30}) => [
        BoxShadow(
          color: color.withValues(alpha: opacity),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: color.withValues(alpha: opacity * 0.4),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];

  /// Inner shadow effect — untuk pressed state / inset look.
  static List<BoxShadow> inner(Color color, {double opacity = 0.08}) => [
        BoxShadow(
          color: color.withValues(alpha: opacity),
          blurRadius: 4,
          spreadRadius: -1,
          offset: const Offset(0, 2),
        ),
      ];
}
