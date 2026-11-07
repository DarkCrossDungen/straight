class BacktrackHandler {
  /// Markers that retract what was just said. When one ends the utterance it
  /// is the "undo my last insertion" command, which belongs to CommandParser,
  /// so it is only consumed here when a correction follows it.
  static final _retractMarker = RegExp(
    r'\b(?:scratch that|ignore that|delete that|never mind|start over)\b',
    caseSensitive: false,
  );

  static final _sentenceEnd = RegExp(r'[.!?](?:\s|$)');

  static final _backtrackPatterns = [
    RegExp(r',?\s*(?:no|wait|actually|sorry|I mean|rather|rather than)\s+\w+[^,]*?(?=,|\.|$)',
        caseSensitive: false),
    RegExp(",?\\s*(?:no|wait)\\s*,?\\s*(?:that's|thats|that is)?\\s*not\\s+\\w+[^,]*?(?=,|\\.|\$)",
        caseSensitive: false),
    RegExp(r',?\s*(?:or rather|or should I say|or let me rephrase|let me rephrase)[^,.]*',
        caseSensitive: false),
    RegExp(r'\b(?:no I meant|no I mean|I meant|what I mean is)\s+', caseSensitive: false),
    RegExp(r',?\s*(?:let me begin again)[^,.]*', caseSensitive: false),
  ];

  String process(String text) {
    var result = _retractClauses(text);

    for (final pattern in _backtrackPatterns) {
      result = result.replaceAll(pattern, '').trim();
    }

    result = result.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (result.endsWith(',') || result.endsWith('and') || result.endsWith('or')) {
      result = result.substring(0, result.length - 1).trim();
    }

    return result;
  }

  /// "meet at three scratch that make it four" keeps only the correction.
  /// Stripping the marker alone used to leave both readings in the text.
  String _retractClauses(String text) {
    var result = text;
    while (true) {
      final match = _retractMarker.firstMatch(result);
      if (match == null) return result;

      final after = result.substring(match.end).trimLeft();
      if (after.isEmpty) return result;

      final kept = _dropLastSentence(result.substring(0, match.start)).trimRight();
      result = kept.isEmpty ? after : '$kept $after';
    }
  }

  /// Retracts the sentence the marker interrupted. When the lead-in already
  /// ends in a full stop the marker names that finished sentence instead, so
  /// one more is dropped. Earlier sentences always survive.
  String _dropLastSentence(String before) {
    final boundaries = _sentenceEnd.allMatches(before).toList();
    if (boundaries.isEmpty) return '';
    final finished = RegExp(r'[.!?]$').hasMatch(before.trimRight());
    final keep = finished ? boundaries.length - 1 : boundaries.length;
    if (keep <= 0) return '';
    return before.substring(0, boundaries[keep - 1].end);
  }
}