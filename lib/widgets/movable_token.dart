import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../constants/app_colors.dart';
import '../models/player_color.dart';
import '../models/token.dart';

/// A single 3D-styled token on the board.
///
/// Visually it's a glossy "bead" that casts its own soft ellipse shadow
/// onto the board beneath it. When [isMovable] is true it lifts
/// slightly off the board and gently bobs to invite a tap — the
/// shadow shrinks and softens as it rises, which is what sells the
/// floating effect. Tapping plays a quick squash before calling
/// [onTap], which triggers the actual move in GameProvider.
class MovableToken extends StatefulWidget {
  final Token token;
  final Color color;
  final bool isMovable;
  final VoidCallback? onTap;

  const MovableToken({
    super.key,
    required this.token,
    required this.color,
    required this.isMovable,
    required this.onTap,
  });

  @override
  State<MovableToken> createState() => _MovableTokenState();
}

class _MovableTokenState extends State<MovableToken> with TickerProviderStateMixin {
  late final AnimationController _bobController;
  late final Animation<double> _bob;

  late final AnimationController _spawnController;
  late final Animation<double> _spawn;

  late final AnimationController _tapController;

  @override
  void initState() {
    super.initState();

    _bobController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _bob = CurvedAnimation(parent: _bobController, curve: Curves.easeInOut);
    _syncBobbing();

    _spawnController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..forward();
    _spawn = CurvedAnimation(parent: _spawnController, curve: Curves.easeOutBack);

    _tapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
    );
  }

  @override
  void didUpdateWidget(covariant MovableToken oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isMovable != widget.isMovable) {
      _syncBobbing();
    }
  }

  void _syncBobbing() {
    if (widget.isMovable) {
      _bobController.repeat(reverse: true);
    } else {
      _bobController.animateTo(0, duration: const Duration(milliseconds: 200));
    }
  }

  Future<void> _handleTap() async {
    if (!widget.isMovable || widget.onTap == null) return;
    await _tapController.animateTo(1.0, curve: Curves.easeOut);
    await _tapController.animateTo(0.0, curve: Curves.easeIn);
    widget.onTap!();
  }

  @override
  void dispose() {
    _bobController.dispose();
    _spawnController.dispose();
    _tapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Color.lerp(widget.color, Colors.black, 0.42)!;

    return Semantics(
      label: '${widget.token.color.label} token',
      button: widget.isMovable,
      child: GestureDetector(
        onTap: widget.isMovable ? _handleTap : null,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double size = constraints.biggest.shortestSide.isFinite
                ? constraints.biggest.shortestSide
                : 28.w;

            return AnimatedBuilder(
              animation: Listenable.merge([_bob, _spawn, _tapController]),
              builder: (context, child) {
                final double lift = widget.isMovable ? _bob.value * size * 0.16 : 0;
                final double tapSquash = _tapController.value;
                final double spawnScale = _spawn.value.clamp(0.0, 1.4);
                final double shadowShrink = widget.isMovable ? (_bob.value * 0.22) : 0.0;

                final double scaleX =
                    spawnScale * (1 + tapSquash * 0.16 - (widget.isMovable ? _bob.value * 0.03 : 0));
                final double scaleY =
                    spawnScale * (1 - tapSquash * 0.16 + (widget.isMovable ? _bob.value * 0.03 : 0));

                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Contact shadow on the board — separate from the
                    // token so it stays put while the token lifts.
                    Positioned(
                      bottom: size * 0.03,
                      child: Container(
                        width: size * 0.66 * (1 - shadowShrink),
                        height: size * 0.26 * (1 - shadowShrink * 0.6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(
                            alpha: widget.isMovable ? 0.22 : 0.34,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: size * 0.14,
                              spreadRadius: size * 0.02,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Transform.translate(
                      offset: Offset(0, -lift),
                      child: Transform.scale(
                        scaleX: scaleX,
                        scaleY: scaleY,
                        child: child,
                      ),
                    ),
                  ],
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.glossSphere(widget.color, dark),
                  border: Border.all(
                    color: Colors.white,
                    width: widget.isMovable ? 2.6.w : 1.8.w,
                  ),
                  boxShadow: [
                    if (widget.isMovable)
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.75),
                        blurRadius: 12.r,
                        spreadRadius: 1.r,
                      ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Bright specular highlight — the key cue that
                    // makes the disc read as a lit sphere.
                    Positioned.fill(
                      child: FractionallySizedBox(
                        alignment: const Alignment(-0.4, -0.5),
                        widthFactor: 0.42,
                        heightFactor: 0.32,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                      ),
                    ),
                    // Subtle rim shade at the bottom edge.
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: size * 0.06,
                      child: Center(
                        child: Container(
                          width: size * 0.18,
                          height: size * 0.18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: dark.withValues(alpha: 0.45),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
