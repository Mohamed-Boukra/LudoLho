import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ludo_game/models/player_color.dart';
import 'package:provider/provider.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;
import '../constants/app_colors.dart';
import '../models/game_phase.dart';
import '../providers/game_provider.dart';

/// A tappable 3D dice. At rest it's a raised, beveled cube showing the
/// last rolled value. While rolling, it deliberately shows **no
/// specific number at all** — only a blurred/spinning face — so there
/// is never a crisp digit on screen that could be mistaken for the
/// real result before the roll has actually finished. The true value
/// only ever appears once, right when it settles.
///
/// The tumble duration always matches [GameProvider.diceRollDuration]
/// — that's also how long the provider waits before it lets tokens
/// become tappable, so the number you see it land on is always
/// exactly what a token move will use.
class DiceWidget extends StatefulWidget {
  const DiceWidget({super.key});

  @override
  State<DiceWidget> createState() => _DiceWidgetState();
}

class _DiceWidgetState extends State<DiceWidget> with SingleTickerProviderStateMixin {
  final Random _random = Random();
  int _displayValue = 1;
  bool _isRolling = false;

  late final AnimationController _tumbleController;
  double _spinsX = 2.4;
  double _spinsY = 1.8;

  @override
  void initState() {
    super.initState();
    _tumbleController = AnimationController(
      vsync: this,
      duration: GameProvider.diceRollDuration,
      // Start at the *settled* end of the tumble curve (value: 1), not
      // the start. At t=1 the rotation formula below evaluates to a
      // flat, camera-facing cube; at t=0 it evaluates to whatever the
      // fractional part of _spinsX/_spinsY happens to be (e.g. 0.4 of
      // a turn), which is a steep, near edge-on tilt. Starting at 0
      // was why the die looked like a thin diagonal sliver before it
      // had ever been rolled.
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _tumbleController.dispose();
    super.dispose();
  }

  Future<void> _handleTap(GameProvider provider) async {
    // Guard against any possible double-trigger (fast double-tap,
    // stray rebuild, etc.) — a roll can only ever start once per turn
    // and only while the provider itself agrees it's roll time.
    if (_isRolling || provider.isRollingDice) return;
    if (!provider.isInitialized || provider.phase != GamePhase.rollPhase) return;

    setState(() {
      _isRolling = true;
      _spinsX = 2 + _random.nextDouble() * 1.5;
      _spinsY = 1.4 + _random.nextDouble() * 1.5;
    });

    _tumbleController.forward(from: 0);
    // The real result is decided right now — but deliberately not
    // shown until the animation below finishes, so what settles on
    // screen is always the one and only number that was ever "the
    // roll".
    final finalValue = provider.rollDice();

    await Future.delayed(GameProvider.diceRollDuration);
    if (!mounted) return;

    setState(() {
      _displayValue = finalValue;
      _isRolling = false;
    });
    // Settle at the *end* of the curve (value: 1 → flat, camera-facing
    // cube), not the start (value: 0 → tilted by the fractional part
    // of this roll's _spinsX/_spinsY). This was the actual bug behind
    // the persistent "thin diagonal line" at rest.
    _tumbleController.value = 1.0;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    final bool canRoll =
        provider.isInitialized && provider.phase == GamePhase.rollPhase && !_isRolling;

    final Color accent =
        provider.isInitialized ? provider.currentPlayer.color.displayColor : AppColors.disabled;

    return GestureDetector(
      onTap: () => _handleTap(provider),
      child: AnimatedBuilder(
        animation: _tumbleController,
        builder: (context, child) {
          final t = _tumbleController.value;
          final settle = Curves.easeOutCubic.transform(t);
          final rotX = (1 - settle) * _spinsX * 2 * pi;
          final rotY = (1 - settle) * _spinsY * 2 * pi;
          final hop = sin(t * pi) * -14.h;

          return Transform.translate(
            offset: Offset(0, hop),
            child: AnimatedScale(
              scale: canRoll ? 1.0 : 0.94,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              child: _DiceCube3D(
                rotX: rotX,
                rotY: rotY,
                value: _displayValue,
                accent: accent,
                dimmed: !canRoll && !_isRolling,
                isRolling: _isRolling,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A real 6-faced cube, not a flat card. Each face is placed in 3D by
/// pushing it out from the center along its own normal and then
/// rotating it into position — the same construction used for CSS/GL
/// cubes. The whole stack of faces is then spun by the parent's
/// [rotX]/[rotY].
///
/// Because every face genuinely occupies its own plane in 3D space,
/// there's always a real, correctly-foreshortened face pointed roughly
/// at the camera. Faces are faded out via backface culling
/// (`facing <= 0`) as they turn away, so the transition between faces
/// is a smooth cross-fade rather than the old flat card collapsing to
/// an edge-on sliver mid-spin.
class _DiceCube3D extends StatefulWidget {
  final double rotX;
  final double rotY;
  final int value;
  final Color accent;
  final bool dimmed;
  final bool isRolling;

  const _DiceCube3D({
    required this.rotX,
    required this.rotY,
    required this.value,
    required this.accent,
    required this.dimmed,
    required this.isRolling,
  });

  @override
  State<_DiceCube3D> createState() => _DiceCube3DState();
}

class _DiceCube3DState extends State<_DiceCube3D> with SingleTickerProviderStateMixin {
  late final AnimationController _blurSpin;

  @override
  void initState() {
    super.initState();
    _blurSpin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..repeat();
  }

  @override
  void dispose() {
    _blurSpin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double s = 66.w;
    final double half = s / 2;

    // A real die: opposite faces always sum to 7. `value` is only
    // guaranteed correct on the face currently pointed at the camera
    // (the front face at rest) — the other five just need to be a
    // physically valid arrangement, since they're only ever glimpsed
    // in profile while spinning.
    final int v = widget.value.clamp(1, 6);
    final int back = 7 - v;
    final List<int> remaining = [1, 2, 3, 4, 5, 6]..remove(v)..remove(back);
    final int right = remaining[0];
    final int top = remaining[1];

    final List<_CubeFaceSpec> specs = [
      _CubeFaceSpec(pipValue: v, rotY: 0, rotX: 0),
      _CubeFaceSpec(pipValue: back, rotY: pi, rotX: 0),
      _CubeFaceSpec(pipValue: right, rotY: pi / 2, rotX: 0),
      _CubeFaceSpec(pipValue: 7 - right, rotY: -pi / 2, rotX: 0),
      _CubeFaceSpec(pipValue: top, rotY: 0, rotX: -pi / 2),
      _CubeFaceSpec(pipValue: 7 - top, rotY: 0, rotX: pi / 2),
    ];

    final Matrix4 outerRotation = Matrix4.identity()
      ..rotateX(widget.rotX)
      ..rotateY(widget.rotY);

    // For each face, rotate its outward normal by (face orientation,
    // then whole-cube spin) and keep only the z-component: that's how
    // much it currently points at the viewer. Sorting by this value
    // gives correct back-to-front paint order for free, and clamping
    // it to [0, 1] gives a clean backface-culled opacity.
    final List<_FaceRender> faces = specs.map((spec) {
      final Matrix4 faceRotation = Matrix4.identity()
        ..rotateY(spec.rotY)
        ..rotateX(spec.rotX);
      final Vector3 normal = outerRotation.multiplied(faceRotation).rotate3(Vector3(0, 0, 1));
      return _FaceRender(spec: spec, facing: normal.z);
    }).toList()
      ..sort((a, b) => a.facing.compareTo(b.facing));

    return Opacity(
      opacity: widget.dimmed ? 0.55 : 1.0,
      child: SizedBox(
        width: s,
        height: s,
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.003)
            ..rotateX(widget.rotX)
            ..rotateY(widget.rotY),
          child: Stack(
            children: faces
                .where((f) => f.facing > 0.02)
                .map((f) {
                  final double opacity = f.facing.clamp(0.0, 1.0);
                  return Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..rotateY(f.spec.rotY)
                      ..rotateX(f.spec.rotX)
                      ..translateByVector3(Vector3(0.0, 0.0, half)),
                    child: Opacity(
                      opacity: opacity,
                      child: _DiceFace(
                        value: f.spec.pipValue,
                        accent: widget.accent,
                        isRolling: widget.isRolling,
                        blurController: _blurSpin,
                        shade: 0.65 + 0.35 * opacity,
                        size: s,
                      ),
                    ),
                  );
                })
                .toList(),
          ),
        ),
      ),
    );
  }
}

class _CubeFaceSpec {
  final int pipValue;
  final double rotY;
  final double rotX;

  const _CubeFaceSpec({required this.pipValue, required this.rotY, required this.rotX});
}

class _FaceRender {
  final _CubeFaceSpec spec;
  final double facing;

  const _FaceRender({required this.spec, required this.facing});
}

/// One face of the cube: a raised, glossy card either showing the pip
/// layout for [value] or — while [isRolling] — a spinning blur so no
/// specific number is ever readable mid-roll.
class _DiceFace extends StatelessWidget {
  final int value;
  final Color accent;
  final bool isRolling;
  final AnimationController blurController;
  final double shade;
  final double size;

  const _DiceFace({
    required this.value,
    required this.accent,
    required this.isRolling,
    required this.blurController,
    required this.shade,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final Color topColor = Color.lerp(Colors.white, Colors.black, (1 - shade) * 0.45)!;
    final Color baseColor = Color.lerp(const Color(0xFFF3EFE2), Colors.black, (1 - shade) * 0.45)!;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: accent, width: 3.w),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [topColor, baseColor],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.32 * shade),
            blurRadius: 12.r,
            offset: Offset(3.w, 7.h),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Soft top-left sheen for extra glossiness.
          Positioned(
            left: 6.w,
            top: 6.h,
            right: size * 0.45,
            height: size * 0.28,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10.r),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.75 * shade),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          if (isRolling)
            _RollingBlur(controller: blurController, accent: accent)
          else
            _DicePips(value: value),
        ],
      ),
    );
  }
}

/// Shown instead of a pip face while the dice is mid-roll: a softly
/// spinning ring of dots with no fixed count and no readable number —
/// unambiguously "still deciding", never mistakable for a result.
class _RollingBlur extends StatelessWidget {
  final AnimationController controller;
  final Color accent;

  const _RollingBlur({required this.controller, required this.accent});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Padding(
          padding: EdgeInsets.all(10.w),
          child: Center(
            child: Transform.rotate(
              angle: controller.value * 2 * pi,
              child: Stack(
                alignment: Alignment.center,
                children: List.generate(6, (i) {
                  final angle = (2 * pi * i / 6);
                  final radius = 15.w;
                  final fade = (0.35 + 0.65 * ((i / 6 + controller.value) % 1.0));
                  return Transform.translate(
                    offset: Offset(cos(angle) * radius, sin(angle) * radius),
                    child: Container(
                      width: 7.w,
                      height: 7.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent.withValues(alpha: fade),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Draws a classic dice pip layout (1-6) on a 3x3 grid, no image assets
/// required, with each pip rendered as a tiny glossy sphere.
class _DicePips extends StatelessWidget {
  final int value;

  const _DicePips({required this.value});

  static const Map<int, List<List<int>>> _pipGrid = {
    1: [
      [1, 1]
    ],
    2: [
      [0, 0],
      [2, 2]
    ],
    3: [
      [0, 0],
      [1, 1],
      [2, 2]
    ],
    4: [
      [0, 0],
      [0, 2],
      [2, 0],
      [2, 2]
    ],
    5: [
      [0, 0],
      [0, 2],
      [1, 1],
      [2, 0],
      [2, 2]
    ],
    6: [
      [0, 0],
      [0, 2],
      [1, 0],
      [1, 2],
      [2, 0],
      [2, 2]
    ],
  };

  @override
  Widget build(BuildContext context) {
    final pips = _pipGrid[value] ?? _pipGrid[1]!;

    return Padding(
      padding: EdgeInsets.all(10.w),
      child: Column(
        children: List.generate(3, (row) {
          return Expanded(
            child: Row(
              children: List.generate(3, (col) {
                final bool hasPip = pips.any((p) => p[0] == row && p[1] == col);
                return Expanded(
                  child: Center(
                    child: hasPip
                        ? Container(
                            width: 11.w,
                            height: 11.w,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                center: const Alignment(-0.4, -0.5),
                                colors: [
                                  Color.lerp(AppColors.appBarText, Colors.white, 0.25)!,
                                  AppColors.appBarText,
                                ],
                              ),
                              boxShadow: const [
                                BoxShadow(color: Colors.black38, blurRadius: 1.5),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                );
              }),
            ),
          );
        }),
      ),
    );
  }
}
