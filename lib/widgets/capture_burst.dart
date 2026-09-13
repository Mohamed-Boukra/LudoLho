import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// A one-shot ring + spark burst played at the cell where a capture
/// just happened — purely decorative, removes itself via [onDone]
/// once the animation finishes.
class CaptureBurst extends StatefulWidget {
  final double size;
  final VoidCallback onDone;

  const CaptureBurst({super.key, required this.size, required this.onDone});

  @override
  State<CaptureBurst> createState() => _CaptureBurstState();
}

class _CaptureBurstState extends State<CaptureBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    )..forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onDone();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          final ringScale = 0.3 + t * 1.6;
          final ringOpacity = (1 - t).clamp(0.0, 1.0);

          return SizedBox(
            width: widget.size,
            height: widget.size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Transform.scale(
                  scale: ringScale,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: ringOpacity),
                        width: 2.5,
                      ),
                    ),
                  ),
                ),
                Opacity(
                  opacity: (1 - t * 1.4).clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: 0.5 + t * 0.5,
                    child: Container(
                      width: widget.size * 0.32,
                      height: widget.size * 0.32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.9),
                            AppColors.gold.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
