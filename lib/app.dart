import 'package:flutter/material.dart';
import 'shared/theme/app_theme.dart';
import 'core/storage/settings_store.dart';
import 'features/bubble/bubble_overlay.dart';
import 'features/settings/settings_page.dart';
import 'features/dictionary/dictionary_page.dart';
import 'features/history/history_page.dart';
import 'features/onboarding/onboarding_page.dart';

class StraightApp extends StatelessWidget {
  const StraightApp({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = SettingsStore.getThemeMode() == 'dark';
    return MaterialApp(
      title: 'Straight',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      home: const BubbleOverlay(),
      routes: {
        '/settings': (_) => const SettingsPage(),
        '/dictionary': (_) => const DictionaryPage(),
        '/history': (_) => const HistoryPage(),
        '/onboarding': (_) => const OnboardingPage(),
      },
    );
  }
}
