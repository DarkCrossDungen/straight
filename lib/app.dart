import 'package:flutter/material.dart';
import 'core/app_navigation.dart';
import 'shared/theme/app_theme.dart';
import 'core/storage/settings_store.dart';
import 'features/bubble/bubble_overlay.dart';
import 'features/settings/settings_page.dart';
import 'features/dictionary/dictionary_page.dart';
import 'features/dictionary/work_profiles_page.dart';
import 'features/history/history_page.dart';
import 'features/onboarding/onboarding_page.dart';
import 'features/setup/setup_page.dart';

/// Decides between first-run setup and the app itself.
///
/// Every build re-reads the flag, so once setup finishes and replaces this
/// route the gate hands over to the app immediately and cannot bounce back.
class _LaunchGate extends StatefulWidget {
  const _LaunchGate();

  @override
  State<_LaunchGate> createState() => _LaunchGateState();
}

class _LaunchGateState extends State<_LaunchGate> {
  bool get _setupDone => SettingsStore.getSetupCompleted();

  @override
  void initState() {
    super.initState();
    if (!_setupDone) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/setup');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_setupDone) return const BubbleOverlay();
    // The setup route takes over on the next frame.
    return const Scaffold(
      body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}

class StraightApp extends StatelessWidget {
  const StraightApp({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = SettingsStore.getThemeMode() == 'dark';
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'Straight',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      home: const _LaunchGate(),
      routes: {
        '/setup': (_) => const SetupPage(),
        '/settings': (_) => const SettingsPage(),
        '/dictionary': (_) => const DictionaryPage(),
        '/work-profiles': (_) => const WorkProfilesPage(),
        '/history': (_) => const HistoryPage(),
        '/onboarding': (_) => const OnboardingPage(),
      },
    );
  }
}
