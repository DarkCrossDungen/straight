/// Types transcript text into whichever app the user was working in.
abstract class TextInjectorPlatform {
  /// Called when dictation begins, so the implementation can remember the
  /// typing target before Straight's own window takes focus.
  void captureFocus();

  /// Returns false when the text could not be placed, which lets the caller
  /// offer a copy fallback instead of losing the transcript.
  bool inject(String text);
}
