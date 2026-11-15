import 'dart:async';
import 'dart:isolate';

import 'moonshine_engine.dart';
import 'qwen_asr_engine.dart';
import 'stt_engine.dart';
import 'whisper_engine.dart';

class SttEngineWorker {
  SttEngineWorker._(this._responses) {
    _responses.listen((message) {
      if (message is Map && message['ready'] is SendPort) {
        _commands = message['ready'] as SendPort;
        if (!_ready.isCompleted) _ready.complete();
        return;
      }
      if (message is! Map) return;
      final id = message['id'] as int?;
      final completer = id == null ? null : _pending.remove(id);
      if (completer == null || completer.isCompleted) return;
      if (message.containsKey('error')) {
        completer.completeError(StateError(message['error'].toString()));
      } else {
        completer.complete(message['result']);
      }
    });
  }

  final ReceivePort _responses;
  final Completer<void> _ready = Completer<void>();
  final Map<int, Completer<Object?>> _pending = {};
  late final Isolate _isolate;
  late SendPort _commands;
  int _nextId = 0;
  bool _disposed = false;

  static Future<SttEngineWorker> start(String modelPath) async {
    final responses = ReceivePort();
    final worker = SttEngineWorker._(responses);
    worker._isolate = await Isolate.spawn(_runSttEngine, responses.sendPort);
    await worker._ready.future;
    try {
      await worker._request('init', {'path': modelPath});
      return worker;
    } catch (_) {
      await worker.dispose();
      rethrow;
    }
  }

  Future<void> setVocabulary(List<String> terms) async {
    await _request('vocabulary', {'terms': terms});
  }

  Future<String> transcribe(List<int> audio) async =>
      (await _request('transcribe', {'audio': audio})) as String;

  Future<Object?> _request(
    String method, [
    Map<String, Object?> values = const {},
  ]) async {
    if (_disposed) throw StateError('Speech engine worker is disposed');
    final id = ++_nextId;
    final completer = Completer<Object?>();
    _pending[id] = completer;
    _commands.send({'id': id, 'method': method, ...values});
    return completer.future;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    try {
      await _request('dispose');
    } finally {
      _disposed = true;
      _isolate.kill(priority: Isolate.immediate);
      _responses.close();
      for (final completer in _pending.values) {
        if (!completer.isCompleted) {
          completer.completeError(StateError('Speech engine worker stopped'));
        }
      }
      _pending.clear();
    }
  }
}

void _runSttEngine(SendPort responses) {
  final commands = ReceivePort();
  SttEngine? engine;
  var chain = Future<void>.value();
  responses.send({'ready': commands.sendPort});

  Future<void> handle(Map<dynamic, dynamic> message) async {
    final id = message['id'] as int;
    try {
      switch (message['method']) {
        case 'init':
          final path = message['path'] as String;
          final normalized = path.toLowerCase();
          engine = normalized.contains('moonshine')
              ? MoonshineEngine()
              : normalized.contains('qwen3-asr') ||
                    normalized.contains('qwen_asr')
              ? QwenAsrEngine()
              : WhisperEngine();
          await engine!.init(path);
          responses.send({'id': id, 'result': null});
          return;
        case 'vocabulary':
          await engine!.setVocabulary(
            List<String>.from(message['terms'] as List),
          );
          responses.send({'id': id, 'result': null});
          return;
        case 'transcribe':
          final result = await engine!.transcribe(
            List<int>.from(message['audio'] as List),
          );
          responses.send({'id': id, 'result': result});
          return;
        case 'dispose':
          await engine?.dispose();
          engine = null;
          responses.send({'id': id, 'result': null});
          commands.close();
          return;
        default:
          throw StateError('Unknown speech engine worker command');
      }
    } catch (error) {
      responses.send({'id': id, 'error': error.toString()});
    }
  }

  commands.listen((message) {
    if (message is Map) {
      chain = chain.then((_) => handle(message));
    }
  });
}
