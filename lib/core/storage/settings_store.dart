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

  static String getThemeMode() =>
      StorageService.settings.get('theme', defaultValue: 'dark') as String;

  static Future<void> setThemeMode(String value) async =>
      StorageService.settings.put('theme', value);

  static Map getHotkey() =>
      StorageService.settings.get('hotkey', defaultValue: _defaultHotkey) as Map;

  static Future<void> setHotkey(Map value) async =>
      StorageService.settings.put('hotkey', value);

  static String getSttModel() =>
      StorageService.settings.get('sttModel', defaultValue: defaultSttModel) as String;

  static Future<void> setSttModel(String value) async =>
      StorageService.settings.put('sttModel', value);

  static String getLlmModel() =>
      StorageService.settings.get('llmModel', defaultValue: defaultLlmModel) as String;

  static Future<void> setLlmModel(String value) async =>
      StorageService.settings.put('llmModel', value);

  static bool getStartOnBoot() =>
      StorageService.settings.get('startOnBoot', defaultValue: false) as bool;

  static Future<void> setStartOnBoot(bool value) async =>
      StorageService.settings.put('startOnBoot', value);

  static bool getPushToTalk() =>
      StorageService.settings.get('pushToTalk', defaultValue: false) as bool;

  static Future<void> setPushToTalk(bool value) async =>
      StorageService.settings.put('pushToTalk', value);
}
