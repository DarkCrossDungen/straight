import 'package:flutter/material.dart';
import 'package:straight/shared/theme/colors.dart';
import 'package:straight/features/onboarding/permission_step.dart';
import 'package:straight/features/onboarding/hotkey_step.dart';
import 'package:straight/features/onboarding/mic_test_step.dart';
import 'package:straight/features/onboarding/tutorial_step.dart';

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
        duration: const Duration(milliseconds: 150),
        curve: Curves.linear,
      );
    } else {
      Navigator.pushReplacementNamed(context, '/');
    }
  }

  void _goBack() {
    if (_currentPage > 0) {
      _controller.previousPage(
        duration: const Duration(milliseconds: 150),
        curve: Curves.linear,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;
    final fgColor = isDark ? AppColors.darkFg : AppColors.lightFg;

    final pages = <Widget>[
      _WelcomePage(fgColor: fgColor),
      const PermissionStep(),
      const HotkeyStep(),
      const MicTestStep(),
      const TutorialStep(),
    ];

    return Scaffold(
      backgroundColor: bgColor,
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
            _buildBottomNav(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav(bool isDark) {
    final isLast = _currentPage == 4;
    final isFirst = _currentPage == 0;
    final showSkip = _currentPage < 3;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDots(isDark),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (!isFirst)
                TextButton(
                  onPressed: _goBack,
                  child: const Text('BACK'),
                )
              else
                const SizedBox(width: 72),
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
        ],
      ),
    );
  }

  Widget _buildDots(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final isActive = i == _currentPage;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 24 : 8,
          height: 4,
          color: isActive
              ? (isDark ? AppColors.primaryDark : AppColors.primaryLight)
              : (isDark ? AppColors.darkMutedFg : AppColors.lightMutedFg),
        );
      }),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  final Color fgColor;

  const _WelcomePage({required this.fgColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: fgColor,
              border: Border.all(color: fgColor, width: 1),
            ),
            child: Icon(Icons.record_voice_over, size: 48, color: fgColor == Colors.white ? Colors.black : Colors.white),
          ),
          const SizedBox(height: 48),
          Text(
            'STRAIGHT',
            style: TextStyle(
              fontFamily: 'SF Mono',
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: fgColor,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'DICTATE. STRAIGHT.',
            style: TextStyle(
              fontFamily: 'SF Mono',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: fgColor.withValues(alpha: 0.5),
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Dictate text anywhere with your voice.\nFast, accurate, and always ready.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              color: fgColor.withValues(alpha: 0.7),
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
