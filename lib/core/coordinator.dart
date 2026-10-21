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
import 'storage/snippets_store.dart';
import 'platform/window_context.dart';
import 'learning/correction_detector.dart';

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

  void Function(double amplitude)? onAmplitudeChanged;

  void _setState(DictationState s) {
    _state = s;
    notifyListeners();
  }

  void _setStatus(String message) {
    _statusMessage = message;
    notifyListeners();
  }

  Future<void> init() async {
    hotkeyService.init(
      onHotkeyTriggered: toggleDictation,
      onKeyDown: _onKeyDown,
      onKeyUp: _onKeyUp,
    );
    await hotkeyService.reloadFromSettings();

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

    sttPipeline.onAmplitudeChanged = (amp) {
      onAmplitudeChanged?.call(amp);
    };

    sttPipeline.isWhisperMode = SettingsStore.getWhisperMode();

    sttPipeline.onResult = _onTranscription;
    sttPipeline.onError = (e) {
      debugPrint('STT error: $e');
      _setStatus('Speech engine error');
      _setState(DictationState.idle);
    };

    _selectedSttModel = SettingsStore.getSttModel();
    _selectedLlmModel = SettingsStore.getLlmModel();
    refreshDictionary();
    refreshSnippets();
  }

  void refreshWhisperMode() {
    sttPipeline.isWhisperMode = SettingsStore.getWhisperMode();
  }

  void _onKeyDown() {
    if (SettingsStore.getPushToTalk() && _state == DictationState.idle) {
      _startDictation();
    }
  }

  void _onKeyUp() {
    if (SettingsStore.getPushToTalk() && _state == DictationState.listening) {
      _stopDictation();
    }
  }

  void refreshDictionary() {
    final dictionary = DictionaryStore.getAll();
    dictationPipeline.setDictionary(dictionary);
  }

  void refreshSnippets() {
    final snippets = SnippetsStore.getAll();
    dictationPipeline.setSnippets(snippets);
  }

  Future<void> bootstrap() async {
    try {
      await init();
    } catch (e) {
      debugPrint('Coordinator init warning: $e');
    }
    try {
      await refreshSpeechModel();
    } catch (e) {
      debugPrint('Coordinator speech model warning: $e');
    }
    try {
      await refreshCleanupModel();
    } catch (e) {
      debugPrint('Coordinator cleanup model warning: $e');
    }
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

  ActiveWindowInfo? _activeWindow;
  ActiveWindowInfo? get activeWindow => _activeWindow;

  final CorrectionDetector _correctionDetector = CorrectionDetector();
  String? _lastDictatedText;
  int _lastDictatedTimestamp = 0;

  String buildBiasingPrompt() {
    final words = <String>[];
    for (final entry in DictionaryStore.getAll()) {
      if (entry['enabled'] == true && entry['replacement'] != null) {
        final rep = entry['replacement'] as String;
        if (rep.isNotEmpty) words.add(rep);
      }
    }
    for (final snippet in SnippetsStore.getAll()) {
      if (snippet['name'] != null) {
        final name = snippet['name'] as String;
        if (name.isNotEmpty) words.add(name);
      }
    }
    return words.join(', ');
  }

  Future<void> _startDictation() async {
    if (!sttPipeline.isInitialized) {
      _setStatus('Speech model missing');
      _setState(DictationState.idle);
      return;
    }
    _activeWindow = WindowContext.getActiveWindow();
    sttPipeline.initialPrompt = buildBiasingPrompt();
    _setStatus('Listening for speech...');
    _setState(DictationState.listening);
    await sttPipeline.start();
  }

  Future<void> _stopDictation() async {
    await sttPipeline.stop();
    _setStatus('Ready to dictate');
    _setState(DictationState.idle);
  }

  void _onTranscription(String rawText) async {
    _setState(DictationState.processing);

    // 1. Check for explicit voice correction command ("correction grok to Grox" / "replace grok with Grox")
    final voiceCorrection = _correctionDetector.parseVoiceCorrection(rawText);
    if (voiceCorrection != null) {
      await _correctionDetector.learn(voiceCorrection.original, voiceCorrection.replacement);
      refreshDictionary();
      _setStatus('Learned: ${voiceCorrection.original} ➔ ${voiceCorrection.replacement}');
      _setState(DictationState.idle);
      return;
    }

    // 2. Implicit self-correction learning:
    // If user recently dictated within 45 seconds, check if the current transcription is a single-word correction
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_lastDictatedText != null && (now - _lastDictatedTimestamp) < 45000) {
      final detected = _correctionDetector.detectWordCorrection(_lastDictatedText!, rawText);
      if (detected != null && detected.confidence >= 0.7) {
        await _correctionDetector.learn(detected.original, detected.replacement);
        refreshDictionary();
      }
    }

    final pauseDuration = sttPipeline.lastPauseDurationMs;
    final windowCtx = _activeWindow ?? WindowContext.getActiveWindow();

    final result = _cleanupModelReady
        ? await dictationPipeline.processWithLlm(rawText, pauseDurationMs: pauseDuration, windowContext: windowCtx)
        : dictationPipeline.process(rawText, pauseDurationMs: pauseDuration, windowContext: windowCtx);

    await textInjector.inject(result.text);

    _lastDictatedText = result.text;
    _lastDictatedTimestamp = now;

    await HistoryStore.addEntry({
      'text': rawText,
      'appliedText': result.text,
      'timestamp': now,
      'app': windowCtx?.processName ?? '',
    });

    _setStatus('Text inserted');
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

  Future<String> _resolveSpeechModelPath(String modelId) async {
    // Try dev-tree path first
    if (modelId == 'qwen3-asr-0.6b') {
      final devQwen = Directory(_devQwenPath());
      if (await devQwen.exists()) return _devQwenPath();
    } else {
      final devWhisper = File(_devWhisperPath(modelId));
      if (await devWhisper.exists()) return _devWhisperPath(modelId);
    }

    // Fall back to app data directory
    final appDir = await getApplicationSupportDirectory();
    final modelsDir = Directory('${appDir.path}${Platform.pathSeparator}models');
    final whisperDir = Directory('${modelsDir.path}${Platform.pathSeparator}whisper');
    final qwenDir = Directory('${modelsDir.path}${Platform.pathSeparator}qwen');

    switch (modelId) {
      case 'whisper-small':
        return '${whisperDir.path}${Platform.pathSeparator}ggml-small.bin';
      case 'whisper-medium':
        return '${whisperDir.path}${Platform.pathSeparator}ggml-medium.bin';
      case 'qwen3-asr-0.6b':
        return '${qwenDir.path}${Platform.pathSeparator}Qwen3-ASR-0.6B';
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
    final modelExists = _selectedSttModel == 'qwen3-asr-0.6b'
        ? await Directory(modelPath).exists()
        : await File(modelPath).exists();
    if (!modelExists) {
      _setStatus('Speech model missing: $_selectedSttModel');
      return;
    }

    try {
      await sttPipeline.dispose();
      await sttPipeline.init(modelPath);
      _setStatus('Ready to dictate');
    } catch (e) {
      _setStatus('Could not load speech model');
      debugPrint('Model load error: $e');
    }
  }

  Future<String?> _resolveCleanupModelPath(String modelId) async {
    if (modelId == 'none') return null;

    final gaufFile = 'qwen2.5-0.5b-instruct-q4_k_m.gguf';
    // Try dev-tree path first
    final devGauf = File('models${Platform.pathSeparator}qwen${Platform.pathSeparator}$gaufFile');
    if (await devGauf.exists()) {
      return devGauf.path;
    }

    // Fall back to app data directory
    final appDir = await getApplicationSupportDirectory();
    final modelsDir = Directory('${appDir.path}${Platform.pathSeparator}models');
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
      try {
        await _qwenEngine.dispose();
      } catch (e) {
        debugPrint('QwenEngine dispose warning: $e');
      }
      return;
    }

    final file = File(modelPath);
    if (!await file.exists()) {
      _cleanupModelReady = false;
      dictationPipeline.setLlmEngine(null);
      try {
        await _qwenEngine.dispose();
      } catch (e) {
        debugPrint('QwenEngine dispose warning: $e');
      }
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
      try {
        await _qwenEngine.dispose();
      } catch (e2) {
        debugPrint('QwenEngine dispose warning: $e2');
      }
      debugPrint('Cleanup model load error: $e');
    }
  }

  @override
  void dispose() {
    hotkeyService.dispose();
    try {
      sttPipeline.dispose();
    } catch (_) {}
    try {
      _qwenEngine.dispose();
    } catch (_) {}
    super.dispose();
  }
}
