import 'package:hive_flutter/hive_flutter.dart';

class StorageService {
  static final settings = Hive.box('settings');
  static final dictionary = Hive.box('dictionary');
  static final history = Hive.box('history');
  static final snippets = Hive.box('snippets');
  static final workProfiles = Hive.box('workProfiles');

  Future<void> clearAll() async {
    await settings.clear();
    await dictionary.clear();
    await history.clear();
    await workProfiles.clear();
  }

  Map<String, int> stats() {
    return {
      'settings': settings.length,
      'dictionary': dictionary.length,
      'history': history.length,
      'workProfiles': workProfiles.length,
    };
  }
}
