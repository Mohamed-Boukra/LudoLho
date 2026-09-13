import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ludo_game/models/player_color.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../constants/board_constants.dart';
import '../models/board_path.dart';
import '../models/token.dart';
import '../providers/game_provider.dart';
import 'board_painter.dart';
import 'capture_burst.dart';
import 'current_turn_glow.dart';
import 'movable_token.dart';

/// Renders the full Ludo board in a lightly-tilted 3D perspective: a
/// real, wooden-table backdrop, a raised board with drop shadow, and
/// every token positioned according to [GameProvider]'s state.
///
/// Tokens that can legally move pulse and are tappable; tapping one
/// calls [GameProvider.moveToken], which animates it cell by cell and
/// resolves captures/blocking. If no match has been initialized yet,
/// this falls back to 4 static dummy tokens per color.
class LudoBoard extends StatefulWidget {
  /// How strongly the board is tilted for the 3D look, in radians.
  /// 0 = perfectly flat/top-down. Kept modest so hit-testing near the
  /// far edge stays comfortable to tap.
  final double tilt;

  const LudoBoard({super.key, this.tilt = 0.32});

  @override
  State<LudoBoard> createState() => _LudoBoardState();
}

class _LudoBoardState extends State<LudoBoard> with SingleTickerProviderStateMixin {
  late final AnimationController _glowController;
  int _lastSeenCaptureEventId = 0;
  final List<_ActiveBurst> _bursts = [];

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  Matrix4 _perspective(double tilt) {
    return Matrix4.identity()
      ..setEntry(3, 2, 0.0016)
      ..rotateX(tilt);
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = context.watch<GameProvider>();

    if (gameProvider.isInitialized &&
        gameProvider.captureEventId != _lastSeenCaptureEventId &&
        gameProvider.lastCaptureCell != null) {
      _lastSeenCaptureEventId = gameProvider.captureEventId;
      final burst = _ActiveBurst(id: _lastSeenCaptureEventId, cell: gameProvider.lastCaptureCell!);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _bursts.add(burst));
      });
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double size = constraints.biggest.shortestSide;
        final double cellSize = size / BoardConstants.gridSize;

        final board = Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.boardBackground,
            border: Border.all(color: AppColors.boardOuterBorder, width: 3.w),
            borderRadius: BorderRadius.circular(size * 0.035),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: size * 0.06,
                offset: Offset(0, size * 0.035),
              ),
              BoxShadow(
                color: AppColors.gold.withValues(alpha: 0.06),
                blurRadius: size * 0.12,
                spreadRadius: size * 0.01,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              AnimatedBuilder(
                animation: _glowController,
                builder: (context, _) => CustomPaint(
                  size: Size(size, size),
                  painter: BoardPainter(
                    cellSize: cellSize,
                    glowT: _glowController.value,
                  ),
                ),
              ),
              if (gameProvider.isInitialized)
                CurrentTurnGlow(
                  key: ValueKey('glow_${gameProvider.currentPlayer.color.key}'),
                  color: gameProvider.currentPlayer.color.displayColor,
                  rect: _yardRect(gameProvider.currentPlayer.color.key, cellSize),
                ),
              if (gameProvider.isInitialized)
                ..._buildStateTokens(context, gameProvider, cellSize)
              else
                ..._buildDummyTokens(cellSize),
              for (final burst in _bursts)
                Positioned(
                  left: burst.cell[1] * cellSize + cellSize / 2 - cellSize,
                  top: burst.cell[0] * cellSize + cellSize / 2 - cellSize,
                  width: cellSize * 2,
                  height: cellSize * 2,
                  child: CaptureBurst(
                    key: ValueKey('burst_${burst.id}'),
                    size: cellSize * 2,
                    onDone: () {
                      if (!mounted) return;
                      setState(() => _bursts.removeWhere((b) => b.id == burst.id));
                    },
                  ),
                ),
            ],
          ),
        );

        return Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.85, end: 1.0),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutBack,
            builder: (context, entrance, child) {
              return Transform(
                alignment: Alignment.center,
                transform: _perspective(widget.tilt * entrance.clamp(0.0, 1.0)),
                child: Opacity(
                  opacity: entrance.clamp(0.0, 1.0),
                  child: child,
                ),
              );
            },
            child: board,
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------
  // Real tokens, driven by GameProvider + BoardPath + GameRules
  // ---------------------------------------------------------------------
  List<Widget> _buildStateTokens(
    BuildContext context,
    GameProvider provider,
    double cellSize,
  ) {
    final tokens = <Widget>[];
    final double tokenSize = cellSize * 1.32;
    final Set<String> movableIds = provider.movableTokenIds;

    // Group tokens sharing a cell so we can fan them out slightly —
    // otherwise stacked tokens on the same path cell hide each other.
    final Map<String, List<Token>> byCell = {};
    for (final player in provider.players) {
      for (final token in player.tokens) {
        final key = _cellKey(token);
        byCell.putIfAbsent(key, () => []).add(token);
      }
    }

    for (final entry in byCell.entries) {
      final group = entry.value;
      for (int i = 0; i < group.length; i++) {
        final token = group[i];
        final Offset base = _tokenCenter(token, cellSize);
        final Offset fanOffset = group.length > 1
            ? _fanOffset(i, group.length, cellSize)
            : Offset.zero;
        final Offset center = base + fanOffset;
        final bool isMovable = movableIds.contains(token.id);

        tokens.add(
          AnimatedPositioned(
            key: ValueKey(token.id),
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeInOutCubic,
            left: center.dx - tokenSize / 2,
            top: center.dy - tokenSize / 2,
            width: tokenSize,
            height: tokenSize,
            child: MovableToken(
              token: token,
              color: token.color.displayColor,
              isMovable: isMovable,
              onTap: () => context.read<GameProvider>().moveToken(token),
            ),
          ),
        );
      }
    }
    return tokens;
  }

  String _cellKey(Token token) {
    if (token.isInYard) return 'yard_${token.color.key}_${token.slot}';
    if (token.isFinished) return 'finished_${token.color.key}';
    if (token.isOnSharedPath) {
      // Group by the actual board square, not by color+step — two
      // different colors can legally share a safe/star cell, and they
      // need to be fanned apart just like same-color stacks are, or
      // one ends up rendered exactly on top of the other and silently
      // eats taps meant for the token underneath it.
      final pos = BoardPath.absolutePosition(token.color, token.step)!;
      return 'cell_${pos[0]}_${pos[1]}';
    }
    // Home-lane cells are only ever occupied by one color, so keying
    // by color+step is fine here.
    return 'lane_${token.color.key}_${token.step}';
  }

  Offset _fanOffset(int index, int total, double cellSize) {
    final double radius = cellSize * 0.16;
    final double angle = (2 * math.pi * index / total) - math.pi / 2;
    return Offset(math.cos(angle) * radius, math.sin(angle) * radius);
  }

  Offset _tokenCenter(Token token, double cellSize) {
    if (token.isInYard) {
      return _yardSlotCenter(token.color.key, token.slot, cellSize);
    }
    if (token.isFinished) {
      return _boardCenter(cellSize);
    }
    final pos = BoardPath.absolutePosition(token.color, token.step)!;
    return Offset(
      pos[1] * cellSize + cellSize / 2,
      pos[0] * cellSize + cellSize / 2,
    );
  }

  // ---------------------------------------------------------------------
  // Dummy tokens — fallback when no match has been initialized yet
  // ---------------------------------------------------------------------
  List<Widget> _buildDummyTokens(double cellSize) {
    final tokens = <Widget>[];
    final double tokenSize = cellSize * 1.32;

    for (final colorKey in BoardConstants.yardBounds.keys) {
      for (int slot = 0; slot < 4; slot++) {
        final center = _yardSlotCenter(colorKey, slot, cellSize);
        tokens.add(
          Positioned(
            left: center.dx - tokenSize / 2,
            top: center.dy - tokenSize / 2,
            width: tokenSize,
            height: tokenSize,
            child: _StaticToken(color: AppColors.fromKey(colorKey)),
          ),
        );
      }
    }
    return tokens;
  }

  // ---------------------------------------------------------------------
  // Shared geometry helpers
  // ---------------------------------------------------------------------
  Offset _yardSlotCenter(String colorKey, int slot, double cellSize) {
    final bounds = BoardConstants.yardBounds[colorKey]!;
    final rowStart = bounds[0];
    final colStart = bounds[2];
    final colEnd = bounds[3];
    final rowEnd = bounds[1];

    final double yardLeft = colStart * cellSize;
    final double yardTop = rowStart * cellSize;
    final double yardWidth = (colEnd - colStart + 1) * cellSize;
    final double yardHeight = (rowEnd - rowStart + 1) * cellSize;

    final fractional = BoardConstants.yardTokenSlots[slot];
    return Offset(
      yardLeft + fractional[0] * yardWidth,
      yardTop + fractional[1] * yardHeight,
    );
  }

  Rect _yardRect(String colorKey, double cellSize) {
    final bounds = BoardConstants.yardBounds[colorKey]!;
    final rowStart = bounds[0];
    final colStart = bounds[2];
    final colEnd = bounds[3];
    final rowEnd = bounds[1];

    return Rect.fromLTWH(
      colStart * cellSize,
      rowStart * cellSize,
      (colEnd - colStart + 1) * cellSize,
      (rowEnd - rowStart + 1) * cellSize,
    );
  }

  Offset _boardCenter(double cellSize) {
    final double left = 6 * cellSize;
    final double top = 6 * cellSize;
    final double extent = 3 * cellSize;
    return Offset(left + extent / 2, top + extent / 2);
  }
}

/// A plain, non-interactive token used only for the dummy/fallback
/// display before a match has been initialized.
class _StaticToken extends StatelessWidget {
  final Color color;

  const _StaticToken({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.glossSphere(color, Color.lerp(color, Colors.black, 0.35)!),
        border: Border.all(color: Colors.white, width: 2.w),
        boxShadow: [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 3.r,
            offset: Offset(0, 2.h),
          ),
        ],
      ),
      child: FractionallySizedBox(
        widthFactor: 0.38,
        heightFactor: 0.38,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}

/// A capture burst currently animating on the board, keyed by the
/// provider's capture event id so simultaneous/rapid captures never
/// collide.
class _ActiveBurst {
  final int id;
  final List<int> cell;
  _ActiveBurst({required this.id, required this.cell});
}
