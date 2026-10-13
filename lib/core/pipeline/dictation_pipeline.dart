import 'filler_remover.dart';
import 'capitalizer.dart';
import 'punctuator.dart';
import 'contraction_normalizer.dart';
import 'number_formatter.dart';
import 'backtrack_handler.dart';
import 'command_parser.dart';
import 'style_cleaner.dart';
import 'word_replacer.dart';
import 'snippet_expander.dart';
import 'code_formatter.dart';
import '../platform/window_context.dart';
import '../llm/llm_engine.dart';

class DictationResult {
  final String text;
  final List<DictationCommand> commands;

  DictationResult({required this.text, this.commands = const []});
}

class DictationPipeline {
  final FillerRemover _fillerRemover = FillerRemover();
  final Capitalizer _capitalizer = Capitalizer();
  final Punctuator _punctuator = Punctuator();
  final ContractionNormalizer _contractionNormalizer = ContractionNormalizer();
  final NumberFormatter _numberFormatter = NumberFormatter();
  final BacktrackHandler _backtrackHandler = BacktrackHandler();
  final CommandParser _commandParser = CommandParser();
  final StyleCleaner _styleCleaner = StyleCleaner();
  final WordReplacer _wordReplacer = WordReplacer();
  final SnippetExpander _snippetExpander = SnippetExpander();
  final CodeFormatter _codeFormatter = CodeFormatter();
  LlmEngine? _llm;
  List<Map> _dictionary = [];
  List<Map> _snippets = [];

  DictationPipeline({this._llm});

  void setLlmEngine(LlmEngine? engine) {
    _llm = engine;
  }

  void setDictionary(List<Map> dictionary) {
    _dictionary = dictionary;
  }

  void setSnippets(List<Map> snippets) {
    _snippets = snippets;
  }

  DictationResult process(String rawText, {int pauseDurationMs = 0, ActiveWindowInfo? windowContext}) {
    if (rawText.isEmpty) return DictationResult(text: '');

    var text = rawText;

    text = _backtrackHandler.process(text);
    text = _fillerRemover.process(text);
    text = _contractionNormalizer.process(text);
    text = _numberFormatter.process(text);
    text = _commandParser.process(text);
    text = _wordReplacer.process(text, _dictionary);
    text = _snippetExpander.process(text, _snippets);

    text = _punctuator.process(text, pauseDurationMs: pauseDurationMs);
    text = _capitalizer.process(text);

    // Context-aware formatting:
    // 1. Voice-command code casing (camelCase, snake_case, etc.)
    text = _codeFormatter.process(text);

    // 2. In Code editors: omit automatic sentence period on code/commands
    if (windowContext?.category == AppCategory.code) {
      if (!_commandParser.detectedCommands.contains(DictationCommand.period) &&
          !_commandParser.detectedCommands.contains(DictationCommand.questionMark) &&
          !_commandParser.detectedCommands.contains(DictationCommand.exclamation)) {
        if (text.endsWith('.') && !text.endsWith('..') && !text.endsWith('...')) {
          text = text.substring(0, text.length - 1);
        }
      }
    }

    // 3. In Chat apps: omit formal trailing period for single-sentence messages
    if (windowContext?.category == AppCategory.chat && !text.contains('\n')) {
      if (!_commandParser.detectedCommands.contains(DictationCommand.period) &&
          text.endsWith('.') && !text.endsWith('..') && !text.endsWith('...')) {
        final periodCount = '.'.allMatches(text).length;
        if (periodCount == 1) {
          text = text.substring(0, text.length - 1);
        }
      }
    }

    text = _styleCleaner.process(text);

    return DictationResult(
      text: text.trim(),
      commands: List.from(_commandParser.detectedCommands),
    );
  }

  Future<DictationResult> processWithLlm(String rawText, {int pauseDurationMs = 0, ActiveWindowInfo? windowContext}) async {
    var result = process(rawText, pauseDurationMs: pauseDurationMs, windowContext: windowContext);
    if (_llm == null || result.text.isEmpty) return result;

    final cleaned = await _llm!.complete(
      'Clean up this dictated text. Fix grammar, remove filler words, make it natural. Keep the exact meaning.\n\nText: ${result.text}\n\nCleaned:',
      maxTokens: 256,
    );

    if (cleaned.isNotEmpty) {
      return DictationResult(
        text: _styleCleaner.process(cleaned.trim()),
        commands: result.commands,
      );
    }

    return result;
  }
}
