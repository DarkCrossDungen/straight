abstract class SttEngine {
  Future<void> init(String modelPath);
  Future<String> transcribe(List<int> pcmAudio, {String? initialPrompt});
  Future<void> dispose();
}
