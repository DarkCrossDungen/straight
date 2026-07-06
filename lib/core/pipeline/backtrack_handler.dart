class BacktrackHandler {
  static final _backtrackPatterns = [
    RegExp(r',?\s*(?:no|wait|actually|sorry|I mean|rather|rather than)\s+\w+[^,]*?(?=,|\.|$)',
        caseSensitive: false),
    RegExp(",?\\s*(?:no|wait)\\s*,?\\s*(?:that's|thats|that is)?\\s*not\\s+\\w+[^,]*?(?=,|\\.|\$)",
        caseSensitive: false),
    RegExp(r',?\s*(?:or rather|or should I say|or let me rephrase|let me rephrase)[^,.]*',
        caseSensitive: false),
    RegExp(r'\b(?:no I meant|no I mean|I meant|what I mean is)\s+', caseSensitive: false),
    RegExp(r'\bscratch that\b', caseSensitive: false),
    RegExp(r'\bignore that\b', caseSensitive: false),
    RegExp(r'\bnever mind\b', caseSensitive: false),
    RegExp(r',?\s*(?:start over|let me start over|let me begin again)[^,.]*',
        caseSensitive: false),
  ];

  String process(String text) {
    var result = text;

    if (_hasFullBacktrack(result)) {
      final segments = result.split(RegExp(r'(?<=[.!?])\s+'));
      if (segments.length >= 2) {
        final last = segments.last;
        if (_hasBacktrackMarker(last)) {
          segments.removeLast();
          result = segments.join(' ');
        }
      }
    }

    for (final pattern in _backtrackPatterns) {
      result = result.replaceAll(pattern, '').trim();
    }

    result = result.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (result.endsWith(',') || result.endsWith('and') || result.endsWith('or')) {
      result = result.substring(0, result.length - 1).trim();
    }

    return result;
  }

  bool _hasFullBacktrack(String text) {
    return text.contains(RegExp(r'\b(start over|never mind|ignore that|scratch that)\b',
        caseSensitive: false));
  }

  bool _hasBacktrackMarker(String text) {
    return text.contains(RegExp(r'\b(no|wait|actually|I mean)\b', caseSensitive: false));
  }
}
