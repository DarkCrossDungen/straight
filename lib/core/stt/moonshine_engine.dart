import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../native/native_library_loader.dart';
import 'stt_engine.dart';

DynamicLibrary _loadLibrary() {
  return openNativeLibrary('moonshine_wrapper.dll', 'libmoonshine_wrapper.so');
}

final DynamicLibrary _library = _loadLibrary();

final _moonshineInit = _library.lookupFunction<
    Pointer<Void> Function(Pointer<Utf8>),
    Pointer<Void> Function(Pointer<Utf8>)>('moonshine_wrapper_init');

final _moonshineLastError = _library.lookupFunction<
    Pointer<Utf8> Function(),
    Pointer<Utf8> Function()>('moonshine_wrapper_last_error');

final _moonshineTranscribe = _library.lookupFunction<
    Pointer<Utf8> Function(Pointer<Void>, Pointer<Float>, Int32),
    Pointer<Utf8> Function(Pointer<Void>, Pointer<Float>, int)>(
  'moonshine_wrapper_transcribe',
);

final _moonshineFreeString = _library.lookupFunction<
    Void Function(Pointer<Utf8>),
    void Function(Pointer<Utf8>)>('moonshine_wrapper_free_string');

final _moonshineFree = _library.lookupFunction<
    Void Function(Pointer<Void>),
    void Function(Pointer<Void>)>('moonshine_wrapper_free');

String _lastNativeError() {
  final pointer = _moonshineLastError();
  if (pointer == nullptr) return 'unknown native error';
  final error = pointer.toDartString();
  return error.isEmpty ? 'unknown native error' : error;
}

class MoonshineEngine implements SttEngine {
  Pointer<Void>? _context;

  @override
  Future<void> init(String modelPath) async {
    final path = modelPath.toNativeUtf8();
    _context = _moonshineInit(path);
    calloc.free(path);

    if (_context == nullptr) {
      throw Exception(
        'Failed to load Moonshine model: $modelPath (${_lastNativeError()})',
      );
    }
  }

  @override
  Future<String> transcribe(List<int> pcmAudio) async {
    final context = _context;
    if (context == null || context == nullptr) {
      throw Exception('Moonshine engine not initialized');
    }
    if (pcmAudio.isEmpty) return '';

    final samples = calloc<Float>(pcmAudio.length);
    for (var index = 0; index < pcmAudio.length; index++) {
      samples[index] = pcmAudio[index] / 32768.0;
    }

    final result = _moonshineTranscribe(context, samples, pcmAudio.length);
    calloc.free(samples);
    if (result == nullptr) {
      throw Exception('Moonshine transcription failed (${_lastNativeError()})');
    }

    try {
      return result.toDartString().trim();
    } finally {
      _moonshineFreeString(result);
    }
  }

  @override
  Future<void> setVocabulary(List<String> terms) async {
    // Moonshine's first integration uses its native acoustic model as-is.
    // Dictionary corrections still run in the shared rules pipeline afterward.
  }

  @override
  Future<void> dispose() async {
    final context = _context;
    if (context != null && context != nullptr) {
      _moonshineFree(context);
    }
    _context = null;
  }
}
