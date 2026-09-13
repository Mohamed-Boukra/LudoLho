import 'player_color.dart';
import 'token.dart';

/// One participant in the match: a color plus their 4 tokens.
class Player {
  final PlayerColor color;
  final String name;
  final bool isAI;
  final List<Token> tokens;
  int kills = 0;
  int deaths = 0;
  List<int> diceStats = List.filled(6, 0);

  int get score => kills - deaths;

  Player({required this.color, this.isAI = false, String? name})
      : name = name ?? color.label,
        tokens = List.generate(4, (i) => Token(color: color, slot: i));

  bool get hasWon => tokens.every((t) => t.isFinished);

  int get tokensInYard => tokens.where((t) => t.isInYard).length;

  int get tokensFinished => tokens.where((t) => t.isFinished).length;
}
