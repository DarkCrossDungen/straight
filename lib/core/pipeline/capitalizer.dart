class Capitalizer {
  static final _sentenceEnd = RegExp(r'(?<=[.!?])\s+');
  static final _firstWord = RegExp(r'^\w');

  String process(String text) {
    if (text.isEmpty) return text;

    var result = text.trim();
    result = result.replaceFirstMapped(_firstWord, (m) => m[0]!.toUpperCase());

    final parts = result.split(_sentenceEnd);
    final capitalized = parts.map((part) {
      part = part.trim();
      if (part.isEmpty) return part;
      return part.replaceFirstMapped(_firstWord, (m) => m[0]!.toUpperCase());
    }).join(' ');

    return capitalized;
  }
}
