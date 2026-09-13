import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../models/game_phase.dart';
import '../models/player_color.dart';
import '../providers/game_provider.dart';
import '../utils/page_transitions.dart';
import '../widgets/dice_widget.dart';
import '../widgets/ludo_board.dart';
import 'game_over_screen.dart';

/// The main gameplay screen: turn banner, the 3D board, and the dice —
/// laid out over a dark felt-table backdrop for a premium, tactile feel.
///
/// Either pass [colors] to start a fresh match (from [SetupScreen]), or
/// set [resume] to true to load a saved match instead. If neither is
/// given (e.g. hot-reload during development), falls back to a default
/// 4-player match so the screen is never left blank.
class GameScreen extends StatefulWidget {
  final List<PlayerColor>? colors;
  final bool resume;

  const GameScreen({super.key, this.colors, this.resume = false});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  int _lastShownCaptureEventId = 0;
  int _lastShownTurnEventId = 0;
  bool _navigatedToGameOver = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<GameProvider>();
      if (provider.isInitialized) return;

      if (widget.resume) {
        final restored = await provider.restoreSavedMatch();
        if (restored) return;
      }
      provider.initGame(
        widget.colors ??
            const [
              PlayerColor.red,
              PlayerColor.green,
              PlayerColor.yellow,
              PlayerColor.blue,
            ],
      );
    });
  }

  void _maybeShowEventSnackBars(GameProvider provider) {
    if (!provider.isInitialized) return;

    String? message;
    bool isCapture = false;
    if (provider.captureEventId != _lastShownCaptureEventId) {
      _lastShownCaptureEventId = provider.captureEventId;
      message = provider.lastCaptureMessage;
      isCapture = true;
    }
    
    if (message == null) return;

    if (isCapture) _buzz();

    final toShow = message;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            // The theme is Brightness.dark, so Material3's default
            // SnackBar text color (colorScheme.onInverseSurface) is
            // dark — meant for a light background. We override the
            // background to a dark color below, so the text color
            // must be overridden too, or it's dark-on-dark and
            // unreadable.
            content: Text(
              toShow,
              style: TextStyle(
                color: AppColors.scaffoldBackground,
                fontWeight: FontWeight.w600,
              ),
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.appBarText,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
          ),
        );
    });
  }

  Future<void> _buzz() async {
    try {
      // flutter/services' HapticFeedback is built into the SDK (no
      // extra plugin needed, so nothing to configure per-platform) —
      // mediumImpact gives a satisfying, distinct "thud" for a capture.
      await HapticFeedback.mediumImpact();
    } catch (_) {
      // Haptics are a nice-to-have; never let a failure affect gameplay.
    }
  }

  void _maybeNavigateToGameOver(GameProvider provider) {
    if (!provider.isInitialized) return;
    if (provider.phase != GamePhase.gameOver) return;
    if (_navigatedToGameOver) return;

    _navigatedToGameOver = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        FadeScaleRoute(page: const GameOverScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    _maybeShowEventSnackBars(provider);
    _maybeNavigateToGameOver(provider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(
          'Ludo',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20.sp, letterSpacing: 1.2),
        ),
        actions: [
          IconButton(
            tooltip: 'Statistics',
            icon: const Icon(Icons.bar_chart),
            onPressed: provider.isInitialized ? () => _showStatsDialog(context, provider) : null,
          ),
          IconButton(
            tooltip: provider.isMuted ? 'Unmute' : 'Mute',
            icon: Icon(provider.isMuted ? Icons.volume_off : Icons.volume_up),
            onPressed: provider.isInitialized ? provider.toggleMute : null,
          ),
          SizedBox(width: 4.w),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.3),
            radius: 1.4,
            colors: [Color(0xFF1B5B49), Color(0xFF0B2A21)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(10.w),
            child: Column(
              children: [
                SizedBox(height: kToolbarHeight - 30.h),
                const _LiveRankBar(),
                SizedBox(height: 10.h),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final double maxSize =
                          constraints.maxWidth < constraints.maxHeight
                              ? constraints.maxWidth
                              : constraints.maxHeight;
                      final double boardSize = maxSize * 0.94;

                      return SizedBox(
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: boardSize,
                              height: boardSize,
                              child: const LudoBoard(),
                            ),
                            if (provider.isInitialized)
                              _ActivePlayerOverlay(
                                boardSize: boardSize,
                                maxWidth: constraints.maxWidth,
                                maxHeight: constraints.maxHeight,
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(height: 12.h),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LiveRankBar extends StatelessWidget {
  const _LiveRankBar();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    if (!provider.isInitialized) return const SizedBox.shrink();

    final players = List.of(provider.players);
    players.sort((a, b) => b.score.compareTo(a.score));

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: players.map((p) {
        return Container(
          margin: EdgeInsets.symmetric(horizontal: 4.w),
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: p.color.displayColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: p.color.displayColor.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Container(
                width: 10.w,
                height: 10.w,
                decoration: BoxDecoration(
                  color: p.color.displayColor,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 4.w),
              Text(
                '${p.score}',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12.sp,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

void _showStatsDialog(BuildContext context, GameProvider provider) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: AppColors.scaffoldBackground,
        title: Text(
          'Dice Statistics',
          style: TextStyle(color: AppColors.appBarText, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: provider.players.map((p) {
              return Padding(
                padding: EdgeInsets.only(bottom: 12.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 12.w,
                          height: 12.w,
                          decoration: BoxDecoration(color: p.color.displayColor, shape: BoxShape.circle),
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          p.name,
                          style: TextStyle(color: p.color.displayColor, fontWeight: FontWeight.bold, fontSize: 14.sp),
                        ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(6, (i) {
                        return Container(
                          width: 36.w,
                          padding: EdgeInsets.symmetric(vertical: 6.h),
                          decoration: BoxDecoration(
                            color: p.color.displayColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8.r),
                            border: Border.all(color: p.color.displayColor.withValues(alpha: 0.4)),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '⚀⚁⚂⚃⚄⚅'[i],
                                style: TextStyle(
                                  color: p.color.displayColor,
                                  fontSize: 18.sp,
                                  height: 1.0,
                                ),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                '${p.diceStats[i]}',
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CLOSE', style: TextStyle(color: AppColors.redLight)),
          ),
        ],
      );
    },
  );
}

class _ActivePlayerOverlay extends StatelessWidget {
  final double boardSize;
  final double maxWidth;
  final double maxHeight;
  const _ActivePlayerOverlay({
    required this.boardSize,
    required this.maxWidth,
    required this.maxHeight,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    if (!provider.isInitialized) return const SizedBox.shrink();

    final currentPlayer = provider.currentPlayer;
    final colorKey = currentPlayer.color.key;
    final timeLeft = provider.turnTimeLeft;

    final double verticalMargin = (maxHeight - boardSize) / 2;
    final double horizontalMargin = (maxWidth - boardSize) / 2;

    // Push the overlay completely above or below the board
    final double bottomForTopPlayers = verticalMargin + boardSize + 10;
    // For bottom players: just below the board but not off-screen
    final double bottomForBottomPlayers = (verticalMargin - 110.0).clamp(0.0, double.infinity);
    final double sideOffsetAmount = horizontalMargin - 10;

    double? top;
    double? left;
    double? bottom;
    double? right;

    switch (colorKey) {
      case 'red':
        bottom = bottomForTopPlayers;
        left = sideOffsetAmount;
        break;
      case 'green':
        bottom = bottomForTopPlayers;
        right = sideOffsetAmount;
        break;
      case 'blue':
        bottom = bottomForBottomPlayers;
        right = sideOffsetAmount;
        break;
      case 'yellow':
        bottom = bottomForBottomPlayers;
        left = sideOffsetAmount;
        break;
    }

    // Whether the player is on the bottom (blue, yellow) or top (red, green)
    final isTop = (colorKey == 'red' || colorKey == 'green');

    final nameAndTimer = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          currentPlayer.name,
          style: TextStyle(
            color: currentPlayer.color.displayColor,
            fontWeight: FontWeight.bold,
            fontSize: 16.sp,
          ),
        ),
        Text(
          '${timeLeft}s',
          style: TextStyle(
            color: timeLeft <= 5 ? Colors.redAccent : Colors.white70,
            fontWeight: FontWeight.bold,
            fontSize: 14.sp,
          ),
        ),
      ],
    );

    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: IgnorePointer(
        ignoring: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: isTop 
            ? [
                nameAndTimer,
                SizedBox(height: 8.h),
                const SizedBox(width: 80, height: 80, child: DiceWidget()),
              ]
            : [
                const SizedBox(width: 80, height: 80, child: DiceWidget()),
                SizedBox(height: 8.h),
                nameAndTimer,
              ],
        ),
      ),
    );
  }
}
