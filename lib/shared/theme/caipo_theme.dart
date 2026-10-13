import 'package:flutter/material.dart';

ThemeData caipoTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1F4E46), brightness: Brightness.light),
    inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
  );
}
