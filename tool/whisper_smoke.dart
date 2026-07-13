// ignore_for_file: avoid_print

import 'dart:math' as math;

import 'package:straight/core/stt/whisper_engine.dart';

Future<void> main() async {
  final engine = WhisperEngine();
  final stopwatch = Stopwatch()..start();
  const modelPath = 'models/whisper/ggml-base.bin';

  print('Whisper smoke: init start');
  await engine.init(modelPath);
  print('Whisper smoke: init ok in ${stopwatch.elapsedMilliseconds} ms');

  const sampleRate = 16000;
  final samples = List<int>.generate(sampleRate, (i) {
    final wave = math.sin(2 * math.pi * 440 * i / sampleRate);
    return (wave * 1200).round();
  });

  stopwatch.reset();
  print('Whisper smoke: transcribe start');
  final text = await engine.transcribe(samples);
  print('Whisper smoke: transcribe ok in ${stopwatch.elapsedMilliseconds} ms');
  print('Whisper smoke: result="${text.replaceAll('\n', ' ')}"');

  await engine.dispose();
}
