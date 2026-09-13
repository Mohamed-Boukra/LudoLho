import 'dart:math';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../models/player_color.dart';
import '../providers/game_provider.dart';
import '../utils/page_transitions.dart';
import 'setup_screen.dart';
import 'start_screen.dart';

/// Shown once [GameProvider.phase] reaches [GamePhase.gameOver]: a
/// podium-style celebration with confetti, then full final standings.
class GameOverScreen extends StatefulWidget {
  const GameOverScreen({super.key});

  @override
  State<GameOverScreen> createState() => _GameOverScreenState();
}

class _GameOverScreenState extends State<GameOverScreen> {
  late final ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _confettiController.play();
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  List<PlayerColor> _finalStandings(GameProvider provider) {
    final players = List.of(provider.players);
    players.sort((a, b) {
      if (a.score != b.score) {
        return b.score.compareTo(a.score);
      }
      final aFinishIndex = provider.finishOrder.indexOf(a.color);
      final bFinishIndex = provider.finishOrder.indexOf(b.color);
      
      final aIndex = aFinishIndex == -1 ? 999 : aFinishIndex;
      final bIndex = bFinishIndex == -1 ? 999 : bFinishIndex;
      
      return aIndex.compareTo(bIndex);
    });
    return players.map((p) => p.color).toList();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    final standings = provider.isInitialized ? _finalStandings(provider) : <PlayerColor>[];
    final winner = standings.isNotEmpty ? standings.first : null;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: AppColors.menuGradient,
          ),
        ),
        child: SafeArea(
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 26.w, vertical: 16.h),
                child: Column(
                  children: [
                    SizedBox(height: 8.h),
                    if (winner != null) _Trophy(color: winner.displayColor),
                    SizedBox(height: 10.h),
                    Text(
                      'GAME OVER',
                      style: TextStyle(
                        fontSize: 24.sp,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                        color: Colors.white,
                      ),
                    ).animate().fadeIn(duration: 400.ms),
                    SizedBox(height: 6.h),
                    if (winner != null)
                      ShaderMask(
                        shaderCallback: (rect) => LinearGradient(
                          colors: [Colors.white, winner.displayColor],
                        ).createShader(rect),
                        child: Text(
                          '${provider.players.firstWhere((p) => p.color == winner).name} wins!',
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ).animate().fadeIn(delay: 150.ms, duration: 400.ms),
                    SizedBox(height: 22.h),
                    if (standings.length >= 3) _Podium(standings: standings),
                    SizedBox(height: 18.h),
                    Expanded(
                      child: standings.isEmpty
                          ? const SizedBox.shrink()
                          : ListView.separated(
                              itemCount: standings.length,
                              separatorBuilder: (_, __) => SizedBox(height: 10.h),
                              itemBuilder: (context, index) {
                                return _StandingRow(rank: index + 1, color: standings[index])
                                    .animate()
                                    .fadeIn(delay: (400 + index * 90).ms, duration: 350.ms)
                                    .slideX(begin: 0.06, end: 0);
                              },
                            ),
                    ),
                    SizedBox(height: 12.h),
                    SizedBox(
                      width: double.infinity,
                      height: 54.h,
                      child: _GradientButton(
                        label: 'PLAY AGAIN',
                        colors: const [AppColors.redLight, AppColors.red, AppColors.redDark],
                        onTap: () {
                          Navigator.of(context).pushAndRemoveUntil(
                            FadeScaleRoute(page: const SetupScreen()),
                            (route) => false,
                          );
                        },
                      ),
                    ),
                    SizedBox(height: 10.h),
                    SizedBox(
                      width: double.infinity,
                      height: 48.h,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(context).pushAndRemoveUntil(
                            FadeScaleRoute(page: const StartScreen()),
                            (route) => false,
                          );
                        },
                        child: Text(
                          'BACK TO MENU',
                          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ConfettiWidget(
                confettiController: _confettiController,
                blastDirection: pi / 2,
                maxBlastForce: 20,
                minBlastForce: 8,
                emissionFrequency: 0.04,
                numberOfParticles: 26,
                gravity: 0.25,
                shouldLoop: false,
                colors: const [AppColors.red, AppColors.green, AppColors.yellow, AppColors.blue, AppColors.gold],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Trophy extends StatelessWidget {
  final Color color;
  const _Trophy({required this.color});

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.emoji_events_rounded, size: 72.sp, color: AppColors.gold)
        .animate()
        .scale(
          begin: const Offset(0.3, 0.3),
          end: const Offset(1.0, 1.0),
          curve: Curves.elasticOut,
          duration: 900.ms,
        )
        .then()
        .shimmer(duration: 1200.ms, color: Colors.white.withValues(alpha: 0.6));
  }
}

class _Podium extends StatelessWidget {
  final List<PlayerColor> standings;
  const _Podium({required this.standings});

  @override
  Widget build(BuildContext context) {
    Widget stand(int rank, double height, {double delay = 0}) {
      if (rank > standings.length) return const Spacer();
      final color = standings[rank - 1];
      return Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              width: 34.w,
              height: 34.w,
              margin: EdgeInsets.only(bottom: 6.h),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.glossSphere(
                  color.displayColor,
                  AppColors.darkFromKey(color.key),
                ),
                border: Border.all(color: Colors.white, width: 2.w),
              ),
            ),
            Container(
              height: height,
              margin: EdgeInsets.symmetric(horizontal: 4.w),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(10.r)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.gold.withValues(alpha: 0.9), AppColors.gold.withValues(alpha: 0.5)],
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                '#$rank',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16.sp, color: AppColors.appBarText),
              ),
            ),
          ],
        ).animate().fadeIn(delay: delay.ms).slideY(begin: 0.4, end: 0, curve: Curves.easeOutBack),
      );
    }

    return SizedBox(
      height: 130.h,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          stand(2, 70.h, delay: 250),
          stand(1, 96.h, delay: 100),
          stand(3, 52.h, delay: 350),
        ],
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String label;
  final List<Color> colors;
  final VoidCallback onTap;
  const _GradientButton({required this.label, required this.colors, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14.r),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14.r),
            gradient: LinearGradient(colors: colors),
            boxShadow: [
              BoxShadow(color: colors[1].withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(0, 6)),
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StandingRow extends StatelessWidget {
  final int rank;
  final PlayerColor color;

  const _StandingRow({required this.rank, required this.color});

  String get _medal {
    switch (rank) {
      case 1:
        return '🥇';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return '#$rank';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          SizedBox(width: 32.w, child: Text(_medal, style: TextStyle(fontSize: 16.sp))),
          Container(
            width: 22.w,
            height: 22.w,
            margin: EdgeInsets.only(right: 12.w),
            decoration: BoxDecoration(
              gradient: AppColors.glossSphere(color.displayColor, AppColors.darkFromKey(color.key)),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.w),
            ),
          ),
          Text(
            context.read<GameProvider>().players.firstWhere((p) => p.color == color).name,
            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          const Spacer(),
          Text(
            'Score: ${context.read<GameProvider>().players.firstWhere((p) => p.color == color).score}',
            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: AppColors.redLight),
          ),
        ],
      ),
    );
  }
}
