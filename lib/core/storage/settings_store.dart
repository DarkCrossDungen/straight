import 'storage_service.dart';

class SettingsStore {
  static const defaultSttModel = 'whisper-small';
  static const defaultLlmModel = 'none';
  static const _whisperSmallMigrationKey = 'migratedToWhisperSmallDefault';
  static const _pushToTalkMigrationKey = 'migratedToPushToTalkDefault';

  static const _defaultHotkey = {
    'alt': true,
    'ctrl': true,
    'shift': false,
    'key': 'Space',
  };

  static const _oldReservedDefaultHotkey = {
    'alt': true,
    'ctrl': false,
    'shift': false,
    'key': 'Space',
  };

  static String getThemeMode() =>
      StorageService.settings.get('theme', defaultValue: 'dark') as String;

  static Future<void> setThemeMode(String value) async =>
      StorageService.settings.put('theme', value);

  static Map getHotkey() {
    final value = StorageService.settings.get('hotkey', defaultValue: _defaultHotkey) as Map;
    if (_isOldReservedDefault(value)) return _defaultHotkey;
    return value;
  }

  static Future<void> setHotkey(Map value) async =>
      StorageService.settings.put('hotkey', value);

  static bool _isOldReservedDefault(Map value) {
    for (final entry in _oldReservedDefaultHotkey.entries) {
      if (value[entry.key] != entry.value) return false;
    }
    return value['meta'] != true;
  }

  static String getSttModel() =>
      StorageService.settings.get('sttModel', defaultValue: defaultSttModel) as String;

  static Future<void> setSttModel(String value) async =>
      StorageService.settings.put('sttModel', value);

  static Future<void> migrateDefaultSttModelToWhisperSmall() async {
    final migrated =
        StorageService.settings.get(_whisperSmallMigrationKey, defaultValue: false) as bool;
    if (migrated) return;

    final current =
        StorageService.settings.get('sttModel', defaultValue: 'whisper-base') as String;
    if (current == 'whisper-base') {
      await StorageService.settings.put('sttModel', defaultSttModel);
    }
    await StorageService.settings.put(_whisperSmallMigrationKey, true);
  }

  static Future<void> migrateDefaultBehaviorToPushToTalk() async {
    final migrated =
        StorageService.settings.get(_pushToTalkMigrationKey, defaultValue: false) as bool;
    if (migrated) return;

    final current = StorageService.settings.get('pushToTalk', defaultValue: false) as bool;
    if (!current) {
      await StorageService.settings.put('pushToTalk', true);
    }
    await StorageService.settings.put(_pushToTalkMigrationKey, true);
  }

  static String getLlmModel() =>
      StorageService.settings.get('llmModel', defaultValue: defaultLlmModel) as String;

  static Future<void> setLlmModel(String value) async =>
      StorageService.settings.put('llmModel', value);

  static bool getStartOnBoot() =>
      StorageService.settings.get('startOnBoot', defaultValue: false) as bool;

  static Future<void> setStartOnBoot(bool value) async =>
      StorageService.settings.put('startOnBoot', value);

  static bool getPushToTalk() =>
      StorageService.settings.get('pushToTalk', defaultValue: true) as bool;

  static Future<void> setPushToTalk(bool value) async =>
      StorageService.settings.put('pushToTalk', value);
}
