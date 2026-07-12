import 'dart:ffi';
import 'package:ffi/ffi.dart';
import '../native/native_library_loader.dart';
import 'llm_engine.dart';

class QwenEngine implements LlmEngine {
  DynamicLibrary? _lib;
  Pointer<Void> Function(Pointer<Utf8>)? _init;
  Pointer<Utf8> Function(Pointer<Void>, Pointer<Utf8>, int)? _complete;
  void Function(Pointer<Void>)? _free;
  void Function(Pointer<Utf8>)? _freeString;
  Pointer<Void>? _ctx;
  bool _initialized = false;

  void _loadLibrary() {
    if (_lib != null) return;
    _lib = openNativeLibrary('qwen_wrapper.dll', 'libqwen_wrapper.so');
    _init = _lib!.lookupFunction<
        Pointer<Void> Function(Pointer<Utf8>),
        Pointer<Void> Function(Pointer<Utf8>)>('qwen_wrapper_init');
    _complete = _lib!.lookupFunction<
        Pointer<Utf8> Function(Pointer<Void>, Pointer<Utf8>, Int32),
        Pointer<Utf8> Function(Pointer<Void>, Pointer<Utf8>, int)>('qwen_wrapper_complete');
    _free = _lib!.lookupFunction<
        Void Function(Pointer<Void>),
        void Function(Pointer<Void>)>('qwen_wrapper_free');
    _freeString = _lib!.lookupFunction<
        Void Function(Pointer<Utf8>),
        void Function(Pointer<Utf8>)>('qwen_wrapper_free_string');
  }

  @override
  Future<void> init(String modelPath) async {
    _loadLibrary();
    final pathPtr = modelPath.toNativeUtf8();
    _ctx = _init!(pathPtr);
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
    final resultPtr = _complete!(_ctx!, promptPtr, maxTokens);
    calloc.free(promptPtr);

    if (resultPtr == nullptr) {
      return '';
    }

    final result = resultPtr.toDartString();
    _freeString!(resultPtr);
    return result;
  }

  @override
  Future<void> dispose() async {
    if (_ctx != nullptr) {
      _free?.call(_ctx!);
      _ctx = nullptr;
    }
    _initialized = false;
  }
}
