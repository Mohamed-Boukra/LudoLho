import 'player_color.dart';

/// A single game piece belonging to a [Player].
///
/// Position is stored as a single logical [step] integer rather than a
/// (row, col) pair — that keeps this model completely independent of
/// board rendering. [BoardPath.absolutePosition] converts a step into
/// an actual grid cell only when something needs to draw it.
///
/// Step meaning (relative to this token's own color):
///  -1        -> sitting in its yard, not yet entered the board
///  0  .. 50  -> on the 51-cell shared path
///  51 .. 55  -> in this color's 5-cell colored home lane
///  56        -> finished (reached the center)
class Token {
  final PlayerColor color;

  /// Which of the player's 4 tokens this is (0-3). Combined with
  /// [color] this forms a stable identity even though [step] changes.
  final int slot;

  int step;

  Token({required this.color, required this.slot}) : step = -1;

  String get id => '${color.key}_$slot';

  bool get isInYard => step == -1;
  bool get isOnSharedPath => step >= 0 && step <= 50;
  bool get isInHomeLane => step >= 51 && step <= 55;
  bool get isFinished => step == 56;

  @override
  String toString() => 'Token($id, step=$step)';
}
