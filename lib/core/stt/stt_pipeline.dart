import 'dart:async';
import 'dart:typed_data';
import 'package:record/record.dart';
import '../audio/vad.dart';
import 'whisper_engine.dart';

enum SttPipelineState { idle, listening, processing }

class SttPipeline {
  final AudioRecorder _recorder = AudioRecorder();
  final VoiceActivityDetector _vad = VoiceActivityDetector();
  final WhisperEngine _engine = WhisperEngine();

  StreamSubscription<Uint8List>? _subscription;
  List<int> _buffer = [];
  bool _initialized = false;
  bool _isProcessing = false;
  Future<void>? _pendingTranscription;

  SttPipelineState _state = SttPipelineState.idle;
  SttPipelineState get state => _state;
  bool get isInitialized => _initialized;

  void Function(SttPipelineState state)? onStateChanged;
  void Function(String text)? onResult;
  void Function(Object error)? onError;

  Future<void> init(String modelPath) async {
    if (_initialized) {
      await _engine.dispose();
      _initialized = false;
    }
    await _engine.init(modelPath);
    _initialized = true;
  }

  Future<void> start() async {
    if (!_initialized) return;
    await stop();
    _setState(SttPipelineState.listening);
    _buffer = [];
    _vad.reset();
    _isProcessing = false;

    final config = RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      numChannels: 1,
      sampleRate: 16000,
    );

    Stream<Uint8List> stream;
    try {
      stream = await _recorder.startStream(config);
    } catch (e) {
      _setState(SttPipelineState.idle);
      onError?.call(e);
      return;
    }

    _subscription = stream.listen(_onAudioChunk,
        onError: (e) {
          _setState(SttPipelineState.idle);
          onError?.call(e);
        });
  }

  void _onAudioChunk(Uint8List chunk) {
    _vad.processChunk(chunk);

    final samples = _convertToInt16(chunk);
    _buffer.addAll(samples);

    if (!_vad.isSpeaking && !_isProcessing && _buffer.length > 16000) {
      _pendingTranscription = _flushBuffer();
    }
  }

  Future<void> _flushBuffer() async {
    if (_buffer.isEmpty || _isProcessing) return;
    _isProcessing = true;
    _setState(SttPipelineState.processing);

    final samples = List<int>.from(_buffer);
    _buffer.clear();
    _vad.reset();

    try {
      final text = await _engine.transcribe(samples);
      if (text.isNotEmpty && !text.startsWith('Transcription returned code:')) {
        onResult?.call(text);
      }
    } catch (e) {
      onError?.call(e);
    } finally {
      _isProcessing = false;
      _setState(SttPipelineState.listening);
    }
  }

  Future<void> stop() async {
    if (_buffer.isNotEmpty && !_isProcessing) {
      await _flushBuffer();
    }
    await _subscription?.cancel();
    _subscription = null;
    await _recorder.stop();
    if (_pendingTranscription != null) {
      await _pendingTranscription;
    }
    _buffer = [];
    _isProcessing = false;
    _pendingTranscription = null;
    _setState(SttPipelineState.idle);
  }

  Future<void> dispose() async {
    await stop();
    _recorder.dispose();
    await _engine.dispose();
  }

  List<int> _convertToInt16(Uint8List bytes) {
    final samples = <int>[];
    for (var i = 0; i + 1 < bytes.length; i += 2) {
      samples.add(((bytes[i + 1] << 8) | bytes[i]).toSigned(16));
    }
    return samples;
  }

  void _setState(SttPipelineState newState) {
    _state = newState;
    onStateChanged?.call(newState);
  }
}
