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

/// Band-limited-ish noise with a predictable RMS, so a test can state the room
/// loudness directly instead of guessing at an amplitude.
Uint8List noiseChunk(double rms, int samples, {int seed = 1}) {
  final bytes = Uint8List(samples * 2);
  final peak = rms * 32768 * 1.7320508;
  var state = seed;
  for (var i = 0; i < samples; i++) {
    state = (state * 1103515245 + 12345) & 0x7fffffff;
    final unit = ((state >> 7) & 0xffff) / 32768.0 - 1.0;
    final value = (unit * peak).round().clamp(-32768, 32767);
    bytes[i * 2] = value & 0xff;
    bytes[i * 2 + 1] = (value >> 8) & 0xff;
  }
  return bytes;
}

void feed(VoiceActivityDetector vad, double rms, int chunks, {int seed = 1}) {
  for (var i = 0; i < chunks; i++) {
    vad.processChunk(noiseChunk(rms, 1600, seed: seed + i));
  }
}

void main() {
  test('uses audio duration rather than the number of chunks', () {
    final vad = VoiceActivityDetector();

    vad.processChunk(pcmChunk(0, 1600));
    vad.processChunk(pcmChunk(1000, 3200));
    expect(vad.isSpeaking, isTrue);

    for (var i = 0; i < 4; i++) {
      vad.processChunk(pcmChunk(0, 3200));
    }
    expect(vad.isSpeaking, isFalse);
  });

  test('ignores a loud stationary noise floor instead of hearing speech', () {
    final vad = VoiceActivityDetector();
    // A laptop mic at full capture gain measured 0.63 RMS with nobody talking.
    feed(vad, 0.63, 40);
    expect(vad.isSpeaking, isFalse);
    expect(vad.noiseFloor, greaterThan(0.4));
  });

  test('ignores a quiet stationary noise floor', () {
    final vad = VoiceActivityDetector();
    feed(vad, 0.02, 40);
    expect(vad.isSpeaking, isFalse);
  });

  test('hears speech above fan noise', () {
    final vad = VoiceActivityDetector();
    feed(vad, 0.05, 10);
    expect(vad.isSpeaking, isFalse);

    feed(vad, 0.30, 4, seed: 900);
    expect(vad.isSpeaking, isTrue);
  });

  test('does not stay latched on noise that steps above the threshold', () {
    final vad = VoiceActivityDetector();
    feed(vad, 0.01, 10);
    // The fan spins up: stationary, but now far louder than the learned floor.
    feed(vad, 0.20, 100, seed: 500);
    expect(vad.isSpeaking, isFalse);

    feed(vad, 0.90, 4, seed: 1200);
    expect(vad.isSpeaking, isTrue);
  });

  test('keeps the learned room floor across a reset', () {
    final vad = VoiceActivityDetector();
    feed(vad, 0.05, 20);
    final learned = vad.noiseFloor;
    vad.reset();

    expect(vad.noiseFloor, learned);
    expect(vad.isSpeaking, isFalse);
    vad.processChunk(noiseChunk(0.05, 1600, seed: 77));
    expect(vad.isSpeaking, isFalse);
  });

  test('reports samples pinned to the digital rail', () {
    final vad = VoiceActivityDetector();
    vad.processChunk(pcmChunk(0, 1600));
    expect(vad.clippedRatio, 0);

    vad.processChunk(pcmChunk(-32768, 1600));
    expect(vad.clippedRatio, 1);
  });

  test('flags a loud wall of noise with no gaps as a dead capsule', () {
    final vad = VoiceActivityDetector();
    // The first chunk is the static, so the detector never mistakes it for
    // speech; it just stays loud without ever dipping.
    feed(vad, 0.60, 20, seed: 300);
    expect(vad.isSpeaking, isFalse);
    expect(vad.hearsOnlyStatic, isTrue);
  });

  test('does not flag quiet rooms or speech as static', () {
    final quiet = VoiceActivityDetector();
    feed(quiet, 0.02, 30);
    expect(quiet.hearsOnlyStatic, isFalse);

    final speaking = VoiceActivityDetector();
    feed(speaking, 0.02, 10);
    feed(speaking, 0.60, 40, seed: 400);
    expect(speaking.hearsOnlyStatic, isFalse);
  });
}