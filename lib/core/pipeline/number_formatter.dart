class NumberFormatter {
  static const Map<String, int> _smallWords = {
    'zero': 0, 'one': 1, 'two': 2, 'three': 3, 'four': 4,
    'five': 5, 'six': 6, 'seven': 7, 'eight': 8, 'nine': 9,
    'ten': 10, 'eleven': 11, 'twelve': 12, 'thirteen': 13, 'fourteen': 14,
    'fifteen': 15, 'sixteen': 16, 'seventeen': 17, 'eighteen': 18, 'nineteen': 19,
    'twenty': 20, 'thirty': 30, 'forty': 40, 'fifty': 50,
    'sixty': 60, 'seventy': 70, 'eighty': 80, 'ninety': 90,
  };

  static const Map<String, int> _multipliers = {
    'hundred': 100,
    'thousand': 1000,
    'million': 1000000,
    'billion': 1000000000,
  };

  static const Map<String, int> _ordinalWordValues = {
    'first': 1, 'second': 2, 'third': 3, 'fourth': 4,
    'fifth': 5, 'sixth': 6, 'seventh': 7, 'eighth': 8,
    'ninth': 9, 'tenth': 10, 'eleventh': 11, 'twelfth': 12,
    'thirteenth': 13, 'fourteenth': 14, 'fifteenth': 15,
    'sixteenth': 16, 'seventeenth': 17, 'eighteenth': 18,
    'nineteenth': 19, 'twentieth': 20, 'thirtieth': 30,
    'fortieth': 40, 'fiftieth': 50, 'sixtieth': 60,
    'seventieth': 70, 'eightieth': 80, 'ninetieth': 90,
    'hundredth': 100, 'thousandth': 1000, 'millionth': 1000000,
  };

  String process(String text) {
    if (text.isEmpty) return '';

    var result = text;

    // 1. Convert spoken currency (e.g. "fifty dollars" -> "$50", "one hundred dollars" -> "$100")
    result = _processCurrency(result);

    // 2. Convert spoken ordinals (e.g. "twenty first" -> "21st", "first" -> "1st")
    result = _processOrdinals(result);

    // 3. Convert spoken cardinal numbers (e.g. "twenty five" -> "25", "one hundred" -> "100")
    result = _processCardinals(result);

    return result;
  }

  String _processCurrency(String text) {
    final currencyPattern = RegExp(
      r'\b((?:(?:zero|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|thirty|forty|fifty|sixty|seventy|eighty|ninety|hundred|thousand|million|billion)[\s\-]+)+)(?:dollars|dollar|bucks)\b',
      caseSensitive: false,
    );

    return text.replaceAllMapped(currencyPattern, (m) {
      final phrase = m[1]!.trim();
      final value = _wordsToNumber(phrase);
      if (value != null) {
        return '\$$value';
      }
      return m[0]!;
    });
  }

  String _processOrdinals(String text) {
    // Check compound ordinals: "twenty first", "one hundredth", "third"
    final ordinalPattern = RegExp(
      r'\b((?:(?:zero|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|thirty|forty|fifty|sixty|seventy|eighty|ninety|hundred|thousand|million|billion)[\s\-]+)*)(first|second|third|fourth|fifth|sixth|seventh|eighth|ninth|tenth|eleventh|twelfth|thirteenth|fourteenth|fifteenth|sixteenth|seventeenth|eighteenth|nineteenth|twentieth|thirtieth|fortieth|fiftieth|sixtieth|seventieth|eightieth|ninetieth|hundredth|thousandth|millionth)\b',
      caseSensitive: false,
    );

    return text.replaceAllMapped(ordinalPattern, (m) {
      final prefix = (m[1] ?? '').trim();
      final ordWord = m[2]!.toLowerCase();

      final ordVal = _ordinalWordValues[ordWord];
      if (ordVal == null) return m[0]!;

      int total = 0;
      if (prefix.isNotEmpty) {
        final prefixVal = _wordsToNumber(prefix);
        if (prefixVal != null) {
          total = prefixVal + ordVal;
        } else {
          total = ordVal;
        }
      } else {
        total = ordVal;
      }

      return _formatOrdinal(total);
    });
  }

  String _processCardinals(String text) {
    final numberPattern = RegExp(
      r'\b(?:zero|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|thirty|forty|fifty|sixty|seventy|eighty|ninety|hundred|thousand|million|billion)(?:[\s\-]+(?:zero|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|thirty|forty|fifty|sixty|seventy|eighty|ninety|hundred|thousand|million|billion|and))*\b',
      caseSensitive: false,
    );

    return text.replaceAllMapped(numberPattern, (m) {
      final phrase = m[0]!.trim();
      final num = _wordsToNumber(phrase);
      if (num != null) {
        return num.toString();
      }
      return m[0]!;
    });
  }

  int? _wordsToNumber(String phrase) {
    final tokens = phrase
        .toLowerCase()
        .replaceAll('-', ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty && t != 'and')
        .toList();

    if (tokens.isEmpty) return null;

    int total = 0;
    int current = 0;

    for (final token in tokens) {
      if (_smallWords.containsKey(token)) {
        current += _smallWords[token]!;
      } else if (token == 'hundred') {
        current = (current == 0 ? 1 : current) * 100;
      } else if (_multipliers.containsKey(token)) {
        final mult = _multipliers[token]!;
        total += (current == 0 ? 1 : current) * mult;
        current = 0;
      } else {
        return null;
      }
    }

    return total + current;
  }

  String _formatOrdinal(int n) {
    if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
    switch (n % 10) {
      case 1:
        return '${n}st';
      case 2:
        return '${n}nd';
      case 3:
        return '${n}rd';
      default:
        return '${n}th';
    }
  }
}
