import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import '../audio/vad.dart';
import 'stt_engine_worker.dart';

enum SttPipelineState { idle, listening, processing }

class SttPipeline {
  final AudioRecorder _recorder = AudioRecorder();
  final VoiceActivityDetector _vad = VoiceActivityDetector();
  SttEngineWorker? _engine;
  Future<void>? _starting;
  Future<void>? _stopping;

  StreamSubscription<Uint8List>? _subscription;
  Future<void>? _primingMicrophone;
  bool _microphonePrimed = false;
  List<int> _buffer = [];
  bool _initialized = false;
  bool _isProcessing = false;
  bool _stopRequested = false;
  int _lastSpeechTimestamp = 0;
  bool _heardSpeechInBuffer = false;
  bool _captureRequested = false;
  double _peakClipping = 0;

  SttPipelineState _state = SttPipelineState.idle;
  SttPipelineState get state => _state;
  bool get isInitialized => _initialized;
  int get lastPauseDurationMs => _lastSpeechTimestamp == 0
      ? 0
      : DateTime.now().millisecondsSinceEpoch - _lastSpeechTimestamp;

  /// Explains a silent session when the microphone, not the user, is at fault.
  /// Both conditions destroy speech before any engine can read it, and both
  /// are fixed by lowering the system input volume.
  String? get microphoneWarning {
    if (_vad.hearsOnlyStatic) {
      return 'Microphone hears only static, not voices. Check it is plugged in and not muted.';
    }
    if (_peakClipping > 0.02) {
      return 'Microphone is clipping. Lower the input volume in Sound settings.';
    }
    if (_vad.noiseFloor > 0.05) {
      return 'Microphone hears constant loud noise. Lower the input volume in Sound settings.';
    }
    return null;
  }

  void Function(SttPipelineState state)? onStateChanged;
  void Function(double level)? onAudioLevel;
  Future<void> Function(String text)? onResult;
  void Function()? onNoSpeech;
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
    if (_starting != null) await _starting;
    if (_captureRequested) return;
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) throw StateError('Microphone permission denied');

    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        numChannels: 1,
        sampleRate: 16000,
      ),
    );
    if (_captureRequested) {
      final capture = stream.listen(_onAudioChunk);
      _subscription = capture;
      return;
    }
    final subscription = stream.listen((_) {});
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await subscription.cancel();
    await _recorder.stop();
    _microphonePrimed = true;
  }

  Future<void> init(String modelPath) async {
    if (_initialized) await unloadModel();
    _engine = await SttEngineWorker.start(modelPath);
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
    final stopping = _stopping;
    if (stopping != null) await stopping;
    if (!_initialized || _isProcessing || _starting != null) return;

    _captureRequested = true;
    _stopRequested = false;
    _setState(SttPipelineState.listening);
    _buffer = [];
    _vad.reset();
    _isProcessing = false;
    _heardSpeechInBuffer = false;
    _lastSpeechTimestamp = 0;
    _peakClipping = 0;

    final priming = _primingMicrophone;
    if (priming != null) await priming;
    if (!_captureRequested || _subscription != null) return;

    final starting = _openRecorder();
    _starting = starting;
    try {
      await starting;
    } finally {
      if (identical(_starting, starting)) _starting = null;
    }
  }

  Future<void> _openRecorder() async {
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) throw StateError('Microphone permission denied');
      if (!_captureRequested || _stopRequested) return;
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          numChannels: 1,
          sampleRate: 16000,
        ),
      );
      if (!_captureRequested || _stopRequested) {
        await _recorder.stop();
        return;
      }
      _subscription = stream.listen(
        _onAudioChunk,
        onError: (Object error) {
          _subscription = null;
          _captureRequested = false;
          _stopRequested = true;
          _setState(SttPipelineState.idle);
          onError?.call(error);
        },
      );
    } catch (error) {
      _captureRequested = false;
      _stopRequested = true;
      _setState(SttPipelineState.idle);
      onError?.call(error);
    }
  }

  void _onAudioChunk(Uint8List chunk) {
    _vad.processChunk(chunk);
    if (_vad.clippedRatio > _peakClipping) _peakClipping = _vad.clippedRatio;
    onAudioLevel?.call(_vad.speechLevel);

    final samples = _convertToInt16(chunk);
    _buffer.addAll(samples);

    if (_vad.isSpeaking) {
      _lastSpeechTimestamp = DateTime.now().millisecondsSinceEpoch;
      _heardSpeechInBuffer = true;
    }

    // Keep the rolling pre-speech buffer bounded while waiting for the first word.
    if (!_heardSpeechInBuffer) {
      if (_buffer.length > 16000) _buffer.clear();
      return;
    }
  }

  Future<void> _flushBuffer() async {
    if (_buffer.isEmpty ||
        !_heardSpeechInBuffer ||
        _isProcessing ||
        _engine == null) {
      return;
    }
    final samples = List<int>.from(_buffer);
    _buffer.clear();
    _vad.reset();
    _heardSpeechInBuffer = false;
    _isProcessing = true;
    _setState(SttPipelineState.processing);

    try {
      final text = cleanTranscriptionForDictation(
        await _engine!.transcribe(samples),
      );
      if (text != null) {
        await onResult?.call(text);
      }
    } catch (e) {
      onError?.call(e);
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> stop() {
    final existing = _stopping;
    if (existing != null) return existing;
    _captureRequested = false;
    _stopRequested = true;
    final stopping = _stopCapture();
    _stopping = stopping;
    return stopping.whenComplete(() {
      if (identical(_stopping, stopping)) _stopping = null;
    });
  }

  Future<void> _stopCapture() async {
    try {
      final starting = _starting;
      if (starting != null) await starting;
      final priming = _primingMicrophone;
      if (priming != null) await priming;

      await _subscription?.cancel();
      _subscription = null;
      await _recorder.stop();

      final heardSpeech = _heardSpeechInBuffer;
      if (_buffer.isNotEmpty && heardSpeech && !_isProcessing) {
        await _flushBuffer();
      } else if (!heardSpeech) {
        onNoSpeech?.call();
      }
    } finally {
      _buffer = [];
      _heardSpeechInBuffer = false;
      _isProcessing = false;
      _captureRequested = false;
      _stopRequested = false;
      _setState(SttPipelineState.idle);
    }
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

    // Whisper can emit caption-like labels for silence. The old check handled
    // one label but missed the repeated form, for example
    // "[BLANK_AUDIO].[BLANK_AUDIO]", which then leaked into the app.
    if (RegExp(r'^(?:\s*\[[^\]]+\]\s*[.,!?;:…-]?\s*)+$').hasMatch(trimmed)) {
      return null;
    }

    if (RegExp(r'^[\s.,!?;:…-]+$').hasMatch(trimmed)) {
      return null;
    }

    // Small Whisper models can repeat punctuation while guessing at silence,
    // room noise, or music. The marks can be separated by spaces, which is why
    // a simple "..." matcher was not enough.
    final hasRepeatedPunctuation = RegExp(
      r'[.!?…](?:\s*[.!?…]){1,}',
    ).hasMatch(trimmed);
    final withoutLongPunctuation = trimmed
        .replaceAll(RegExp(r'[.!?…](?:\s*[.!?…]){1,}'), ' ')
        .replaceAll(RegExp(r'(?<=\s)[.!?…](?=\s|$)'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (withoutLongPunctuation.isEmpty ||
        RegExp(r'^[\s.,!?;:…-]+$').hasMatch(withoutLongPunctuation)) {
      return null;
    }

    final punctuationCount = RegExp(
      r'[.,!?;:…-]',
    ).allMatches(withoutLongPunctuation).length;
    final letterCount = RegExp(
      r'[A-Za-z0-9]',
    ).allMatches(withoutLongPunctuation).length;
    final wordCount = RegExp(
      r"\b[A-Za-z0-9']+\b",
    ).allMatches(withoutLongPunctuation).length;

    // Whisper often hallucinates a single vague word followed by many dots
    // when the input is silence, room noise, or a clipped utterance.
    if ((punctuationCount * 3 > letterCount || hasRepeatedPunctuation) &&
        wordCount < 2) {
      return null;
    }

    // Non-speech labels and music captions are not useful dictation.
    if (RegExp(
      r'^\(?\s*(?:music|applause|laughter|silence|noise)\s*\)?$',
      caseSensitive: false,
    ).hasMatch(withoutLongPunctuation)) {
      return null;
    }

    return withoutLongPunctuation;
  }

  void _setState(SttPipelineState newState) {
    _state = newState;
    onStateChanged?.call(newState);
  }
}
