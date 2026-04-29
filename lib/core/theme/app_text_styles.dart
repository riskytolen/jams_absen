import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Reusable text styles yang sering dipakai di luar Theme context.
///
/// Gunakan ini untuk widget yang membutuhkan TextStyle langsung
/// tanpa harus akses `Theme.of(context).textTheme`.
///
/// Untuk text di atas background gelap, gunakan varian `onDark`.
abstract final class AppTextStyles {
  static final _base = GoogleFonts.plusJakartaSans();

  // ── Display / Hero ────────────────────────────────────
  static final displayLg = _base.copyWith(
    fontSize: 40,
    fontWeight: FontWeight.w800,
    color: AppColors.textDark,
    letterSpacing: -1,
    height: 1.2,
  );

  // ── Heading ───────────────────────────────────────────
  static final h1 = _base.copyWith(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    color: AppColors.textDark,
    letterSpacing: -0.5,
    height: 1.3,
  );

  static final h2 = _base.copyWith(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.textDark,
    letterSpacing: -0.3,
    height: 1.3,
  );

  static final h3 = _base.copyWith(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.textDark,
    height: 1.4,
  );

  static final h4 = _base.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  // ── Body ──────────────────────────────────────────────
  static final bodyLg = _base.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  static final body = _base.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  static final bodySm = _base.copyWith(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  // ── Label / Caption ───────────────────────────────────
  static final label = _base.copyWith(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static final labelSm = _base.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  static final caption = _base.copyWith(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.textMuted,
  );

  // ── Button ────────────────────────────────────────────
  static final button = _base.copyWith(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.textOnPrimary,
  );

  static final buttonSm = _base.copyWith(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.primary600,
  );

  // ── On Dark (untuk di atas background gelap) ──────────
  static final onDarkTitle = _base.copyWith(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );

  static final onDarkBody = _base.copyWith(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: const Color(0xE6FFFFFF), // 90% white
  );

  static final onDarkCaption = _base.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: const Color(0xB3FFFFFF), // 70% white
  );

  static final onDarkMuted = _base.copyWith(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: const Color(0x80FFFFFF), // 50% white
  );

  // ── Numeric / Tabular ─────────────────────────────────
  static final numericLg = _base.copyWith(
    fontSize: 38,
    fontWeight: FontWeight.w800,
    color: Colors.white,
    letterSpacing: 2,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static final numericMd = _base.copyWith(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    color: AppColors.textDark,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static final numericSm = _base.copyWith(
    fontSize: 17,
    fontWeight: FontWeight.w800,
    color: AppColors.primary800,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}
