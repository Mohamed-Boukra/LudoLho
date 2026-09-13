import '../constants/board_constants.dart';
import 'board_path.dart';
import 'player.dart';
import 'player_color.dart';
import 'token.dart';

/// Pure, UI-free rule functions: legal-move computation (Phase 5), and
/// safe cells / blocking / capturing (Phase 6). Kept separate from
/// [GameProvider] so every rule can be unit tested in isolation — see
/// test/game_rules_test.dart.
class GameRules {
  GameRules._();

  /// Returns the token's new step if moving by [diceValue] is legal in
  /// isolation (ignores blocking, which needs the full player list —
  /// see [legalMovesForPlayer]).
  ///
  /// Returns null if illegal:
  ///  - the token already finished,
  ///  - it's in the yard and [diceValue] isn't exactly 6,
  ///  - or the move would overshoot past the finish (exact-finish rule).
  static int? computeNewStep(Token token, int diceValue) {
    if (token.isFinished) return null;

    if (token.isInYard) {
      return diceValue == 6 ? 0 : null;
    }

    final newStep = token.step + diceValue;
    if (newStep > BoardPath.finishedStep) return null; // overshoot
    return newStep;
  }

  /// All of [player]'s tokens that can legally move given [diceValue],
  /// additionally factoring in blocking against [allPlayers].
  static List<Token> legalMovesForPlayer(
    Player player,
    int diceValue,
    List<Player> allPlayers, {
    bool enableBlocking = true,
  }) {
    var movable = <Token>[];

    for (final token in player.tokens) {
      final newStep = computeNewStep(token, diceValue);
      if (newStep == null) continue;

      if (enableBlocking && newStep >= 0 && newStep <= 50) {
        final cell = BoardPath.absolutePosition(token.color, newStep);
        if (cell != null &&
            isBlockedForOpponent(allPlayers, token.color, cell)) {
          continue;
        }
      }

      movable.add(token);
    }

    // Rule: No 6s in final stretch (step >= 39) if other tokens can move
    if (diceValue == 6) {
      final hasTokenBefore39 = movable.any((t) => t.step < 39);
      if (hasTokenBefore39) {
        movable = movable.where((t) => t.step < 39).toList();
      }
    }

    // Rule: Mandatory capture
    final capturingMoves = <Token>[];
    for (final token in movable) {
      final newStep = computeNewStep(token, diceValue);
      if (newStep != null && newStep >= 0 && newStep <= 50) {
        final cell = BoardPath.absolutePosition(token.color, newStep);
        if (cell != null) {
          final captured = captureOpponentsAt(allPlayers, token.color, cell, captureAll: true);
          if (captured.isNotEmpty) {
            capturingMoves.add(token);
          }
        }
      }
    }
    
    if (capturingMoves.isNotEmpty) {
      movable = capturingMoves;
    }

    return movable;
  }

  /// True if [cell] is one of the 8 safe cells (4 colored start cells +
  /// 4 star cells), where capturing never happens.
  static bool isSafeCell(List<int> cell) {
    bool matches(List<int> c) => c[0] == cell[0] && c[1] == cell[1];
    return BoardConstants.starCells.any(matches) ||
        BoardConstants.startCells.values.any(matches);
  }

  /// True if 2+ tokens of a single opponent color already occupy [cell]
  /// (a "block"), which [movingColor] may not land on.
  static bool isBlockedForOpponent(
    List<Player> allPlayers,
    PlayerColor movingColor,
    List<int> cell,
  ) {
    for (final player in allPlayers) {
      if (player.color == movingColor) continue;

      final count = player.tokens.where((t) {
        if (!t.isOnSharedPath) return false;
        final pos = BoardPath.absolutePosition(t.color, t.step);
        return pos != null && pos[0] == cell[0] && pos[1] == cell[1];
      }).length;

      if (count >= 2) return true;
    }
    return false;
  }

  /// The opponent token(s) captured if [movingColor] lands on [cell].
  /// Capturing only happens when exactly one opponent token sits there
  /// (a block of 2+ is immune) and [cell] isn't a safe cell.
  static List<Token> captureOpponentsAt(
    List<Player> allPlayers,
    PlayerColor movingColor,
    List<int> cell, {
    bool captureAll = false,
  }) {
    if (isSafeCell(cell)) return [];

    final captured = <Token>[];
    for (final player in allPlayers) {
      if (player.color == movingColor) continue;

      final atCell = player.tokens.where((t) {
        if (!t.isOnSharedPath) return false;
        final pos = BoardPath.absolutePosition(t.color, t.step);
        return pos != null && pos[0] == cell[0] && pos[1] == cell[1];
      }).toList();

      if (atCell.isNotEmpty) {
        if (captureAll) {
          captured.addAll(atCell);
        } else {
          captured.add(atCell.first);
        }
      }
    }
    return captured;
  }
}
