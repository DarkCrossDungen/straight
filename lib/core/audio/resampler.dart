class AudioResampler {
  final int inputRate;
  final int outputRate;
  final double _ratio;

  AudioResampler({
    this.inputRate = 44100,
    this.outputRate = 16000,
  }) : _ratio = outputRate / inputRate;

  List<int> resample(List<int> input) {
    if (inputRate == outputRate) return input;

    final outputLength = (input.length * _ratio).ceil();
    final output = List<int>.filled(outputLength, 0);

    for (var i = 0; i < outputLength; i++) {
      final srcPos = i / _ratio;
      final index = srcPos.floor();
      final frac = srcPos - index;

      if (index + 1 < input.length) {
        output[i] = _lerp(input[index], input[index + 1], frac);
      } else if (index < input.length) {
        output[i] = input[index];
      }
    }

    return output;
  }

  int _lerp(int a, int b, double t) {
    return (a + (b - a) * t).round();
  }

  void reset() {}
}
