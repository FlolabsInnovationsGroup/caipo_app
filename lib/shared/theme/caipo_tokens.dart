import 'package:flutter/material.dart';

/// Neutral stand-ins until the CAIPO brand values arrive.
///
/// Every color, type choice, and space used by the UI comes from here.
/// [fontFamily] stays unset so the phone's own font is used.
abstract final class CaipoPalette {
  static const lightBackground = Color(0xFFF4F4F2);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightInk = Color(0xFF1A1C1B);
  static const lightMuted = Color(0xFF5C615E);
  static const lightAccent = Color(0xFF3A403D);
  static const lightLine = Color(0xFFE2E2DE);

  static const darkBackground = Color(0xFF121413);
  static const darkSurface = Color(0xFF1C1F1E);
  static const darkInk = Color(0xFFF3F4F2);
  static const darkMuted = Color(0xFFB4B8B5);
  static const darkAccent = Color(0xFFD7DBD8);
  static const darkLine = Color(0xFF2C302E);

  /// LED states. These values are the product colors, not placeholders.
  static const ledStandby = Color(0xFF2F6FED);
  static const ledBoot = Color(0xFFF7F7F5);
  static const ledVideo = Color(0xFF2E9B4F);
  static const ledAudio = Color(0xFFE2B100);
  static const ledAlert = Color(0xFFD23B3B);
  static const ledCharging = Color(0xFF21B7C5);
  static const ledProcessing = Color(0xFF7A4DDB);
}

abstract final class CaipoType {
  /// Brand font is not chosen yet.
  static const String? fontFamily = null;
}

abstract final class CaipoSpace {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 16.0;
  static const l = 24.0;
  static const xl = 32.0;
  static const radius = 12.0;
}
