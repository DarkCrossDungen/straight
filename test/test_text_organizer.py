import unittest

from tool.text_organizer import organize


class TextOrganizerTests(unittest.TestCase):
    def test_none_preserves_exact_input(self):
        source = " um hello   world "
        self.assertEqual(organize(source, "none"), source)

    def test_removes_fillers_and_fixes_basic_punctuation(self):
        self.assertEqual(
            organize("um hello ,world . uh this is fine"),
            "Hello, world. This is fine",
        )

    def test_formats_explicit_ordinal_list(self):
        self.assertEqual(
            organize("First buy milk, second call Sam, finally go home"),
            "1. Buy milk\n2. Call Sam\n3. Go home",
        )

    def test_formats_explicit_bullets(self):
        self.assertEqual(
            organize("Remember new bullet call Sam new bullet send the email"),
            "Remember\n• call Sam\n• send the email",
        )

    def test_preserves_explicit_line_and_paragraph_cues(self):
        self.assertEqual(
            organize("Hello new line there new paragraph Next topic"),
            "Hello\nthere\n\nNext topic",
        )

    def test_applies_explicit_backtrack(self):
        self.assertEqual(
            organize("The meeting is at three scratch that make it four."),
            "Make it four.",
        )

    def test_medium_removes_adjacent_repeated_words(self):
        self.assertEqual(organize("I I think we should go."), "I think we should go.")

    def test_light_keeps_repetitions(self):
        self.assertEqual(organize("I I think we should go.", "light"), "I I think we should go.")

    def test_splits_known_topic_transition(self):
        self.assertEqual(
            organize("The launch is ready. On another note the budget changed."),
            "The launch is ready.\n\nOn another note the budget changed.",
        )

    def test_invalid_cleanup_level_is_rejected(self):
        with self.assertRaises(ValueError):
            organize("Hello", "extreme")


if __name__ == "__main__":
    unittest.main()
