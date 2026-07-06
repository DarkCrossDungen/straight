class NumberFormatter {
  static const _ones = [
    '', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine',
    'ten', 'eleven', 'twelve', 'thirteen', 'fourteen', 'fifteen', 'sixteen',
    'seventeen', 'eighteen', 'nineteen',
  ];

  static const _tens = [
    '', '', 'twenty', 'thirty', 'forty', 'fifty', 'sixty', 'seventy', 'eighty', 'ninety',
  ];

  static final _numberPattern = RegExp(r'\b\d{1,15}\b');
  static final _currencyPattern = RegExp(r'\$\s*(\d+)\b');
  static final _ordinalPattern = RegExp(r'\b(\d+)(st|nd|rd|th)\b', caseSensitive: false);

  String process(String text) {
    var result = text;

    result = result.replaceAllMapped(_ordinalPattern, (m) {
      final num = int.tryParse(m[1]!);
      if (num == null) return m[0]!;
      final suffix = m[2]!.toLowerCase();
      return '${_numberToWords(num)}$suffix';
    });

    result = result.replaceAllMapped(_currencyPattern, (m) {
      final num = int.tryParse(m[1]!);
      if (num == null) return m[0]!;
      return '${_numberToWords(num)} dollars';
    });

    result = result.replaceAllMapped(_numberPattern, (m) {
      final num = int.tryParse(m[0]!);
      if (num == null) return m[0]!;
      if (num > 999999999999) return m[0]!;
      if (m[0]!.length > 1 && m[0]![0] == '0') return m[0]!;
      return _numberToWords(num);
    });

    return result;
  }

  String _numberToWords(int n) {
    if (n == 0) return 'zero';

    final parts = <String>[];

    if (n >= 1000000000) {
      parts.add('${_numberToWords(n ~/ 1000000000)} billion');
      n %= 1000000000;
    }

    if (n >= 1000000) {
      parts.add('${_numberToWords(n ~/ 1000000)} million');
      n %= 1000000;
    }

    if (n >= 1000) {
      parts.add('${_numberToWords(n ~/ 1000)} thousand');
      n %= 1000;
    }

    if (n >= 100) {
      parts.add('${_ones[n ~/ 100]} hundred');
      n %= 100;
    }

    if (n > 0) {
      if (n < 20) {
        parts.add(_ones[n]);
      } else {
        parts.add(_tens[n ~/ 10]);
        if (n % 10 > 0) {
          parts.add(_ones[n % 10]);
        }
      }
    }

    return parts.join(' ');
  }
}
