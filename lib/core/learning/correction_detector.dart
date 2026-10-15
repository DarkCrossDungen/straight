import '../storage/dictionary_store.dart';

class CorrectionResult {
  final String original;
  final String replacement;
  final double confidence;

  CorrectionResult({
    required this.original,
    required this.replacement,
    required this.confidence,
  });
}

class CorrectionDetector {
  /// Compares the last dictated text with a subsequent correction to find single-word or short-phrase edits.
  /// For example:
  /// original: "let us test with grok"
  /// corrected: "let us test with Grox"
  /// -> detects: 'grok' -> 'Grox'
  CorrectionResult? detectWordCorrection(String originalText, String correctedText) {
    if (originalText.isEmpty || correctedText.isEmpty) return null;
    if (originalText.trim().toLowerCase() == correctedText.trim().toLowerCase()) return null;

    final origWords = originalText.trim().split(RegExp(r'\s+'));
    final corrWords = correctedText.trim().split(RegExp(r'\s+'));

    // Case 1: Same number of words, exactly one word changed
    if (origWords.length == corrWords.length) {
      int diffIndex = -1;
      int diffCount = 0;

      for (int i = 0; i < origWords.length; i++) {
        final w1 = _cleanWord(origWords[i]);
        final w2 = _cleanWord(corrWords[i]);
        if (w1 != w2) {
          diffCount++;
          diffIndex = i;
        }
      }

      if (diffCount == 1 && diffIndex != -1) {
        final orig = _cleanWord(origWords[diffIndex]);
        final corr = _cleanWord(corrWords[diffIndex]);
        if (orig.isNotEmpty && corr.isNotEmpty && orig.toLowerCase() != corr.toLowerCase()) {
          final dist = _levenshtein(orig.toLowerCase(), corr.toLowerCase());
          if (dist <= 3) {
            return CorrectionResult(
              original: orig,
              replacement: corr,
              confidence: 1.0 - (dist / orig.length.clamp(1, 10)),
            );
          }
        }
      }
    }

    // Case 2: Single word replacement (e.g. user backspaced single word and typed correction)
    if (origWords.length == 1 && corrWords.length == 1) {
      final orig = _cleanWord(origWords.first);
      final corr = _cleanWord(corrWords.first);
      if (orig.isNotEmpty && corr.isNotEmpty && orig.toLowerCase() != corr.toLowerCase()) {
        final dist = _levenshtein(orig.toLowerCase(), corr.toLowerCase());
        if (dist <= 3) {
          return CorrectionResult(original: orig, replacement: corr, confidence: 0.9);
        }
      }
    }

    return null;
  }

  /// Parses voice correction commands like:
  /// "correction grok to Grox"
  /// "replace grok with Grox"
  CorrectionResult? parseVoiceCorrection(String text) {
    if (text.isEmpty) return null;

    final replacePattern = RegExp(
      r'\b(?:replace|correction)\s+([a-zA-Z0-9_\-]+)\s+(?:with|to)\s+([a-zA-Z0-9_\-]+)\b',
      caseSensitive: false,
    );

    final match = replacePattern.firstMatch(text);
    if (match != null) {
      final orig = match.group(1)!;
      final corr = match.group(2)!;
      return CorrectionResult(original: orig, replacement: corr, confidence: 1.0);
    }

    return null;
  }

  /// Automatically registers the learned correction into local DictionaryStore
  Future<bool> learn(String original, String replacement) async {
    final cleanOrig = _cleanWord(original).toLowerCase();
    final cleanCorr = _cleanWord(replacement);

    if (cleanOrig.isEmpty || cleanCorr.isEmpty || cleanOrig == cleanCorr.toLowerCase()) {
      return false;
    }

    final existing = DictionaryStore.getAll();
    for (final entry in existing) {
      if ((entry['word'] as String).toLowerCase() == cleanOrig) {
        await DictionaryStore.updateWord(entry['id'] as String, {
          'replacement': cleanCorr,
          'enabled': true,
        });
        return true;
      }
    }

    await DictionaryStore.addWord(cleanOrig, cleanCorr);
    return true;
  }

  String _cleanWord(String word) {
    return word.replaceAll(RegExp(r'^[^\w]+|[^\w]+$'), '');
  }

  int _levenshtein(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    List<int> v0 = List<int>.generate(t.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(t.length + 1, 0);

    for (int i = 0; i < s.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < t.length; j++) {
        int cost = (s[i] == t[j]) ? 0 : 1;
        v1[j + 1] = [v1[j] + 1, v0[j + 1] + 1, v0[j] + cost].reduce((a, b) => a < b ? a : b);
      }
      for (int j = 0; j <= t.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v1[t.length];
  }
}
