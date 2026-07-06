class ContractionNormalizer {
  static final _contractions = {
    RegExp(r"\bdont\b", caseSensitive: false): "don't",
    RegExp(r"\bcant\b", caseSensitive: false): "can't",
    RegExp(r"\bwont\b", caseSensitive: false): "won't",
    RegExp(r"\bdidnt\b", caseSensitive: false): "didn't",
    RegExp(r"\bdoesnt\b", caseSensitive: false): "doesn't",
    RegExp(r"\bisnt\b", caseSensitive: false): "isn't",
    RegExp(r"\barent\b", caseSensitive: false): "aren't",
    RegExp(r"\bwasnt\b", caseSensitive: false): "wasn't",
    RegExp(r"\bwerent\b", caseSensitive: false): "weren't",
    RegExp(r"\bhasnt\b", caseSensitive: false): "hasn't",
    RegExp(r"\bhavent\b", caseSensitive: false): "haven't",
    RegExp(r"\bhadnt\b", caseSensitive: false): "hadn't",
    RegExp(r"\bcouldnt\b", caseSensitive: false): "couldn't",
    RegExp(r"\bwouldnt\b", caseSensitive: false): "wouldn't",
    RegExp(r"\bshouldnt\b", caseSensitive: false): "shouldn't",
    RegExp(r"\bmustnt\b", caseSensitive: false): "mustn't",
    RegExp(r"\bneednt\b", caseSensitive: false): "needn't",
    RegExp(r"\bdare not\b", caseSensitive: false): "daren't",
    RegExp(r"\bim\b", caseSensitive: false): "I'm",
    RegExp(r"\byoure\b", caseSensitive: false): "you're",
    RegExp(r"\bhes\b", caseSensitive: false): "he's",
    RegExp(r"\bshes\b", caseSensitive: false): "she's",
    RegExp(r"\bits\b(?!\s+\w)", caseSensitive: false): "it's",
    RegExp(r"\bwere\b(?=\s+(?:going|not|just|really))", caseSensitive: false): "we're",
    RegExp(r"\btheyll\b", caseSensitive: false): "they'll",
    RegExp(r"\bwell\b(?=\s+(?:be|go|see|do|have|not|just|really))", caseSensitive: false): "we'll",
    RegExp(r"\byoull\b", caseSensitive: false): "you'll",
    RegExp(r"\bimma\b", caseSensitive: false): "I'm going to",
    RegExp(r"\bgonna\b", caseSensitive: false): "going to",
    RegExp(r"\bwanna\b", caseSensitive: false): "want to",
    RegExp(r"\bgotta\b", caseSensitive: false): "got to",
    RegExp(r"\bdunno\b", caseSensitive: false): "don't know",
    RegExp(r"\b kinda\b", caseSensitive: false): " kind of",
  };

  String process(String text) {
    var result = text;
    for (final entry in _contractions.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }
    return result;
  }
}
