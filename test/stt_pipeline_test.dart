import 'package:flutter_test/flutter_test.dart';
import 'package:straight/core/stt/stt_pipeline.dart';

void main() {
  test('drops whisper dotted hallucinations', () {
    expect(
      SttPipeline.cleanTranscriptionForDictation('One,............................'),
      isNull,
    );
    expect(
      SttPipeline.cleanTranscriptionForDictation('Testing .................'),
      isNull,
    );
    expect(
      SttPipeline.cleanTranscriptionForDictation("What's ??????????????????????"),
      isNull,
    );
    expect(
      SttPipeline.cleanTranscriptionForDictation(
        '[BLANK_AUDIO].[BLANK_AUDIO].[BLANK_AUDIO].',
      ),
      isNull,
    );
  });

  test('keeps useful text while removing long dot runs', () {
    expect(
      SttPipeline.cleanTranscriptionForDictation('Testing one two three..........'),
      'Testing one two three',
    );
    expect(
      SttPipeline.cleanTranscriptionForDictation("What's the time ?????????"),
      "What's the time",
    );
    expect(
      SttPipeline.cleanTranscriptionForDictation(
        'I want the shimless ....................................................................',
      ),
      'I want the shimless',
    );
  });

  test('drops spaced and mixed punctuation hallucinations', () {
    expect(
      SttPipeline.cleanTranscriptionForDictation('What is this ? . ? . ?'),
      'What is this',
    );
    expect(
      SttPipeline.cleanTranscriptionForDictation('One, . . . . .'),
      isNull,
    );
    expect(
      SttPipeline.cleanTranscriptionForDictation('Hello world . . . .'),
      'Hello world',
    );
  });
}
