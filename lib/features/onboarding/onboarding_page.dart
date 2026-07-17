import 'package:flutter/material.dart';
import 'package:straight/features/onboarding/hotkey_step.dart';
import 'package:straight/features/onboarding/mic_test_step.dart';
import 'package:straight/features/onboarding/permission_step.dart';
import 'package:straight/features/onboarding/tutorial_step.dart';
import 'package:straight/shared/theme/colors.dart';
import 'package:straight/shared/widgets/app_surface.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _controller = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goNext() {
    if (_currentPage < 4) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    } else {
      Navigator.pushReplacementNamed(context, '/');
    }
  }

  void _goBack() {
    if (_currentPage > 0) {
      _controller.previousPage(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pages = <Widget>[
      const _WelcomePage(),
      const PermissionStep(),
      const HotkeyStep(),
      const MicTestStep(),
      const TutorialStep(),
    ];

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemCount: pages.length,
                itemBuilder: (context, index) => pages[index],
              ),
            ),
            _bottomNav(isDark),
          ],
        ),
      ),
    );
  }

  Widget _bottomNav(bool isDark) {
    final isLast = _currentPage == 4;
    final isFirst = _currentPage == 0;
    final showSkip = _currentPage < 3;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
      child: AppSurface(
        shadow: false,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            if (!isFirst)
              TextButton(onPressed: _goBack, child: const Text('BACK'))
            else
              const SizedBox(width: 72),
            Expanded(child: _dots(isDark)),
            if (showSkip)
              TextButton(
                onPressed: () => _controller.jumpToPage(4),
                child: const Text('SKIP'),
              )
            else
              ElevatedButton(
                onPressed: _goNext,
                child: Text(isLast ? 'GET STARTED' : 'NEXT'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _dots(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final active = i == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 26 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active
                ? (isDark ? AppColors.primaryDark : AppColors.primaryLight)
                : (isDark ? AppColors.darkMutedFg : AppColors.lightMutedFg),
            border: Border.all(
              color: isDark ? AppColors.darkFg : AppColors.lightFg,
              width: 1,
            ),
          ),
        );
      }),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: AppSurface(
        padding: EdgeInsets.zero,
        shadow: true,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 134,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        border: Border.all(
                          color: scheme.primary.withValues(alpha: 0.35),
                        ),
                        borderRadius: const BorderRadius.all(
                          Radius.circular(40),
                        ),
                      ),
                      child: Icon(
                        Icons.mic_none_rounded,
                        size: 28,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Straight',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 12),
                    const AppBadge(label: 'Offline Windows Dictation'),
                    const SizedBox(height: 18),
                    Text(
                      'Speak naturally. Straight cleans up your words and types them into the app already in front of you.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(height: 1.45),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
