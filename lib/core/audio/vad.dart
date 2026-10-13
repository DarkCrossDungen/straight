import 'dart:math';
import 'dart:typed_data';

/// Noise-Proof Voice Activity Detector (VAD).
/// Incorporates adaptive background noise floor estimation and zero-crossing
/// rate (ZCR) validation to prevent keyboard clicks, fans, and ambient noise
/// from triggering false speech detections.
class VoiceActivityDetector {
  static const double _minSpeechThreshold = 0.012;
  static const double _whisperSpeechThreshold = 0.004;
  static const int _sampleRate = 16000;
  static const double _silenceDurationMs = 750;
  static const int _minSpeechDurationMs = 180;

  final int _silenceFrames;
  final int _minSpeechFrames;

  int _silentCount = 0;
  int _speechCount = 0;
  bool _isSpeaking = false;
  bool isWhisperMode = false;

  // Adaptive background noise floor tracker
  double _noiseFloor = 0.005;

  VoiceActivityDetector({this.isWhisperMode = false})
      : _silenceFrames = (_silenceDurationMs * _sampleRate / 1000).ceil() ~/ 320,
        _minSpeechFrames = (_minSpeechDurationMs * _sampleRate / 1000).ceil() ~/ 320;

  bool get isSpeaking => _isSpeaking;
  double get currentBaseThreshold =>
      isWhisperMode ? _whisperSpeechThreshold : _minSpeechThreshold;

  void reset() {
    _silentCount = 0;
    _speechCount = 0;
    _isSpeaking = false;
    _noiseFloor = isWhisperMode ? 0.003 : 0.006;
  }

  double processChunk(Uint8List chunk) {
    final rms = computeRms(chunk);
    final zcr = computeZeroCrossingRate(chunk);

    // Track ambient noise floor (slowly adapt to room acoustics)
    if (rms < _noiseFloor * 2.0) {
      _noiseFloor = _noiseFloor * 0.96 + rms * 0.04;
    } else {
      _noiseFloor = min(_noiseFloor * 1.002, 0.03);
    }

    // Speech criteria:
    // 1. Energy must exceed both base threshold and adaptive noise floor by margin
    // 2. Zero-crossing rate must be within human vocal range (rejects sharp key clicks & ultra-high hiss)
    final dynamicThreshold = max(currentBaseThreshold, _noiseFloor * 1.6);
    final isVoiceZcr = isWhisperMode ? (zcr <= 0.65) : (zcr >= 0.02 && zcr <= 0.50);
    final isSpeechEnergy = rms >= dynamicThreshold;

    if (isSpeechEnergy && isVoiceZcr) {
      _speechCount++;
      _silentCount = 0;
      if (_speechCount >= _minSpeechFrames && !_isSpeaking) {
        _isSpeaking = true;
      }
    } else {
      _silentCount++;
      if (_silentCount >= _silenceFrames && _isSpeaking) {
        _isSpeaking = false;
        _speechCount = 0;
      }
    }

    return rms;
  }

  double computeRms(Uint8List chunk) {
    double sum = 0;
    final count = chunk.lengthInBytes ~/ 2;

    for (var i = 0; i + 1 < chunk.length; i += 2) {
      final sample = ((chunk[i + 1] << 8) | chunk[i]).toSigned(16);
      final normalized = sample / 32768.0;
      sum += normalized * normalized;
    }

    if (count == 0) return 0.0;
    return sqrt(sum / count);
  }

  double computeZeroCrossingRate(Uint8List chunk) {
    final count = chunk.lengthInBytes ~/ 2;
    if (count < 2) return 0.0;

    int crossings = 0;
    int prevSample = ((chunk[1] << 8) | chunk[0]).toSigned(16);

    for (var i = 2; i + 1 < chunk.length; i += 2) {
      final currSample = ((chunk[i + 1] << 8) | chunk[i]).toSigned(16);
      if ((prevSample >= 0 && currSample < 0) || (prevSample < 0 && currSample >= 0)) {
        crossings++;
      }
      prevSample = currSample;
    }

    return crossings / (count - 1);
  }
}
