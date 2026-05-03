import 'package:flutter/material.dart';

/// Shadow presets — clean, subtle, profesional.
///
/// Hierarki: [subtle] → [card] → [cardHover] → [elevated] → [modal]
abstract final class AppShadows {
  static final subtle = [
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.03),
      blurRadius: 6,
      offset: const Offset(0, 1),
    ),
  ];

  static final card = [
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.05),
      blurRadius: 12,
      offset: const Offset(0, 2),
    ),
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.02),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];

  static final cardHover = [
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.08),
      blurRadius: 20,
      offset: const Offset(0, 6),
    ),
  ];

  static final elevated = [
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.08),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.03),
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
  ];

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

  static final bottomNav = [
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.06),
      blurRadius: 16,
      offset: const Offset(0, -2),
    ),
  ];

  static List<BoxShadow> colored(Color color, {double opacity = 0.20}) => [
        BoxShadow(
          color: color.withValues(alpha: opacity),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> coloredLg(Color color, {double opacity = 0.25}) => [
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

  static List<BoxShadow> inner(Color color, {double opacity = 0.08}) => [
        BoxShadow(
          color: color.withValues(alpha: opacity),
          blurRadius: 4,
          spreadRadius: -1,
          offset: const Offset(0, 2),
        ),
      ];
}
