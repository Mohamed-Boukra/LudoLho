import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_game/models/board_path.dart';
import 'package:ludo_game/models/player_color.dart';

void main() {
  group('BoardPath.absolutePosition', () {
    test('yard (-1) and finished (56) steps have no single cell', () {
      expect(BoardPath.absolutePosition(PlayerColor.red, -1), isNull);
      expect(BoardPath.absolutePosition(PlayerColor.red, 56), isNull);
    });

    test('each color starts on its own colored, safe start cell', () {
      expect(BoardPath.absolutePosition(PlayerColor.red, 0), [6, 1]);
      expect(BoardPath.absolutePosition(PlayerColor.green, 0), [1, 8]);
      expect(BoardPath.absolutePosition(PlayerColor.blue, 0), [8, 13]);
      expect(BoardPath.absolutePosition(PlayerColor.yellow, 0), [13, 6]);
    });

    test('red walks the shared ring correctly step by step', () {
      expect(BoardPath.absolutePosition(PlayerColor.red, 1), [6, 2]);
      expect(BoardPath.absolutePosition(PlayerColor.red, 5), [5, 6]);
      // Step 50 is the last shared-path step, just before turning home.
      expect(BoardPath.absolutePosition(PlayerColor.red, 50), [7, 0]);
    });

    test('home lane steps (51-55) map to that color\'s colored lane', () {
      expect(BoardPath.absolutePosition(PlayerColor.red, 51), [7, 1]);
      expect(BoardPath.absolutePosition(PlayerColor.red, 55), [7, 5]);
      expect(BoardPath.absolutePosition(PlayerColor.yellow, 51), [13, 7]);
      expect(BoardPath.absolutePosition(PlayerColor.yellow, 55), [9, 7]);
    });

    test('a full lap (51 steps) never revisits a start cell twice', () {
      final visited = <String>{};
      for (int step = 0; step < BoardPath.sharedPathSteps; step++) {
        final pos = BoardPath.absolutePosition(PlayerColor.green, step)!;
        final key = '${pos[0]},${pos[1]}';
        expect(visited.contains(key), isFalse,
            reason: 'cell $key visited twice at step $step');
        visited.add(key);
      }
      expect(visited.length, BoardPath.sharedPathSteps);
    });
  });
}
