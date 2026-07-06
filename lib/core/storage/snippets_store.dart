import 'storage_service.dart';

class SnippetsStore {
  static List<Map> getAll() {
    final entries = StorageService.snippets.values;
    final list = entries.map((e) => e as Map).toList();
    list.sort((a, b) => ((a['name'] ?? '') as String).compareTo(b['name'] ?? ''));
    return list;
  }

  static List<Map> search(String query) {
    final q = query.toLowerCase();
    return getAll().where((e) {
      final name = (e['name'] ?? '').toString().toLowerCase();
      final content = (e['content'] ?? '').toString().toLowerCase();
      return name.contains(q) || content.contains(q);
    }).toList();
  }

  static Future<void> addSnippet(String name, String content) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    await StorageService.snippets.put(id, {
      'id': id,
      'name': name,
      'content': content,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  static Future<void> updateSnippet(String id, Map updates) async {
    final existing = StorageService.snippets.get(id) as Map?;
    if (existing == null) return;
    existing.addAll(updates);
    await StorageService.snippets.put(id, existing);
  }

  static Future<void> deleteSnippet(String id) async {
    await StorageService.snippets.delete(id);
  }
}
