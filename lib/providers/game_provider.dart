import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/board_path.dart';
import '../models/game_phase.dart';
import '../models/game_rules.dart';
import '../models/player.dart';
import '../models/player_color.dart';
import '../models/token.dart';
import '../services/sound_service.dart';

/// The single source of truth for an in-progress match: which players
/// are playing, whose turn it is, the last dice roll, the current phase
/// of the turn state machine, move/capture/blocking resolution (Phase
/// 5/6), and now (Phase 7) turn-skip messaging + mid-match persistence,
/// plus (Phase 8) win detection and final standings.
class GameProvider extends ChangeNotifier {
  static const String _prefsKey = 'ludo_saved_match';
  static const Duration _stepAnimationDelay = Duration(milliseconds: 260);
  static const Duration _autoPassDelay = Duration(milliseconds: 900);

  /// How long the dice's visual tumble animation takes. Shared with
  /// [DiceWidget] so the widget's animation and the moment tokens
  /// actually become tappable never drift apart.
  static const Duration diceRollDuration = Duration(milliseconds: 850);

  List<Player> _players = [];
  int _currentPlayerIndex = 0;
  int? _lastDiceValue;
  GamePhase _phase = GamePhase.rollPhase;
  int _consecutiveSixes = 0;
  bool _isAnimating = false;

  /// True from the moment [rollDice] is called until [diceRollDuration]
  /// has elapsed. While true, [movableTokens] deliberately reports no
  /// legal moves — even though the real roll and phase transition
  /// already happened internally — so a token can never be tapped and
  /// moved before the player has actually seen the dice settle.
  bool _isRollingDice = false;

  Timer? _turnTimer;
  int turnTimeLeft = 0;
  static const int turnDurationSeconds = 15;

  // Phase 8: finishing order + whether the match ends at the first
  // winner or keeps going so every player gets a final rank.
  final List<PlayerColor> _finishOrder = [];
  bool endOnFirstWinner = true;

  // Phase 6: house-rule toggles.
  bool enableBlocking = true;
  bool enableExtraTurnOnCapture = true;
  bool eatAllOnBlocked = false;

  bool isMuted = false;

  // One-off UI events (capture / turn-skip): the UI remembers the last
  // event id it displayed and compares against these to avoid re-firing
  // a SnackBar on every rebuild.
  int _captureEventId = 0;
  String? _lastCaptureMessage;
  List<int>? _lastCaptureCell;
  int _turnEventId = 0;
  String? _lastTurnMessage;

  final Random _random = Random();

  List<Player> get players => List.unmodifiable(_players);
  bool get isInitialized => _players.isNotEmpty;

  Player get currentPlayer => _players[_currentPlayerIndex];
  int get currentPlayerIndex => _currentPlayerIndex;

  int? get lastDiceValue => _lastDiceValue;
  GamePhase get phase => _phase;
  bool get isAnimating => _isAnimating;
  bool get isRollingDice => _isRollingDice;

  int get captureEventId => _captureEventId;
  String? get lastCaptureMessage => _lastCaptureMessage;

  /// The (row, col) board cell the last capture happened at — set right
  /// before the captured token(s) are sent back to their yard, so the
  /// UI can play a one-off impact effect at that spot. `null` until the
  /// first capture of the match.
  List<int>? get lastCaptureCell => _lastCaptureCell;
  int get turnEventId => _turnEventId;
  String? get lastTurnMessage => _lastTurnMessage;

  /// Final standings in finishing order (1st, 2nd, ...). Only populated
  /// once players start finishing (Phase 8).
  List<PlayerColor> get finishOrder => List.unmodifiable(_finishOrder);

  /// The current player's tokens that can legally move with the last
  /// rolled value, right now. Deliberately empty while [isRollingDice]
  /// is true — see that field's doc for why.
  List<Token> get movableTokens {
    if (_isRollingDice) return const [];
    return _rawMovableTokens();
  }

  /// Same computation as [movableTokens] but ignoring the dice-rolling
  /// animation gate — used internally (e.g. the no-legal-moves auto
  /// pass check) where we need the true legal-move set regardless of
  /// whether the dice widget has finished its visual tumble yet.
  List<Token> _rawMovableTokens() {
    if (!isInitialized || _lastDiceValue == null) return const [];
    if (_phase != GamePhase.movePhase || _isAnimating) return const [];
    return GameRules.legalMovesForPlayer(
      currentPlayer,
      _lastDiceValue!,
      _players,
      enableBlocking: enableBlocking,
    );
  }

  Set<String> get movableTokenIds => movableTokens.map((t) => t.id).toSet();

  // -----------------------------------------------------------------
  // Setup
  // -----------------------------------------------------------------

  /// Sets up a fresh match with these exact [colors] (2-4, no repeats),
  /// in turn order. Color assignment happens on the Phase 7 setup screen.
  void initGame(List<PlayerColor> colors, {List<String>? names}) {
    assert(colors.length >= 2 && colors.length <= 4);
    assert(colors.toSet().length == colors.length, 'colors must be unique');

    _players = [];
    for (int i = 0; i < colors.length; i++) {
      final name = names != null && i < names.length ? names[i] : colors[i].label;
      _players.add(Player(color: colors[i], name: name));
    }
    _currentPlayerIndex = 0;
    _lastDiceValue = null;
    _phase = GamePhase.rollPhase;
    _consecutiveSixes = 0;
    _isAnimating = false;
    _isRollingDice = false;
    _captureEventId = 0;
    _lastCaptureMessage = null;
    _lastCaptureCell = null;
    _turnEventId = 0;
    _lastTurnMessage = null;
    _finishOrder.clear();
    _turnTimer?.cancel();
    turnTimeLeft = 0;

    _persist();
    notifyListeners();
  }

  @override
  void dispose() {
    _turnTimer?.cancel();
    super.dispose();
  }

  // -----------------------------------------------------------------
  // Dice
  // -----------------------------------------------------------------

  /// Rolls the dice for the current player and stores the result so
  /// [movableTokens] can consume it. Returns the rolled value so the
  /// Dice widget's animation can land on it.
  int rollDice() {
    if (!isInitialized || _phase != GamePhase.rollPhase) {
      return _lastDiceValue ?? 1;
    }

    final value = _random.nextInt(6) + 1;
    _lastDiceValue = value;
    _consecutiveSixes = value == 6 ? _consecutiveSixes + 1 : 0;
    currentPlayer.diceStats[value - 1]++;

    if (_consecutiveSixes == 3) {
      // Classic rule: three 6s in a row forfeits the turn entirely.
      _consecutiveSixes = 0;
      _lastDiceValue = null;
      _lastTurnMessage =
          '${currentPlayer.color.label} rolled three 6s in a row — turn forfeited!';
      _turnEventId++;
      _advanceTurn();
    } else {
      _phase = GamePhase.movePhase;
      _isRollingDice = true;
      // Reveal the real legal moves — and let tokens become tappable —
      // only once the dice's visual tumble has actually finished, so
      // what the player sees settle on screen always matches what
      // happens when they tap a token.
      _settleDiceRoll();
      // Fire-and-forget: if nothing can legally move, auto-pass after a
      // short pause so the player can see why, rather than getting stuck.
      _autoPassIfNoLegalMoves();
    }

    SoundService.instance.diceRoll();
    _persist();
    notifyListeners();
    return value;
  }

  Future<void> _settleDiceRoll() async {
    await Future.delayed(diceRollDuration);
    if (!_isRollingDice) return; // superseded by a later roll/turn change
    _isRollingDice = false;
    
    final moves = _rawMovableTokens();
    if (moves.length == 1) {
      // Auto-play if only one legal move
      moveToken(moves.first);
    } else if (moves.isNotEmpty) {
      // Start the turn timer only if they actually have a choice to make
      _startTurnTimer();
    }
    
    notifyListeners();
  }

  void _startTurnTimer() {
    _turnTimer?.cancel();
    turnTimeLeft = turnDurationSeconds;
    _turnTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (turnTimeLeft > 0) {
        turnTimeLeft--;
        notifyListeners();
      } else {
        timer.cancel();
        _autoPassForTimeout();
      }
    });
  }

  void _autoPassForTimeout() {
    if (_phase == GamePhase.movePhase && !_isAnimating) {
      _lastDiceValue = null;
      _lastTurnMessage = '${currentPlayer.name} ran out of time — turn skipped';
      _turnEventId++;
      _advanceTurn();
      _persist();
      notifyListeners();
    }
  }

  Future<void> _autoPassIfNoLegalMoves() async {
    if (_rawMovableTokens().isNotEmpty) return;
    final skippedPlayerLabel = currentPlayer.color.label;
    await Future.delayed(_autoPassDelay);
    // Re-check: state may have changed while we were waiting.
    if (_phase == GamePhase.movePhase &&
        !_isAnimating &&
        _rawMovableTokens().isEmpty) {
      _isRollingDice = false;
      _lastDiceValue = null;
      _lastTurnMessage = '$skippedPlayerLabel had no legal moves — turn skipped';
      _turnEventId++;
      _advanceTurn();
      _persist();
      notifyListeners();
    }
  }

  // -----------------------------------------------------------------
  // Movement (Phase 5) + capture/blocking (Phase 6) + win check (Phase 8)
  // -----------------------------------------------------------------

  /// Moves [token] by the last rolled value, animating it one cell at a
  /// time, then resolves captures, checks for a win, and hands off the
  /// turn.
  Future<void> moveToken(Token token) async {
    if (!isInitialized || _phase != GamePhase.movePhase || _isAnimating) return;
    if (_isRollingDice) return; // dice hasn't visually settled yet
    if (token.color != currentPlayer.color) return;
    if (_lastDiceValue == null) return;

    final newStep = GameRules.computeNewStep(token, _lastDiceValue!);
    if (newStep == null) return; // illegal move, ignore silently

    if (enableBlocking && newStep >= 0 && newStep <= 50) {
      final destCell = BoardPath.absolutePosition(token.color, newStep);
      if (destCell != null &&
          GameRules.isBlockedForOpponent(_players, token.color, destCell)) {
        return; // destination is blocked by a stacked opponent pair
      }
    }

    _turnTimer?.cancel();
    _isAnimating = true;
    notifyListeners();

    final int startStep = token.step;
    if (startStep == -1) {
      // Leaving the yard is a single hop onto the start cell.
      token.step = 0;
      SoundService.instance.tokenStep();
      notifyListeners();
      await Future.delayed(_stepAnimationDelay);
    } else {
      for (int s = startStep + 1; s <= newStep; s++) {
        token.step = s;
        SoundService.instance.tokenStep();
        notifyListeners();
        await Future.delayed(_stepAnimationDelay);
      }
    }

    bool captured = false;
    if (token.isOnSharedPath) {
      final cell = BoardPath.absolutePosition(token.color, token.step)!;
      final capturedTokens =
          GameRules.captureOpponentsAt(_players, token.color, cell, captureAll: eatAllOnBlocked);
      if (capturedTokens.isNotEmpty) {
        _lastCaptureCell = cell;
        for (final t in capturedTokens) {
          t.step = -1; // sent back to yard
          final capturedPlayer = _players.firstWhere((p) => p.color == t.color);
          capturedPlayer.deaths++;
        }
        captured = true;
        currentPlayer.kills += capturedTokens.length;
        _captureEventId++;
        _lastCaptureMessage = capturedTokens.length == 1
            ? '${token.color.label} captured ${capturedTokens.first.color.label}\'s token!'
            : '${token.color.label} captured ${capturedTokens.length} tokens!';
        SoundService.instance.capture();
      }
    }

    _isAnimating = false;

    // Phase 8: did this move finish the mover's whole team?
    if (token.isFinished &&
        currentPlayer.hasWon &&
        !_finishOrder.contains(currentPlayer.color)) {
      _finishOrder.add(currentPlayer.color);
    }
    if (token.isFinished) {
      SoundService.instance.tokenFinish();
    }

    final bool matchOver = _isMatchOver();

    final bool rolledSix = _lastDiceValue == 6;
    _lastDiceValue = null;

    if (matchOver) {
      _phase = GamePhase.gameOver;
      SoundService.instance.victory();
      _clearSavedMatch();
    } else if (rolledSix || (captured && enableExtraTurnOnCapture)) {
      _phase = GamePhase.rollPhase; // extra turn, same player
      _persist();
    } else {
      _advanceTurn();
      _persist();
    }

    notifyListeners();
  }

  bool _isMatchOver() {
    if (_finishOrder.isEmpty) return false;
    if (endOnFirstWinner) return true;
    // Keep going until only one player hasn't finished yet.
    final unfinished = _players.where((p) => !p.hasWon).length;
    return unfinished <= 1;
  }

  void _advanceTurn() {
    _consecutiveSixes = 0;
    int next = _currentPlayerIndex;
    for (int i = 0; i < _players.length; i++) {
      next = (next + 1) % _players.length;
      // Skip players who have already finished all 4 tokens (relevant
      // only when endOnFirstWinner is false and the match continues).
      if (!_players[next].hasWon) break;
    }
    _currentPlayerIndex = next;
    _phase = GamePhase.rollPhase;
  }

  // -----------------------------------------------------------------
  // Settings
  // -----------------------------------------------------------------

  void toggleMute() {
    isMuted = !isMuted;
    SoundService.instance.muted = isMuted;
    notifyListeners();
  }

  // -----------------------------------------------------------------
  // Phase 7: mid-match persistence
  // -----------------------------------------------------------------

  Map<String, dynamic> toJson() => {
        'names': _players.map((p) => p.name).toList(),
        'colors': _players.map((p) => p.color.key).toList(),
        'tokens': _players.map((p) => p.tokens.map((t) => t.step).toList()).toList(),
        'kills': _players.map((p) => p.kills).toList(),
        'deaths': _players.map((p) => p.deaths).toList(),
        'diceStats': _players.map((p) => p.diceStats).toList(),
        'currentPlayerIndex': _currentPlayerIndex,
        'lastDiceValue': _lastDiceValue,
        'phase': _phase.name,
        'consecutiveSixes': _consecutiveSixes,
        'enableBlocking': enableBlocking,
        'enableExtraTurnOnCapture': enableExtraTurnOnCapture,
        'endOnFirstWinner': endOnFirstWinner,
        'eatAllOnBlocked': eatAllOnBlocked,
        'finishOrder': _finishOrder.map((c) => c.key).toList(),
        'isMuted': isMuted,
      };

  void _restoreFromJson(Map<String, dynamic> json) {
    final colorKeys = List<String>.from(json['colors'] as List);
    final names = (json['names'] as List?)?.cast<String>() ?? colorKeys;
    
    _players = [];
    for (int i = 0; i < colorKeys.length; i++) {
      _players.add(Player(color: playerColorFromKey(colorKeys[i]), name: names[i]));
    }

    final tokensData = json['tokens'] as List;
    final killsData = (json['kills'] as List?) ?? List.filled(_players.length, 0);
    final deathsData = (json['deaths'] as List?) ?? List.filled(_players.length, 0);
    final diceStatsData = (json['diceStats'] as List?) ?? List.filled(_players.length, List.filled(6, 0));
    
    for (int i = 0; i < _players.length; i++) {
      _players[i].kills = killsData[i] as int;
      _players[i].deaths = deathsData[i] as int;
      _players[i].diceStats = List<int>.from(diceStatsData[i] as List);
      final steps = List<int>.from(tokensData[i] as List);
      for (int j = 0; j < steps.length && j < _players[i].tokens.length; j++) {
        _players[i].tokens[j].step = steps[j];
      }
    }

    _currentPlayerIndex = (json['currentPlayerIndex'] as int?) ?? 0;
    _lastDiceValue = json['lastDiceValue'] as int?;
    _phase = GamePhase.values.byName((json['phase'] as String?) ?? 'rollPhase');
    _consecutiveSixes = (json['consecutiveSixes'] as int?) ?? 0;
    enableBlocking = (json['enableBlocking'] as bool?) ?? true;
    enableExtraTurnOnCapture = (json['enableExtraTurnOnCapture'] as bool?) ?? true;
    endOnFirstWinner = (json['endOnFirstWinner'] as bool?) ?? true;
    eatAllOnBlocked = (json['eatAllOnBlocked'] as bool?) ?? false;
    isMuted = (json['isMuted'] as bool?) ?? false;
    SoundService.instance.muted = isMuted;
    _finishOrder
      ..clear()
      ..addAll(
        ((json['finishOrder'] as List?) ?? const [])
            .map((k) => playerColorFromKey(k as String)),
      );
    _isAnimating = false;
    _isRollingDice = false;
  }

  Future<void> _persist() async {
    if (!isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(toJson()));
    } catch (_) {
      // Persistence is a convenience, not a correctness requirement —
      // silently ignore failures (e.g. platform without prefs support).
    }
  }

  Future<void> _clearSavedMatch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    } catch (_) {
      // Ignore.
    }
  }

  /// True if a mid-match save exists that [restoreSavedMatch] could load.
  Future<bool> hasSavedMatch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_prefsKey);
    } catch (_) {
      return false;
    }
  }

  /// Loads the saved match into this provider. Returns true on success.
  Future<bool> restoreSavedMatch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return false;
      _restoreFromJson(jsonDecode(raw) as Map<String, dynamic>);
      notifyListeners();
      if (_phase == GamePhase.movePhase) {
        // Cover the edge case where the app was closed in the brief
        // window before an auto-pass check could run.
        _autoPassIfNoLegalMoves();
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}
