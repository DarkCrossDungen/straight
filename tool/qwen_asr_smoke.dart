// ignore_for_file: avoid_print

import 'dart:math' as math;

import 'package:straight/core/stt/qwen_asr_engine.dart';

Future<void> main() async {
  final engine = QwenAsrEngine();
  final stopwatch = Stopwatch()..start();
  const modelPath = 'models/qwen/Qwen3-ASR-0.6B';

  print('Qwen smoke: init start');
  await engine.init(modelPath);
  print('Qwen smoke: init ok in ${stopwatch.elapsedMilliseconds} ms');

  const sampleRate = 16000;
  final samples = List<int>.generate(sampleRate, (i) {
    final wave = math.sin(2 * math.pi * 440 * i / sampleRate);
    return (wave * 1200).round();
  });

  stopwatch.reset();
  print('Qwen smoke: transcribe start');
  final text = await engine.transcribe(samples);
  print('Qwen smoke: transcribe ok in ${stopwatch.elapsedMilliseconds} ms');
  print('Qwen smoke: result="${text.replaceAll('\n', ' ')}"');

  await engine.dispose();
}
