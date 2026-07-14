import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:straight/core/audio/vad.dart';

Uint8List pcmChunk(int amplitude, int samples) {
  final bytes = Uint8List(samples * 2);
  for (var i = 0; i < samples; i++) {
    bytes[i * 2] = amplitude & 0xff;
    bytes[i * 2 + 1] = (amplitude >> 8) & 0xff;
  }
  return bytes;
}

void main() {
  test('uses audio duration rather than the number of chunks', () {
    final vad = VoiceActivityDetector();

    vad.processChunk(pcmChunk(1000, 3200));
    expect(vad.isSpeaking, isTrue);

    for (var i = 0; i < 4; i++) {
      vad.processChunk(pcmChunk(0, 3200));
    }
    expect(vad.isSpeaking, isFalse);
  });
}
