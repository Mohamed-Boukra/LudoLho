import 'package:audioplayers/audioplayers.dart';

/// Thin wrapper around `audioplayers` for the game's sound effects.
/// [GameProvider] calls into this at the relevant moments. Playback
/// failures are swallowed on purpose — sound is a nice-to-have and must
/// never affect gameplay (e.g. a platform without audio support, or
/// assets not yet bundled).
///
/// Two players are used: [_sfxPlayer] for one-off cues (dice, capture,
/// finish, victory), and [_tickPlayer] for the rapid-fire "step" tick
/// played once per cell during token movement, kept separate so a fast
/// sequence of ticks doesn't cut off a longer sound effect.
class SoundService {
  SoundService._internal() {
    _tickPlayer.setPlayerMode(PlayerMode.lowLatency);
    _sfxPlayer.setPlayerMode(PlayerMode.lowLatency);
  }

  static final SoundService instance = SoundService._internal();

  final AudioPlayer _sfxPlayer = AudioPlayer();
  final AudioPlayer _tickPlayer = AudioPlayer();

  bool muted = false;

  Future<void> _play(AudioPlayer player, String assetPath) async {
    if (muted) return;
    try {
      await player.stop();
      await player.play(AssetSource(assetPath));
    } catch (_) {
      // Ignore — see class doc.
    }
  }

  Future<void> diceRoll() => _play(_sfxPlayer, 'sounds/dice_roll.wav');
  Future<void> tokenStep() => _play(_tickPlayer, 'sounds/token_move.wav');
  Future<void> capture() => _play(_sfxPlayer, 'sounds/capture.wav');
  Future<void> tokenFinish() => _play(_sfxPlayer, 'sounds/token_finish.wav');
  Future<void> victory() => _play(_sfxPlayer, 'sounds/victory.wav');
}
