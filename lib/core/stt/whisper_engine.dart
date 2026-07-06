import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'stt_engine.dart';

DynamicLibrary _loadLib() {
  if (Platform.isWindows) {
    return DynamicLibrary.open('native/prebuilt/whisper_wrapper.dll');
  }
  return DynamicLibrary.open('native/prebuilt/libwhisper_wrapper.so');
}

final DynamicLibrary _lib = _loadLib();

final _whisperInit = _lib.lookupFunction<
    Pointer<Void> Function(Pointer<Utf8>),
    Pointer<Void> Function(Pointer<Utf8>)>('whisper_wrapper_init');

final _whisperFree = _lib.lookupFunction<
    Void Function(Pointer<Void>),
    void Function(Pointer<Void>)>('whisper_wrapper_free');

final _whisperDefaultParams = _lib.lookupFunction<
    Pointer<Void> Function(Int32),
    Pointer<Void> Function(int)>('whisper_wrapper_default_params');

final _whisperFull = _lib.lookupFunction<
    Int32 Function(Pointer<Void>, Pointer<Void>, Pointer<Float>, Int32),
    int Function(Pointer<Void>, Pointer<Void>, Pointer<Float>, int)>('whisper_wrapper_full');

final _whisperFreeParams = _lib.lookupFunction<
    Void Function(Pointer<Void>),
    void Function(Pointer<Void>)>('whisper_wrapper_free_params');

final _whisperFullNSegments = _lib.lookupFunction<
    Int32 Function(Pointer<Void>),
    int Function(Pointer<Void>)>('whisper_wrapper_n_segments');

final _whisperFullGetSegmentText = _lib.lookupFunction<
    Pointer<Utf8> Function(Pointer<Void>, Int32),
    Pointer<Utf8> Function(Pointer<Void>, int)>('whisper_wrapper_segment_text');

class WhisperEngine implements SttEngine {
  Pointer<Void>? _ctx;
  bool _initialized = false;

  @override
  Future<void> init(String modelPath) async {
    final pathPtr = modelPath.toNativeUtf8();
    _ctx = _whisperInit(pathPtr);
    calloc.free(pathPtr);
    if (_ctx == nullptr) {
      throw Exception('Failed to load whisper model: $modelPath');
    }
    _initialized = true;
  }

  @override
  Future<String> transcribe(List<int> pcmAudio) async {
    if (!_initialized || _ctx == nullptr) {
      throw Exception('Whisper engine not initialized');
    }

    final paramsPtr = _whisperDefaultParams(0);

    final samplesPtr = calloc<Float>(pcmAudio.length);
    for (var i = 0; i < pcmAudio.length; i++) {
      samplesPtr[i] = pcmAudio[i] / 32768.0;
    }

    final ret = _whisperFull(_ctx!, paramsPtr, samplesPtr, pcmAudio.length);
    _whisperFreeParams(paramsPtr);
    calloc.free(samplesPtr);

    if (ret != 0) {
      return 'Transcription returned code: $ret';
    }

    final nSegments = _whisperFullNSegments(_ctx!);

    final buffer = StringBuffer();
    for (var i = 0; i < nSegments; i++) {
      final textPtr = _whisperFullGetSegmentText(_ctx!, i);
      buffer.write(textPtr.toDartString());
      buffer.write(' ');
    }

    return buffer.toString().trim();
  }

  @override
  Future<void> dispose() async {
    if (_ctx != nullptr) {
      _whisperFree(_ctx!);
      _ctx = nullptr;
    }
    _initialized = false;
  }
}
