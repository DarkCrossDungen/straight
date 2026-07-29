class StructureFormatter {
  static final _ordinal = RegExp(
    r'\b(first(?:ly)?|second(?:ly)?|third(?:ly)?|fourth(?:ly)?|finally)[,:]?\s+',
    caseSensitive: false,
  );

  static final _topicTransition = RegExp(
    r'([.!?])\s+((?:on another note|moving on|regarding|as for|next topic|separately|additionally)\b)',
    caseSensitive: false,
  );

  String process(String text) {
    if (text.isEmpty) return text;

    var result = text.replaceAllMapped(
      _topicTransition,
      (match) => '${match[1]}\n\n${match[2]}',
    );

    final ordinals = _ordinal.allMatches(result).toList();
    if (ordinals.length < 2) return result;

    final prefix = result.substring(0, ordinals.first.start).trim();
    final items = <String>[];
    for (var index = 0; index < ordinals.length; index++) {
      final start = ordinals[index].end;
      final end = index + 1 < ordinals.length
          ? ordinals[index + 1].start
          : result.length;
      final item = result
          .substring(start, end)
          .trim()
          .replaceFirst(RegExp(r'^[,;:\s]+'), '')
          .replaceFirst(RegExp(r'[,;:\s]+$'), '');
      if (item.isNotEmpty) items.add('• $item');
    }

    if (items.length < 2) return result;
    return [
      if (prefix.isNotEmpty) prefix,
      items.join('\n'),
    ].join(prefix.isEmpty ? '' : '\n');
  }
}
