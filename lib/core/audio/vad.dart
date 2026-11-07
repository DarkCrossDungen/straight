import 'dart:math';
import 'dart:typed_data';

class VoiceActivityDetector {
  /// Below this nothing is worth transcribing, however quiet the room is.
  static const double _quietFloor = 0.0035;

  /// Speech must stand this far above the measured room noise. A constant
  /// threshold cannot work: capture gain differs by tens of dB between
  /// machines, and a laptop fan alone can sit above any fixed value.
  static const double _noiseMargin = 3.2;

  /// Upward adaptation per silent chunk. Deliberately slow so a pause between
  /// words is not mistaken for a louder room.
  static const double _noiseRise = 0.02;

  static const int _sampleRate = 16000;
  static const double _silenceDurationMs = 800;
  static const int _minSpeechDurationMs = 200;

  /// Stationary noise can drift above the threshold and latch the detector on.
  /// A voice always dips below it within this long; a continuous hum does not.
  static const double _maxContinuousSpeechMs = 6000;

  /// A dead or unplugged capsule is not quiet, it is a flat wall of noise.
  /// Real rooms drop between phrases, so sustained loudness with no gap at all
  /// means nothing is being heard rather than something loud.
  static const double _saturatedFloor = 0.20;
  static const double _staticDurationMs = 1200;

  final int _silenceSamples;
  final int _minSpeechSamples;
  final int _maxContinuousSamples;
  final int _staticSamples;

  int _silentSamples = 0;
  int _speechSamples = 0;
  int _continuousSamples = 0;
  bool _isSpeaking = false;
  double _level = 0;
  double _noiseFloor = 0;
  bool _seeded = false;
  double _clippedRatio = 0;
  int _loudSamples = 0;

  VoiceActivityDetector()
    : _silenceSamples = (_silenceDurationMs * _sampleRate / 1000).ceil(),
      _minSpeechSamples = (_minSpeechDurationMs * _sampleRate / 1000).ceil(),
      _maxContinuousSamples =
          (_maxContinuousSpeechMs * _sampleRate / 1000).ceil(),
      _staticSamples = (_staticDurationMs * _sampleRate / 1000).ceil();

  bool get isSpeaking => _isSpeaking;
  double get level => _level;
  double get noiseFloor => _noiseFloor;
  double get speechThreshold => max(_quietFloor, _noiseFloor * _noiseMargin);

  /// Fraction of samples pinned to the digital rail. Anything above a few
  /// percent means the input gain is too high and speech is being destroyed.
  double get clippedRatio => _clippedRatio;

  /// True when the input has been continuously loud with no pause for a while,
  /// which is how a broken or muted capsule presents itself.
  bool get hearsOnlyStatic => _loudSamples >= _staticSamples;

  /// Loudness relative to the detection threshold, for the companion visual.
  /// A raw RMS would animate on room noise alone.
  double get speechLevel {
    final threshold = speechThreshold;
    if (_level <= threshold) return 0;
    return ((_level - threshold) / (threshold * 3)).clamp(0.0, 1.0).toDouble();
  }

  void reset() {
    _silentSamples = 0;
    _speechSamples = 0;
    _continuousSamples = 0;
    _isSpeaking = false;
    _level = 0;
    _clippedRatio = 0;
    // The room does not change between shortcut presses, so the learned floor
    // survives; relearning it would deafen the first second of every session.
  }

  void processChunk(Uint8List chunk) {
    final sampleCount = chunk.lengthInBytes ~/ 2;
    if (sampleCount == 0) return;

    final (rms, clipped) = _measure(chunk);
    _level = rms;
    _clippedRatio = clipped;
    final threshold = speechThreshold;

    if (!_isSpeaking) {
      _loudSamples = rms >= _saturatedFloor ? _loudSamples + sampleCount : 0;
    }

    if (!_seeded) {
      _noiseFloor = rms;
      _seeded = true;
    } else if (!_isSpeaking) {
      if (rms < _noiseFloor) {
        _noiseFloor = rms;
      } else if (rms < threshold) {
        _noiseFloor += (rms - _noiseFloor) * _noiseRise;
      }
    }

    if (rms >= threshold) {
      _silentSamples = 0;
      _continuousSamples += sampleCount;
      if (!_isSpeaking) {
        _speechSamples += sampleCount;
        if (_speechSamples >= _minSpeechSamples) {
          _isSpeaking = true;
          _loudSamples = 0;
        }
      }
      if (_isSpeaking && _continuousSamples >= _maxContinuousSamples) {
        _noiseFloor = rms;
        _isSpeaking = false;
        _speechSamples = 0;
        _continuousSamples = 0;
      }
    } else {
      _continuousSamples = 0;
      if (_isSpeaking) {
        _silentSamples += sampleCount;
      } else {
        _speechSamples = 0;
      }
      if (_isSpeaking && _silentSamples >= _silenceSamples) {
        _isSpeaking = false;
        _speechSamples = 0;
      }
    }
  }

  (double, double) _measure(Uint8List chunk) {
    double sum = 0;
    var clipped = 0;
    final count = chunk.lengthInBytes ~/ 2;

    for (var i = 0; i + 1 < chunk.length; i += 2) {
      final sample = ((chunk[i + 1] << 8) | chunk[i]).toSigned(16);
      if (sample <= -32767 || sample >= 32766) clipped++;
      final normalized = sample / 32768.0;
      sum += normalized * normalized;
    }

    if (count == 0) return (0.0, 0.0);
    return (sqrt(sum / count), clipped / count);
  }
}