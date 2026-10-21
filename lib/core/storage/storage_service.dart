import 'package:hive_flutter/hive_flutter.dart';

class StorageService {
  static Box get settings => Hive.box('settings');
  static Box get dictionary => Hive.box('dictionary');
  static Box get history => Hive.box('history');
  static Box get snippets => Hive.box('snippets');

  Future<void> clearAll() async {
    await settings.clear();
    await dictionary.clear();
    await history.clear();
  }

  Map<String, int> stats() {
    return {
      'settings': settings.length,
      'dictionary': dictionary.length,
      'history': history.length,
    };
  }
}
