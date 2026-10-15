class StyleCleaner {
  static final _spaceBeforePunctuation = RegExp(r'\s+([,.;:!?])');
  static final _spaceAfterPunctuation = RegExp(r'([,.;:!?])([^\s\n])');
  static final _collapsedSpaces = RegExp(r'[ \t]{2,}');
  static final _multiNewlines = RegExp(r'\n{3,}');
  static final _standaloneI = RegExp(r'\bi\b');
  static final _spaceAroundNewlines = RegExp(r'[ \t]*\n[ \t]*');

  static final _urlOrEmail = RegExp(
    r'https?://[^\s]+|[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
  );

  String process(String text) {
    if (text.isEmpty) return text;

    // 1. Protect URLs and emails from having punctuation spaced out
    final protected = <String>[];
    var result = text.replaceAllMapped(_urlOrEmail, (m) {
      protected.add(m[0]!);
      return '___PROTECTED_URL_${protected.length - 1}___';
    });

    result = result.trim();
    result = result.replaceAll(_spaceAroundNewlines, '\n');
    result = result.replaceAllMapped(_spaceBeforePunctuation, (m) => m[1]!);
    result = result.replaceAllMapped(_spaceAfterPunctuation, (m) => '${m[1]} ${m[2]}');
    result = result.replaceAll(_collapsedSpaces, ' ');
    result = result.replaceAll(_multiNewlines, '\n\n');
    result = result.replaceAll(_standaloneI, 'I');

    // 2. Restore protected URLs and emails intact
    for (int i = 0; i < protected.length; i++) {
      result = result.replaceAll('___PROTECTED_URL_${i}___', protected[i]);
    }

    return result.trim();
  }
}
