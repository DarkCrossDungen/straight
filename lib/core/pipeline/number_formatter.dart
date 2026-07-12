class NumberFormatter {
  static const _ones = [
    '', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine',
    'ten', 'eleven', 'twelve', 'thirteen', 'fourteen', 'fifteen', 'sixteen',
    'seventeen', 'eighteen', 'nineteen',
  ];

  static const _tens = [
    '', '', 'twenty', 'thirty', 'forty', 'fifty', 'sixty', 'seventy', 'eighty', 'ninety',
  ];

  static const _ordinalOnes = [
    '', 'first', 'second', 'third', 'fourth', 'fifth', 'sixth', 'seventh', 'eighth', 'ninth',
    'tenth', 'eleventh', 'twelfth', 'thirteenth', 'fourteenth', 'fifteenth', 'sixteenth',
    'seventeenth', 'eighteenth', 'nineteenth',
  ];

  static const _ordinalTens = [
    '', '', 'twentieth', 'thirtieth', 'fortieth', 'fiftieth', 'sixtieth', 'seventieth', 'eightieth', 'ninetieth',
  ];

  static final _numberPattern = RegExp(r'\b\d{1,15}\b');
  static final _currencyPattern = RegExp(r'\$\s*(\d+)\b');
  static final _ordinalPattern = RegExp(r'\b(\d+)(st|nd|rd|th)\b', caseSensitive: false);

  String process(String text) {
    var result = text;

    result = result.replaceAllMapped(_ordinalPattern, (m) {
      final num = int.tryParse(m[1]!);
      if (num == null) return m[0]!;
      return _ordinalToWords(num);
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

  String _ordinalToWords(int n) {
    if (n < 20) return _ordinalOnes[n];
    if (n < 100) {
      final t = n ~/ 10;
      final o = n % 10;
      if (o == 0) return _ordinalTens[t];
      return '${_tens[t]}-${_ordinalOnes[o]}';
    }
    if (n < 1000) {
      final h = n ~/ 100;
      final r = n % 100;
      if (r == 0) return '${_ones[h]} hundredth';
      return '${_ones[h]} hundred ${_ordinalToWords(r)}';
    }
    return '${_numberToWords(n)}th';
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
