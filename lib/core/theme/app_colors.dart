import 'package:flutter/material.dart';

/// Design system — Deep Blue / Navy palette.
///
/// Corporate, trustworthy, profesional.
/// Warna bold untuk aksen, clean untuk surface.
abstract final class AppColors {
  // ── Brand Primary (Deep Navy Scale) ────────────────────
  static const primary900  = Color(0xFF0A1628);   // Paling gelap
  static const primary800  = Color(0xFF111D35);   // Header bg
  static const primary700  = Color(0xFF162544);   // Header gradient
  static const primary600  = Color(0xFF1B3A5C);   // Tombol, aksen kuat
  static const primary      = Color(0xFF1E4D8C);   // Brand utama
  static const primary400  = Color(0xFF2E6AB4);   // Highlight
  static const primary300  = Color(0xFF5A8FCC);   // Soft accent
  static const primary200  = Color(0xFF9BBDE0);   // Light tint
  static const primary100  = Color(0xFFD0E2F3);   // Subtle bg
  static const primary50   = Color(0xFFEBF2FA);   // Card tint

  // ── Accent (Bright Blue — untuk CTA & highlight) ───────
  static const accent      = Color(0xFF2563EB);
  static const accentLight = Color(0xFF60A5FA);
  static const accentBg    = Color(0xFFEFF6FF);

  // ── Semantic ───────────────────────────────────────────
  static const success     = Color(0xFF059669);
  static const successLight = Color(0xFF34D399);
  static const successBg   = Color(0xFFECFDF5);
  static const warning     = Color(0xFFD97706);
  static const warningLight = Color(0xFFFBBF24);
  static const warningBg   = Color(0xFFFFFBEB);
  static const error       = Color(0xFFDC2626);
  static const errorLight  = Color(0xFFF87171);
  static const errorBg     = Color(0xFFFEF2F2);
  static const info        = Color(0xFF2563EB);
  static const infoLight   = Color(0xFF60A5FA);
  static const infoBg      = Color(0xFFEFF6FF);

  // ── Surface ────────────────────────────────────────────
  static const background  = Color(0xFFF5F7FA);   // Cool gray bg
  static const surface     = Color(0xFFFFFFFF);
  static const surfaceAlt  = Color(0xFFF1F3F7);
  static const surfaceDim  = Color(0xFFE2E6ED);
  static const border      = Color(0xFFE2E6ED);
  static const borderLight = Color(0xFFF1F3F7);
  static const divider     = Color(0xFFE8ECF1);
  static const shimmer     = Color(0xFFE2E6ED);

  // ── Text ───────────────────────────────────────────────
  static const textDark      = Color(0xFF0F172A);   // Judul utama
  static const textPrimary   = Color(0xFF1E293B);   // Body text
  static const textSecondary = Color(0xFF64748B);   // Secondary
  static const textMuted     = Color(0xFF94A3B8);   // Hint / caption
  static const textDisabled  = Color(0xFFCBD5E1);   // Disabled
  static const textOnPrimary = Color(0xFFFFFFFF);   // Di atas primary
  static const textOnDark    = Color(0xFFF8FAFC);   // Di atas dark

  // ── Overlay ────────────────────────────────────────────
  static const overlay       = Color(0x33000000);
  static const overlayLight  = Color(0x1A000000);
  static const overlayWhite  = Color(0x33FFFFFF);

  // ── Gradients ──────────────────────────────────────────

  /// Header — deep navy gradient.
  static const headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0A1628), Color(0xFF162544), Color(0xFF1B3A5C)],
    stops: [0.0, 0.5, 1.0],
  );

  /// Primary gradient — navy to blue.
  static const primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1B3A5C), Color(0xFF2E6AB4)],
  );

  /// Accent gradient — bright blue.
  static const accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2563EB), Color(0xFF60A5FA)],
  );

  /// Soft gradient — untuk card bg.
  static const primarySoftGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEBF2FA), Color(0xFFF5F7FA)],
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

  // ── Menu Card Gradients (bold, solid-feel) ─────────────
  static const skyGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1B3A5C), Color(0xFF2E6AB4)],
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

  // ── Secondary (kept for compatibility) ─────────────────
  static const secondary      = Color(0xFF059669);
  static const secondaryLight = Color(0xFF34D399);
}
