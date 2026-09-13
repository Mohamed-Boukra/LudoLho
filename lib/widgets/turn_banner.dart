import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ludo_game/models/player_color.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../providers/game_provider.dart';

/// "Whose turn is it" banner — a glassy, color-tinted pill that slides
/// and cross-fades in whenever the active player or phase changes,
/// with a small pulsing dot that mirrors [DiceWidget]'s roll/move state.
class TurnBanner extends StatelessWidget {
  const TurnBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();

    if (!provider.isInitialized) {
      return SizedBox(height: 40.h);
    }

    final color = provider.currentPlayer.color;
    final name = provider.currentPlayer.name;
    final timeLeft = provider.turnTimeLeft;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      transitionBuilder: (child, animation) {
        final slide = Tween<Offset>(
          begin: const Offset(0, -0.35),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: slide, child: child),
        );
      },
      child: Container(
        key: ValueKey('${color.key}_${name}_$timeLeft'),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28.r),
          gradient: LinearGradient(
            colors: [
              color.displayColor.withValues(alpha: 0.16),
              color.displayColor.withValues(alpha: 0.05),
            ],
          ),
          border: Border.all(color: color.displayColor.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
              color: color.displayColor.withValues(alpha: 0.18),
              blurRadius: 10.r,
              offset: Offset(0, 3.h),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PulsingDot(color: color.displayColor),
            SizedBox(width: 8.w),
            Flexible(
              child: Text(
                "${name}'s turn${timeLeft > 0 ? ' • $timeLeft s' : ''}",
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.appBarText,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return Container(
          width: 12.w,
          height: 12.w,
          decoration: BoxDecoration(
            gradient: AppColors.glossSphere(
              widget.color,
              Color.lerp(widget.color, Colors.black, 0.4)!,
            ),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.4.w),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.5 + 0.3 * t),
                blurRadius: 3 + 4 * t,
              ),
            ],
          ),
        );
      },
    );
  }
}
