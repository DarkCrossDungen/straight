import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
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

  Future<void> reloadFromSettings() async {
    final stored = SettingsStore.getHotkey();
    await stop();
    _currentHotkey = _hotkeyFromStoredMap(Map.from(stored));
    await start();
    notifyListeners();
  }

  Future<void> start() async {
    if (_registeredHotkey != null) return;

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
    } catch (e) {
      _registeredHotkey = null;
      debugPrint('Hotkey registration failed: $e');
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

  Future<void> registerHotkey(HotKey hotkey) async {
    await stop();
    _currentHotkey = hotkey;
    await start();
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
