import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import '../audio/vad.dart';
import 'stt_engine.dart';
import 'whisper_engine.dart';
import 'qwen_asr_engine.dart';
import 'moonshine_engine.dart';

enum SttPipelineState { idle, listening, processing }

class SttPipeline {
  final AudioRecorder _recorder = AudioRecorder();
  final VoiceActivityDetector _vad = VoiceActivityDetector();
  SttEngine? _engine;

  StreamSubscription<Uint8List>? _subscription;
  Future<void>? _primingMicrophone;
  bool _microphonePrimed = false;
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

  Future<void> prepareMicrophone() async {
    if (_microphonePrimed) return;
    final inFlight = _primingMicrophone;
    if (inFlight != null) return inFlight;

    _primingMicrophone = _primeMicrophone();
    try {
      await _primingMicrophone;
    } catch (_) {
      // Permission failures are surfaced when dictation actually starts.
    } finally {
      _primingMicrophone = null;
    }
  }

  Future<void> _primeMicrophone() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) throw StateError('Microphone permission denied');

    final stream = await _recorder.startStream(const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      numChannels: 1,
      sampleRate: 16000,
    ));
    final subscription = stream.listen((_) {});
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await subscription.cancel();
    await _recorder.stop();
    _microphonePrimed = true;
  }

  Future<void> init(String modelPath) async {
    if (_initialized) {
      await unloadModel();
    }

    // Choose engine based on model path
    final normalizedPath = modelPath.toLowerCase();
    if (normalizedPath.contains('moonshine')) {
      _engine = MoonshineEngine();
    } else if (normalizedPath.contains('qwen3-asr') || normalizedPath.contains('qwen_asr')) {
      _engine = QwenAsrEngine();
    } else {
      _engine = WhisperEngine();
    }

    await _engine!.init(modelPath);
    _initialized = true;
  }

  Future<void> setVocabulary(List<String> terms) async {
    await _engine?.setVocabulary(terms);
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
    if (_isProcessing) return;
    _setState(SttPipelineState.listening);
    _buffer = [];
    _vad.reset();
    _isProcessing = false;
    _heardSpeechInBuffer = false;

    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) throw StateError('Microphone permission denied');
      final stream = await _recorder.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        numChannels: 1,
        sampleRate: 16000,
      ));
      _subscription = stream.listen(
        _onAudioChunk,
        onError: (Object error) {
          _subscription = null;
          _setState(SttPipelineState.idle);
          onError?.call(error);
        },
      );
    } catch (e) {
      _setState(SttPipelineState.idle);
      onError?.call(e);
    }
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
      final text = cleanTranscriptionForDictation(await _engine!.transcribe(samples));
      if (text != null) {
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
    // Stop incoming audio before beginning transcription. This releases the
    // Windows microphone immediately when the user releases the hotkey.
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

  @visibleForTesting
  static String? cleanTranscriptionForDictation(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || trimmed.startsWith('Transcription returned code:')) {
      return null;
    }

    if (RegExp(r'^(?:\[[^\]]+\]\s*)+$').hasMatch(trimmed)) {
      return null;
    }

    if (RegExp(r'^[\s.,!?;:…-]+$').hasMatch(trimmed)) {
      return null;
    }

    // Small Whisper models can repeat punctuation while guessing at silence,
    // room noise, or music. The marks can be separated by spaces, which is why
    // a simple "..." matcher was not enough.
    final hasRepeatedPunctuation = RegExp(r'[.!?…](?:\s*[.!?…]){1,}').hasMatch(trimmed);
    final withoutLongPunctuation = trimmed
        .replaceAll(RegExp(r'[.!?…](?:\s*[.!?…]){1,}'), ' ')
        .replaceAll(RegExp(r'(?<=\s)[.!?…](?=\s|$)'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (withoutLongPunctuation.isEmpty ||
        RegExp(r'^[\s.,!?;:…-]+$').hasMatch(withoutLongPunctuation)) {
      return null;
    }

    final punctuationCount = RegExp(r'[.,!?;:…-]').allMatches(withoutLongPunctuation).length;
    final letterCount = RegExp(r'[A-Za-z0-9]').allMatches(withoutLongPunctuation).length;
    final wordCount = RegExp(r"\b[A-Za-z0-9']+\b").allMatches(withoutLongPunctuation).length;

    // Whisper often hallucinates a single vague word followed by many dots
    // when the input is silence, room noise, or a clipped utterance.
    if ((punctuationCount * 3 > letterCount || hasRepeatedPunctuation) && wordCount < 2) {
      return null;
    }

    // Non-speech labels and music captions are not useful dictation.
    if (RegExp(r'^\(?\s*(?:music|applause|laughter|silence|noise)\s*\)?$',
            caseSensitive: false)
        .hasMatch(withoutLongPunctuation)) {
      return null;
    }

    return withoutLongPunctuation;
  }

  void _setState(SttPipelineState newState) {
    _state = newState;
    onStateChanged?.call(newState);
  }
}
