import 'package:hive_flutter/hive_flutter.dart';

class StorageService {
  static final settings = Hive.box('settings');
  static final dictionary = Hive.box('dictionary');
  static final history = Hive.box('history');
  static final snippets = Hive.box('snippets');

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
