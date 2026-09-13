import 'package:flutter/material.dart';

/// Central place for every color used in the game.
///
/// Beyond flat colors, this now carries the gradient / lighting palette
/// that gives the board, tokens and dice their 3D, glossy look —
/// every "surface" in the game is lit from the same virtual light
/// source (upper-left), which is what actually sells depth.
class AppColors {
  AppColors._();

  // ---------------------------------------------------------------
  // Player colors (flat, kept for back-compat / text / icons)
  // ---------------------------------------------------------------
  static const Color red = Color(0xFFE8433A);
  static const Color green = Color(0xFF2FAE5B);
  static const Color yellow = Color(0xFFF4B400);
  static const Color blue = Color(0xFF2B7FE0);

  // Deeper shade of each color, used for shadows / pressed states /
  // the "underside" of 3D tokens.
  static const Color redDark = Color(0xFF9E2620);
  static const Color greenDark = Color(0xFF166B37);
  static const Color yellowDark = Color(0xFFB37D00);
  static const Color blueDark = Color(0xFF184F8C);

  static const Color redLight = Color(0xFFFF8079);
  static const Color greenLight = Color(0xFF7DE3A2);
  static const Color yellowLight = Color(0xFFFFE28A);
  static const Color blueLight = Color(0xFF7FB4F5);

  // ---------------------------------------------------------------
  // Board neutrals
  // ---------------------------------------------------------------
  static const Color boardBackground = Color(0xFFFBF7EE);
  static const Color pathCell = Color(0xFFFFFDF6);
  static const Color cellBorder = Color(0xFFD9CFB8);
  static const Color boardOuterBorder = Color(0xFF2B2118);
  static const Color boardFelt = Color(0xFF0E4A3B);
  static const Color boardFeltDark = Color(0xFF08301F);

  // ---------------------------------------------------------------
  // UI / chrome
  // ---------------------------------------------------------------
  static const Color scaffoldBackground = Color(0xFFF3EFE4);
  static const Color appBarText = Color(0xFF262019);
  static const Color disabled = Color(0xFF9E9E9E);
  static const Color gold = Color(0xFFF2C037);

  static const List<Color> backgroundGradient = [
    Color(0xFF12362C),
    Color(0xFF0B241D),
  ];

  static const List<Color> menuGradient = [
    Color(0xFF19493C),
    Color(0xFF0D2A22),
    Color(0xFF081B16),
  ];

  /// Helper to get a player's color from an enum-like string key.
  static Color fromKey(String key) {
    switch (key) {
      case 'red':
        return red;
      case 'green':
        return green;
      case 'yellow':
        return yellow;
      case 'blue':
        return blue;
      default:
        return disabled;
    }
  }

  static Color darkFromKey(String key) {
    switch (key) {
      case 'red':
        return redDark;
      case 'green':
        return greenDark;
      case 'yellow':
        return yellowDark;
      case 'blue':
        return blueDark;
      default:
        return disabled;
    }
  }

  static Color lightFromKey(String key) {
    switch (key) {
      case 'red':
        return redLight;
      case 'green':
        return greenLight;
      case 'yellow':
        return yellowLight;
      case 'blue':
        return blueLight;
      default:
        return disabled;
    }
  }

  /// A glossy radial "sphere" gradient for a given base color — used by
  /// tokens and dice pips to fake a curved, lit 3D surface.
  static RadialGradient glossSphere(Color base, Color dark) {
    return RadialGradient(
      center: const Alignment(-0.35, -0.45),
      radius: 0.9,
      colors: [
        Color.lerp(base, Colors.white, 0.55)!,
        base,
        dark,
      ],
      stops: const [0.0, 0.55, 1.0],
    );
  }

  /// Vertical bevel gradient used for raised UI panels (yards, buttons).
  static LinearGradient bevel(Color base, Color dark) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color.lerp(base, Colors.white, 0.25)!, base, dark],
      stops: const [0.0, 0.5, 1.0],
    );
  }
}
