import 'package:flutter_test/flutter_test.dart';
import 'package:straight/core/pipeline/command_parser.dart';
import 'package:straight/core/pipeline/filler_remover.dart';
import 'package:straight/core/pipeline/capitalizer.dart';
import 'package:straight/core/pipeline/contraction_normalizer.dart';
import 'package:straight/core/pipeline/number_formatter.dart';
import 'package:straight/core/pipeline/backtrack_handler.dart';
import 'package:straight/core/pipeline/punctuator.dart';
import 'package:straight/core/pipeline/style_cleaner.dart';
import 'package:straight/core/pipeline/word_replacer.dart';
import 'package:straight/core/pipeline/dictation_pipeline.dart';

void main() {
  group('CommandParser', () {
    late CommandParser parser;

    setUp(() {
      parser = CommandParser();
    });

    test('new line command', () {
      final result = parser.process('hello new line world');
      expect(result, contains('\n'));
      expect(parser.detectedCommands, contains(DictationCommand.newLine));
    });

    test('new paragraph command', () {
      final result = parser.process('hello new paragraph world');
      expect(result, contains('\n\n'));
      expect(parser.detectedCommands, contains(DictationCommand.newParagraph));
    });

    test('period command', () {
      final result = parser.process('hello period');
      expect(result, contains('.'));
      expect(parser.detectedCommands, contains(DictationCommand.period));
    });

    test('comma command', () {
      final result = parser.process('hello comma world');
      expect(result, contains(','));
      expect(parser.detectedCommands, contains(DictationCommand.comma));
    });

    test('question mark command', () {
      final result = parser.process('hello question mark');
      expect(result, contains('?'));
      expect(parser.detectedCommands, contains(DictationCommand.questionMark));
    });

    test('exclamation point command', () {
      final result = parser.process('hello exclamation point');
      expect(result, contains('!'));
      expect(parser.detectedCommands, contains(DictationCommand.exclamation));
    });

    test('colon command', () {
      final result = parser.process('hello colon world');
      expect(result, contains(':'));
      expect(parser.detectedCommands, contains(DictationCommand.colon));
    });

    test('semicolon command', () {
      final result = parser.process('hello semi colon world');
      expect(result, contains(';'));
      expect(parser.detectedCommands, contains(DictationCommand.semiColon));
    });

    test('open quote command', () {
      final result = parser.process('open quote hello');
      expect(result, contains('"'));
      expect(parser.detectedCommands, contains(DictationCommand.openQuote));
    });

    test('close quote command', () {
      final result = parser.process('hello close quote');
      expect(result, contains('"'));
      expect(parser.detectedCommands, contains(DictationCommand.closeQuote));
    });

    test('scratch that removes everything', () {
      final result = parser.process('hello world scratch that');
      expect(result, 'hello world');
      expect(parser.detectedCommands, contains(DictationCommand.scratchLast));
    });

    test('scratch all returns empty', () {
      final result = parser.process('hello world scratch all');
      expect(result, '');
      expect(parser.detectedCommands, contains(DictationCommand.scratchAll));
    });

    test('delete all returns empty', () {
      final result = parser.process('hello world delete all');
      expect(result, '');
    });

    test('clear returns empty', () {
      final result = parser.process('hello world clear');
      expect(result, '');
    });

    test('cap next capitalizes next word', () {
      final result = parser.process('hello cap world');
      expect(result, contains('World'));
      expect(parser.detectedCommands, contains(DictationCommand.capNext));
    });

    test('all caps command', () {
      parser.process('hello all caps');
      expect(parser.detectedCommands, contains(DictationCommand.allCaps));
    });

    test('select all command', () {
      parser.process('hello select all');
      expect(parser.detectedCommands, contains(DictationCommand.selectAll));
    });

    test('copy command', () {
      parser.process('hello copy that');
      expect(parser.detectedCommands, contains(DictationCommand.copy));
    });

    test('paste command', () {
      parser.process('hello paste that');
      expect(parser.detectedCommands, contains(DictationCommand.paste));
    });

    test('multiple commands in one text', () {
      parser.process('hello period new line world');
      expect(parser.detectedCommands.length, greaterThanOrEqualTo(2));
    });

    test('empty text returns empty', () {
      final result = parser.process('');
      expect(result, '');
    });
  });

  group('FillerRemover', () {
    late FillerRemover remover;

    setUp(() {
      remover = FillerRemover();
    });

    test('removes um', () {
      final result = remover.process('I um went to the store');
      expect(result, isNot(contains('um')));
    });

    test('removes uh', () {
      final result = remover.process('I uh went to the store');
      expect(result, isNot(contains('uh')));
    });

    test('preserves words which can carry meaning', () {
      final result = remover.process(
        'I think maybe I actually like this approach',
      );
      expect(result, 'I think maybe I actually like this approach');
    });

    test('removes duplicate words', () {
      final result = remover.process('I I went to the the store');
      expect(result, isNot(contains('I I')));
      expect(result, isNot(contains('the the')));
    });

    test('preserves meaningful text', () {
      final result = remover.process('I went to the store');
      expect(result, contains('I went to the store'));
    });

    test('empty text returns empty', () {
      final result = remover.process('');
      expect(result, '');
    });
  });

  group('Capitalizer', () {
    late Capitalizer capitalizer;

    setUp(() {
      capitalizer = Capitalizer();
    });

    test('capitalizes first letter', () {
      final result = capitalizer.process('hello world');
      expect(result, startsWith('H'));
    });

    test('capitalizes after period', () {
      final result = capitalizer.process('hello. world');
      expect(result, contains('. W'));
    });

    test('capitalizes after question mark', () {
      final result = capitalizer.process('hello? world');
      expect(result, contains('? W'));
    });

    test('capitalizes after exclamation', () {
      final result = capitalizer.process('hello! world');
      expect(result, contains('! W'));
    });

    test('preserves already capitalized', () {
      final result = capitalizer.process('Hello World');
      expect(result, 'Hello World');
    });

    test('empty text returns empty', () {
      final result = capitalizer.process('');
      expect(result, '');
    });
  });

  group('ContractionNormalizer', () {
    late ContractionNormalizer normalizer;

    setUp(() {
      normalizer = ContractionNormalizer();
    });

    test('dont -> don\'t', () {
      final result = normalizer.process('I dont know');
      expect(result, contains("don't"));
    });

    test('cant -> can\'t', () {
      final result = normalizer.process('I cant go');
      expect(result, contains("can't"));
    });

    test('wont -> won\'t', () {
      final result = normalizer.process('I wont go');
      expect(result, contains("won't"));
    });

    test('im -> I\'m', () {
      final result = normalizer.process('im going');
      expect(result, contains("I'm"));
    });

    test('youre -> you\'re', () {
      final result = normalizer.process('youre going');
      expect(result, contains("you're"));
    });

    test('gonna -> going to', () {
      final result = normalizer.process('I gonna go');
      expect(result, contains('going to'));
    });

    test('wanna -> want to', () {
      final result = normalizer.process('I wanna go');
      expect(result, contains('want to'));
    });

    test('gotta -> got to', () {
      final result = normalizer.process('I gotta go');
      expect(result, contains('got to'));
    });

    test('empty text returns empty', () {
      final result = normalizer.process('');
      expect(result, '');
    });
  });

  group('NumberFormatter', () {
    late NumberFormatter formatter;

    setUp(() {
      formatter = NumberFormatter();
    });

    test('converts small numbers', () {
      final result = formatter.process('I have 5 apples');
      expect(result, contains('five'));
    });

    test('converts teen numbers', () {
      final result = formatter.process('I have 15 apples');
      expect(result, contains('fifteen'));
    });

    test('converts tens', () {
      final result = formatter.process('I have 20 apples');
      expect(result, contains('twenty'));
    });

    test('converts hundreds', () {
      final result = formatter.process('I have 100 apples');
      expect(result, contains('one hundred'));
    });

    test('converts ordinals', () {
      final result = formatter.process('I am 1st');
      expect(result, contains('first'));
    });

    test('handles currency', () {
      final result = formatter.process('It costs \$50');
      expect(result, contains('fifty dollars'));
    });

    test('skips numbers with leading zeros', () {
      final result = formatter.process('code 007');
      expect(result, contains('007'));
    });

    test('empty text returns empty', () {
      final result = formatter.process('');
      expect(result, '');
    });
  });

  group('BacktrackHandler', () {
    late BacktrackHandler handler;

    setUp(() {
      handler = BacktrackHandler();
    });

    test('removes scratch that', () {
      final result = handler.process('hello world scratch that');
      expect(result, isNot(contains('scratch that')));
    });

    test('removes no wait', () {
      final result = handler.process('hello no wait actually world');
      expect(result, isNot(contains('no wait')));
    });

    test('removes I mean', () {
      final result = handler.process('hello I mean world');
      expect(result, isNot(contains('I mean')));
    });

    test('preserves normal text', () {
      final result = handler.process('hello world');
      expect(result, contains('hello world'));
    });

    test('empty text returns empty', () {
      final result = handler.process('');
      expect(result, '');
    });
  });

  group('Punctuator', () {
    late Punctuator punctuator;

    setUp(() {
      punctuator = Punctuator();
    });

    test('adds period for long pause', () {
      final result = punctuator.process('hello world', pauseDurationMs: 1000);
      expect(result, endsWith('.'));
    });

    test('adds question mark for question words', () {
      final result = punctuator.process('what is that', pauseDurationMs: 1000);
      expect(result, endsWith('?'));
    });

    test('does not add punctuation for short pause', () {
      final result = punctuator.process('hello world', pauseDurationMs: 100);
      expect(result, isNot(endsWith('.')));
    });

    test('preserves existing punctuation', () {
      final result = punctuator.process('hello.', pauseDurationMs: 1000);
      expect(result, 'hello.');
    });

    test('empty text returns empty', () {
      final result = punctuator.process('', pauseDurationMs: 1000);
      expect(result, '');
    });
  });

  group('StyleCleaner', () {
    late StyleCleaner cleaner;

    setUp(() {
      cleaner = StyleCleaner();
    });

    test('fixes spaces around punctuation', () {
      final result = cleaner.process('hello . world');
      expect(result, isNot(contains(' .')));
    });

    test('collapses multiple spaces', () {
      final result = cleaner.process('hello   world');
      expect(result, isNot(contains('   ')));
    });

    test('capitalizes standalone I', () {
      final result = cleaner.process('i went to the store');
      expect(result, contains('I'));
    });

    test('cleans repeated punctuation and bracket spacing', () {
      final result = cleaner.process('hello !!! ( world )');
      expect(result, 'hello! (world)');
    });

    test('empty text returns empty', () {
      final result = cleaner.process('');
      expect(result, '');
    });
  });

  group('WordReplacer', () {
    late WordReplacer replacer;

    setUp(() {
      replacer = WordReplacer();
    });

    test('replaces enabled words', () {
      final dictionary = [
        {'word': 'test', 'replacement': 'exam', 'enabled': true},
      ];
      final result = replacer.process('this is a test', dictionary);
      expect(result, contains('exam'));
      expect(result, isNot(contains('test')));
    });

    test('skips disabled words', () {
      final dictionary = [
        {'word': 'test', 'replacement': 'exam', 'enabled': false},
      ];
      final result = replacer.process('this is a test', dictionary);
      expect(result, contains('test'));
    });

    test('replaces multiple words', () {
      final dictionary = [
        {'word': 'hello', 'replacement': 'hi', 'enabled': true},
        {'word': 'world', 'replacement': 'earth', 'enabled': true},
      ];
      final result = replacer.process('hello world', dictionary);
      expect(result, contains('hi'));
      expect(result, contains('earth'));
    });

    test('case insensitive replacement', () {
      final dictionary = [
        {'word': 'test', 'replacement': 'exam', 'enabled': true},
      ];
      final result = replacer.process('This is a TEST', dictionary);
      expect(result, contains('exam'));
    });

    test('word boundary matching', () {
      final dictionary = [
        {'word': 'test', 'replacement': 'exam', 'enabled': true},
      ];
      final result = replacer.process('testing testing', dictionary);
      expect(result, contains('testing'));
    });

    test('replaces pronunciation aliases with the exact spelling', () {
      final dictionary = [
        {
          'word': 'Khrisshy',
          'replacement': 'Khrisshy',
          'aliases': ['krishi', 'crushy'],
          'enabled': true,
        },
      ];
      expect(replacer.process('hello krishi', dictionary), 'hello Khrisshy');
      expect(replacer.process('hello crushy', dictionary), 'hello Khrisshy');
    });

    test('empty dictionary returns original', () {
      final result = replacer.process('hello world', []);
      expect(result, 'hello world');
    });

    test('empty text returns empty', () {
      final result = replacer.process('', []);
      expect(result, '');
    });
  });

  group('DictationPipeline (Full Integration)', () {
    late DictationPipeline pipeline;

    setUp(() {
      pipeline = DictationPipeline();
    });

    test('processes simple text', () {
      final result = pipeline.process('hello world');
      expect(result.text, isNotEmpty);
    });

    test('removes fillers and applies rules', () {
      final result = pipeline.process('I um went to the uh store');
      expect(result.text, isNot(contains('um')));
      expect(result.text, isNot(contains('uh')));
    });

    test('handles commands', () {
      final result = pipeline.process('hello period');
      expect(result.text, contains('.'));
    });

    test('handles dictionary', () {
      pipeline.setDictionary([
        {'word': 'test', 'replacement': 'exam', 'enabled': true},
      ]);
      final result = pipeline.process('this is a test');
      expect(result.text, contains('exam'));
    });

    test('handles backtrack', () {
      final result = pipeline.process('hello world scratch that');
      expect(result.text, isNot(contains('scratch that')));
    });

    test('handles punctuation with pause', () {
      final result = pipeline.process('hello world', pauseDurationMs: 1000);
      expect(result.text, endsWith('.'));
    });

    test('empty text returns empty', () {
      final result = pipeline.process('');
      expect(result.text, '');
    });

    test('processes complex mixed input', () {
      final result = pipeline.process(
        'I um went to the uh store period new line hello world',
        pauseDurationMs: 500,
      );
      expect(result.text, isNot(contains('um')));
      expect(result.text, isNot(contains('uh')));
      expect(result.text, contains('.'));
    });
  });
}
