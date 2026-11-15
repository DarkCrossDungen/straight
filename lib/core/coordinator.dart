import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'app_navigation.dart';
import 'hotkey/hotkey_service.dart';
import 'stt/stt_pipeline.dart';
import 'injection/text_injector.dart';
import 'injection/typing_access.dart';
import 'pipeline/dictation_pipeline.dart';
import 'pipeline/python_text_organizer.dart';
import 'llm/qwen_engine.dart';
import 'storage/history_store.dart';
import 'storage/settings_store.dart';
import 'storage/dictionary_store.dart';
import 'storage/work_profile_store.dart';
import '../shared/widgets/typing_prompt_dialog.dart';
import 'windows/active_app_service.dart';
import 'windows/media_control_service.dart';

enum DictationState { idle, listening, processing }

class StraightCoordinator extends ChangeNotifier {
  final HotkeyService hotkeyService = HotkeyService();
  final SttPipeline sttPipeline = SttPipeline();
  final TextInjector textInjector = TextInjector();
  final DictationPipeline dictationPipeline = DictationPipeline();
  final PythonTextOrganizer _pythonTextOrganizer = PythonTextOrganizer();
  final QwenEngine _qwenEngine = QwenEngine();
  final ActiveAppService _activeAppService = ActiveAppService();
  final MediaControlService _mediaControlService = MediaControlService();

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
  String? _notice;
  Completer<String?>? _pronunciationCapture;
  bool get isCapturingPronunciation => _pronunciationCapture != null;
  bool _discardNextTranscription = false;
  bool _hotkeyRegistered = true;
  DateTime? _hotkeyPressedAt;
  Timer? _hotkeyReleaseWatcher;
  bool _toggleQueuedDuringProcessing = false;
  bool _mediaWasPaused = false;
  bool _startInFlight = false;
  bool _stopInFlight = false;
  bool _modelLoadStarted = false;
  String? _lastActiveApp;
  String? get lastActiveApp => _lastActiveApp;
  double _speechLevel = 0;
  double get speechLevel => _speechLevel;

  void _setState(DictationState s) {
    _state = s;
    if (s != DictationState.listening) _speechLevel = 0;
    notifyListeners();
  }

  void _setStatus(String message, {bool alert = false}) {
    _statusMessage = message;
    if (alert) _notice = message;
    notifyListeners();
  }

  /// One-shot problem report for the bubble. Routine status stays out of it so
  /// the chip does not nag after every successful dictation.
  String? takeNotice() {
    final message = _notice;
    _notice = null;
    return message;
  }

  String? takeCopyFallbackText() {
    final text = _copyFallbackText;
    _copyFallbackText = null;
    return text;
  }

  Future<void> init() async {
    await SettingsStore.migrateDefaultBehaviorToPushToTalk();
    await SettingsStore.migrateSttModelForPlatform();
    unawaited(sttPipeline.prepareMicrophone());

    hotkeyService.init(
      onHotkeyTriggered: toggleDictation,
      onKeyDown: _onKeyDown,
      onKeyUp: _onKeyUp,
    );
    // On Linux the desktop owns the key and notifies us over the control port,
    // so grabbing a shortcut inside the app would only ever fail.
    _hotkeyRegistered =
        Platform.isLinux || await hotkeyService.reloadFromSettings();
    if (!_hotkeyRegistered) {
      _setStatus(
        'Hotkey unavailable. Choose another shortcut in Settings.',
        alert: true,
      );
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
          if (_state != DictationState.processing) {
            _setState(DictationState.idle);
            unawaited(_resumeMediaIfNeeded());
          }
          break;
      }
    };

    sttPipeline.onResult = (text) async => _onTranscription(text);
    sttPipeline.onNoSpeech = () {
      _setStatus(
        sttPipeline.microphoneWarning ??
            'No speech detected. Check the microphone and try again.',
        alert: true,
      );
    };
    sttPipeline.onAudioLevel = (level) {
      if (_state != DictationState.listening) return;
      _speechLevel = level;
      notifyListeners();
    };
    sttPipeline.onError = (e) {
      debugPrint('STT error: $e');
      final message = e.toString();
      _setStatus(
        message.contains('Microphone permission denied')
            ? 'Microphone permission denied'
            : 'Speech engine error',
        alert: true,
      );
      _setState(DictationState.idle);
      unawaited(_resumeMediaIfNeeded());
      _finishPronunciationCapture(null);
    };

    _selectedSttModel = SettingsStore.getSttModel();
    _selectedLlmModel = SettingsStore.getLlmModel();
    await refreshDictionary();
  }

  void _onKeyDown() {
    if (!Platform.isWindows || !SettingsStore.getPushToTalk()) return;
    if (_hotkeyPressedAt != null) return;
    _hotkeyPressedAt = DateTime.now();
    _hotkeyReleaseWatcher = Timer.periodic(const Duration(milliseconds: 8), (
      _,
    ) {
      if (!hotkeyService.isCurrentHotkeyHeld()) _handleHotkeyRelease();
    });
    if (_state == DictationState.idle) {
      unawaited(_startDictation());
    } else if (_state == DictationState.processing) {
      _toggleQueuedDuringProcessing = true;
    }
  }

  void _onKeyUp() {
    if (Platform.isWindows) _handleHotkeyRelease();
  }

  void _handleHotkeyRelease() {
    _hotkeyReleaseWatcher?.cancel();
    _hotkeyReleaseWatcher = null;
    if (!SettingsStore.getPushToTalk()) return;
    _hotkeyPressedAt = null;
    if (_state == DictationState.listening &&
        (_startInFlight || sttPipeline.state == SttPipelineState.listening)) {
      unawaited(_stopDictation());
    } else if (_state == DictationState.processing) {
      _toggleQueuedDuringProcessing = false;
    }
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
        unawaited(_startDictation());
        break;
      case DictationState.listening:
        unawaited(_stopDictation());
        break;
      case DictationState.processing:
        _toggleQueuedDuringProcessing = !_toggleQueuedDuringProcessing;
        break;
    }
  }

  Future<bool> reloadHotkey() => hotkeyService.reloadFromSettings();

  /// Captures one short hotkey dictation for a dictionary entry. The result is
  /// deliberately not inserted or added to normal history.
  Future<String?> capturePronunciation() {
    final existing = _pronunciationCapture;
    if (existing != null) return existing.future;
    if (!sttPipeline.isInitialized) {
      _setStatus('Speech model missing', alert: true);
      return Future<String?>.value(null);
    }

    final capture = Completer<String?>();
    _pronunciationCapture = capture;
    _setStatus('Press the hotkey, say the pronunciation, then release.');
    return capture.future;
  }

  void cancelPronunciationCapture() {
    if (_pronunciationCapture != null &&
        (_state == DictationState.listening ||
            _state == DictationState.processing)) {
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
      // The speech model is still loading (bootstrap runs after the first
      // frame). Don't dead-end the press: kick off the load and tell the user
      // to try again in a moment instead of showing a permanent error.
      if (!_modelLoadStarted) {
        _modelLoadStarted = true;
        unawaited(refreshSpeechModel());
      }
      _setStatus('Loading speech model — press again in a moment');
      _setState(DictationState.idle);
      return;
    }
    // A second press arriving mid-start must not open two recorders on the same
    // device; the state guard above is the only thing standing between them.
    if (_startInFlight) return;
    _startInFlight = true;
    // The bubble must answer the press immediately so the hotkey feels live.
    _setStatus('Listening for speech...');
    _setState(DictationState.listening);
    try {
      // The microphone opens before anything that could block on D-Bus, so
      // speech is captured from the first frame the bubble is visible.
      final recorderStart = sttPipeline.start();
      unawaited(
        recorderStart.catchError((Object error) {
          debugPrint('Recorder start failed: $error');
          _setStatus('Microphone did not start — try again', alert: true);
          _setState(DictationState.idle);
          unawaited(_resumeMediaIfNeeded());
        }),
      );
      unawaited(_ensureTypingAccess());
      textInjector.captureFocus();
      _mediaWasPaused = await _mediaControlService.pauseIfPlaying();
      if (_state == DictationState.listening) {
        await recorderStart;
      } else {
        await _resumeMediaIfNeeded();
      }
    } finally {
      _startInFlight = false;
    }
  }

  /// The accessibility switch that lets Straight type can be turned off after
  /// setup (or by a system update). Check it before each dictation and offer
  /// to put it back rather than silently falling back to the clipboard.
  Future<void> _ensureTypingAccess() async {
    if (!Platform.isLinux) return;
    final enabled = await TypingAccess.isEnabled();
    if (enabled != false) return;
    final context = appNavigatorKey.currentContext;
    if (context == null) return;
    final restored = await requestTypingAccess(context);
    if (restored) {
      _setStatus('Typing is on again');
    } else {
      _setStatus('Typing is off — words will be copied to the clipboard');
    }
  }

  Future<void> _stopDictation() async {
    if (_stopInFlight) return;
    _stopInFlight = true;
    try {
      await sttPipeline.stop();
      _setState(DictationState.idle);
    } catch (error) {
      // A recorder that dies mid-session still ends the session: leaving the
      // bubble listening is the failure the user sees as a stuck pill.
      debugPrint('Stop failed: $error');
      _setStatus('Dictation stopped', alert: true);
      _setState(DictationState.idle);
    } finally {
      _stopInFlight = false;
      await _resumeMediaIfNeeded();
      if (_toggleQueuedDuringProcessing) {
        _toggleQueuedDuringProcessing = false;
        unawaited(_startDictation());
      }
    }
  }

  Future<void> _resumeMediaIfNeeded() async {
    if (!_mediaWasPaused) return;
    _mediaWasPaused = false;
    await _mediaControlService.resumeIfPausedByStraight();
  }

  Future<void> _onTranscription(String rawText) async {
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
    try {
      // The app executable is only used to select a locally stored vocabulary
      // profile. Straight never reads window contents or monitors typing.
      final activeApp = _activeAppService.foregroundExecutable();
      if (activeApp != null && activeApp.toLowerCase() != 'straight.exe') {
        _lastActiveApp = activeApp;
      }
      final profile = SettingsStore.getAutomaticProfileSwitching()
          ? WorkProfileStore.findForExecutable(_lastActiveApp)
          : null;
      dictationPipeline.setDictionary(
        DictionaryStore.getForProfile(profile?['id']?.toString()),
      );

      final pauseDuration = sttPipeline.lastPauseDurationMs;
      final cleaned = _cleanupModelReady
          ? await dictationPipeline.processWithLlm(
              rawText,
              pauseDurationMs: pauseDuration,
            )
          : dictationPipeline.process(rawText, pauseDurationMs: pauseDuration);
      final organizedText = await _pythonTextOrganizer.organize(cleaned.text);

      final inserted = await textInjector.inject(organizedText);
      if (!inserted && organizedText.trim().isNotEmpty) {
        _copyFallbackText = organizedText;
      }

      await HistoryStore.addEntry({
        'text': rawText,
        'appliedText': organizedText,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'app': _lastActiveApp ?? '',
        'profileId': profile?['id'] ?? '',
      });

      _setStatus(
        inserted ? 'Text inserted' : 'Could not type — copied to clipboard',
      );
    } catch (error) {
      debugPrint('Dictation processing failed: $error');
      _setStatus('Dictation failed — try again', alert: true);
    } finally {
      _setState(DictationState.idle);
    }
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
    final modelExists =
        _selectedSttModel == 'qwen3-asr-0.6b' ||
            _selectedSttModel == 'moonshine-small-streaming-en'
        ? await Directory(modelPath).exists()
        : await File(modelPath).exists();
    if (!modelExists) {
      _setStatus('Speech model missing: $_selectedSttModel', alert: true);
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
        alert: !_hotkeyRegistered,
      );
    } catch (e) {
      _setStatus('Could not load speech model', alert: true);
      debugPrint('Model load error: $e');
    } finally {
      _modelLoadStarted = false;
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
    _hotkeyReleaseWatcher?.cancel();
    unawaited(_resumeMediaIfNeeded());
    _finishPronunciationCapture(null);
    hotkeyService.dispose();
    unawaited(sttPipeline.dispose());
    unawaited(_qwenEngine.dispose());
    super.dispose();
  }
}
