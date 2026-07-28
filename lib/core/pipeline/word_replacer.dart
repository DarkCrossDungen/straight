class WordReplacer {
  String process(String text, List<Map> dictionary) {
    if (text.isEmpty || dictionary.isEmpty) return text;

    final rules = dictionary
        .where((entry) => entry['enabled'] == true)
        .map(_ReplacementRule.fromEntry)
        .whereType<_ReplacementRule>()
        .toList();
    if (rules.isEmpty) return text;

    var result = text;
    for (final rule in rules) {
      // Long phrases go first so a specific pronunciation alias is never
      // partially replaced by a shorter dictionary entry.
      final aliases = rule.aliases.toList()
        ..sort((a, b) => b.length.compareTo(a.length));
      for (final alias in aliases) {
        final pattern = RegExp(
          r'(?<![A-Za-z0-9])' + RegExp.escape(alias) + r'(?![A-Za-z0-9])',
          caseSensitive: false,
        );
        result = result.replaceAll(pattern, rule.replacement);
      }
    }

    return _replaceStrictTechnicalNearMisses(result, rules);
  }

  String _replaceStrictTechnicalNearMisses(
    String text,
    List<_ReplacementRule> rules,
  ) {
    final technicalRules = rules.where((rule) => rule.isTechnical).toList();
    if (technicalRules.isEmpty) return text;

    final tokens = RegExp(r"[A-Za-z0-9']+").allMatches(text).toList();
    if (tokens.isEmpty) return text;

    final replacements = <_TextReplacement>[];
    for (var start = 0; start < tokens.length; start++) {
      _TechnicalCandidate? best;
      for (final rule in technicalRules) {
        final targetTokens = _spokenTokens(rule.replacement);
        if (targetTokens.isEmpty) continue;
        for (
          var count = targetTokens.length - 1;
          count <= targetTokens.length + 1;
          count++
        ) {
          if (count < 1 || start + count > tokens.length) continue;
          final spoken = tokens
              .skip(start)
              .take(count)
              .map((match) => match.group(0)!)
              .join(' ');
          final score = _similarity(
            _normalize(spoken),
            _normalize(rule.replacement),
          );
          if (score < 0.90) continue;
          final candidate = _TechnicalCandidate(rule, score, count);
          if (best == null || candidate.score > best.score) {
            best = candidate;
          } else if ((candidate.score - best.score).abs() < 0.04 &&
              candidate.rule.replacement != best.rule.replacement) {
            // Leave an ambiguous phrase alone rather than guessing.
            best = null;
          }
        }
      }

      if (best != null) {
        replacements.add(
          _TextReplacement(
            tokens[start].start,
            tokens[start + best.tokenCount - 1].end,
            best.rule.replacement,
          ),
        );
        start += best.tokenCount - 1;
      }
    }

    var result = text;
    for (final replacement in replacements.reversed) {
      result = result.replaceRange(
        replacement.start,
        replacement.end,
        replacement.value,
      );
    }
    return result;
  }

  static List<String> _spokenTokens(String value) => value
      .replaceAllMapped(
        RegExp(r'([a-z0-9])([A-Z])'),
        (match) => '${match[1]} ${match[2]}',
      )
      .replaceAll(RegExp(r'[_.\\/-]+'), ' ')
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();

  static String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  static double _similarity(String left, String right) {
    if (left.isEmpty || right.isEmpty) return 0;
    final distance = _levenshtein(left, right);
    return 1 -
        distance / (left.length > right.length ? left.length : right.length);
  }

  static int _levenshtein(String left, String right) {
    var previous = List<int>.generate(right.length + 1, (index) => index);
    for (var i = 0; i < left.length; i++) {
      final current = <int>[i + 1];
      for (var j = 0; j < right.length; j++) {
        final substitution = previous[j] + (left[i] == right[j] ? 0 : 1);
        current.add(
          [
            current[j] + 1,
            previous[j + 1] + 1,
            substitution,
          ].reduce((a, b) => a < b ? a : b),
        );
      }
      previous = current;
    }
    return previous.last;
  }
}

class _ReplacementRule {
  _ReplacementRule({
    required this.replacement,
    required this.aliases,
    required this.isTechnical,
  });

  final String replacement;
  final Set<String> aliases;
  final bool isTechnical;

  static _ReplacementRule? fromEntry(Map entry) {
    final word = (entry['word'] as String? ?? '').trim();
    final replacement = (entry['replacement'] as String? ?? '').trim();
    if (word.isEmpty || replacement.isEmpty) return null;

    final aliases = <String>{word, replacement};
    final storedAliases = entry['aliases'];
    if (storedAliases is Iterable) {
      aliases.addAll(
        storedAliases.whereType<String>().map((value) => value.trim()),
      );
    }
    aliases.removeWhere((value) => value.isEmpty);

    final imported =
        entry['source'] == 'folder' || entry['source'] == 'wordList';
    final isTechnical =
        imported &&
        replacement.length >= 8 &&
        (RegExp(r'[_.\\/-0-9]').hasMatch(replacement) ||
            RegExp(r'[a-z][A-Z]').hasMatch(replacement));
    return _ReplacementRule(
      replacement: replacement,
      aliases: aliases,
      isTechnical: isTechnical,
    );
  }
}

class _TechnicalCandidate {
  const _TechnicalCandidate(this.rule, this.score, this.tokenCount);

  final _ReplacementRule rule;
  final double score;
  final int tokenCount;
}

class _TextReplacement {
  const _TextReplacement(this.start, this.end, this.value);

  final int start;
  final int end;
  final String value;
}
