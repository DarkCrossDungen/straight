class SnippetExpander {
  String process(String text, List<Map> snippets) {
    if (text.isEmpty || snippets.isEmpty) return text;

    var result = text;
    // Sort longer snippet triggers first to avoid partial prefix collisions
    final sorted = List<Map>.from(snippets)
      ..sort((a, b) =>
          ((b['name'] ?? '').toString()).length.compareTo(((a['name'] ?? '').toString()).length));

    for (final snippet in sorted) {
      final name = (snippet['name'] ?? '').toString().trim();
      final content = (snippet['content'] ?? '').toString();
      if (name.isEmpty || content.isEmpty) continue;

      final escaped = RegExp.escape(name);
      final pattern = RegExp('\\b$escaped\\b', caseSensitive: false);
      result = result.replaceAll(pattern, content);
    }

    return result;
  }
}
