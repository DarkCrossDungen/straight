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
  });

  test('keeps useful text while removing long dot runs', () {
    expect(
      SttPipeline.cleanTranscriptionForDictation('Testing one two three..........'),
      'Testing one two three',
    );
  });
}
