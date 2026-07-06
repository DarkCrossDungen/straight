import 'package:flutter/material.dart';
import 'colors.dart';

class AppTheme {
  AppTheme._();

  static const _ffSans = 'Inter';
  static const _ffMono = 'SF Mono';

  static ThemeData get dark {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBg,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryDark,
        secondary: AppColors.accentDark,
        surface: AppColors.darkCard,
        error: AppColors.error,
        onPrimary: AppColors.darkFg,
        onSecondary: AppColors.darkBg,
        onSurface: AppColors.darkFg,
        onError: AppColors.darkFg,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkBg,
        foregroundColor: AppColors.darkFg,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: _ffMono,
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: AppColors.darkFg,
          letterSpacing: 0,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkCard,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: AppColors.darkBorder, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkMuted,
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.darkBorder, width: 1),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.darkBorder, width: 1),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.primaryDark, width: 1),
        ),
        labelStyle: const TextStyle(
          fontFamily: _ffMono,
          fontSize: 13,
          color: AppColors.darkMutedFg,
        ),
        hintStyle: const TextStyle(
          fontFamily: _ffSans,
          fontSize: 14,
          color: AppColors.darkMutedFg,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryDark,
          foregroundColor: AppColors.darkFg,
          disabledBackgroundColor: AppColors.darkMuted,
          disabledForegroundColor: AppColors.darkMutedFg,
          elevation: 0,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: const TextStyle(
            fontFamily: _ffMono,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.darkFg,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          textStyle: const TextStyle(
            fontFamily: _ffMono,
            fontSize: 13,
            letterSpacing: 0,
          ),
        ),
      ),
      iconTheme: const IconThemeData(color: AppColors.darkFg, size: 20),
      dividerTheme: const DividerThemeData(
        color: AppColors.darkDivider,
        thickness: 1,
        space: 0,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.darkBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: AppColors.darkBorder, width: 1),
        ),
        titleTextStyle: TextStyle(
          fontFamily: _ffMono,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.darkFg,
          letterSpacing: 0,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primaryDark;
          return AppColors.darkMutedFg;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primaryDark.withValues(alpha: 0.3);
          return AppColors.darkMuted;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((_) => Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primaryDark;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.resolveWith((_) => AppColors.darkFg),
        side: const BorderSide(color: AppColors.darkBorder, width: 1),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primaryDark;
          return AppColors.darkFg;
        }),
      ),
      listTileTheme: const ListTileThemeData(
        titleTextStyle: TextStyle(
          fontFamily: _ffSans,
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: AppColors.darkFg,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: _ffSans,
          fontSize: 13,
          color: AppColors.darkMutedFg,
        ),
        leadingAndTrailingTextStyle: TextStyle(
          fontFamily: _ffMono,
          fontSize: 13,
          color: AppColors.darkFg,
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontFamily: _ffMono, fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.darkFg, letterSpacing: 0),
        headlineMedium: TextStyle(fontFamily: _ffMono, fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.darkFg, letterSpacing: 0),
        titleLarge: TextStyle(fontFamily: _ffSans, fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.darkFg),
        titleMedium: TextStyle(fontFamily: _ffSans, fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.darkFg),
        bodyLarge: TextStyle(fontFamily: _ffSans, fontSize: 15, color: AppColors.darkFg),
        bodyMedium: TextStyle(fontFamily: _ffSans, fontSize: 14, color: AppColors.darkFg),
        bodySmall: TextStyle(fontFamily: _ffSans, fontSize: 12, color: AppColors.darkMutedFg),
        labelLarge: TextStyle(fontFamily: _ffMono, fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.darkFg, letterSpacing: 0),
        labelSmall: TextStyle(fontFamily: _ffMono, fontSize: 11, color: AppColors.darkMutedFg),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.darkMuted,
        labelStyle: const TextStyle(fontFamily: _ffMono, fontSize: 12, color: AppColors.darkFg),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: AppColors.darkBorder, width: 1),
        ),
        side: const BorderSide(color: AppColors.darkBorder, width: 1),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryDark,
        foregroundColor: AppColors.darkFg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.darkMuted,
        contentTextStyle: const TextStyle(fontFamily: _ffSans, fontSize: 14, color: AppColors.darkFg),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: AppColors.darkBorder, width: 1),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.darkBg,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: AppColors.darkBorder, width: 1),
        ),
        textStyle: const TextStyle(fontFamily: _ffSans, fontSize: 14, color: AppColors.darkFg),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.darkBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: AppColors.darkBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primaryDark,
        linearMinHeight: 2,
      ),
    );
  }

  static ThemeData get light {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBg,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primaryLight,
        secondary: AppColors.accentLight,
        surface: AppColors.lightCard,
        error: AppColors.error,
        onPrimary: AppColors.lightFg,
        onSecondary: AppColors.lightFg,
        onSurface: AppColors.lightFg,
        onError: AppColors.lightBg,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.lightBg,
        foregroundColor: AppColors.lightFg,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: _ffMono,
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: AppColors.lightFg,
          letterSpacing: 0,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightCard,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: AppColors.lightBorder, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightMuted,
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.lightBorder, width: 1),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.lightBorder, width: 1),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.primaryLight, width: 1),
        ),
        labelStyle: const TextStyle(
          fontFamily: _ffMono,
          fontSize: 13,
          color: AppColors.lightMutedFg,
        ),
        hintStyle: const TextStyle(
          fontFamily: _ffSans,
          fontSize: 14,
          color: AppColors.lightMutedFg,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryLight,
          foregroundColor: AppColors.lightFg,
          disabledBackgroundColor: AppColors.lightMuted,
          disabledForegroundColor: AppColors.lightMutedFg,
          elevation: 0,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: const TextStyle(
            fontFamily: _ffMono,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.lightFg,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          textStyle: const TextStyle(
            fontFamily: _ffMono,
            fontSize: 13,
            letterSpacing: 0,
          ),
        ),
      ),
      iconTheme: const IconThemeData(color: AppColors.lightFg, size: 20),
      dividerTheme: const DividerThemeData(
        color: AppColors.lightDivider,
        thickness: 1,
        space: 0,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.lightBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: AppColors.lightBorder, width: 1),
        ),
        titleTextStyle: TextStyle(
          fontFamily: _ffMono,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.lightFg,
          letterSpacing: 0,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primaryLight;
          return AppColors.lightMutedFg;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primaryLight.withValues(alpha: 0.3);
          return AppColors.lightMuted;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((_) => Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primaryLight;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.resolveWith((_) => AppColors.lightFg),
        side: const BorderSide(color: AppColors.lightBorder, width: 1),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primaryLight;
          return AppColors.lightFg;
        }),
      ),
      listTileTheme: const ListTileThemeData(
        titleTextStyle: TextStyle(
          fontFamily: _ffSans,
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: AppColors.lightFg,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: _ffSans,
          fontSize: 13,
          color: AppColors.lightMutedFg,
        ),
        leadingAndTrailingTextStyle: TextStyle(
          fontFamily: _ffMono,
          fontSize: 13,
          color: AppColors.lightFg,
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontFamily: _ffMono, fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.lightFg, letterSpacing: 0),
        headlineMedium: TextStyle(fontFamily: _ffMono, fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.lightFg, letterSpacing: 0),
        titleLarge: TextStyle(fontFamily: _ffSans, fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.lightFg),
        titleMedium: TextStyle(fontFamily: _ffSans, fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.lightFg),
        bodyLarge: TextStyle(fontFamily: _ffSans, fontSize: 15, color: AppColors.lightFg),
        bodyMedium: TextStyle(fontFamily: _ffSans, fontSize: 14, color: AppColors.lightFg),
        bodySmall: TextStyle(fontFamily: _ffSans, fontSize: 12, color: AppColors.lightMutedFg),
        labelLarge: TextStyle(fontFamily: _ffMono, fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.lightFg, letterSpacing: 0),
        labelSmall: TextStyle(fontFamily: _ffMono, fontSize: 11, color: AppColors.lightMutedFg),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.lightMuted,
        labelStyle: const TextStyle(fontFamily: _ffMono, fontSize: 12, color: AppColors.lightFg),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: AppColors.lightBorder, width: 1),
        ),
        side: const BorderSide(color: AppColors.lightBorder, width: 1),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryLight,
        foregroundColor: AppColors.lightFg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.lightMuted,
        contentTextStyle: const TextStyle(fontFamily: _ffSans, fontSize: 14, color: AppColors.lightFg),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: AppColors.lightBorder, width: 1),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.lightBg,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: AppColors.lightBorder, width: 1),
        ),
        textStyle: const TextStyle(fontFamily: _ffSans, fontSize: 14, color: AppColors.lightFg),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.lightBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: AppColors.lightBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primaryLight,
        linearMinHeight: 2,
      ),
    );
  }
}
