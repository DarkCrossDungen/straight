class FillerRemover {
  static final _fillers = RegExp(
    // Only remove clear vocal noise. Words such as "like", "actually",
    // and "I think" can carry meaning in normal dictation.
    r'\b(?:um|uh|er|ah|hmm|mm)\b',
    caseSensitive: false,
  );

  static final _repeatedWords = RegExp(
    r'\b(\w+)(?:[\s,]+(\1))+\b',
    caseSensitive: false,
  );

  String process(String text) {
    var result = text.replaceAll(_fillers, '');
    result = result.replaceAll(RegExp(r'\s+'), ' ').trim();

    var prev = '';
    while (prev != result) {
      prev = result;
      result = result.replaceAllMapped(_repeatedWords, (m) => m[1]!);
    }

    return result;
  }
}
