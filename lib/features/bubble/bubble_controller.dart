import 'package:flutter/material.dart';

enum BubbleState { idle, listening, processing }

class BubbleController extends ChangeNotifier {
  BubbleState _state = BubbleState.idle;
  List<double> _waveformAmplitudes = List.filled(20, 0.1);

  BubbleState get state => _state;
  List<double> get waveformAmplitudes => _waveformAmplitudes;

  void setState(BubbleState newState) {
    _state = newState;
    notifyListeners();
  }

  void updateWaveform(List<double> amplitudes) {
    _waveformAmplitudes = amplitudes;
    notifyListeners();
  }

  void pushAmplitude(double amp) {
    final normalized = (amp * 4.5).clamp(0.08, 1.0);
    final next = List<double>.from(_waveformAmplitudes.sublist(1))..add(normalized);
    _waveformAmplitudes = next;
    notifyListeners();
  }
}

