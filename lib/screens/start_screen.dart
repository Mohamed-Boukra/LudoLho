import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../providers/game_provider.dart';
import '../utils/page_transitions.dart';
import 'game_screen.dart';
import 'setup_screen.dart';

/// The very first screen the player sees: a dark, felt-table backdrop
/// with softly floating 3D-styled tokens, the game title, and buttons
/// to start a new match or resume one that was left mid-way.
class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> with TickerProviderStateMixin {
  late Future<bool> _hasSavedMatch;
  late final AnimationController _floatController;

  @override
  void initState() {
    super.initState();
    _hasSavedMatch = context.read<GameProvider>().hasSavedMatch();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: AppColors.menuGradient,
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _floatController,
                builder: (context, _) => CustomPaint(
                  painter: _FloatingPiecesPainter(t: _floatController.value),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32.w),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ColorDotsRow()
                          .animate()
                          .fadeIn(duration: 500.ms)
                          .slideY(begin: -0.3, end: 0, curve: Curves.easeOutCubic),
                      SizedBox(height: 20.h),
                      _Title()
                          .animate()
                          .fadeIn(delay: 100.ms, duration: 600.ms)
                          .scale(begin: const Offset(0.85, 0.85), curve: Curves.easeOutBack),
                      SizedBox(height: 8.h),
                      Text(
                        'A Premium 3D Edition',
                        style: TextStyle(
                          fontSize: 15.sp,
                          color: Colors.white.withValues(alpha: 0.65),
                          letterSpacing: 1.2,
                        ),
                      ).animate().fadeIn(delay: 250.ms, duration: 500.ms),
                      SizedBox(height: 52.h),
                      _PrimaryButton(
                        label: 'PLAY',
                        onTap: () {
                          Navigator.of(context).push(
                            FadeScaleRoute(page: const SetupScreen()),
                          );
                        },
                      ).animate().fadeIn(delay: 350.ms, duration: 450.ms).slideY(
                            begin: 0.3,
                            end: 0,
                            curve: Curves.easeOutCubic,
                          ),
                      FutureBuilder<bool>(
                        future: _hasSavedMatch,
                        builder: (context, snapshot) {
                          if (snapshot.data != true) return const SizedBox.shrink();
                          return Padding(
                            padding: EdgeInsets.only(top: 12.h),
                            child: _SecondaryButton(
                              label: 'RESUME MATCH',
                              onTap: () {
                                Navigator.of(context).push(
                                  FadeScaleRoute(page: const GameScreen(resume: true)),
                                );
                              },
                            ),
                          ).animate().fadeIn(delay: 450.ms, duration: 450.ms);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (rect) => const LinearGradient(
        colors: [Colors.white, AppColors.gold],
      ).createShader(rect),
      child: Text(
        'LUDO',
        style: TextStyle(
          fontSize: 56.sp,
          fontWeight: FontWeight.w900,
          letterSpacing: 6.w,
          color: Colors.white,
          shadows: [
            Shadow(color: Colors.black.withValues(alpha: 0.4), offset: const Offset(0, 4), blurRadius: 10),
          ],
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PrimaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _PressableScale(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 56.h,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16.r),
          gradient: LinearGradient(
            colors: [AppColors.redLight, AppColors.red, AppColors.redDark],
            stops: const [0.0, 0.5, 1.0],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.red.withValues(alpha: 0.45),
              blurRadius: 18.r,
              offset: Offset(0, 8.h),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 19.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.5.w,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SecondaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _PressableScale(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 50.h,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14.r),
          color: Colors.white.withValues(alpha: 0.08),
          border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: Colors.white.withValues(alpha: 0.92),
          ),
        ),
      ),
    );
  }
}

/// Wraps any child with a satisfying tap-scale-down/up microinteraction.
class _PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _PressableScale({required this.child, required this.onTap});

  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.96),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Small decorative row of the 4 player colors shown above the title,
/// rendered as tiny glossy spheres.
class _ColorDotsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final keys = ['red', 'green', 'yellow', 'blue'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: keys.map((k) {
        final c = AppColors.fromKey(k);
        final dark = AppColors.darkFromKey(k);
        return Container(
          margin: EdgeInsets.symmetric(horizontal: 7.w),
          width: 22.w,
          height: 22.w,
          decoration: BoxDecoration(
            gradient: AppColors.glossSphere(c, dark),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 2.w),
            boxShadow: [
              BoxShadow(color: c.withValues(alpha: 0.55), blurRadius: 10),
            ],
          ),
        );
      }).toList(),
    );
  }
}

/// Faint, slowly drifting dice/token silhouettes in the background for
/// atmosphere — purely decorative, ignores hit testing.
class _FloatingPiecesPainter extends CustomPainter {
  final double t;
  _FloatingPiecesPainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final rand = math.Random(7);
    for (int i = 0; i < 10; i++) {
      final baseX = rand.nextDouble() * size.width;
      final baseY = rand.nextDouble() * size.height;
      final speed = 0.5 + rand.nextDouble();
      final radius = 10.0 + rand.nextDouble() * 22;
      final phase = rand.nextDouble() * math.pi * 2;
      final y = (baseY + math.sin(t * 2 * math.pi * speed + phase) * 18) % size.height;
      final x = (baseX + math.cos(t * 2 * math.pi * speed * 0.6 + phase) * 14) % size.width;

      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()
          ..color = AppColors.gold.withValues(alpha: 0.05)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FloatingPiecesPainter oldDelegate) => oldDelegate.t != t;
}
