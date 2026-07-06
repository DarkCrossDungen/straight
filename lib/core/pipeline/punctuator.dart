class Punctuator {
  static final _hasEndPunctuation = RegExp(r'[.!?:;…]$');
  static final _questionWords = RegExp(
    r'^(what|why|how|where|when|who|whose|whom|which|'
    r'do|does|did|is|are|was|were|has|have|had|'
    r'can|could|will|would|shall|should|may|might)\b',
    caseSensitive: false,
  );

  String process(String text, {int pauseDurationMs = 0}) {
    if (text.isEmpty) return text;

    var result = text.trim();

    if (_hasEndPunctuation.hasMatch(result)) return result;

    if (pauseDurationMs >= 500) {
      if (_questionWords.hasMatch(result)) {
        result += '?';
      } else {
        result += '.';
      }
    }

    return result;
  }
}
