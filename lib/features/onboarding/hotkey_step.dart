import 'package:flutter/material.dart';
import 'package:straight/shared/theme/colors.dart';

class HotkeyStep extends StatefulWidget {
  const HotkeyStep({super.key});

  @override
  State<HotkeyStep> createState() => _HotkeyStepState();
}

class _HotkeyStepState extends State<HotkeyStep> {
  String _hotkey = 'Alt + Space';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fgColor = isDark ? AppColors.darkFg : AppColors.lightFg;
    final primaryColor = isDark ? AppColors.primaryDark : AppColors.primaryLight;

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
            child: Icon(Icons.keyboard, size: 48, color: fgColor),
          ),
          const SizedBox(height: 48),
          Text(
            'SET YOUR HOTKEY',
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
            'Press a key combination to start/stop\ndictation from anywhere.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: fgColor.withValues(alpha: 0.7),
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => Dialog(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PRESS KEYS',
                          style: TextStyle(
                            fontFamily: 'SF Mono',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: fgColor,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Press your desired key\ncombination.',
                          style: TextStyle(
                            fontSize: 14,
                            color: fgColor.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            setState(() => _hotkey = 'Ctrl + Shift + D');
                            Navigator.pop(ctx);
                          },
                          child: const Text('CAPTURE CTRL+SHIFT+D'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                border: Border.all(color: primaryColor, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.keyboard, color: primaryColor, size: 18),
                  const SizedBox(width: 12),
                  Text(
                    _hotkey,
                    style: TextStyle(
                      fontFamily: 'SF Mono',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Default: Alt + Space',
            style: TextStyle(
              fontFamily: 'SF Mono',
              fontSize: 11,
              color: fgColor.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
