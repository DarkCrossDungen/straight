import 'dart:async';
import 'dart:typed_data';
import 'package:record/record.dart';
import 'vad.dart';

class AudioCapture {
  final AudioRecorder _recorder = AudioRecorder();
  final VoiceActivityDetector _vad = VoiceActivityDetector();
  StreamSubscription<Uint8List>? _streamSub;
  bool _isRecording = false;

  bool get isRecording => _isRecording;
  VoiceActivityDetector get vad => _vad;

  Future<bool> hasPermission() => _recorder.hasPermission();

  Stream<List<int>> startStream() async* {
    if (_isRecording) return;

    _isRecording = true;
    _vad.reset();

    final config = RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      numChannels: 1,
      sampleRate: 16000,
    );

    final Stream<Uint8List> rawStream;
    try {
      rawStream = await _recorder.startStream(config);
    } catch (e) {
      _isRecording = false;
      rethrow;
    }

    await for (final chunk in rawStream) {
      if (!_isRecording) break;

      final samples = _recorder.convertBytesToInt16(chunk);
      _vad.processChunk(chunk);
      yield samples;
    }
  }

  Future<void> stop() async {
    _isRecording = false;
    await _streamSub?.cancel();
    _streamSub = null;
    await _recorder.stop();
  }

  void dispose() {
    stop();
    _recorder.dispose();
  }
}
