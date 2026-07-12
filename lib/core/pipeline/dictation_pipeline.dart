import 'filler_remover.dart';
import 'capitalizer.dart';
import 'punctuator.dart';
import 'contraction_normalizer.dart';
import 'number_formatter.dart';
import 'backtrack_handler.dart';
import 'command_parser.dart';
import 'style_cleaner.dart';
import 'word_replacer.dart';
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
  LlmEngine? _llm;
  List<Map> _dictionary = [];

  DictationPipeline({this._llm});

  void setLlmEngine(LlmEngine? engine) {
    _llm = engine;
  }

  void setDictionary(List<Map> dictionary) {
    _dictionary = dictionary;
  }

  DictationResult process(String rawText, {int pauseDurationMs = 0}) {
    if (rawText.isEmpty) return DictationResult(text: '');

    var text = rawText;

    text = _backtrackHandler.process(text);
    text = _fillerRemover.process(text);
    text = _contractionNormalizer.process(text);
    text = _numberFormatter.process(text);
    text = _commandParser.process(text);
    text = _wordReplacer.process(text, _dictionary);
    text = _punctuator.process(text, pauseDurationMs: pauseDurationMs);
    text = _capitalizer.process(text);
    text = _styleCleaner.process(text);

    return DictationResult(
      text: text.trim(),
      commands: List.from(_commandParser.detectedCommands),
    );
  }

  Future<DictationResult> processWithLlm(String rawText, {int pauseDurationMs = 0}) async {
    var result = process(rawText, pauseDurationMs: pauseDurationMs);
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
