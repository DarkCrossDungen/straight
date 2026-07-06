class FillerRemover {
  static final _fillers = RegExp(
    r'\b(?:um|uh|er|ah|hmm|mm|like|you know|sort of|kind of|'
    r'actually|basically|literally|honestly|seriously|'
    r'I mean|you see|well|so anyway|anyway|'
    r'right|okay|alright|you know what I mean)\b',
    caseSensitive: false,
  );

  static final _repeatedWords = RegExp(
    r'\b(\w+)(?:[\s,]+(\1))\b',
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
