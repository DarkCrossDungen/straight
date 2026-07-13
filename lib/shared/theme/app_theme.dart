import 'package:flutter/material.dart';
import 'colors.dart';

class AppTheme {
  AppTheme._();

  static const _fontSans = 'DM Sans';
  static const _fontMono = 'Space Mono';

  static ThemeData get dark => _build(
    brightness: Brightness.dark,
    bg: AppColors.darkBg,
    fg: AppColors.darkFg,
    card: AppColors.darkCard,
    muted: AppColors.darkMuted,
    mutedFg: AppColors.darkMutedFg,
    primary: AppColors.primaryDark,
    primaryFg: AppColors.lightFg,
    secondary: AppColors.secondaryDark,
    accent: AppColors.accentDark,
  );

  static ThemeData get light => _build(
    brightness: Brightness.light,
    bg: AppColors.lightBg,
    fg: AppColors.lightFg,
    card: AppColors.lightCard,
    muted: AppColors.lightMuted,
    mutedFg: AppColors.lightMutedFg,
    primary: AppColors.primaryLight,
    primaryFg: AppColors.darkFg,
    secondary: AppColors.secondaryLight,
    accent: AppColors.accentLight,
  );

  static ThemeData _build({
    required Brightness brightness,
    required Color bg,
    required Color fg,
    required Color card,
    required Color muted,
    required Color mutedFg,
    required Color primary,
    required Color primaryFg,
    required Color secondary,
    required Color accent,
  }) {
    final border = fg;
    final baseText = TextStyle(
      fontFamily: _fontSans,
      color: fg,
      letterSpacing: 0,
      height: 1.25,
    );
    final monoText = TextStyle(
      fontFamily: _fontMono,
      color: fg,
      letterSpacing: 0,
      height: 1.2,
    );

    return ThemeData(
      brightness: brightness,
      useMaterial3: true,
      fontFamily: _fontSans,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: primary,
        onPrimary: primaryFg,
        secondary: secondary,
        onSecondary: AppColors.lightFg,
        error: AppColors.error,
        onError: brightness == Brightness.dark
            ? AppColors.lightFg
            : AppColors.darkFg,
        surface: card,
        onSurface: fg,
      ),
      textTheme: TextTheme(
        headlineLarge: monoText.copyWith(
          fontSize: 34,
          fontWeight: FontWeight.w700,
        ),
        headlineMedium: monoText.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: baseText.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: baseText.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        titleSmall: monoText.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: baseText.copyWith(fontSize: 15),
        bodyMedium: baseText.copyWith(fontSize: 14),
        bodySmall: baseText.copyWith(fontSize: 12, color: mutedFg),
        labelLarge: monoText.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        labelMedium: monoText.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
        labelSmall: monoText.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: fg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: monoText.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: border, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: muted,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: accent, width: 2),
        ),
        hintStyle: baseText.copyWith(color: mutedFg, fontSize: 14),
        labelStyle: monoText.copyWith(color: mutedFg, fontSize: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: primaryFg,
          disabledBackgroundColor: muted,
          disabledForegroundColor: mutedFg,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          minimumSize: const Size(40, 40),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          side: BorderSide(color: border, width: 1),
          textStyle: monoText.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: fg,
          backgroundColor: card,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          minimumSize: const Size(40, 40),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          side: BorderSide(color: border, width: 1),
          textStyle: monoText.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: fg,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          textStyle: monoText.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: fg,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected) ? primary : mutedFg;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected) ? secondary : muted;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((_) => border),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected) ? primary : fg;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? primary
              : Colors.transparent;
        }),
        checkColor: WidgetStateProperty.resolveWith((_) => primaryFg),
        side: BorderSide(color: border, width: 1),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: border, width: 1),
        ),
        titleTextStyle: monoText.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: brightness == Brightness.dark
            ? AppColors.darkBg
            : AppColors.lightMuted,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: fg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
        titleTextStyle: baseText.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
        subtitleTextStyle: baseText.copyWith(fontSize: 13, color: mutedFg),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: secondary,
        labelStyle: monoText.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.lightFg,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: border, width: 1),
        ),
        side: BorderSide(color: border, width: 1),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: muted,
        contentTextStyle: baseText.copyWith(fontSize: 14, color: fg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: border, width: 1),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: primaryFg,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearMinHeight: 3,
      ),
    );
  }
}
