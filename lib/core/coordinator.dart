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

  void _setState(DictationState s) {
    _state = s;
    notifyListeners();
  }

  void _setStatus(String message) {
    _statusMessage = message;
    notifyListeners();
  }

  Future<void> init() async {
    hotkeyService.init(onHotkeyTriggered: toggleDictation);
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

    sttPipeline.onResult = _onTranscription;
    sttPipeline.onError = (e) {
      debugPrint('STT error: $e');
      _setStatus('Speech engine error');
      _setState(DictationState.idle);
    };

    _selectedSttModel = SettingsStore.getSttModel();
    _selectedLlmModel = SettingsStore.getLlmModel();
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
    await sttPipeline.stop();
    _setStatus('Ready to dictate');
    _setState(DictationState.idle);
  }

  void _onTranscription(String rawText) async {
    _setState(DictationState.processing);

    final result = _cleanupModelReady
        ? await dictationPipeline.processWithLlm(rawText)
        : dictationPipeline.process(rawText);

    textInjector.inject(result.text);

    await HistoryStore.addEntry({
      'text': rawText,
      'appliedText': result.text,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'app': '',
    });

    _setStatus('Text inserted');
    _setState(DictationState.idle);
  }

  Future<String> _resolveSpeechModelPath(String modelId) async {
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
        return '${qwenDir.path}${Platform.pathSeparator}qwen3-asr-0.6b.gguf';
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
    final file = File(modelPath);
    if (!await file.exists()) {
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

    final appDir = await getApplicationSupportDirectory();
    final modelsDir = Directory('${appDir.path}${Platform.pathSeparator}models');
    final qwenDir = Directory('${modelsDir.path}${Platform.pathSeparator}qwen');

    switch (modelId) {
      case 'qwen2.5-0.5b':
        return '${qwenDir.path}${Platform.pathSeparator}qwen2.5-0.5b-instruct-q4_k_m.gguf';
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
    hotkeyService.dispose();
    unawaited(sttPipeline.dispose());
    unawaited(_qwenEngine.dispose());
    super.dispose();
  }
}
