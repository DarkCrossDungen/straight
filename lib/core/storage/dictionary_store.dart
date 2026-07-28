import 'package:uuid/uuid.dart';
import 'storage_service.dart';

class DictionaryStore {
  static const _uuid = Uuid();

  static List<Map> getAll() {
    final box = StorageService.dictionary;
    return box.keys.map((key) {
      return <dynamic, dynamic>{'id': key, ...Map.from(box.get(key) as Map)};
    }).toList();
  }

  static Future<void> addWord(
    String word,
    String replacement, {
    Iterable<String> aliases = const [],
    String? profileId,
    String source = 'manual',
  }) async {
    final id = _uuid.v4();
    await StorageService.dictionary.put(id, {
      'word': word,
      'replacement': replacement,
      'aliases': aliases
          .map((alias) => alias.trim())
          .where(
            (alias) =>
                alias.isNotEmpty && alias.toLowerCase() != word.toLowerCase(),
          )
          .toSet()
          .toList(),
      'enabled': true,
      'profileId': profileId,
      'source': source,
    });
  }

  static List<Map> getForProfile(String? profileId) {
    final entries = getAll().where((entry) {
      final entryProfile = entry['profileId'];
      return entryProfile == null || entryProfile == profileId;
    }).toList();

    // Profile entries are intentionally last. WordReplacer applies later
    // entries after global entries, so the active profile wins a collision.
    entries.sort((a, b) {
      final aProfile = a['profileId'] == profileId && profileId != null;
      final bProfile = b['profileId'] == profileId && profileId != null;
      if (aProfile == bProfile) return 0;
      return aProfile ? 1 : -1;
    });
    return entries;
  }

  static Future<bool> addImportedTerm(
    String replacement, {
    required String profileId,
    required String source,
    Iterable<String> aliases = const [],
  }) async {
    final normalizedReplacement = replacement.trim();
    if (normalizedReplacement.isEmpty) return false;

    final existing = getAll().cast<Map?>().firstWhere(
      (entry) =>
          entry?['profileId'] == profileId &&
          (entry?['replacement']?.toString().toLowerCase() ?? '') ==
              normalizedReplacement.toLowerCase(),
      orElse: () => null,
    );
    if (existing != null) return false;

    await addWord(
      normalizedReplacement,
      normalizedReplacement,
      aliases: aliases,
      profileId: profileId,
      source: source,
    );
    return true;
  }

  static Future<void> deleteForProfile(String profileId) async {
    final ids = getAll()
        .where((entry) => entry['profileId'] == profileId)
        .map((entry) => entry['id'].toString())
        .toList();
    for (final id in ids) {
      await deleteWord(id);
    }
  }

  static Future<void> updateWord(String id, Map changes) async {
    final existing = StorageService.dictionary.get(id);
    if (existing != null) {
      final updated = Map<String, dynamic>.from(existing as Map)
        ..addAll(Map<String, dynamic>.from(changes));
      await StorageService.dictionary.put(id, updated);
    }
  }

  static Future<void> deleteWord(String id) async {
    await StorageService.dictionary.delete(id);
  }

  static List<Map> search(String query) {
    final lower = query.toLowerCase();
    final box = StorageService.dictionary;
    return box.keys
        .map(
          (key) => <dynamic, dynamic>{
            'id': key,
            ...Map.from(box.get(key) as Map),
          },
        )
        .where((entry) {
          final word = (entry['word'] as String).toLowerCase();
          final replacement = (entry['replacement'] as String).toLowerCase();
          return word.contains(lower) || replacement.contains(lower);
        })
        .toList();
  }
}
