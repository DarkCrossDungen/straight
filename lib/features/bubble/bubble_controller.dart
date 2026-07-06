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
}
