import 'dart:async';
import 'dart:typed_data';
import 'package:record/record.dart';
import '../audio/vad.dart';
import 'stt_engine.dart';
import 'whisper_engine.dart';
import 'qwen_asr_engine.dart';

enum SttPipelineState { idle, listening, processing }

class SttPipeline {
  final AudioRecorder _recorder = AudioRecorder();
  final VoiceActivityDetector _vad = VoiceActivityDetector();
  SttEngine? _engine;

  StreamSubscription<Uint8List>? _subscription;
  List<int> _buffer = [];
  bool _initialized = false;
  bool _isProcessing = false;
  Future<void>? _pendingTranscription;
  int _lastSpeechTimestamp = 0;
  bool _heardSpeechInBuffer = false;
  bool _isAutoStopping = false;

  SttPipelineState _state = SttPipelineState.idle;
  SttPipelineState get state => _state;
  bool get isInitialized => _initialized;
  int get lastPauseDurationMs {
    if (_lastSpeechTimestamp == 0) return 0;
    return DateTime.now().millisecondsSinceEpoch - _lastSpeechTimestamp;
  }

  void Function(SttPipelineState state)? onStateChanged;
  void Function(String text)? onResult;
  void Function(Object error)? onError;

  Future<void> init(String modelPath) async {
    if (_initialized) {
      await unloadModel();
    }

    // Choose engine based on model path
    final normalizedPath = modelPath.toLowerCase();
    if (normalizedPath.contains('qwen3-asr') || normalizedPath.contains('qwen_asr')) {
      _engine = QwenAsrEngine();
    } else {
      _engine = WhisperEngine();
    }

    await _engine!.init(modelPath);
    _initialized = true;
  }

  /// Stops capture and releases only the speech engine. The recorder remains
  /// usable so a model can be reloaded while the app is open.
  Future<void> unloadModel() async {
    await stop();
    await _engine?.dispose();
    _engine = null;
    _initialized = false;
  }

  Future<void> start() async {
    if (!_initialized) return;
    await stop();
    _setState(SttPipelineState.listening);
    _buffer = [];
    _vad.reset();
    _isProcessing = false;
    _heardSpeechInBuffer = false;

    final config = RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      numChannels: 1,
      sampleRate: 16000,
    );

    Stream<Uint8List> stream;
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        throw StateError('Microphone permission denied');
      }
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

    if (_vad.isSpeaking) {
      _lastSpeechTimestamp = DateTime.now().millisecondsSinceEpoch;
      _heardSpeechInBuffer = true;
    }

    // Never ask Whisper to interpret an open microphone that has contained
    // only silence. It can return labels such as [BLANK_AUDIO] for silence.
    if (!_heardSpeechInBuffer) {
      if (_buffer.length > 16000) _buffer.clear();
      return;
    }

    if (!_vad.isSpeaking && !_isProcessing && _buffer.length > 16000) {
      _pendingTranscription = _stopAfterSpeechPause();
    }
  }

  Future<void> _stopAfterSpeechPause() async {
    if (_isAutoStopping) return;
    _isAutoStopping = true;
    try {
      await _subscription?.cancel();
      _subscription = null;
      await _recorder.stop();
      await _flushBuffer();
    } finally {
      _buffer = [];
      _heardSpeechInBuffer = false;
      _pendingTranscription = null;
      _setState(SttPipelineState.idle);
      _isAutoStopping = false;
    }
  }

  Future<void> _flushBuffer() async {
    if (_buffer.isEmpty || !_heardSpeechInBuffer || _isProcessing || _engine == null) {
      return;
    }
    _isProcessing = true;
    _setState(SttPipelineState.processing);

    final samples = List<int>.from(_buffer);
    _buffer.clear();
    _vad.reset();
    _heardSpeechInBuffer = false;

    try {
      final text = await _engine!.transcribe(samples);
      if (_isUsableTranscription(text)) {
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
    if (_isAutoStopping) {
      await _pendingTranscription;
      return;
    }
    // Stop incoming audio before starting a potentially long transcription.
    // Otherwise fresh chunks can race with the buffer being transcribed.
    await _subscription?.cancel();
    _subscription = null;
    await _recorder.stop();

    if (_buffer.isNotEmpty && _heardSpeechInBuffer && !_isProcessing) {
      await _flushBuffer();
    }
    if (_pendingTranscription != null) {
      await _pendingTranscription;
    }
    _buffer = [];
    _heardSpeechInBuffer = false;
    _isProcessing = false;
    _pendingTranscription = null;
    _setState(SttPipelineState.idle);
  }

  Future<void> dispose() async {
    await unloadModel();
    _recorder.dispose();
  }

  List<int> _convertToInt16(Uint8List bytes) {
    final samples = <int>[];
    for (var i = 0; i + 1 < bytes.length; i += 2) {
      samples.add(((bytes[i + 1] << 8) | bytes[i]).toSigned(16));
    }
    return samples;
  }

  bool _isUsableTranscription(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || trimmed.startsWith('Transcription returned code:')) {
      return false;
    }

    if (RegExp(r'^(?:\[[^\]]+\]\s*)+$').hasMatch(trimmed)) {
      return false;
    }

    return !RegExp(r'^[\s.,!?;:…-]+$').hasMatch(trimmed);
  }

  void _setState(SttPipelineState newState) {
    _state = newState;
    onStateChanged?.call(newState);
  }
}
