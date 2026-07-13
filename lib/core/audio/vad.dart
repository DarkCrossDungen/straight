import 'dart:math';
import 'dart:typed_data';

class VoiceActivityDetector {
  // A conservative level that still works with laptop microphones at normal
  // speaking volume. Blank-audio filtering protects against quiet rooms.
  static const double _speechThreshold = 0.006;
  static const int _sampleRate = 16000;
  static const double _silenceDurationMs = 800;
  static const int _minSpeechDurationMs = 200;

  final int _silenceFrames;
  final int _minSpeechFrames;

  int _silentCount = 0;
  int _speechCount = 0;
  bool _isSpeaking = false;

  VoiceActivityDetector()
      : _silenceFrames = (_silenceDurationMs * _sampleRate / 1000).ceil() ~/ 320,
        _minSpeechFrames = (_minSpeechDurationMs * _sampleRate / 1000).ceil() ~/ 320;

  bool get isSpeaking => _isSpeaking;

  void reset() {
    _silentCount = 0;
    _speechCount = 0;
    _isSpeaking = false;
  }

  void processChunk(Uint8List chunk) {
    final rms = _computeRms(chunk);

    if (rms >= _speechThreshold) {
      _speechCount++;
      _silentCount = 0;
      if (_speechCount >= _minSpeechFrames && !_isSpeaking) {
        _isSpeaking = true;
      }
    } else {
      _silentCount++;
      if (_silentCount >= _silenceFrames && _isSpeaking) {
        _isSpeaking = false;
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
