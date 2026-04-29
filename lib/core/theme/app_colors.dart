import 'package:flutter/material.dart';

/// Design system color palette untuk Jams Attendance.
///
/// Primary: Sky Blue — segar, modern, profesional.
/// Menggunakan skala gelap→terang untuk menjaga kontras
/// di berbagai konteks (header gelap, surface putih, dll).
abstract final class AppColors {
  // ── Brand Primary (Sky Blue Scale) ─────────────────────
  static const primary900  = Color(0xFF0C4A6E);   // Paling gelap — header bg
  static const primary800  = Color(0xFF075985);   // Header gradient mid
  static const primary700  = Color(0xFF0369A1);   // Header gradient end
  static const primary600  = Color(0xFF0284C7);   // Tombol, link, aksen kuat
  static const primary      = Color(0xFF0EA5E9);   // Brand utama — Sky-500
  static const primary400  = Color(0xFF38BDF8);   // Highlight, progress bar
  static const primary300  = Color(0xFF7DD3FC);   // Soft accent
  static const primary200  = Color(0xFFBAE6FD);   // Light tint
  static const primary100  = Color(0xFFE0F2FE);   // Subtle background
  static const primary50   = Color(0xFFF0F9FF);   // Card tint

  // ── Secondary ──────────────────────────────────────────
  static const secondary      = Color(0xFF00BFA5);
  static const secondaryLight = Color(0xFF64FFDA);

  // ── Semantic ───────────────────────────────────────────
  static const success     = Color(0xFF10B981);
  static const successLight = Color(0xFF34D399);
  static const successBg   = Color(0xFFECFDF5);
  static const warning     = Color(0xFFF59E0B);
  static const warningLight = Color(0xFFFBBF24);
  static const warningBg   = Color(0xFFFFFBEB);
  static const error       = Color(0xFFEF4444);
  static const errorLight  = Color(0xFFF87171);
  static const errorBg     = Color(0xFFFEF2F2);
  static const info        = Color(0xFF3B82F6);
  static const infoLight   = Color(0xFF60A5FA);
  static const infoBg      = Color(0xFFEFF6FF);

  // ── Surface ────────────────────────────────────────────
  static const background  = Color(0xFFF0F9FF);   // Sky-50 tinted bg
  static const surface     = Color(0xFFFFFFFF);
  static const surfaceAlt  = Color(0xFFF1F5F9);
  static const surfaceDim  = Color(0xFFE2E8F0);   // Disabled / skeleton bg
  static const border      = Color(0xFFE2E8F0);
  static const borderLight = Color(0xFFF1F5F9);
  static const divider     = Color(0xFFE2E8F0);
  static const shimmer     = Color(0xFFE2E8F0);   // Skeleton loading shimmer

  // ── Text ───────────────────────────────────────────────
  static const textDark      = Color(0xFF0C4A6E);   // primary900 — judul utama
  static const textPrimary   = Color(0xFF1E293B);   // Body text
  static const textSecondary = Color(0xFF64748B);   // Secondary text
  static const textMuted     = Color(0xFF94A3B8);   // Hint / caption
  static const textDisabled  = Color(0xFFCBD5E1);   // Disabled text
  static const textOnPrimary = Color(0xFFFFFFFF);   // Di atas primary gelap
  static const textOnDark    = Color(0xFFF8FAFC);   // Di atas surface gelap

  // ── Overlay ────────────────────────────────────────────
  static const overlay       = Color(0x33000000);   // 20% black overlay
  static const overlayLight  = Color(0x1A000000);   // 10% black overlay
  static const overlayWhite  = Color(0x33FFFFFF);   // 20% white overlay

  // ── Gradients ──────────────────────────────────────────

  /// Header utama — biru muda gelap → biru muda, segar & kontras kuat.
  static const headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF075985), Color(0xFF0284C7), Color(0xFF0EA5E9)],
    stops: [0.0, 0.5, 1.0],
  );

  /// Gradient brand ringan.
  static const primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0284C7), Color(0xFF38BDF8)],
  );

  /// Gradient brand sangat ringan — untuk card background.
  static const primarySoftGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE0F2FE), Color(0xFFF0F9FF)],
  );

  static const clockInGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF059669), Color(0xFF34D399)],
  );

  static const clockOutGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFDC2626), Color(0xFFF87171)],
  );

  // ── Menu Card Gradients ────────────────────────────────
  static const skyGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0284C7), Color(0xFF38BDF8)],
  );

  static const blueGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2563EB), Color(0xFF60A5FA)],
  );

  static const orangeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEA580C), Color(0xFFFB923C)],
  );

  static const purpleGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7C3AED), Color(0xFFA78BFA)],
  );

  static const tealGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0D9488), Color(0xFF2DD4BF)],
  );

  static const roseGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE11D48), Color(0xFFFB7185)],
  );

  static const indigoGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4F46E5), Color(0xFF818CF8)],
  );

  static const amberGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFD97706), Color(0xFFFBBF24)],
  );

  static const slateGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF334155), Color(0xFF64748B)],
  );

  static const emeraldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF059669), Color(0xFF34D399)],
  );

  static const cyanGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0891B2), Color(0xFF22D3EE)],
  );
}
