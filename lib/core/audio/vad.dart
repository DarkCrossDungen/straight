import 'dart:math';
import 'dart:typed_data';

class VoiceActivityDetector {
  // A conservative level that still works with laptop microphones at normal
  // speaking volume. Blank-audio filtering protects against quiet rooms.
  static const double _speechThreshold = 0.006;
  static const int _sampleRate = 16000;
  static const double _silenceDurationMs = 800;
  static const int _minSpeechDurationMs = 200;

  final int _silenceSamples;
  final int _minSpeechSamples;

  int _silentSamples = 0;
  int _speechSamples = 0;
  bool _isSpeaking = false;

  VoiceActivityDetector()
      : _silenceSamples = (_silenceDurationMs * _sampleRate / 1000).ceil(),
        _minSpeechSamples = (_minSpeechDurationMs * _sampleRate / 1000).ceil();

  bool get isSpeaking => _isSpeaking;

  void reset() {
    _silentSamples = 0;
    _speechSamples = 0;
    _isSpeaking = false;
  }

  void processChunk(Uint8List chunk) {
    final rms = _computeRms(chunk);
    final sampleCount = chunk.lengthInBytes ~/ 2;
    if (sampleCount == 0) return;

    if (rms >= _speechThreshold) {
      _silentSamples = 0;
      if (!_isSpeaking) _speechSamples += sampleCount;
      if (_speechSamples >= _minSpeechSamples && !_isSpeaking) {
        _isSpeaking = true;
      }
    } else {
      if (_isSpeaking) {
        _silentSamples += sampleCount;
      } else {
        _speechSamples = 0;
      }
      if (_silentSamples >= _silenceSamples && _isSpeaking) {
        _isSpeaking = false;
        _speechSamples = 0;
      }
    }
  }

  double _computeRms(Uint8List chunk) {
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
}
