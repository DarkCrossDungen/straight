// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:straight/core/stt/moonshine_engine.dart';

int _readUint32(Uint8List bytes, int offset) =>
    bytes[offset] |
    (bytes[offset + 1] << 8) |
    (bytes[offset + 2] << 16) |
    (bytes[offset + 3] << 24);

int _readUint16(Uint8List bytes, int offset) =>
    bytes[offset] | (bytes[offset + 1] << 8);

List<int> _readPcm16Wav(String path) {
  final bytes = File(path).readAsBytesSync();
  if (String.fromCharCodes(bytes.sublist(0, 4)) != 'RIFF' ||
      String.fromCharCodes(bytes.sublist(8, 12)) != 'WAVE') {
    throw StateError('Expected a WAV file');
  }

  var offset = 12;
  var sampleRate = 0;
  var channels = 0;
  var bitsPerSample = 0;
  Uint8List? audio;
  while (offset + 8 <= bytes.length) {
    final name = String.fromCharCodes(bytes.sublist(offset, offset + 4));
    final size = _readUint32(bytes, offset + 4);
    final start = offset + 8;
    if (name == 'fmt ') {
      sampleRate = _readUint32(bytes, start + 4);
      channels = _readUint16(bytes, start + 2);
      bitsPerSample = _readUint16(bytes, start + 14);
    } else if (name == 'data') {
      audio = Uint8List.sublistView(bytes, start, start + size);
      break;
    }
    offset = start + size + (size.isOdd ? 1 : 0);
  }

  if (sampleRate != 16000 || channels != 1 || bitsPerSample != 16 || audio == null) {
    throw StateError('Expected 16 kHz mono 16-bit WAV, got $sampleRate Hz / $channels channel(s) / $bitsPerSample bit');
  }

  final samples = <int>[];
  for (var index = 0; index + 1 < audio.length; index += 2) {
    samples.add((audio[index] | (audio[index + 1] << 8)).toSigned(16));
  }
  return samples;
}

Future<void> main() async {
  // Dart itself can find an unrelated older ONNX Runtime on PATH. The packaged
  // Flutter app has this DLL next to its executable; preload that same local
  // copy for this standalone verification.
  DynamicLibrary.open('native/prebuilt/onnxruntime.dll');
  final engine = MoonshineEngine();
  final stopwatch = Stopwatch()..start();
  const modelPath = 'models/moonshine/small-streaming-en';
  const samplePath = 'native/moonshine/windows-cli-transcriber/cli-transcriber/beckett.wav';

  print('Moonshine smoke: init start');
  await engine.init(modelPath);
  print('Moonshine smoke: init ok in ${stopwatch.elapsedMilliseconds} ms');

  final samples = _readPcm16Wav(samplePath);
  stopwatch.reset();
  print('Moonshine smoke: transcribe start');
  final text = await engine.transcribe(samples);
  print('Moonshine smoke: transcribe ok in ${stopwatch.elapsedMilliseconds} ms');
  print('Moonshine smoke: result="$text"');

  await engine.dispose();
}
