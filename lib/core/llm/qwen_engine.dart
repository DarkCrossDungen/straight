import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'llm_engine.dart';

final DynamicLibrary _lib = Platform.isWindows
    ? DynamicLibrary.open('native/prebuilt/qwen_wrapper.dll')
    : DynamicLibrary.open('native/prebuilt/libqwen_wrapper.so');

final _init = _lib.lookupFunction<
    Pointer<Void> Function(Pointer<Utf8>),
    Pointer<Void> Function(Pointer<Utf8>)>('qwen_wrapper_init');

final _complete = _lib.lookupFunction<
    Pointer<Utf8> Function(Pointer<Void>, Pointer<Utf8>, Int32),
    Pointer<Utf8> Function(Pointer<Void>, Pointer<Utf8>, int)>('qwen_wrapper_complete');

final _free = _lib.lookupFunction<
    Void Function(Pointer<Void>),
    void Function(Pointer<Void>)>('qwen_wrapper_free');

final _freeString = _lib.lookupFunction<
    Void Function(Pointer<Utf8>),
    void Function(Pointer<Utf8>)>('qwen_wrapper_free_string');

class QwenEngine implements LlmEngine {
  Pointer<Void>? _ctx;
  bool _initialized = false;

  @override
  Future<void> init(String modelPath) async {
    final pathPtr = modelPath.toNativeUtf8();
    _ctx = _init(pathPtr);
    calloc.free(pathPtr);
    if (_ctx == nullptr) {
      throw Exception('Failed to load Qwen model: $modelPath');
    }
    _initialized = true;
  }

  @override
  Future<String> complete(String prompt, {int maxTokens = 128}) async {
    if (!_initialized || _ctx == nullptr) {
      throw Exception('Qwen engine not initialized');
    }

    final promptPtr = prompt.toNativeUtf8();
    final resultPtr = _complete(_ctx!, promptPtr, maxTokens);
    calloc.free(promptPtr);

    if (resultPtr == nullptr) {
      return '';
    }

    final result = resultPtr.toDartString();
    _freeString(resultPtr);
    return result;
  }

  @override
  Future<void> dispose() async {
    if (_ctx != nullptr) {
      _free(_ctx!);
      _ctx = nullptr;
    }
    _initialized = false;
  }
}
