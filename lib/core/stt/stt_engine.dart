abstract class SttEngine {
  Future<void> init(String modelPath);
  Future<String> transcribe(List<int> pcmAudio);

  /// Lets engines that support it use the user's names and technical terms as
  /// a recognition hint. Engines without vocabulary support safely ignore it.
  Future<void> setVocabulary(List<String> terms) async {}

  Future<void> dispose();
}
