import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'hotkey/hotkey_service.dart';
import 'stt/stt_pipeline.dart';
import 'injection/text_injector.dart';
import 'pipeline/dictation_pipeline.dart';
import 'llm/qwen_engine.dart';
import 'storage/history_store.dart';
import 'storage/settings_store.dart';
import 'storage/dictionary_store.dart';

enum DictationState { idle, listening, processing }

class StraightCoordinator extends ChangeNotifier {
  final HotkeyService hotkeyService = HotkeyService();
  final SttPipeline sttPipeline = SttPipeline();
  final TextInjector textInjector = TextInjector();
  final DictationPipeline dictationPipeline = DictationPipeline();
  final QwenEngine _qwenEngine = QwenEngine();

  DictationState _state = DictationState.idle;
  DictationState get state => _state;
  String _statusMessage = 'Starting...';
  String get statusMessage => _statusMessage;
  String _selectedSttModel = SettingsStore.getSttModel();
  String get selectedSttModel => _selectedSttModel;
  String _selectedLlmModel = SettingsStore.getLlmModel();
  String get selectedLlmModel => _selectedLlmModel;
  bool _cleanupModelReady = false;
  String? _copyFallbackText;
  String? get copyFallbackText => _copyFallbackText;
  Completer<String?>? _pronunciationCapture;
  bool get isCapturingPronunciation => _pronunciationCapture != null;
  bool _discardNextTranscription = false;
  bool _hotkeyRegistered = true;
  static const _shortTapThreshold = Duration(milliseconds: 180);
  static const _doubleTapWindow = Duration(milliseconds: 260);
  DateTime? _hotkeyPressedAt;
  Timer? _pendingTapRelease;
  Timer? _hotkeyReleaseWatcher;
  bool _latchedDictation = false;

  void _setState(DictationState s) {
    _state = s;
    notifyListeners();
  }

  void _setStatus(String message) {
    _statusMessage = message;
    notifyListeners();
  }

  String? takeCopyFallbackText() {
    final text = _copyFallbackText;
    _copyFallbackText = null;
    return text;
  }

  Future<void> init() async {
    await SettingsStore.migrateDefaultSttModelToWhisperSmall();
    await SettingsStore.migrateDefaultBehaviorToPushToTalk();
    unawaited(sttPipeline.prepareMicrophone());

    hotkeyService.init(
      onHotkeyTriggered: toggleDictation,
      onKeyDown: _onKeyDown,
      onKeyUp: _onKeyUp,
    );
    _hotkeyRegistered = await hotkeyService.reloadFromSettings();
    if (!_hotkeyRegistered) {
      _setStatus('Hotkey unavailable. Choose another shortcut in Settings.');
    }

    sttPipeline.onStateChanged = (s) {
      switch (s) {
        case SttPipelineState.listening:
          _setState(DictationState.listening);
          break;
        case SttPipelineState.processing:
          _setState(DictationState.processing);
          break;
        case SttPipelineState.idle:
          _setState(DictationState.idle);
          break;
      }
    };

    sttPipeline.onResult = _onTranscription;
    sttPipeline.onError = (e) {
      debugPrint('STT error: $e');
      final message = e.toString();
      _setStatus(
        message.contains('Microphone permission denied')
            ? 'Microphone permission denied'
            : 'Speech engine error',
      );
      _setState(DictationState.idle);
      _finishPronunciationCapture(null);
    };

    _selectedSttModel = SettingsStore.getSttModel();
    _selectedLlmModel = SettingsStore.getLlmModel();
    await refreshDictionary();
  }

  void _onKeyDown() {
    if (!SettingsStore.getPushToTalk()) return;

    if (_latchedDictation) {
      // A latched session is stopped by one more press, not a key release.
      if (_state == DictationState.listening) {
        _latchedDictation = false;
        unawaited(_stopDictation());
      }
      return;
    }

    if (_pendingTapRelease?.isActive == true &&
        _state == DictationState.listening) {
      _pendingTapRelease?.cancel();
      _pendingTapRelease = null;
      _latchedDictation = true;
      _setStatus('Toggle dictation on. Press the hotkey once to stop.');
      return;
    }

    _hotkeyPressedAt = DateTime.now();
    _watchForHotkeyRelease();
    if (_state == DictationState.idle) {
      unawaited(_startDictation());
    }
  }

  void _onKeyUp() {
    _handleHotkeyRelease();
  }

  void _watchForHotkeyRelease() {
    _hotkeyReleaseWatcher?.cancel();
    _hotkeyReleaseWatcher = Timer.periodic(const Duration(milliseconds: 8), (_) {
      if (!hotkeyService.isCurrentHotkeyHeld()) {
        _handleHotkeyRelease();
      }
    });
  }

  void _handleHotkeyRelease() {
    _hotkeyReleaseWatcher?.cancel();
    _hotkeyReleaseWatcher = null;
    if (!SettingsStore.getPushToTalk() || _latchedDictation) return;
    if (_state != DictationState.listening) return;

    final pressedAt = _hotkeyPressedAt;
    _hotkeyPressedAt = null;
    final heldFor = pressedAt == null
        ? Duration.zero
        : DateTime.now().difference(pressedAt);

    if (heldFor > _shortTapThreshold) {
      unawaited(_stopDictation());
      return;
    }

    // A very quick tap waits only long enough to tell whether a second tap is
    // coming. Normal spoken push-to-talk releases without this delay.
    _pendingTapRelease?.cancel();
    _pendingTapRelease = Timer(_doubleTapWindow, () {
      _pendingTapRelease = null;
      if (!_latchedDictation && _state == DictationState.listening) {
        unawaited(_stopDictation());
      }
    });
  }

  Future<void> refreshDictionary() async {
    final dictionary = DictionaryStore.getAll();
    dictationPipeline.setDictionary(dictionary);
    final vocabulary = <String>[];
    for (final entry in dictionary) {
      if (entry['enabled'] != true) continue;
      vocabulary.add((entry['replacement'] ?? '').toString());
      vocabulary.add((entry['word'] ?? '').toString());
      final aliases = entry['aliases'];
      if (aliases is Iterable) {
        vocabulary.addAll(aliases.map((alias) => alias.toString()));
      }
    }
    await sttPipeline.setVocabulary(vocabulary);
  }

  Future<void> bootstrap() async {
    await init();
    await refreshSpeechModel();
    await refreshCleanupModel();
  }

  void toggleDictation() {
    switch (_state) {
      case DictationState.idle:
        _startDictation();
        break;
      case DictationState.listening:
        _stopDictation();
        break;
      case DictationState.processing:
        break;
    }
  }

  /// Captures one short hotkey dictation for a dictionary entry. The result is
  /// deliberately not inserted or added to normal history.
  Future<String?> capturePronunciation() {
    final existing = _pronunciationCapture;
    if (existing != null) return existing.future;
    if (!sttPipeline.isInitialized) {
      _setStatus('Speech model missing');
      return Future<String?>.value(null);
    }

    final capture = Completer<String?>();
    _pronunciationCapture = capture;
    _setStatus('Press the hotkey, say the pronunciation, then release.');
    return capture.future;
  }

  void cancelPronunciationCapture() {
    if (_pronunciationCapture != null &&
        (_state == DictationState.listening || _state == DictationState.processing)) {
      _discardNextTranscription = true;
    }
    _finishPronunciationCapture(null);
  }

  void _finishPronunciationCapture(String? text) {
    final capture = _pronunciationCapture;
    if (capture == null) return;
    _pronunciationCapture = null;
    if (!capture.isCompleted) capture.complete(text);
  }

  Future<void> _startDictation() async {
    if (!sttPipeline.isInitialized) {
      _setStatus('Speech model missing');
      _setState(DictationState.idle);
      return;
    }
    _setStatus('Listening for speech...');
    _setState(DictationState.listening);
    await sttPipeline.start();
  }

  Future<void> _stopDictation() async {
    _hotkeyReleaseWatcher?.cancel();
    _hotkeyReleaseWatcher = null;
    await sttPipeline.stop();
    _setStatus('Ready to dictate');
    _setState(DictationState.idle);
  }

  void _onTranscription(String rawText) async {
    if (_pronunciationCapture != null) {
      _finishPronunciationCapture(rawText);
      _setStatus('Pronunciation captured');
      _setState(DictationState.idle);
      return;
    }

    if (_discardNextTranscription) {
      _discardNextTranscription = false;
      _setStatus('Pronunciation capture cancelled');
      _setState(DictationState.idle);
      return;
    }

    _setState(DictationState.processing);

    final pauseDuration = sttPipeline.lastPauseDurationMs;
    final result = _cleanupModelReady
        ? await dictationPipeline.processWithLlm(
            rawText,
            pauseDurationMs: pauseDuration,
          )
        : dictationPipeline.process(rawText, pauseDurationMs: pauseDuration);

    final inserted = textInjector.inject(result.text);
    if (!inserted && result.text.trim().isNotEmpty) {
      _copyFallbackText = result.text;
    }

    await HistoryStore.addEntry({
      'text': rawText,
      'appliedText': result.text,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'app': '',
    });

    _setStatus(inserted ? 'Text inserted' : 'Copy transcription');
    _setState(DictationState.idle);
  }

  String _devWhisperPath(String modelId) {
    switch (modelId) {
      case 'whisper-small':
        return 'models${Platform.pathSeparator}whisper${Platform.pathSeparator}ggml-small.bin';
      case 'whisper-medium':
        return 'models${Platform.pathSeparator}whisper${Platform.pathSeparator}ggml-medium.bin';
      case 'whisper-base':
      default:
        return 'models${Platform.pathSeparator}whisper${Platform.pathSeparator}ggml-base.bin';
    }
  }

  String _devQwenPath() =>
      'models${Platform.pathSeparator}qwen${Platform.pathSeparator}Qwen3-ASR-0.6B';

  String _devMoonshinePath() =>
      'models${Platform.pathSeparator}moonshine${Platform.pathSeparator}small-streaming-en';

  Future<String?> _findDevPath(
    String relativePath, {
    required bool directory,
  }) async {
    final roots = <Directory>[
      Directory.current,
      File(Platform.resolvedExecutable).parent,
    ];

    for (final root in roots) {
      var dir = root;
      for (var i = 0; i < 8; i++) {
        final path = '${dir.path}${Platform.pathSeparator}$relativePath';
        final exists = directory
            ? await Directory(path).exists()
            : await File(path).exists();
        if (exists) return path;

        final parent = dir.parent;
        if (parent.path == dir.path) break;
        dir = parent;
      }
    }

    return null;
  }

  Future<String> _resolveSpeechModelPath(String modelId) async {
    // Try dev-tree path first
    if (modelId == 'qwen3-asr-0.6b') {
      final devQwen = await _findDevPath(_devQwenPath(), directory: true);
      if (devQwen != null) return devQwen;
    } else if (modelId == 'moonshine-small-streaming-en') {
      final devMoonshine = await _findDevPath(
        _devMoonshinePath(),
        directory: true,
      );
      if (devMoonshine != null) return devMoonshine;
    } else {
      final devWhisper = await _findDevPath(
        _devWhisperPath(modelId),
        directory: false,
      );
      if (devWhisper != null) return devWhisper;
    }

    // Fall back to app data directory
    final appDir = await getApplicationSupportDirectory();
    final modelsDir = Directory(
      '${appDir.path}${Platform.pathSeparator}models',
    );
    final whisperDir = Directory(
      '${modelsDir.path}${Platform.pathSeparator}whisper',
    );
    final qwenDir = Directory('${modelsDir.path}${Platform.pathSeparator}qwen');
    final moonshineDir = Directory(
      '${modelsDir.path}${Platform.pathSeparator}moonshine${Platform.pathSeparator}small-streaming-en',
    );

    switch (modelId) {
      case 'whisper-small':
        return '${whisperDir.path}${Platform.pathSeparator}ggml-small.bin';
      case 'whisper-medium':
        return '${whisperDir.path}${Platform.pathSeparator}ggml-medium.bin';
      case 'qwen3-asr-0.6b':
        return '${qwenDir.path}${Platform.pathSeparator}Qwen3-ASR-0.6B';
      case 'moonshine-small-streaming-en':
        return moonshineDir.path;
      case 'whisper-base':
      default:
        return '${whisperDir.path}${Platform.pathSeparator}ggml-base.bin';
    }
  }

  Future<void> refreshSpeechModel() async {
    _selectedSttModel = SettingsStore.getSttModel();
    _selectedLlmModel = SettingsStore.getLlmModel();
    _setStatus('Loading speech model...');

    final modelPath = await _resolveSpeechModelPath(_selectedSttModel);
    final modelExists = _selectedSttModel == 'qwen3-asr-0.6b' ||
            _selectedSttModel == 'moonshine-small-streaming-en'
        ? await Directory(modelPath).exists()
        : await File(modelPath).exists();
    if (!modelExists) {
      _setStatus('Speech model missing: $_selectedSttModel');
      return;
    }

    try {
      // A reload can be requested while dictation is active. Stop and replace
      // the engine without disposing the recorder used by later dictation.
      await sttPipeline.unloadModel();
      await sttPipeline.init(modelPath);
      unawaited(sttPipeline.prepareMicrophone());
      await refreshDictionary();
      _setStatus(
        _hotkeyRegistered
            ? 'Ready to dictate'
            : 'Hotkey unavailable. Choose another shortcut in Settings.',
      );
    } catch (e) {
      _setStatus('Could not load speech model');
      debugPrint('Model load error: $e');
    }
  }

  Future<String?> _resolveCleanupModelPath(String modelId) async {
    if (modelId == 'none') return null;

    final gaufFile = 'qwen2.5-0.5b-instruct-q4_k_m.gguf';
    // Try dev-tree path first
    final devGauf = await _findDevPath(
      'models${Platform.pathSeparator}qwen${Platform.pathSeparator}$gaufFile',
      directory: false,
    );
    if (devGauf != null) {
      return devGauf;
    }

    // Fall back to app data directory
    final appDir = await getApplicationSupportDirectory();
    final modelsDir = Directory(
      '${appDir.path}${Platform.pathSeparator}models',
    );
    final qwenDir = Directory('${modelsDir.path}${Platform.pathSeparator}qwen');

    switch (modelId) {
      case 'qwen2.5-0.5b':
        return '${qwenDir.path}${Platform.pathSeparator}$gaufFile';
      case 'qwen2.5-1.5b':
        return '${qwenDir.path}${Platform.pathSeparator}qwen2.5-1.5b-instruct-q4_k_m.gguf';
      default:
        return null;
    }
  }

  Future<void> refreshCleanupModel() async {
    _selectedLlmModel = SettingsStore.getLlmModel();
    final modelPath = await _resolveCleanupModelPath(_selectedLlmModel);

    if (modelPath == null) {
      _cleanupModelReady = false;
      dictationPipeline.setLlmEngine(null);
      unawaited(_qwenEngine.dispose());
      return;
    }

    final file = File(modelPath);
    if (!await file.exists()) {
      _cleanupModelReady = false;
      dictationPipeline.setLlmEngine(null);
      unawaited(_qwenEngine.dispose());
      return;
    }

    try {
      if (_cleanupModelReady) {
        await _qwenEngine.dispose();
      }
      await _qwenEngine.init(modelPath);
      dictationPipeline.setLlmEngine(_qwenEngine);
      _cleanupModelReady = true;
    } catch (e) {
      _cleanupModelReady = false;
      dictationPipeline.setLlmEngine(null);
      unawaited(_qwenEngine.dispose());
      debugPrint('Cleanup model load error: $e');
    }
  }

  @override
  void dispose() {
    _pendingTapRelease?.cancel();
    _hotkeyReleaseWatcher?.cancel();
    _finishPronunciationCapture(null);
    hotkeyService.dispose();
    unawaited(sttPipeline.dispose());
    unawaited(_qwenEngine.dispose());
    super.dispose();
  }
}
