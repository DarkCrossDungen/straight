class WordReplacer {
  String process(String text, List<Map> dictionary) {
    if (text.isEmpty || dictionary.isEmpty) return text;

    var result = text;

    for (final entry in dictionary) {
      if (entry['enabled'] != true) continue;

      final word = (entry['word'] as String? ?? '').trim();
      final replacement = (entry['replacement'] as String? ?? '').trim();
      if (word.isEmpty || replacement.isEmpty) continue;

      final aliases = <String>[word];
      final storedAliases = entry['aliases'];
      if (storedAliases is Iterable) {
        aliases.addAll(storedAliases.whereType<String>().map((value) => value.trim()));
      }

      // Long phrases go first so a specific pronunciation alias is never
      // partially replaced by a shorter dictionary entry.
      aliases.sort((a, b) => b.length.compareTo(a.length));
      for (final alias in aliases.toSet()) {
        if (alias.isEmpty) continue;
        final pattern = RegExp(
          r'(?<![A-Za-z0-9])' + RegExp.escape(alias) + r'(?![A-Za-z0-9])',
          caseSensitive: false,
        );
        result = result.replaceAll(pattern, replacement);
      }
    }

    return result;
  }
}
