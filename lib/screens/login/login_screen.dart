import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../dashboard/dashboard_screen.dart';
import 'qr_scan_screen.dart';

/// Halaman login — modern, clean, satu metode: Scan QR Code ID Card.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  // ── Entrance animations ──
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;
  late final AnimationController _slideCtrl;
  late final Animation<Offset> _slideAnim;

  // ── Floating circles ──
  late final AnimationController _floatCtrl;

  // ── QR button pulse ──
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));

    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnim = Tween(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _fadeCtrl.forward();
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _slideCtrl.dispose();
    _floatCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Open QR Scanner ───────────────────────────────────
  void _openQrScanner() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => QrScanScreen(
          onScanned: (code) {
            Navigator.of(context).pop();
            _navigateToDashboard();
          },
        ),
        transitionsBuilder: (context, anim, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: anim,
              curve: AppSpacing.curveDefault,
            )),
            child: child,
          );
        },
        transitionDuration: AppSpacing.durationPage,
      ),
    );
  }

  // ── Navigate to Dashboard ─────────────────────────────
  void _navigateToDashboard() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const DashboardScreen(),
        transitionsBuilder: (context, anim, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: anim, curve: Curves.easeInOut),
            child: child,
          );
        },
        transitionDuration: AppSpacing.durationPage,
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        body: Stack(
          children: [
            const _BackgroundGradient(),
            _FloatingCircles(animation: _floatCtrl),
            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: _buildContent(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  const SizedBox(height: AppSpacing.huge),
                  _buildLogo(),
                  const SizedBox(height: AppSpacing.huge + 16),
                  _buildScanCard(),
                  const SizedBox(height: AppSpacing.xxl),
                  _buildHowItWorks(),
                  const Spacer(),
                  _buildFooter(),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════
  // LOGO & BRANDING
  // ═══════════════════════════════════════════════════════
  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
            boxShadow: AppShadows.elevated,
          ),
          child: Center(
            child: ShaderMask(
              shaderCallback: (bounds) =>
                  AppColors.primaryGradient.createShader(bounds),
              child: const Icon(
                Icons.fingerprint_rounded,
                size: 44,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'JamsAbsen',
          style: AppTextStyles.h1.copyWith(
            color: Colors.white,
            fontSize: 28,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Smart Attendance System',
          style: AppTextStyles.onDarkBody.copyWith(
            color: Colors.white.withValues(alpha: 0.70),
            fontSize: 14,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  // SCAN QR CARD — CTA utama
  // ═══════════════════════════════════════════════════════
  Widget _buildScanCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXxl),
        boxShadow: AppShadows.elevated,
      ),
      child: Column(
        children: [
          // ── Illustration: ID Card icon ──
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary50,
              borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
              border: Border.all(
                color: AppColors.primary200.withValues(alpha: 0.6),
              ),
            ),
            child: const Icon(
              Icons.qr_code_scanner_rounded,
              size: 36,
              color: AppColors.primary600,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Title ──
          Text(
            'Scan ID Card Anda',
            style: AppTextStyles.h2,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Arahkan kamera ke QR Code pada\nID Card pegawai untuk masuk',
            style: AppTextStyles.body.copyWith(height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl + 4),

          // ── Scan Button ──
          ListenableBuilder(
            listenable: _pulseCtrl,
            builder: (_, child) => Transform.scale(
              scale: _pulseAnim.value,
              child: child,
            ),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusMd + 2),
                  gradient: AppColors.primaryGradient,
                  boxShadow:
                      AppShadows.coloredLg(AppColors.primary600, opacity: 0.35),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _openQrScanner,
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusMd + 2),
                    splashColor: Colors.white.withValues(alpha: 0.15),
                    highlightColor: Colors.white.withValues(alpha: 0.05),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.qr_code_scanner_rounded,
                          color: Colors.white,
                          size: AppSpacing.iconLg,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Text(
                          'Scan QR Code',
                          style: AppTextStyles.button.copyWith(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // HOW IT WORKS — 3 langkah kecil
  // ═══════════════════════════════════════════════════════
  Widget _buildHowItWorks() {
    return Column(
      children: [
        Text(
          'Cara Masuk',
          style: AppTextStyles.onDarkBody.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: AppSpacing.base),
        Row(
          children: [
            _buildStep(
              number: '1',
              icon: Icons.badge_rounded,
              label: 'Siapkan\nID Card',
            ),
            _buildStepConnector(),
            _buildStep(
              number: '2',
              icon: Icons.qr_code_rounded,
              label: 'Scan QR\nCode',
            ),
            _buildStepConnector(),
            _buildStep(
              number: '3',
              icon: Icons.verified_rounded,
              label: 'Verifikasi\nBerhasil',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep({
    required String number,
    required IconData icon,
    required String label,
  }) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
            child: Icon(icon, color: AppColors.primary300, size: 22),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.onDarkMuted.copyWith(
              color: Colors.white.withValues(alpha: 0.60),
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepConnector() {
    return SizedBox(
      width: 24,
      child: Center(
        child: Container(
          width: 20,
          height: 1,
          margin: const EdgeInsets.only(bottom: 28),
          color: Colors.white.withValues(alpha: 0.15),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // FOOTER
  // ═══════════════════════════════════════════════════════
  Widget _buildFooter() {
    return Column(
      children: [
        Text(
          'JamsAbsen v1.0.0',
          style: AppTextStyles.onDarkMuted.copyWith(
            color: Colors.white.withValues(alpha: 0.35),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '\u00A9 2026 JamsAbsen. All rights reserved.',
          style: AppTextStyles.onDarkMuted.copyWith(
            color: Colors.white.withValues(alpha: 0.25),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════
// BACKGROUND GRADIENT
// ═════════════════════════════════════════════════════════
class _BackgroundGradient extends StatelessWidget {
  const _BackgroundGradient();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF075985),
            Color(0xFF0369A1),
            Color(0xFF0C4A6E),
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════
// FLOATING DECORATIVE CIRCLES
// ═════════════════════════════════════════════════════════
class _FloatingCircles extends StatelessWidget {
  final AnimationController animation;

  const _FloatingCircles({required this.animation});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return ListenableBuilder(
      listenable: animation,
      builder: (_, _) {
        final t = animation.value;
        return Stack(
          children: [
            Positioned(
              right: -60 + (20 * math.sin(t * math.pi * 2)),
              top: -40 + (15 * math.cos(t * math.pi * 2)),
              child: _circle(180, 0.04),
            ),
            Positioned(
              left: -80 + (12 * math.cos(t * math.pi * 2)),
              top: size.height * 0.35 + (20 * math.sin(t * math.pi * 2)),
              child: _circle(200, 0.03),
            ),
            Positioned(
              right: 30 + (18 * math.sin(t * math.pi * 2 + 1)),
              bottom: size.height * 0.15 + (10 * math.cos(t * math.pi * 2)),
              child: _circle(100, 0.05),
            ),
            Positioned(
              left: 40 + (8 * math.cos(t * math.pi * 2 + 2)),
              top: 120 + (12 * math.sin(t * math.pi * 2 + 1)),
              child: _circle(60, 0.06),
            ),
          ],
        );
      },
    );
  }

  Widget _circle(double diameter, double opacity) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }
}
