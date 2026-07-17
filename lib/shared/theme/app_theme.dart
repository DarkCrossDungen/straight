import 'package:flutter/material.dart';

import 'colors.dart';

class AppTheme {
  AppTheme._();

  static const _fontSans = 'Segoe UI';
  static const _fontDisplay = 'Georgia';
  static const _fontMono = 'Cascadia Mono';

  static ThemeData get light => _build(
    brightness: Brightness.light,
    bg: AppColors.lightBg,
    fg: AppColors.lightFg,
    card: AppColors.lightCard,
    muted: AppColors.lightMuted,
    mutedFg: AppColors.lightMutedFg,
    border: AppColors.lightBorder,
    divider: AppColors.lightDivider,
    primary: AppColors.primaryLight,
    secondary: AppColors.secondaryLight,
    accent: AppColors.accentLight,
  );

  static ThemeData get dark => _build(
    brightness: Brightness.dark,
    bg: AppColors.darkBg,
    fg: AppColors.darkFg,
    card: AppColors.darkCard,
    muted: AppColors.darkMuted,
    mutedFg: AppColors.darkMutedFg,
    border: AppColors.darkBorder,
    divider: AppColors.darkDivider,
    primary: AppColors.primaryDark,
    secondary: AppColors.secondaryDark,
    accent: AppColors.accentDark,
  );

  static ThemeData _build({
    required Brightness brightness,
    required Color bg,
    required Color fg,
    required Color card,
    required Color muted,
    required Color mutedFg,
    required Color border,
    required Color divider,
    required Color primary,
    required Color secondary,
    required Color accent,
  }) {
    final sans = TextStyle(fontFamily: _fontSans, color: fg, height: 1.35);
    final display = TextStyle(
      fontFamily: _fontDisplay,
      color: fg,
      height: 1.05,
    );
    final mono = TextStyle(fontFamily: _fontMono, color: fg, height: 1.2);
    const radius = BorderRadius.all(Radius.circular(10));

    return ThemeData(
      brightness: brightness,
      useMaterial3: true,
      fontFamily: _fontSans,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: primary,
        onPrimary: AppColors.lightCard,
        secondary: secondary,
        onSecondary: fg,
        error: primary,
        onError: AppColors.lightCard,
        surface: card,
        onSurface: fg,
      ),
      textTheme: TextTheme(
        headlineLarge: display.copyWith(
          fontSize: 46,
          fontWeight: FontWeight.w400,
          letterSpacing: -1.8,
        ),
        headlineMedium: display.copyWith(
          fontSize: 31,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.8,
        ),
        titleLarge: sans.copyWith(fontSize: 20, fontWeight: FontWeight.w600),
        titleMedium: sans.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
        titleSmall: sans.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
        bodyLarge: sans.copyWith(fontSize: 16),
        bodyMedium: sans.copyWith(fontSize: 14),
        bodySmall: sans.copyWith(fontSize: 12, color: mutedFg),
        labelLarge: sans.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
        labelMedium: mono.copyWith(fontSize: 11, fontWeight: FontWeight.w600),
        labelSmall: mono.copyWith(fontSize: 10, fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: fg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: display.copyWith(fontSize: 25, letterSpacing: -0.5),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        hintStyle: sans.copyWith(color: mutedFg, fontSize: 14),
        labelStyle: mono.copyWith(color: mutedFg, fontSize: 11),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: AppColors.lightCard,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          minimumSize: const Size(42, 42),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          textStyle: sans.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: fg,
          backgroundColor: card,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          minimumSize: const Size(42, 42),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          side: BorderSide(color: border),
          textStyle: sans.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: fg,
          textStyle: sans.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: fg,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? primary : mutedFg,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primarySoft
              : muted,
        ),
        trackOutlineColor: WidgetStateProperty.all(border),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? primary : mutedFg,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? primary
              : Colors.transparent,
        ),
        checkColor: WidgetStateProperty.all(AppColors.lightCard),
        side: BorderSide(color: border),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
      ),
      dividerTheme: DividerThemeData(color: divider, thickness: 1, space: 1),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: border),
        ),
        titleTextStyle: sans.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: mutedFg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        titleTextStyle: sans.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        subtitleTextStyle: sans.copyWith(fontSize: 13, color: mutedFg),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: muted,
        labelStyle: mono.copyWith(fontSize: 10, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(6)),
          side: BorderSide(color: border),
        ),
        side: BorderSide(color: border),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: fg,
        contentTextStyle: sans.copyWith(fontSize: 14, color: bg),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: AppColors.lightCard,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearMinHeight: 3,
      ),
    );
  }
}
