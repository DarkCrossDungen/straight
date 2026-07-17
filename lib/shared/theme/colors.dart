import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Warm, quiet surfaces keep attention on the spoken words. Coral is used
  // only for recording and primary actions.
  static const lightBg = Color(0xFFF3EFE7);
  static const lightFg = Color(0xFF24221F);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightMuted = Color(0xFFEDE9E1);
  static const lightMutedFg = Color(0xFF746F67);
  static const lightBorder = Color(0xFFD9D3C9);
  static const lightDivider = Color(0xFFE4DED5);

  static const darkBg = Color(0xFF201F1C);
  static const darkFg = Color(0xFFF7F4EE);
  static const darkCard = Color(0xFF2A2925);
  static const darkMuted = Color(0xFF36342F);
  static const darkMutedFg = Color(0xFFB6B0A7);
  static const darkBorder = Color(0xFF4A4741);
  static const darkDivider = Color(0xFF3D3A35);

  static const primaryLight = Color(0xFFE96D5B);
  static const primaryDark = Color(0xFFFF8A77);
  static const primarySoft = Color(0xFFFCE4DF);
  static const accentLight = Color(0xFF565F73);
  static const accentDark = Color(0xFFBEC6D7);
  static const secondaryLight = Color(0xFFF3E9C9);
  static const secondaryDark = Color(0xFF4D452C);

  static const success = Color(0xFF53725B);
  static const warning = Color(0xFF9B7324);
  static const error = primaryLight;
  static const info = accentLight;

  static const waveformIdle = Color(0xFF6D675E);
  static const waveformActive = primaryLight;
  static const waveformDark = Color(0xFFD9D3C9);
}
