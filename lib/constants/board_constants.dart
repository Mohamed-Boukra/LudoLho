/// The Ludo board is always a 15x15 logical grid, regardless of the
/// screen's actual pixel size. Every widget divides the rendered board
/// size by [gridSize] to get a responsive cell size.
class BoardConstants {
  BoardConstants._();

  static const int gridSize = 15;

  /// The 8 safe (star) cells that are not a colored start cell.
  /// Stored as (row, col).
  static const List<List<int>> starCells = [
    [8, 2],
    [2, 6],
    [6, 12],
    [12, 8],
  ];

  /// Each color's colored starting cell on the shared path (also safe).
  static const Map<String, List<int>> startCells = {
    'red': [6, 1],
    'green': [1, 8],
    'blue': [8, 13],
    'yellow': [13, 6],
  };

  /// Each color's home-lane cells (the 5 colored cells leading into the
  /// center triangle, excluding the center itself). Stored as (row, col).
  static const Map<String, List<List<int>>> homeLaneCells = {
    'red': [
      [7, 1],
      [7, 2],
      [7, 3],
      [7, 4],
      [7, 5],
    ],
    'green': [
      [1, 7],
      [2, 7],
      [3, 7],
      [4, 7],
      [5, 7],
    ],
    'blue': [
      [7, 13],
      [7, 12],
      [7, 11],
      [7, 10],
      [7, 9],
    ],
    'yellow': [
      [13, 7],
      [12, 7],
      [11, 7],
      [10, 7],
      [9, 7],
    ],
  };

  /// Bounding box (rowStart, rowEnd, colStart, colEnd) of each yard,
  /// inclusive.
  static const Map<String, List<int>> yardBounds = {
    'red': [0, 5, 0, 5],
    'green': [0, 5, 9, 14],
    'blue': [9, 14, 9, 14],
    'yellow': [9, 14, 0, 5],
  };

  /// The 4 relative token slot positions inside a yard's inner square,
  /// as fractions (0-1) of the yard's inner box. Used to lay out the
  /// 4 dummy/real tokens neatly inside each yard.
  static const List<List<double>> yardTokenSlots = [
    [0.28, 0.28],
    [0.72, 0.28],
    [0.28, 0.72],
    [0.72, 0.72],
  ];

  /// The 52 shared/common path cells, in fixed clockwise board order,
  /// starting arbitrarily at [6, 0]. Every color's token travels through
  /// 51 of these (relative to its own entry point below) before turning
  /// off into its own colored home lane. Stored as (row, col).
  ///
  /// This list was constructed arm-by-arm around the board and cross-
  /// checked against [startCells] and [starCells] above — every start
  /// cell and star cell above lands exactly on the index you'd expect,
  /// which is what confirms the layout is self-consistent.
  static const List<List<int>> sharedPathRing = [
    [6, 0], [6, 1], [6, 2], [6, 3], [6, 4], [6, 5], // 0-5
    [5, 6], [4, 6], [3, 6], [2, 6], [1, 6], [0, 6], // 6-11
    [0, 7], // 12
    [0, 8], [1, 8], [2, 8], [3, 8], [4, 8], [5, 8], // 13-18
    [6, 9], [6, 10], [6, 11], [6, 12], [6, 13], [6, 14], // 19-24
    [7, 14], // 25
    [8, 14], [8, 13], [8, 12], [8, 11], [8, 10], [8, 9], // 26-31
    [9, 8], [10, 8], [11, 8], [12, 8], [13, 8], [14, 8], // 32-37
    [14, 7], // 38
    [14, 6], [13, 6], [12, 6], [11, 6], [10, 6], [9, 6], // 39-44
    [8, 5], [8, 4], [8, 3], [8, 2], [8, 1], [8, 0], // 45-50
    [7, 0], // 51
  ];

  /// The index into [sharedPathRing] where each color's token first
  /// enters the shared path — i.e. that color's colored, safe starting
  /// cell. Each is exactly 13 cells apart (52 / 4 players).
  static const Map<String, int> ringStartIndex = {
    'red': 1,
    'green': 14,
    'blue': 27,
    'yellow': 40,
  };
}
