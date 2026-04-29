import 'package:flutter/material.dart';

/// Spacing, sizing, dan animation constants untuk konsistensi layout.
///
/// Semua spacing menggunakan 4px grid system.
abstract final class AppSpacing {
  // ── Base spacing scale (4px grid) ──────────────────────
  static const double xs   = 4;
  static const double sm   = 8;
  static const double md   = 12;
  static const double base = 16;
  static const double lg   = 20;
  static const double xl   = 24;
  static const double xxl  = 32;
  static const double xxxl = 40;
  static const double huge = 48;

  // ── Screen padding ────────────────────────────────────
  static const screenH   = EdgeInsets.symmetric(horizontal: lg);
  static const screenAll = EdgeInsets.all(lg);
  static const screenV   = EdgeInsets.symmetric(vertical: lg);

  // ── Common padding presets ────────────────────────────
  static const paddingSm   = EdgeInsets.all(sm);
  static const paddingMd   = EdgeInsets.all(md);
  static const paddingBase = EdgeInsets.all(base);
  static const paddingLg   = EdgeInsets.all(lg);
  static const paddingXl   = EdgeInsets.all(xl);

  // ── Border radius ─────────────────────────────────────
  static const double radiusSm   = 8;
  static const double radiusMd   = 12;
  static const double radiusLg   = 16;
  static const double radiusXl   = 20;
  static const double radiusXxl  = 24;
  static const double radiusFull = 999;

  // ── Icon sizes ────────────────────────────────────────
  static const double iconXs = 16;
  static const double iconSm = 18;
  static const double iconMd = 22;
  static const double iconLg = 24;
  static const double iconXl = 28;
  static const double iconXxl = 32;

  // ── Animation durations ───────────────────────────────
  static const Duration durationFast   = Duration(milliseconds: 150);
  static const Duration durationNormal = Duration(milliseconds: 250);
  static const Duration durationSlow   = Duration(milliseconds: 350);
  static const Duration durationPage   = Duration(milliseconds: 400);

  // ── Animation curves ──────────────────────────────────
  static const Curve curveDefault    = Curves.easeOutCubic;
  static const Curve curveEmphasized = Curves.easeInOutCubicEmphasized;
  static const Curve curveBounce     = Curves.elasticOut;
  static const Curve curveDecelerate = Curves.decelerate;
}
