import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// The 4 possible player colors. Kept as an enum (type-safe) at the
/// model layer, with a [key] getter that bridges to the string keys
/// used in [BoardConstants]'s map literals.
enum PlayerColor { red, green, yellow, blue }

/// Reverse of [PlayerColorX.key] — used when restoring persisted state
/// (Phase 7) from a plain string.
PlayerColor playerColorFromKey(String key) {
  switch (key) {
    case 'red':
      return PlayerColor.red;
    case 'green':
      return PlayerColor.green;
    case 'yellow':
      return PlayerColor.yellow;
    case 'blue':
      return PlayerColor.blue;
    default:
      throw ArgumentError('Unknown PlayerColor key: $key');
  }
}

extension PlayerColorX on PlayerColor {
  /// String key matching BoardConstants' map keys.
  String get key {
    switch (this) {
      case PlayerColor.red:
        return 'red';
      case PlayerColor.green:
        return 'green';
      case PlayerColor.yellow:
        return 'yellow';
      case PlayerColor.blue:
        return 'blue';
    }
  }

  Color get displayColor => AppColors.fromKey(key);

  String get label {
    switch (this) {
      case PlayerColor.red:
        return 'Red';
      case PlayerColor.green:
        return 'Green';
      case PlayerColor.yellow:
        return 'Yellow';
      case PlayerColor.blue:
        return 'Blue';
    }
  }
}
