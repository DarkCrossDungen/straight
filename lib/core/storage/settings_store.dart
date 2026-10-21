import 'package:hive_flutter/hive_flutter.dart';
import 'storage_service.dart';

class SettingsStore {
  static const defaultSttModel = 'whisper-base';
  static const defaultLlmModel = 'none';

  static const _defaultHotkey = {
    'alt': true,
    'ctrl': false,
    'shift': false,
    'key': 'Space',
  };

  static String getThemeMode() {
    try {
      if (Hive.isBoxOpen('settings')) {
        return StorageService.settings.get('theme', defaultValue: 'dark') as String;
      }
    } catch (_) {}
    return 'dark';
  }

  static Future<void> setThemeMode(String value) async {
    try {
      if (Hive.isBoxOpen('settings')) {
        await StorageService.settings.put('theme', value);
      }
    } catch (_) {}
  }

  static Map getHotkey() {
    try {
      if (Hive.isBoxOpen('settings')) {
        return StorageService.settings.get('hotkey', defaultValue: _defaultHotkey) as Map;
      }
    } catch (_) {}
    return _defaultHotkey;
  }

  static Future<void> setHotkey(Map value) async {
    try {
      if (Hive.isBoxOpen('settings')) {
        await StorageService.settings.put('hotkey', value);
      }
    } catch (_) {}
  }

  static String getSttModel() {
    try {
      if (Hive.isBoxOpen('settings')) {
        return StorageService.settings.get('sttModel', defaultValue: defaultSttModel) as String;
      }
    } catch (_) {}
    return defaultSttModel;
  }

  static Future<void> setSttModel(String value) async {
    try {
      if (Hive.isBoxOpen('settings')) {
        await StorageService.settings.put('sttModel', value);
      }
    } catch (_) {}
  }

  static String getLlmModel() {
    try {
      if (Hive.isBoxOpen('settings')) {
        return StorageService.settings.get('llmModel', defaultValue: defaultLlmModel) as String;
      }
    } catch (_) {}
    return defaultLlmModel;
  }

  static Future<void> setLlmModel(String value) async {
    try {
      if (Hive.isBoxOpen('settings')) {
        await StorageService.settings.put('llmModel', value);
      }
    } catch (_) {}
  }

  static bool getStartOnBoot() {
    try {
      if (Hive.isBoxOpen('settings')) {
        return StorageService.settings.get('startOnBoot', defaultValue: false) as bool;
      }
    } catch (_) {}
    return false;
  }

  static Future<void> setStartOnBoot(bool value) async {
    try {
      if (Hive.isBoxOpen('settings')) {
        await StorageService.settings.put('startOnBoot', value);
      }
    } catch (_) {}
  }

  static bool getPushToTalk() {
    try {
      if (Hive.isBoxOpen('settings')) {
        return StorageService.settings.get('pushToTalk', defaultValue: false) as bool;
      }
    } catch (_) {}
    return false;
  }

  static Future<void> setPushToTalk(bool value) async {
    try {
      if (Hive.isBoxOpen('settings')) {
        await StorageService.settings.put('pushToTalk', value);
      }
    } catch (_) {}
  }

  static bool getWhisperMode() {
    try {
      if (Hive.isBoxOpen('settings')) {
        return StorageService.settings.get('whisperMode', defaultValue: false) as bool;
      }
    } catch (_) {}
    return false;
  }

  static Future<void> setWhisperMode(bool value) async {
    try {
      if (Hive.isBoxOpen('settings')) {
        await StorageService.settings.put('whisperMode', value);
      }
    } catch (_) {}
  }
}
