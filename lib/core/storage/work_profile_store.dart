import 'package:uuid/uuid.dart';

import 'storage_service.dart';

class WorkProfileStore {
  static const _uuid = Uuid();

  static List<Map> getAll() {
    return StorageService.workProfiles.keys.map((key) {
        return <dynamic, dynamic>{
          'id': key,
          ...Map.from(StorageService.workProfiles.get(key) as Map),
        };
      }).toList()
      ..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
  }

  static Map? getById(String id) {
    final value = StorageService.workProfiles.get(id);
    if (value == null) return null;
    return <dynamic, dynamic>{'id': id, ...Map.from(value as Map)};
  }

  static Future<String> create(String name) async {
    final id = _uuid.v4();
    await StorageService.workProfiles.put(id, {
      'name': name.trim(),
      'enabled': true,
      'appExecutables': <String>[],
      'sourceFolders': <String>[],
      'sourceLists': <String>[],
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
    return id;
  }

  static Future<void> update(String id, Map changes) async {
    final existing = StorageService.workProfiles.get(id);
    if (existing == null) return;
    final updated = Map<String, dynamic>.from(existing as Map)
      ..addAll(Map<String, dynamic>.from(changes));
    await StorageService.workProfiles.put(id, updated);
  }

  static Future<void> addAppExecutable(String id, String executable) async {
    final normalized = executable.trim().toLowerCase();
    if (normalized.isEmpty) return;

    // An app belongs to one profile. Moving it is safer than silently using
    // the first matching profile.
    for (final profile in getAll()) {
      final apps = _strings(profile['appExecutables']);
      if (apps.map((value) => value.toLowerCase()).contains(normalized)) {
        apps.removeWhere((value) => value.toLowerCase() == normalized);
        await update(profile['id'].toString(), {'appExecutables': apps});
      }
    }

    final current = getById(id);
    if (current == null) return;
    final apps = _strings(current['appExecutables']);
    if (!apps.map((value) => value.toLowerCase()).contains(normalized)) {
      apps.add(executable.trim());
      await update(id, {'appExecutables': apps});
    }
  }

  static Future<void> removeAppExecutable(String id, String executable) async {
    final profile = getById(id);
    if (profile == null) return;
    final apps = _strings(profile['appExecutables'])
      ..removeWhere((value) => value.toLowerCase() == executable.toLowerCase());
    await update(id, {'appExecutables': apps});
  }

  static Future<void> addSource(
    String id,
    String source, {
    required bool folder,
  }) async {
    final profile = getById(id);
    if (profile == null) return;
    final key = folder ? 'sourceFolders' : 'sourceLists';
    final sources = _strings(profile[key]);
    if (!sources.contains(source)) sources.add(source);
    await update(id, {key: sources});
  }

  static Map? findForExecutable(String? executable) {
    if (executable == null || executable.isEmpty) return null;
    final target = executable.toLowerCase();
    for (final profile in getAll()) {
      if (profile['enabled'] != true) continue;
      if (_strings(
        profile['appExecutables'],
      ).map((value) => value.toLowerCase()).contains(target)) {
        return profile;
      }
    }
    return null;
  }

  static Future<void> delete(String id) async =>
      StorageService.workProfiles.delete(id);

  static List<String> _strings(Object? value) => value is Iterable
      ? value.map((item) => item.toString()).toList()
      : <String>[];
}
