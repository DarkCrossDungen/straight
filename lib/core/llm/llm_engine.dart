abstract class LlmEngine {
  Future<void> init(String modelPath);
  Future<String> complete(String prompt, {int maxTokens = 128});
  Future<void> dispose();
}
