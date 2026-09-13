/// Minimal turn state machine, expanded further in Phase 7.
///
///  rollPhase  -> the current player needs to tap the dice
///  movePhase  -> a value has been rolled; a move is pending
///                (Phase 5 adds real "select a token" behavior here)
///  gameOver   -> the match has ended (used from Phase 8 onward)
enum GamePhase { rollPhase, movePhase, gameOver }
