import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'hotkey/hotkey_service.dart';
import 'hotkey/input_access.dart';
import 'hotkey/keyboard_watcher.dart';
import 'stt/stt_pipeline.dart';
import 'injection/text_injector.dart';
import 'pipeline/dictation_pipeline.dart';
import 'llm/qwen_engine.dart';
import 'storage/history_store.dart';
import 'storage/settings_store.dart';
import 'storage/dictionary_store.dart';
import 'storage/work_profile_store.dart';
import 'windows/active_app_service.dart';
import 'windows/media_control_service.dart';

enum DictationState { idle, listening, processing }

class StraightCoordinator extends ChangeNotifier {
  static const _doubleTapWindow = Duration(milliseconds: 400);

  /// How long a release waits before stopping, so a second tap can turn a hold
  /// into locked dictation instead.
  static const _tapGrace = Duration(milliseconds: 260);
  final HotkeyService hotkeyService = HotkeyService();
  final SttPipeline sttPipeline = SttPipeline();
  final TextInjector textInjector = TextInjector();
  final DictationPipeline dictationPipeline = DictationPipeline();
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
  DateTime? _lastPressAt;
  KeyboardWatcher? _watcher;
  Timer? _tapGraceTimer;
  DateTime? _rawKeyEventAt;
  Timer? _hotkeyReleaseWatcher;
  bool _mediaWasPaused = false;
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
    unawaited(_startWatcher());

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
    sttPipeline.onNoSpeech = () {
      _setStatus(
        sttPipeline.microphoneWarning ??
            'Heard no speech. Press the shortcut and start talking.',
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
    if (!SettingsStore.getPushToTalk()) return;
    // Ignore repeat key-down events. A push-to-talk session starts once and
    // ends only when one of its keys is released.
    if (_state != DictationState.idle || _hotkeyPressedAt != null) return;
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
    _hotkeyReleaseWatcher = Timer.periodic(const Duration(milliseconds: 8), (
      _,
    ) {
      if (!hotkeyService.isCurrentHotkeyHeld()) {
        _handleHotkeyRelease();
      }
    });
  }

  void _handleHotkeyRelease() {
    _hotkeyReleaseWatcher?.cancel();
    _hotkeyReleaseWatcher = null;
    if (!SettingsStore.getPushToTalk()) return;
    _hotkeyPressedAt = null;
    if (_state != DictationState.listening) return;
    unawaited(_stopDictation());
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
    // When raw keys are readable, the same physical press also arrives here
    // through the desktop shortcut, which cannot report a release. The watcher
    // owns that press instead.
    final rawEvent = _rawKeyEventAt;
    if (_watcher != null &&
        rawEvent != null &&
        DateTime.now().difference(rawEvent) < _doubleTapWindow) {
      return;
    }

    final now = DateTime.now();
    final sinceLastPress = _lastPressAt == null
        ? null
        : now.difference(_lastPressAt!);
    _lastPressAt = now;

    switch (_state) {
      case DictationState.idle:
        _startDictation();
        break;
      case DictationState.listening:
        // A desktop shortcut only reports presses, never a release, so a quick
        // second press is the only way to say "keep recording until I stop
        // you". One press ends the session instead.
        if (sinceLastPress != null &&
            sinceLastPress < _doubleTapWindow &&
            !sttPipeline.keepsListeningPastSilence) {
          sttPipeline.keepsListeningPastSilence = true;
          _setStatus('Locked. Press the shortcut again to stop.');
          return;
        }
        _stopDictation();
        break;
      case DictationState.processing:
        break;
    }
  }

  /// Starts the raw-key reader when the machine allows it. Without read access
  /// to /dev/input this returns quietly and presses-only behavior stays.
  Future<void> _startWatcher() async {
    if (!InputAccess.isSupported || _watcher != null) return;
    final watcher = await KeyboardWatcher.start(
      HotkeySpec.fromSettings(SettingsStore.getHotkey()),
    );
    if (watcher == null) return;
    _watcher = watcher;
    watcher.events.listen(_onRawKeyEvent);
    notifyListeners();
  }

  /// Whether raw key events are readable, so a hold can be told from a tap.
  bool get holdToRecordReady => _watcher != null;

  /// Retries the raw-key reader after the user grants keyboard access.
  Future<bool> enableHoldToRecord() async {
    await _startWatcher();
    return _watcher != null;
  }

  /// Hold to record, release to stop, double tap to lock dictation until the
  /// next tap. Only possible with raw key events, because Wayland hands a
  /// shortcut over as a press with no matching release.
  void _onRawKeyEvent(KeyboardEvent event) {
    _rawKeyEventAt = DateTime.now();

    if (event.isDown) {
      final waitingForSecondTap = _tapGraceTimer != null;
      _tapGraceTimer?.cancel();
      _tapGraceTimer = null;

      if (waitingForSecondTap && _state == DictationState.listening) {
        sttPipeline.keepsListeningPastSilence = true;
        _setStatus('Locked. Press again to stop.');
        return;
      }
      switch (_state) {
        case DictationState.idle:
          _lastPressAt = DateTime.now();
          unawaited(_startDictation());
        case DictationState.listening:
          unawaited(_stopDictation());
        case DictationState.processing:
          break;
      }
      return;
    }

    if (_state != DictationState.listening ||
        sttPipeline.keepsListeningPastSilence) {
      return;
    }
    // Releasing stops recording, but only after a tap has had a chance to be
    // the second half of a double tap.
    _tapGraceTimer = Timer(_tapGrace, () {
      _tapGraceTimer = null;
      if (_state == DictationState.listening) unawaited(_stopDictation());
    });
  }

  /// Points every shortcut layer at the stored hotkey.
  Future<bool> reloadHotkey() async {
    final registered = await hotkeyService.reloadFromSettings();
    _watcher?.updateSpec(HotkeySpec.fromSettings(SettingsStore.getHotkey()));
    return registered;
  }

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
      _setStatus('Speech model missing', alert: true);
      _setState(DictationState.idle);
      return;
    }
    // AT-SPI must learn the typing target before the bubble takes focus.
    textInjector.captureFocus();
    _mediaWasPaused = await _mediaControlService.pauseIfPlaying();
    _setStatus('Listening for speech...');
    _setState(DictationState.listening);
    await sttPipeline.start();
  }

  Future<void> _stopDictation() async {
    _hotkeyReleaseWatcher?.cancel();
    _hotkeyReleaseWatcher = null;
    _tapGraceTimer?.cancel();
    _tapGraceTimer = null;
    try {
      await sttPipeline.stop();
      _setStatus('Ready to dictate');
      _setState(DictationState.idle);
    } finally {
      await _resumeMediaIfNeeded();
    }
  }

  Future<void> _resumeMediaIfNeeded() async {
    if (!_mediaWasPaused) return;
    _mediaWasPaused = false;
    await _mediaControlService.resumeIfPausedByStraight();
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
      'app': _lastActiveApp ?? '',
      'profileId': profile?['id'] ?? '',
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
    _tapGraceTimer?.cancel();
    _watcher?.dispose();
    unawaited(_resumeMediaIfNeeded());
    _finishPronunciationCapture(null);
    hotkeyService.dispose();
    unawaited(sttPipeline.dispose());
    unawaited(_qwenEngine.dispose());
    super.dispose();
  }
}
