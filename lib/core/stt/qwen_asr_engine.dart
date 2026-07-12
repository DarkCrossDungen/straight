import 'dart:ffi';
import 'package:ffi/ffi.dart';
import '../native/native_library_loader.dart';
import 'stt_engine.dart';

typedef _InitNative = Pointer<Void> Function(Pointer<Utf8> modelDir);
typedef _InitDart = Pointer<Void> Function(Pointer<Utf8> modelDir);

typedef _FreeNative = Void Function(Pointer<Void> ctx);
typedef _FreeDart = void Function(Pointer<Void> ctx);

typedef _TranscribeNative = Pointer<Utf8> Function(
    Pointer<Void> ctx, Pointer<Float> samples, Int32 nSamples);
typedef _TranscribeDart = Pointer<Utf8> Function(
    Pointer<Void> ctx, Pointer<Float> samples, int nSamples);

typedef _FreeStringNative = Void Function(Pointer<Utf8> str);
typedef _FreeStringDart = void Function(Pointer<Utf8> str);

typedef _SetPromptNative = Int32 Function(Pointer<Void> ctx, Pointer<Utf8> prompt);
typedef _SetPromptDart = int Function(Pointer<Void> ctx, Pointer<Utf8> prompt);

typedef _SetLanguageNative = Int32 Function(Pointer<Void> ctx, Pointer<Utf8> language);
typedef _SetLanguageDart = int Function(Pointer<Void> ctx, Pointer<Utf8> language);

typedef _LastErrorNative = Pointer<Utf8> Function();
typedef _LastErrorDart = Pointer<Utf8> Function();

class QwenAsrEngine extends SttEngine {
  DynamicLibrary? _lib;
  Pointer<Void>? _ctx;

  _InitDart? _init;
  _FreeDart? _free;
  _TranscribeDart? _transcribe;
  _FreeStringDart? _freeString;
  _SetPromptDart? _setPrompt;
  _SetLanguageDart? _setLanguage;
  _LastErrorDart? _lastError;

  bool get isLoaded => _ctx != null && _ctx != nullptr;

  @override
  Future<void> init(String modelPath) async {
    final dir = modelPath;

    try {
      _lib = openNativeLibrary(
        'qwen_asr_wrapper.dll',
        'libqwen_asr_wrapper.so',
      );
    } catch (e) {
      throw Exception('Failed to load qwen_asr_wrapper.dll: $e');
    }

    _init = _lib!.lookupFunction<_InitNative, _InitDart>('qwen_asr_wrapper_init');
    _free = _lib!.lookupFunction<_FreeNative, _FreeDart>('qwen_asr_wrapper_free');
    _transcribe = _lib!.lookupFunction<_TranscribeNative, _TranscribeDart>(
        'qwen_asr_wrapper_transcribe');
    _freeString = _lib!.lookupFunction<_FreeStringNative, _FreeStringDart>(
        'qwen_asr_wrapper_free_string');
    _setPrompt = _lib!.lookupFunction<_SetPromptNative, _SetPromptDart>(
        'qwen_asr_wrapper_set_prompt');
    _setLanguage = _lib!.lookupFunction<_SetLanguageNative, _SetLanguageDart>(
        'qwen_asr_wrapper_set_language');
    _lastError = _lib!.lookupFunction<_LastErrorNative, _LastErrorDart>(
        'qwen_asr_wrapper_last_error');

    final dirPtr = dir.toNativeUtf8();
    try {
      _ctx = _init!(dirPtr);
    } finally {
      calloc.free(dirPtr);
    }

    if (_ctx == null || _ctx == nullptr) {
      final errorPtr = _lastError?.call();
      final detail = errorPtr == null || errorPtr == nullptr
          ? 'unknown native error'
          : errorPtr.toDartString();
      throw Exception('Failed to load Qwen3-ASR model from: $dir ($detail)');
    }
  }

  @override
  Future<String> transcribe(List<int> pcmAudio) async {
    if (!isLoaded) throw Exception('Qwen3-ASR not initialized');

    final floatSamples = calloc<Float>(pcmAudio.length);
    try {
      for (var i = 0; i < pcmAudio.length; i++) {
        floatSamples[i] = pcmAudio[i] / 32768.0;
      }

      final resultPtr = _transcribe!(_ctx!, floatSamples, pcmAudio.length);
      if (resultPtr == nullptr) return '';

      try {
        return resultPtr.toDartString();
      } finally {
        _freeString!(resultPtr);
      }
    } finally {
      calloc.free(floatSamples);
    }
  }

  @override
  Future<void> dispose() async {
    if (_ctx != null && _ctx != nullptr) {
      _free!(_ctx!);
      _ctx = null;
    }
    _lib = null;
  }

  Future<bool> setPrompt(String prompt) async {
    if (!isLoaded) return false;
    final promptPtr = prompt.toNativeUtf8();
    try {
      return _setPrompt!(_ctx!, promptPtr) == 0;
    } finally {
      calloc.free(promptPtr);
    }
  }

  Future<bool> setLanguage(String language) async {
    if (!isLoaded) return false;
    final langPtr = language.toNativeUtf8();
    try {
      return _setLanguage!(_ctx!, langPtr) == 0;
    } finally {
      calloc.free(langPtr);
    }
  }
}
