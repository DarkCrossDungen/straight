abstract class SttEngine {
  Future<void> init(String modelPath);
  Future<String> transcribe(List<int> pcmAudio);
  Future<void> dispose();
}
