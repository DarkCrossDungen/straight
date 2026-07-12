enum DictationCommand {
  newLine,
  newParagraph,
  scratchLast,
  scratchAll,
  selectAll,
  copy,
  paste,
  capNext,
  allCaps,
  uncap,
  period,
  comma,
  questionMark,
  exclamation,
  colon,
  semiColon,
  openQuote,
  closeQuote,
  none,
}

class CommandParser {
  static final _commands = [
    _CommandDef(RegExp(r'\bnew\s+line\b', caseSensitive: false), DictationCommand.newLine, '\n'),
    _CommandDef(RegExp(r'\bnew\s+para(graph)?\b', caseSensitive: false), DictationCommand.newParagraph, '\n\n'),
    _CommandDef(RegExp(r'\bscratch\s+that\b', caseSensitive: false), DictationCommand.scratchLast, ''),
    _CommandDef(RegExp(r'\bscratch\s+all\b|\bdelete\s+all\b|\bclear\b', caseSensitive: false), DictationCommand.scratchAll, ''),
    _CommandDef(RegExp(r'\bselect\s+all\b', caseSensitive: false), DictationCommand.selectAll, ''),
    _CommandDef(RegExp(r'\bcopy\s+that\b|\bcopy\b', caseSensitive: false), DictationCommand.copy, ''),
    _CommandDef(RegExp(r'\bpaste\s+that\b|\bpaste\b', caseSensitive: false), DictationCommand.paste, ''),
    _CommandDef(RegExp(r'\bcap\b|\bcapitalize\b', caseSensitive: false), DictationCommand.capNext, ''),
    _CommandDef(RegExp(r'\ball\s+caps\b', caseSensitive: false), DictationCommand.allCaps, ''),
    _CommandDef(RegExp(r'\buncap\b|\bno\s+caps\b', caseSensitive: false), DictationCommand.uncap, ''),
    _CommandDef(RegExp(r'\bperiod\b', caseSensitive: false), DictationCommand.period, '.'),
    _CommandDef(RegExp(r'\bcomma\b', caseSensitive: false), DictationCommand.comma, ','),
    _CommandDef(RegExp(r'\bquestion\s+mark\b', caseSensitive: false), DictationCommand.questionMark, '?'),
    _CommandDef(RegExp(r'\bexclamation\s+(point|mark)\b', caseSensitive: false), DictationCommand.exclamation, '!'),
    _CommandDef(RegExp(r'\bsemi\s+colon\b', caseSensitive: false), DictationCommand.semiColon, ';'),
    _CommandDef(RegExp(r'\bcolon\b', caseSensitive: false), DictationCommand.colon, ':'),
    _CommandDef(RegExp(r'\bopen\s+quote\b', caseSensitive: false), DictationCommand.openQuote, '"'),
    _CommandDef(RegExp(r'\bclose\s+quote\b', caseSensitive: false), DictationCommand.closeQuote, '"'),
  ];

  final List<DictationCommand> detectedCommands = [];
  final List<String> commandTexts = [];

  String process(String text) {
    detectedCommands.clear();
    commandTexts.clear();

    var result = text;

    for (final cmd in _commands) {
      while (true) {
        final match = cmd.pattern.firstMatch(result);
        if (match == null) break;

        detectedCommands.add(cmd.command);
        commandTexts.add(match[0]!);

        final before = result.substring(0, match.start).trimRight();
        final after = result.substring(match.end).trimLeft();

        if (cmd.command == DictationCommand.capNext && after.isNotEmpty) {
          final words = after.split(' ');
          words[0] = words[0][0].toUpperCase() + words[0].substring(1);
          result = '$before ${words.join(' ')}';
        } else if (cmd.command == DictationCommand.scratchLast) {
          result = before;
          return result;
        } else if (cmd.command == DictationCommand.scratchAll) {
          return '';
        } else {
          result = '$before${cmd.replacement}$after';
        }

        result = result.replaceAll(RegExp(r'[ \t]+'), ' ');
        result = result.replaceAll(RegExp(r' *\n *'), '\n');
        result = result.trim();
      }
    }

    return result;
  }

}

class _CommandDef {
  final RegExp pattern;
  final DictationCommand command;
  final String replacement;

  _CommandDef(this.pattern, this.command, this.replacement);
}
