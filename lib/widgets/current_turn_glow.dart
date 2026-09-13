import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A pulsing, rotating colored outline drawn over the current player's
/// yard, so it's always obvious whose turn it is just by glancing at
/// the board — animated with both a soft pulse and a slowly sweeping
/// conic highlight for a premium "spotlight" feel.
class CurrentTurnGlow extends StatefulWidget {
  final Color color;
  final Rect rect;

  const CurrentTurnGlow({super.key, required this.color, required this.rect});

  @override
  State<CurrentTurnGlow> createState() => _CurrentTurnGlowState();
}

class _CurrentTurnGlowState extends State<CurrentTurnGlow> with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _sweepController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _sweepController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fromRect(
      rect: widget.rect,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: Listenable.merge([_pulseController, _sweepController]),
          builder: (context, child) {
            final double t = _pulseController.value;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(widget.rect.width * 0.12),
                    border: Border.all(
                      color: widget.color.withValues(alpha: 0.35 + 0.5 * t),
                      width: 3 + 2 * t,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.35 * t),
                        blurRadius: 14 * t + 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(widget.rect.width * 0.12),
                    child: Transform.rotate(
                      angle: _sweepController.value * 2 * math.pi,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: SweepGradient(
                            colors: [
                              Colors.transparent,
                              widget.color.withValues(alpha: 0.22),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.15, 0.32],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
