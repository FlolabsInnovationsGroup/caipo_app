import 'package:flutter/material.dart';

import 'caipo_tokens.dart';

ThemeData caipoLightTheme() {
  return _theme(
    brightness: Brightness.light,
    seed: CaipoPalette.lightAccent,
    background: CaipoPalette.lightBackground,
    surface: CaipoPalette.lightSurface,
    ink: CaipoPalette.lightInk,
  );
}

ThemeData caipoDarkTheme() {
  return _theme(
    brightness: Brightness.dark,
    seed: CaipoPalette.darkAccent,
    background: CaipoPalette.darkBackground,
    surface: CaipoPalette.darkSurface,
    ink: CaipoPalette.darkInk,
  );
}

ThemeData _theme({
  required Brightness brightness,
  required Color seed,
  required Color background,
  required Color surface,
  required Color ink,
}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: brightness,
  ).copyWith(surface: surface, onSurface: ink, error: CaipoPalette.ledAlert);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    fontFamily: CaipoType.fontFamily,
    inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      indicatorColor: scheme.primaryContainer,
    ),
  );
}
