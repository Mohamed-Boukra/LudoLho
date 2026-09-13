import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_game/models/board_path.dart';
import 'package:ludo_game/models/game_rules.dart';
import 'package:ludo_game/models/player.dart';
import 'package:ludo_game/models/player_color.dart';

void main() {
  group('GameRules.computeNewStep', () {
    test('a yard token needs exactly a 6 to exit', () {
      final player = Player(color: PlayerColor.red);
      final token = player.tokens.first; // step == -1

      expect(GameRules.computeNewStep(token, 4), isNull);
      expect(GameRules.computeNewStep(token, 6), 0);
    });

    test('overshooting past the finish is illegal (exact-finish rule)', () {
      final player = Player(color: PlayerColor.red);
      final token = player.tokens.first..step = 54; // 2 away from finished

      expect(GameRules.computeNewStep(token, 3), isNull); // 54+3=57, overshoot
      expect(GameRules.computeNewStep(token, 2), 56); // exact finish, legal
    });

    test('an already-finished token can never move again', () {
      final player = Player(color: PlayerColor.red);
      final token = player.tokens.first..step = 56;

      expect(GameRules.computeNewStep(token, 6), isNull);
    });
  });

  group('GameRules.isSafeCell', () {
    test('recognizes colored start cells and star cells', () {
      expect(GameRules.isSafeCell([6, 1]), isTrue); // red start
      expect(GameRules.isSafeCell([1, 8]), isTrue); // green start
      expect(GameRules.isSafeCell([8, 2]), isTrue); // star cell
      expect(GameRules.isSafeCell([2, 6]), isTrue); // star cell
    });

    test('does not flag an ordinary shared cell as safe', () {
      expect(GameRules.isSafeCell([6, 3]), isFalse);
    });
  });

  group('GameRules.captureOpponentsAt', () {
    test('sends a lone opponent token on a non-safe cell back to yard', () {
      final green = Player(color: PlayerColor.green);
      final greenToken = green.tokens.first..step = 5;
      final cell = BoardPath.absolutePosition(PlayerColor.green, 5)!;

      final players = [Player(color: PlayerColor.red), green];
      final captured = GameRules.captureOpponentsAt(players, PlayerColor.red, cell);

      expect(captured, hasLength(1));
      expect(captured.first, same(greenToken));
    });

    test('never captures a token sitting on a safe cell', () {
      final green = Player(color: PlayerColor.green);
      green.tokens.first.step = 0; // green's own (safe) start cell
      final cell = BoardPath.absolutePosition(PlayerColor.green, 0)!;

      final players = [Player(color: PlayerColor.red), green];
      final captured = GameRules.captureOpponentsAt(players, PlayerColor.red, cell);

      expect(captured, isEmpty);
    });

    test('does not capture a blocked pair (2 stacked opponent tokens)', () {
      final green = Player(color: PlayerColor.green);
      green.tokens[0].step = 5;
      green.tokens[1].step = 5; // two green tokens stacked on one cell
      final cell = BoardPath.absolutePosition(PlayerColor.green, 5)!;

      final players = [Player(color: PlayerColor.red), green];
      final captured = GameRules.captureOpponentsAt(players, PlayerColor.red, cell);

      expect(captured, isEmpty);
    });

    test('never captures your own color', () {
      final red = Player(color: PlayerColor.red);
      red.tokens.first.step = 5;
      final cell = BoardPath.absolutePosition(PlayerColor.red, 5)!;

      final captured = GameRules.captureOpponentsAt([red], PlayerColor.red, cell);

      expect(captured, isEmpty);
    });
  });

  group('GameRules.isBlockedForOpponent', () {
    test('detects two same-color opponent tokens stacked on one cell', () {
      final green = Player(color: PlayerColor.green);
      green.tokens[0].step = 5;
      green.tokens[1].step = 5;
      final cell = BoardPath.absolutePosition(PlayerColor.green, 5)!;

      final players = [Player(color: PlayerColor.red), green];
      expect(GameRules.isBlockedForOpponent(players, PlayerColor.red, cell), isTrue);
    });

    test('a single opponent token does not count as a block', () {
      final green = Player(color: PlayerColor.green);
      green.tokens.first.step = 5;
      final cell = BoardPath.absolutePosition(PlayerColor.green, 5)!;

      final players = [Player(color: PlayerColor.red), green];
      expect(GameRules.isBlockedForOpponent(players, PlayerColor.red, cell), isFalse);
    });
  });

  group('GameRules.legalMovesForPlayer', () {
    test('excludes a move that would land on a cell blocked by two opponent tokens', () {
      final red = Player(color: PlayerColor.red);
      red.tokens.first.step = 0; // already on the shared path

      final green = Player(color: PlayerColor.green);
      // Verified by hand: red's ring start index is 1, green's is 14.
      // Red moving 5 from step 0 lands on ring index 6; green sitting at
      // step 44 also lands on ring index (14+44)%52 = 6 — the same cell.
      green.tokens[0].step = 44;
      green.tokens[1].step = 44; // stacked pair -> a block

      final redDestCell = BoardPath.absolutePosition(PlayerColor.red, 5);
      final greenCell = BoardPath.absolutePosition(PlayerColor.green, 44);
      expect(redDestCell, greenCell); // sanity-check the scenario itself

      final movable = GameRules.legalMovesForPlayer(red, 5, [red, green]);
      expect(movable.map((t) => t.id), isNot(contains(red.tokens.first.id)));
    });

    test('yard tokens are only offered when the roll is a 6', () {
      final player = Player(color: PlayerColor.red); // all 4 in yard
      final allPlayers = [player];

      expect(GameRules.legalMovesForPlayer(player, 4, allPlayers), isEmpty);
      expect(GameRules.legalMovesForPlayer(player, 6, allPlayers), hasLength(4));
    });
  });
}
