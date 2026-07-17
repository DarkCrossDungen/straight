import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:win32/win32.dart';
import '../storage/settings_store.dart';

class HotkeyService extends ChangeNotifier {
  static final HotkeyService _instance = HotkeyService._();
  factory HotkeyService() => _instance;
  HotkeyService._();

  HotKey _currentHotkey = HotKey(
    key: LogicalKeyboardKey.space,
    modifiers: [HotKeyModifier.control, HotKeyModifier.alt],
  );

  HotKey get currentHotkey => _currentHotkey;

  VoidCallback? _onHotkeyTriggered;
  VoidCallback? _onKeyDown;
  VoidCallback? _onKeyUp;
  HotKey? _registeredHotkey;
  DateTime? _lastToggleAt;
  String? _registrationError;

  String? get registrationError => _registrationError;

  void init({VoidCallback? onHotkeyTriggered, VoidCallback? onKeyDown, VoidCallback? onKeyUp}) {
    _onHotkeyTriggered = onHotkeyTriggered;
    _onKeyDown = onKeyDown;
    _onKeyUp = onKeyUp;
  }

  HotKey _hotkeyFromStoredMap(Map hotkey) {
    final keyLabel = (hotkey['key'] ?? 'Space').toString();
    final key = _logicalKeyFromLabel(keyLabel);
    final modifiers = <HotKeyModifier>[];
    if (hotkey['alt'] == true) modifiers.add(HotKeyModifier.alt);
    if (hotkey['ctrl'] == true) modifiers.add(HotKeyModifier.control);
    if (hotkey['shift'] == true) modifiers.add(HotKeyModifier.shift);
    if (hotkey['meta'] == true) modifiers.add(HotKeyModifier.meta);
    return HotKey(key: key, modifiers: modifiers);
  }

  LogicalKeyboardKey _logicalKeyFromLabel(String label) {
    switch (label.toLowerCase()) {
      case 'space':
        return LogicalKeyboardKey.space;
      case 'enter':
        return LogicalKeyboardKey.enter;
      case 'tab':
        return LogicalKeyboardKey.tab;
      case 'escape':
        return LogicalKeyboardKey.escape;
      default:
        if (label.length == 1) {
          return LogicalKeyboardKey(label.codeUnitAt(0));
        }
        return LogicalKeyboardKey.space;
    }
  }

  Future<bool> reloadFromSettings() async {
    final stored = SettingsStore.getHotkey();
    await stop();
    _currentHotkey = _hotkeyFromStoredMap(Map.from(stored));
    final registered = await start();
    notifyListeners();
    return registered;
  }

  Future<bool> start() async {
    if (_registeredHotkey != null) return true;

    try {
      final isPushToTalk = SettingsStore.getPushToTalk();
      if (isPushToTalk) {
        await hotKeyManager.register(
          _currentHotkey,
          keyDownHandler: (_) => _onKeyDown?.call(),
          keyUpHandler: (_) => _onKeyUp?.call(),
        );
      } else {
        await hotKeyManager.register(
          _currentHotkey,
          keyDownHandler: (_) => _triggerToggle(),
        );
      }
      _registeredHotkey = _currentHotkey;
      _registrationError = null;
      return true;
    } catch (e) {
      _registeredHotkey = null;
      _registrationError = e.toString();
      debugPrint('Hotkey registration failed: $_registrationError');
      notifyListeners();
      return false;
    }
  }

  void _triggerToggle() {
    // Windows can repeat WM_HOTKEY while the keys are still held. Without a
    // short guard, one press can stop dictation and immediately start it again.
    final now = DateTime.now();
    if (_lastToggleAt != null && now.difference(_lastToggleAt!).inMilliseconds < 800) {
      return;
    }
    _lastToggleAt = now;
    _onHotkeyTriggered?.call();
  }

  Future<void> stop() async {
    final hotkey = _registeredHotkey;
    if (hotkey == null) return;

    try {
      await hotKeyManager.unregister(hotkey);
    } catch (e) {
      debugPrint('Hotkey unregister failed: $e');
    } finally {
      _registeredHotkey = null;
    }
  }

  Future<bool> registerHotkey(HotKey hotkey) async {
    await stop();
    _currentHotkey = hotkey;
    final registered = await start();
    notifyListeners();
    return registered;
  }

  /// Windows RegisterHotKey emits WM_HOTKEY on press but has no matching
  /// release message. Poll the physical state only while dictating so
  /// push-to-talk can still stop as soon as a key is released.
  bool isCurrentHotkeyHeld() {
    if (!Platform.isWindows) return false;
    final stored = SettingsStore.getHotkey();
    final keys = <int>[
      if (stored['alt'] == true) VK_MENU,
      if (stored['ctrl'] == true) VK_CONTROL,
      if (stored['shift'] == true) VK_SHIFT,
      if (stored['meta'] == true) VK_LWIN,
      _virtualKeyFromLabel((stored['key'] ?? 'Space').toString()),
    ];
    return keys.every((key) => (GetAsyncKeyState(key) & 0x8000) != 0);
  }

  int _virtualKeyFromLabel(String label) {
    switch (label.toLowerCase()) {
      case 'space':
        return VK_SPACE;
      case 'enter':
        return VK_RETURN;
      case 'tab':
        return VK_TAB;
      case 'escape':
        return VK_ESCAPE;
      default:
        if (label.length == 1) return label.toUpperCase().codeUnitAt(0);
        return VK_SPACE;
    }
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
