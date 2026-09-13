import '../constants/board_constants.dart';
import 'player_color.dart';

/// Pure, UI-free math that converts a [Token]'s logical step count into
/// an absolute (row, col) cell on the 15x15 board grid.
///
/// This is deliberately isolated from every widget so it can be unit
/// tested on its own — see test/board_path_test.dart. Nothing in this
/// file imports `package:flutter/material.dart` or touches a Canvas;
/// it only does integer/list math against [BoardConstants].
class BoardPath {
  BoardPath._();

  /// Number of steps a token spends on the shared 52-cell ring before
  /// turning into its own color's home lane (relative steps 0-50).
  static const int sharedPathSteps = 51;

  /// Number of cells in each color's colored home lane (relative steps
  /// 51-55).
  static const int homeLaneSteps = 5;

  /// The step value that means "finished" (reached the center).
  static const int finishedStep = sharedPathSteps + homeLaneSteps; // 56

  /// Converts [step] (relative to [color]) into an absolute (row, col)
  /// grid cell, or `null` if the token is in its yard (step < 0) or has
  /// already finished (step >= [finishedStep]) — both of those are
  /// rendered specially by the UI rather than as a single path cell.
  static List<int>? absolutePosition(PlayerColor color, int step) {
    if (step < 0 || step >= finishedStep) return null;

    if (step < sharedPathSteps) {
      final ring = BoardConstants.sharedPathRing;
      final startIndex = BoardConstants.ringStartIndex[color.key]!;
      final ringIndex = (startIndex + step) % ring.length;
      return ring[ringIndex];
    }

    final laneIndex = step - sharedPathSteps; // 0..4
    return BoardConstants.homeLaneCells[color.key]![laneIndex];
  }
}
