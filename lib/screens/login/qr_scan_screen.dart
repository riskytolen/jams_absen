import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';

/// Halaman scan QR Code pada ID Card pegawai untuk login.
///
/// Saat ini menggunakan placeholder UI (belum integrasi kamera).
/// Ketika package camera/qr_scanner ditambahkan, ganti area kamera
/// dengan widget kamera sesungguhnya.
class QrScanScreen extends StatefulWidget {
  final ValueChanged<String> onScanned;

  const QrScanScreen({super.key, required this.onScanned});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen>
    with TickerProviderStateMixin {
  // ── Scan line animation ──
  late final AnimationController _scanLineCtrl;
  late final Animation<double> _scanLineAnim;

  // ── Corner pulse ──
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  // ── Flash state ──
  bool _isFlashOn = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();

    _scanLineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);

    _scanLineAnim = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanLineCtrl, curve: Curves.easeInOut),
    );

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnim = Tween(begin: 0.97, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scanLineCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _toggleFlash() {
    HapticFeedback.lightImpact();
    setState(() => _isFlashOn = !_isFlashOn);
    // TODO: Integrasi toggle flash kamera
  }

  /// Simulasi scan berhasil — nanti ganti dengan hasil kamera.
  void _simulateScan() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();

    // Simulasi proses verifikasi
    await Future.delayed(const Duration(milliseconds: 1200));

    if (!mounted) return;

    HapticFeedback.heavyImpact();
    widget.onScanned('EMP-001');
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // ── Camera placeholder ──
            Container(color: const Color(0xFF0A0A0A)),

            // ── Dimmed overlay di luar viewfinder ──
            _DimOverlay(),

            // ── Scanner viewfinder ──
            _ScannerViewfinder(
              scanLineAnimation: _scanLineAnim,
              scanLineController: _scanLineCtrl,
              pulseAnimation: _pulseAnim,
              pulseController: _pulseCtrl,
            ),

            // ── Top bar ──
            _buildTopBar(),

            // ── Bottom section ──
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildBottomSection(),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // TOP BAR
  // ═══════════════════════════════════════════════════════
  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            // Back button
            _GlassButton(
              icon: Icons.arrow_back_rounded,
              onTap: () => Navigator.of(context).pop(),
            ),
            const Spacer(),

            // Title
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.10),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.badge_rounded,
                    color: AppColors.primary300,
                    size: AppSpacing.iconSm,
                  ),
                  const SizedBox(width: AppSpacing.sm - 2),
                  Text(
                    'Scan ID Card',
                    style: AppTextStyles.onDarkBody.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Flash button
            _GlassButton(
              icon: _isFlashOn
                  ? Icons.flash_on_rounded
                  : Icons.flash_off_rounded,
              isActive: _isFlashOn,
              onTap: _toggleFlash,
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // BOTTOM SECTION
  // ═══════════════════════════════════════════════════════
  Widget _buildBottomSection() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xxl,
        AppSpacing.xl,
        MediaQuery.of(context).padding.bottom + AppSpacing.xl,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.90),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Instruction chip ──
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.base,
              vertical: AppSpacing.sm + 2,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.qr_code_rounded,
                  color: AppColors.primary300,
                  size: AppSpacing.iconSm,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Arahkan ke QR Code pada ID Card',
                  style: AppTextStyles.onDarkBody.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.base),

          // ── Description ──
          Text(
            'Posisikan QR Code di dalam bingkai\nScan akan berjalan otomatis',
            textAlign: TextAlign.center,
            style: AppTextStyles.onDarkCaption.copyWith(
              color: Colors.white.withValues(alpha: 0.50),
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // ── Simulate scan button (demo) ──
          SizedBox(
            width: double.infinity,
            height: 50,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                gradient:
                    _isProcessing ? null : AppColors.primaryGradient,
                color: _isProcessing
                    ? AppColors.primary600.withValues(alpha: 0.4)
                    : null,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _isProcessing ? null : _simulateScan,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  splashColor: Colors.white.withValues(alpha: 0.12),
                  child: Center(
                    child: _isProcessing
                        ? const _ScanProcessingIndicator()
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.touch_app_rounded,
                                color: Colors.white,
                                size: AppSpacing.iconMd,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                'Simulasi Scan (Demo)',
                                style: AppTextStyles.button
                                    .copyWith(fontSize: 14),
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
}

// ═════════════════════════════════════════════════════════
// GLASS BUTTON (top bar)
// ═════════════════════════════════════════════════════════
class _GlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isActive;

  const _GlassButton({
    required this.icon,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppSpacing.durationFast,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary600.withValues(alpha: 0.30)
              : Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: isActive
                ? AppColors.primary400.withValues(alpha: 0.40)
                : Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Icon(
          icon,
          color: isActive ? AppColors.primary300 : Colors.white,
          size: AppSpacing.iconMd,
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════
// SCAN PROCESSING INDICATOR
// ═════════════════════════════════════════════════════════
class _ScanProcessingIndicator extends StatelessWidget {
  const _ScanProcessingIndicator();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(Colors.white),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Text(
          'Memverifikasi...',
          style: AppTextStyles.button.copyWith(fontSize: 14),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════
// DIM OVERLAY — gelap di luar area scan
// ═════════════════════════════════════════════════════════
class _DimOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final scanSize = size.width * 0.68;

    return ColorFiltered(
      colorFilter: ColorFilter.mode(
        Colors.black.withValues(alpha: 0.55),
        BlendMode.srcOut,
      ),
      child: Stack(
        children: [
          // Full screen fill
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              backgroundBlendMode: BlendMode.dstOut,
            ),
          ),
          // Cutout hole
          Center(
            child: Container(
              width: scanSize,
              height: scanSize,
              decoration: BoxDecoration(
                color: Colors.red, // warna apapun, akan di-cut
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════
// SCANNER VIEWFINDER
// ═════════════════════════════════════════════════════════
class _ScannerViewfinder extends StatelessWidget {
  final Animation<double> scanLineAnimation;
  final AnimationController scanLineController;
  final Animation<double> pulseAnimation;
  final AnimationController pulseController;

  const _ScannerViewfinder({
    required this.scanLineAnimation,
    required this.scanLineController,
    required this.pulseAnimation,
    required this.pulseController,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final scanSize = size.width * 0.68;

    return Center(
      child: SizedBox(
        width: scanSize,
        height: scanSize,
        child: Stack(
          children: [
            // ── Corner brackets with pulse ──
            ListenableBuilder(
              listenable: pulseController,
              builder: (_, _) => Transform.scale(
                scale: pulseAnimation.value,
                child: CustomPaint(
                  size: Size(scanSize, scanSize),
                  painter: _CornerBracketPainter(
                    color: AppColors.primary400,
                    strokeWidth: 3.5,
                    cornerLength: 30,
                    cornerRadius: AppSpacing.radiusLg,
                  ),
                ),
              ),
            ),

            // ── Scan line ──
            ListenableBuilder(
              listenable: scanLineController,
              builder: (_, _) {
                final top = scanLineAnimation.value * (scanSize - 4);
                return Positioned(
                  top: top,
                  left: 18,
                  right: 18,
                  child: Container(
                    height: 2.5,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary400.withValues(alpha: 0.0),
                          AppColors.primary400.withValues(alpha: 0.7),
                          AppColors.primary400,
                          AppColors.primary400.withValues(alpha: 0.7),
                          AppColors.primary400.withValues(alpha: 0.0),
                        ],
                        stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              AppColors.primary400.withValues(alpha: 0.45),
                          blurRadius: 14,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            // ── Center hint icon ──
            Center(
              child: Icon(
                Icons.qr_code_2_rounded,
                size: 48,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════
// CORNER BRACKET PAINTER
// ═════════════════════════════════════════════════════════
class _CornerBracketPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double cornerLength;
  final double cornerRadius;

  _CornerBracketPainter({
    required this.color,
    required this.strokeWidth,
    required this.cornerLength,
    required this.cornerRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;
    final cl = cornerLength;
    final cr = cornerRadius;

    // Top-left
    canvas.drawPath(
      Path()
        ..moveTo(0, cl)
        ..lineTo(0, cr)
        ..quadraticBezierTo(0, 0, cr, 0)
        ..lineTo(cl, 0),
      paint,
    );

    // Top-right
    canvas.drawPath(
      Path()
        ..moveTo(w - cl, 0)
        ..lineTo(w - cr, 0)
        ..quadraticBezierTo(w, 0, w, cr)
        ..lineTo(w, cl),
      paint,
    );

    // Bottom-left
    canvas.drawPath(
      Path()
        ..moveTo(0, h - cl)
        ..lineTo(0, h - cr)
        ..quadraticBezierTo(0, h, cr, h)
        ..lineTo(cl, h),
      paint,
    );

    // Bottom-right
    canvas.drawPath(
      Path()
        ..moveTo(w - cl, h)
        ..lineTo(w - cr, h)
        ..quadraticBezierTo(w, h, w, h - cr)
        ..lineTo(w, h - cl),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CornerBracketPainter oldDelegate) =>
      color != oldDelegate.color ||
      strokeWidth != oldDelegate.strokeWidth ||
      cornerLength != oldDelegate.cornerLength;
}
