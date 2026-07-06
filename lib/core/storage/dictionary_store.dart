import 'package:uuid/uuid.dart';
import 'storage_service.dart';

class DictionaryStore {
  static const _uuid = Uuid();

  static List<Map> getAll() {
    final box = StorageService.dictionary;
    return box.keys.map((key) {
      return <dynamic, dynamic>{
        'id': key,
        ...Map.from(box.get(key) as Map),
      };
    }).toList();
  }

  static Future<void> addWord(String word, String replacement) async {
    final id = _uuid.v4();
    await StorageService.dictionary.put(id, {
      'word': word,
      'replacement': replacement,
      'enabled': true,
    });
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
        .map((key) => <dynamic, dynamic>{
              'id': key,
              ...Map.from(box.get(key) as Map),
            })
        .where((entry) {
          final word = (entry['word'] as String).toLowerCase();
          final replacement = (entry['replacement'] as String).toLowerCase();
          return word.contains(lower) || replacement.contains(lower);
        })
        .toList();
  }
}
