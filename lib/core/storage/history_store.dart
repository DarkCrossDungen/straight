import 'storage_service.dart';

class HistoryStore {
  static List<Map> getAll({int? limit, int? offset}) {
    final box = StorageService.history;
    final entries = box.keys.map((key) {
      return <dynamic, dynamic>{
        'key': key,
        ...Map.from(box.get(key) as Map),
      };
    }).toList()
      ..sort((a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int));

    final start = offset ?? 0;
    if (limit != null) {
      return entries.skip(start).take(limit).toList();
    }
    return entries.skip(start).toList();
  }

  static Future<void> addEntry(Map entry) async {
    final key = '${entry['timestamp']}';
    await StorageService.history.put(key, entry);
  }

  static Future<void> deleteEntry(String key) async {
    await StorageService.history.delete(key);
  }

  static Future<void> clearAll() async {
    await StorageService.history.clear();
  }

  static List<Map> search(String query) {
    final lower = query.toLowerCase();
    final box = StorageService.history;
    return box.keys
        .map((key) => <dynamic, dynamic>{
              'key': key,
              ...Map.from(box.get(key) as Map),
            })
        .where((entry) {
          final text = (entry['text'] as String).toLowerCase();
          final appliedText = (entry['appliedText'] as String).toLowerCase();
          return text.contains(lower) || appliedText.contains(lower);
        })
        .toList()
      ..sort((a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int));
  }

  static Map<String, int> getStats() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = todayStart.subtract(Duration(days: todayStart.weekday - 1));

    int total = 0;
    int today = 0;
    int thisWeek = 0;

    for (final entry in StorageService.history.values) {
      final ts = (entry as Map)['timestamp'] as int;
      total++;
      final date = DateTime.fromMillisecondsSinceEpoch(ts);
      if (date.isAfter(todayStart)) {
        today++;
      }
      if (date.isAfter(weekStart)) {
        thisWeek++;
      }
    }

    return {
      'total': total,
      'today': today,
      'thisWeek': thisWeek,
    };
  }
}
