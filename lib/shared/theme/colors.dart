import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Light theme tokens from the 21st.dev-style reference.
  static const lightBg = Color(0xFFFFFFFF);
  static const lightFg = Color(0xFF000000);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightMuted = Color(0xFFF0F0F0);
  static const lightMutedFg = Color(0xFF333333);
  static const lightBorder = Color(0xFF000000);
  static const lightDivider = Color(0xFF000000);

  // Dark theme tokens.
  static const darkBg = Color(0xFF000000);
  static const darkFg = Color(0xFFFFFFFF);
  static const darkCard = Color(0xFF333333);
  static const darkMuted = Color(0xFF1A1A1A);
  static const darkMutedFg = Color(0xFFCCCCCC);
  static const darkBorder = Color(0xFFFFFFFF);
  static const darkDivider = Color(0xFFFFFFFF);

  // Brand and accent.
  static const primaryLight = Color(0xFFFF3333);
  static const primaryDark = Color(0xFFFF6666);
  static const accentLight = Color(0xFF0066FF);
  static const accentDark = Color(0xFF3399FF);
  static const secondaryLight = Color(0xFFFFFF00);
  static const secondaryDark = Color(0xFFFFFF33);

  // Semantic.
  static const success = Color(0xFF00CC00);
  static const warning = Color(0xFFFFFF00);
  static const error = Color(0xFFFF3333);
  static const info = Color(0xFF0066FF);

  // Waveform.
  static const waveformIdle = Color(0xFF333333);
  static const waveformActive = Color(0xFFFF3333);
  static const waveformDark = Color(0xFFCCCCCC);
}
