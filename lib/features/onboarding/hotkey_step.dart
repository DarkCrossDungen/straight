import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:straight/shared/theme/colors.dart';
import 'package:straight/core/hotkey/hotkey_service.dart';
import 'package:straight/core/storage/settings_store.dart';

class HotkeyStep extends StatefulWidget {
  const HotkeyStep({super.key});

  @override
  State<HotkeyStep> createState() => _HotkeyStepState();
}

class _HotkeyStepState extends State<HotkeyStep> {
  bool _capturing = false;
  String _hotkey = 'Alt + Space';

  @override
  void initState() {
    super.initState();
    _loadCurrentHotkey();
  }

  void _loadCurrentHotkey() {
    final stored = SettingsStore.getHotkey();
    final parts = <String>[];
    if (stored['alt'] == true) parts.add('Alt');
    if (stored['ctrl'] == true) parts.add('Ctrl');
    if (stored['shift'] == true) parts.add('Shift');
    if (stored['meta'] == true) parts.add('Meta');
    parts.add((stored['key'] ?? 'Space').toString());
    _hotkey = parts.join(' + ');
  }

  void _startCapture() {
    setState(() {
      _capturing = true;
    });
    HardwareKeyboard.instance.addHandler(_onKeyEvent);
  }

  void _stopCapture() {
    HardwareKeyboard.instance.removeHandler(_onKeyEvent);
    setState(() => _capturing = false);
  }

  bool _onKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    final key = event.logicalKey;
    final modifiers = <HotKeyModifier>{};

    if (HardwareKeyboard.instance.isAltPressed) modifiers.add(HotKeyModifier.alt);
    if (HardwareKeyboard.instance.isControlPressed) modifiers.add(HotKeyModifier.control);
    if (HardwareKeyboard.instance.isShiftPressed) modifiers.add(HotKeyModifier.shift);
    if (HardwareKeyboard.instance.isMetaPressed) modifiers.add(HotKeyModifier.meta);

    if (key == LogicalKeyboardKey.alt ||
        key == LogicalKeyboardKey.control ||
        key == LogicalKeyboardKey.shift ||
        key == LogicalKeyboardKey.meta) {
      return false;
    }

    _stopCapture();
    _saveHotkey(key, modifiers);
    return true;
  }

  Future<void> _saveHotkey(LogicalKeyboardKey key, Set<HotKeyModifier> modifiers) async {
    final keyLabel = key.keyLabel;
    final hotkeyMap = {
      'alt': modifiers.contains(HotKeyModifier.alt),
      'ctrl': modifiers.contains(HotKeyModifier.control),
      'shift': modifiers.contains(HotKeyModifier.shift),
      'meta': modifiers.contains(HotKeyModifier.meta),
      'key': keyLabel,
    };

    await SettingsStore.setHotkey(hotkeyMap);

    final hotkey = HotKey(
      key: key,
      modifiers: modifiers.toList(),
    );
    await HotkeyService().registerHotkey(hotkey);

    _loadCurrentHotkey();
  }

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
              color: _capturing
                  ? (isDark ? AppColors.primaryDark : AppColors.primaryLight)
                  : (isDark ? AppColors.darkMuted : AppColors.lightMuted),
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
            onTap: _capturing ? null : _startCapture,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: _capturing
                    ? (isDark ? AppColors.primaryDark.withValues(alpha: 0.2) : AppColors.primaryLight.withValues(alpha: 0.2))
                    : (isDark ? AppColors.darkMuted : AppColors.lightMuted),
                border: Border.all(
                  color: _capturing ? primaryColor : fgColor.withValues(alpha: 0.3),
                  width: _capturing ? 2 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _capturing ? Icons.keyboard : Icons.keyboard,
                    color: _capturing ? primaryColor : fgColor,
                    size: 18,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _capturing ? 'PRESS KEYS...' : _hotkey,
                    style: TextStyle(
                      fontFamily: 'SF Mono',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _capturing ? primaryColor : fgColor,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _capturing ? 'Press any key combination' : 'Default: Alt + Space',
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
