class WordReplacer {
  String process(String text, List<Map> dictionary) {
    if (text.isEmpty || dictionary.isEmpty) return text;

    var result = text;

    for (final entry in dictionary) {
      if (entry['enabled'] != true) continue;

      final word = entry['word'] as String;
      final replacement = entry['replacement'] as String;
      if (word.isEmpty || replacement.isEmpty) continue;

      final pattern = RegExp(
        r'\b' + RegExp.escape(word) + r'\b',
        caseSensitive: false,
      );
      result = result.replaceAll(pattern, replacement);
    }

    return result;
  }
}
