class StyleCleaner {
  static final _spaceBeforePunctuation = RegExp(r'\s+([,.;:!?])');
  static final _spaceAfterPunctuation = RegExp(r'([,.;:!?])([^\s\n])');
  static final _collapsedSpaces = RegExp(r'[ \t]{2,}');
  static final _multiNewlines = RegExp(r'\n{3,}');
  static final _standaloneI = RegExp(r'\bi\b');
  static final _spaceAroundNewlines = RegExp(r'[ \t]*\n[ \t]*');

  String process(String text) {
    if (text.isEmpty) return text;

    var result = text.trim();
    result = result.replaceAll(_spaceAroundNewlines, '\n');
    result = result.replaceAllMapped(_spaceBeforePunctuation, (m) => m[1]!);
    result = result.replaceAllMapped(_spaceAfterPunctuation, (m) => '${m[1]} ${m[2]}');
    result = result.replaceAll(_collapsedSpaces, ' ');
    result = result.replaceAll(_multiNewlines, '\n\n');
    result = result.replaceAll(_standaloneI, 'I');
    return result.trim();
  }
}
