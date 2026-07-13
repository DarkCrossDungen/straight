import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class ModelDownloader extends ChangeNotifier {
  bool _isDownloading = false;
  double _progress = 0.0;
  String? _currentModel;
  String? _statusText;

  bool get isDownloading => _isDownloading;
  double get progress => _progress;
  String? get currentModel => _currentModel;
  String? get statusText => _statusText;

  static const _models = {
    'whisper-base': {
      'name': 'Whisper Base',
      'url': 'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin',
      'filename': 'ggml-base.bin',
      'subdir': 'whisper',
      'size': 141_000_000,
      'type': 'stt',
    },
    'whisper-small': {
      'name': 'Whisper Small',
      'url': 'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin',
      'filename': 'ggml-small.bin',
      'subdir': 'whisper',
      'size': 461_000_000,
      'type': 'stt',
    },
    'whisper-medium': {
      'name': 'Whisper Medium',
      'url': 'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.bin',
      'filename': 'ggml-medium.bin',
      'subdir': 'whisper',
      'size': 1_420_000_000,
      'type': 'stt',
    },
    'qwen3-asr-0.6b': {
      'name': 'Qwen3-ASR 0.6B',
      'url': 'https://huggingface.co/Qwen/Qwen3-ASR-0.6B/resolve/main/model.safetensors',
      'filename': 'Qwen3-ASR-0.6B',
      'subdir': 'qwen',
      'size': 1_876_000_000,
      'type': 'stt',
      'isDirectory': true,
      'note': 'Experimental in this app until the native Qwen ASR DLL is rebuilt with acceleration. Download full model directory from: huggingface-cli download Qwen/Qwen3-ASR-0.6B --local-dir <path>/qwen/Qwen3-ASR-0.6B',
    },
    'qwen2.5-0.5b': {
      'name': 'Qwen2.5-0.5B Instruct',
      'url': 'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf',
      'filename': 'qwen2.5-0.5b-instruct-q4_k_m.gguf',
      'subdir': 'qwen',
      'size': 390_000_000,
      'type': 'llm',
    },
    'qwen2.5-1.5b': {
      'name': 'Qwen2.5-1.5B Instruct',
      'url': 'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf',
      'filename': 'qwen2.5-1.5b-instruct-q4_k_m.gguf',
      'subdir': 'qwen',
      'size': 980_000_000,
      'type': 'llm',
    },
  };

  Future<String> _getModelsDir() async {
    final appDir = await getApplicationSupportDirectory();
    final dir = Directory('${appDir.path}${Platform.pathSeparator}models');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  Future<String> _getFilePath(String modelId) async {
    final model = _models[modelId];
    if (model == null) throw ArgumentError('Unknown model: $modelId');
    final modelsDir = await _getModelsDir();
    final subdir = model['subdir'] as String;
    final filename = model['filename'] as String;
    return '$modelsDir${Platform.pathSeparator}$subdir${Platform.pathSeparator}$filename';
  }

  Future<void> _ensureDirForModel(String modelId) async {
    final model = _models[modelId];
    if (model == null) return;
    final modelsDir = await _getModelsDir();
    final subdir = model['subdir'] as String;
    final dir = Directory('$modelsDir${Platform.pathSeparator}$subdir');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  Future<void> downloadModel(
    String modelId, {
    required void Function(double progress, String status) onProgress,
  }) async {
    final model = _models[modelId];
    if (model == null) throw ArgumentError('Unknown model: $modelId');

    _isDownloading = true;
    _currentModel = modelId;
    _progress = 0.0;
    _statusText = 'Starting download...';
    notifyListeners();
    onProgress(_progress, _statusText!);

    try {
      await _ensureDirForModel(modelId);
      final filePath = await _getFilePath(modelId);
      final file = File(filePath);
      int downloadedBytes = 0;

      if (await file.exists()) {
        downloadedBytes = await file.length();
      }

      final uri = Uri.parse(model['url'] as String);
      final client = http.Client();

      try {
        final request = http.Request('GET', uri);

        if (downloadedBytes > 0) {
          request.headers['Range'] = 'bytes=$downloadedBytes-';
        }

        final response = await client.send(request);
        final totalBytes = response.contentLength ?? (model['size'] as int);

        if (response.statusCode == 200 || response.statusCode == 206) {
          final raf = await file.open(mode: FileMode.append);

          try {
            await for (final chunk in response.stream) {
              await raf.writeFrom(chunk);
              downloadedBytes += chunk.length;

              final total = totalBytes > 0 ? totalBytes : model['size'] as int;
              _progress = total > 0 ? downloadedBytes / total : 0.0;

              final downloadedMb = downloadedBytes / (1024 * 1024);
              final totalMb = total / (1024 * 1024);
              _statusText =
                  'Downloaded ${downloadedMb.toStringAsFixed(1)} MB / ${totalMb.toStringAsFixed(1)} MB';

              onProgress(_progress, _statusText!);
              notifyListeners();
            }
          } finally {
            await raf.close();
          }
        } else {
          throw HttpException('Unexpected status code: ${response.statusCode}');
        }
      } finally {
        client.close();
      }
    } catch (e) {
      _isDownloading = false;
      _currentModel = null;
      _progress = 0.0;
      _statusText = 'Download failed: $e';
      notifyListeners();
      onProgress(0.0, _statusText!);
      rethrow;
    }

    _isDownloading = false;
    _currentModel = null;
    _progress = 1.0;
    _statusText = 'Download complete';
    notifyListeners();
    onProgress(1.0, _statusText!);
  }

  Future<bool> isModelDownloaded(String modelId) async {
    final model = _models[modelId];
    if (model == null) throw ArgumentError('Unknown model: $modelId');
    final filePath = await _getFilePath(modelId);
    return await File(filePath).exists();
  }

  Future<Map<String, dynamic>> getModelInfo(String modelId) async {
    final model = _models[modelId];
    if (model == null) throw ArgumentError('Unknown model: $modelId');
    final filePath = await _getFilePath(modelId);
    final file = File(filePath);
    final exists = await file.exists();
    final size = exists ? await file.length() : 0;
    return {
      'downloaded': exists,
      'size': size,
      'path': filePath,
    };
  }

  Future<List<Map<String, dynamic>>> listModels() async {
    final results = <Map<String, dynamic>>[];
    for (final modelId in _models.keys) {
      final info = await getModelInfo(modelId);
      info['id'] = modelId;
      info['name'] = (_models[modelId]! as Map)['name'];
      info['type'] = (_models[modelId]! as Map)['type'];
      results.add(info);
    }
    return results;
  }
}
