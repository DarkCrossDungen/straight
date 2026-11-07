// ignore_for_file: avoid_print

import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:straight/core/pipeline/dictation_pipeline.dart';
import 'package:straight/core/stt/moonshine_engine.dart';

/// Proves the dictation chain without a microphone: a known 16 kHz speech file
/// goes through the same engine and cleanup rules the app uses, and the raw and
/// cleaned text are both printed.
Future<void> main(List<String> args) async {
  final wavPath = args.isNotEmpty
      ? args.first
      : '/usr/share/sounds/speech-dispatcher/test.wav';

  if (Platform.isLinux) {
    // The wrapper resolves ONNX Runtime from its own directory; preload the
    // packaged copy so a system one cannot be picked instead.
    DynamicLibrary.open('native/prebuilt/libonnxruntime.so.1');
  }

  final samples = _readPcm16Wav(wavPath);
  print('audio: $wavPath  ${(samples.length / 16000).toStringAsFixed(2)} s');

  final engine = MoonshineEngine();
  final watch = Stopwatch()..start();
  await engine.init('models/moonshine/small-streaming-en');
  print('model loaded in ${watch.elapsedMilliseconds} ms');

  watch.reset();
  final raw = await engine.transcribe(samples);
  print('transcribed in ${watch.elapsedMilliseconds} ms');
  print('raw    : "$raw"');

  final pipeline = DictationPipeline()..setDictionary(const []);
  final cleaned = pipeline.process(raw);
  print('cleaned: "${cleaned.text}"');
  await engine.dispose();

  print('');
  print('cleanup rules on known phrases:');
  for (final phrase in [
    'um so i think we should uh ship it on friday',
    'send the report new line then say thanks period',
    'the meeting is at 3 pm scratch that make it 4 pm',
    'i dont know whats happening',
  ]) {
    print('  "$phrase" -> "${pipeline.process(phrase).text}"');
  }
}

int _uint32(Uint8List b, int o) =>
    b[o] | (b[o + 1] << 8) | (b[o + 2] << 16) | (b[o + 3] << 24);

int _uint16(Uint8List b, int o) => b[o] | (b[o + 1] << 8);

List<int> _readPcm16Wav(String path) {
  final bytes = File(path).readAsBytesSync();
  if (String.fromCharCodes(bytes.sublist(0, 4)) != 'RIFF') {
    throw StateError('Expected a WAV file');
  }
  var offset = 12;
  var rate = 0;
  var channels = 0;
  var bits = 0;
  Uint8List? audio;
  while (offset + 8 <= bytes.length) {
    final name = String.fromCharCodes(bytes.sublist(offset, offset + 4));
    final size = _uint32(bytes, offset + 4);
    final start = offset + 8;
    if (name == 'fmt ') {
      rate = _uint32(bytes, start + 4);
      channels = _uint16(bytes, start + 2);
      bits = _uint16(bytes, start + 14);
    } else if (name == 'data') {
      audio = Uint8List.sublistView(bytes, start, start + size);
      break;
    }
    offset = start + size + (size.isOdd ? 1 : 0);
  }
  if (rate != 16000 || channels != 1 || bits != 16 || audio == null) {
    throw StateError(
      'Expected 16 kHz mono 16-bit WAV, got $rate Hz / $channels / $bits bit',
    );
  }
  final samples = <int>[];
  for (var i = 0; i + 1 < audio.length; i += 2) {
    samples.add((audio[i] | (audio[i + 1] << 8)).toSigned(16));
  }
  return samples;
}
