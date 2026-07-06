import 'package:flutter/material.dart';
import 'package:straight/shared/theme/colors.dart';

class TutorialStep extends StatelessWidget {
  const TutorialStep({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fgColor = isDark ? AppColors.darkFg : AppColors.lightFg;
    final primaryColor = isDark ? AppColors.primaryDark : AppColors.primaryLight;

    final items = [
      'Press your hotkey to start dictation',
      'Speak naturally and clearly',
      'Press hotkey again to stop',
      'Text is injected at your cursor',
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
              border: Border.all(color: fgColor, width: 1),
            ),
            child: Icon(Icons.touch_app, size: 48, color: fgColor),
          ),
          const SizedBox(height: 48),
          Text(
            'HOW TO USE',
            style: TextStyle(
              fontFamily: 'SF Mono',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fgColor,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Press your hotkey, speak naturally,\nand your words appear as text.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: fgColor.withValues(alpha: 0.7),
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ...List.generate(items.length, (i) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    color: primaryColor,
                    child: const Icon(Icons.check, size: 14, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      items[i],
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: fgColor,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
