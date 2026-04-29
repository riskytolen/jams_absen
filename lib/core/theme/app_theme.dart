import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_spacing.dart';

/// Konfigurasi tema global aplikasi.
///
/// Menyediakan [light] theme yang lengkap dengan semua component theme
/// agar konsisten di seluruh aplikasi.
abstract final class AppTheme {
  static ThemeData get light {
    final baseText = GoogleFonts.plusJakartaSansTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,

      // ── Color Scheme ──────────────────────────────────
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary600,
        onPrimary: AppColors.textOnPrimary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        error: AppColors.error,
        onError: AppColors.textOnPrimary,
        outline: AppColors.border,
      ),

      // ── Typography ────────────────────────────────────
      textTheme: baseText.copyWith(
        headlineLarge: baseText.headlineLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: AppColors.textDark,
          letterSpacing: -0.5,
        ),
        headlineMedium: baseText.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
          letterSpacing: -0.3,
        ),
        headlineSmall: baseText.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
        ),
        titleLarge: baseText.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
          fontSize: 18,
        ),
        titleMedium: baseText.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        titleSmall: baseText.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        bodyLarge: baseText.bodyLarge?.copyWith(
          color: AppColors.textPrimary,
          height: 1.5,
        ),
        bodyMedium: baseText.bodyMedium?.copyWith(
          color: AppColors.textSecondary,
          height: 1.5,
        ),
        bodySmall: baseText.bodySmall?.copyWith(
          color: AppColors.textMuted,
          height: 1.4,
        ),
        labelLarge: baseText.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        labelMedium: baseText.labelMedium?.copyWith(
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
        labelSmall: baseText.labelSmall?.copyWith(
          fontWeight: FontWeight.w500,
          color: AppColors.textMuted,
        ),
      ),

      // ── AppBar ────────────────────────────────────────
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textOnPrimary,
        ),
        iconTheme: const IconThemeData(
          color: AppColors.textOnPrimary,
          size: AppSpacing.iconLg,
        ),
      ),

      // ── Card ──────────────────────────────────────────
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
      ),

      // ── Elevated Button ───────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.primary600,
          foregroundColor: AppColors.textOnPrimary,
          disabledBackgroundColor: AppColors.surfaceDim,
          disabledForegroundColor: AppColors.textDisabled,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
        ),
      ),

      // ── Outlined Button ───────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary600,
          disabledForegroundColor: AppColors.textDisabled,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          side: const BorderSide(color: AppColors.primary300),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
        ),
      ),

      // ── Text Button ───────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary600,
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
        ),
      ),

      // ── Input Decoration ──────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: AppSpacing.md,
        ),
        hintStyle: GoogleFonts.plusJakartaSans(
          color: AppColors.textMuted,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        labelStyle: GoogleFonts.plusJakartaSans(
          color: AppColors.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        errorStyle: GoogleFonts.plusJakartaSans(
          color: AppColors.error,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: const BorderSide(color: AppColors.primary600, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
      ),

      // ── Bottom Sheet ──────────────────────────────────
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusXxl),
          ),
        ),
        showDragHandle: true,
        dragHandleColor: AppColors.surfaceDim,
        dragHandleSize: Size(40, 4),
      ),

      // ── Dialog ────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        ),
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
        ),
        contentTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
          height: 1.5,
        ),
      ),

      // ── SnackBar ──────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.primary900,
        contentTextStyle: GoogleFonts.plusJakartaSans(
          color: AppColors.textOnPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        elevation: 4,
        insetPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: AppSpacing.sm,
        ),
      ),

      // ── Chip ──────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.primary50,
        selectedColor: AppColors.primary100,
        disabledColor: AppColors.surfaceAlt,
        labelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.primary800,
        ),
        side: const BorderSide(color: AppColors.primary200),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),

      // ── Divider ───────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),

      // ── Floating Action Button ────────────────────────
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary600,
        foregroundColor: AppColors.textOnPrimary,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
      ),

      // ── Icon ──────────────────────────────────────────
      iconTheme: const IconThemeData(
        color: AppColors.textSecondary,
        size: AppSpacing.iconLg,
      ),

      // ── ListTile ──────────────────────────────────────
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: AppSpacing.xs,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        subtitleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
        ),
        iconColor: AppColors.textSecondary,
      ),

      // ── Tab Bar ───────────────────────────────────────
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.primary600,
        unselectedLabelColor: AppColors.textMuted,
        indicatorColor: AppColors.primary600,
        labelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
      ),

      // ── Switch ────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary600;
          }
          return AppColors.surfaceDim;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary200;
          }
          return AppColors.surfaceAlt;
        }),
      ),

      // ── Progress Indicator ────────────────────────────
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary600,
        linearTrackColor: AppColors.primary100,
        circularTrackColor: AppColors.primary100,
      ),

      // ── Tooltip ───────────────────────────────────────
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.primary900,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        textStyle: GoogleFonts.plusJakartaSans(
          color: AppColors.textOnPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),

      // ── Splash & Highlight ────────────────────────────
      splashColor: AppColors.primary100,
      highlightColor: AppColors.primary50,
      splashFactory: InkSparkle.splashFactory,
    );
  }
}
