import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

class TextInjector {
  bool inject(String text) {
    // Avoid typing into the desktop or back into Straight's own overlay. This
    // lets the caller offer a short copy fallback instead of losing the text.
    final foreground = GetForegroundWindow();
    if (foreground == 0) return false;

    final titleLength = GetWindowTextLength(foreground);
    if (titleLength == 0) return false;
    final title = wsalloc(titleLength + 1);
    try {
      GetWindowText(foreground, title, titleLength + 1);
      final targetTitle = title.toDartString();
      if (targetTitle.toLowerCase().contains('straight') ||
          targetTitle == 'Program Manager') {
        return false;
      }
    } finally {
      free(title);
    }

    int count = 0;
    for (final rune in text.runes) {
      if (rune == 0x0A || rune == 0x0D) {
        count += 2;
      } else if (rune <= 0xFFFF) {
        count += 2;
      } else {
        count += 4;
      }
    }
    if (count == 0) return false;

    final ptr = calloc<INPUT>(count);
    int i = 0;
    for (final rune in text.runes) {
      if (rune == 0x0A || rune == 0x0D) {
        _setKeyboardInput(ptr[i], VK_RETURN, 0, 0);
        i++;
        _setKeyboardInput(ptr[i], VK_RETURN, 0, KEYEVENTF_KEYUP);
        i++;
      } else if (rune <= 0xFFFF) {
        _setUnicodeInput(ptr[i], rune, false);
        i++;
        _setUnicodeInput(ptr[i], rune, true);
        i++;
      } else {
        final high = 0xD800 + ((rune - 0x10000) >> 10);
        final low = 0xDC00 + ((rune - 0x10000) & 0x3FF);
        _setUnicodeInput(ptr[i], high, false);
        i++;
        _setUnicodeInput(ptr[i], high, true);
        i++;
        _setUnicodeInput(ptr[i], low, false);
        i++;
        _setUnicodeInput(ptr[i], low, true);
        i++;
      }
    }

    final sent = SendInput(count, ptr, sizeOf<INPUT>());
    calloc.free(ptr);
    return sent == count;
  }

  void _setKeyboardInput(INPUT input, int wVk, int wScan, int dwFlags) {
    input.type = INPUT_KEYBOARD;
    input.ki.wVk = wVk;
    input.ki.wScan = wScan;
    input.ki.dwFlags = dwFlags;
    input.ki.time = 0;
    input.ki.dwExtraInfo = 0;
  }

  void _setUnicodeInput(INPUT input, int codeUnit, bool keyUp) {
    input.type = INPUT_KEYBOARD;
    input.ki.wVk = 0;
    input.ki.wScan = codeUnit;
    input.ki.dwFlags = KEYEVENTF_UNICODE | (keyUp ? KEYEVENTF_KEYUP : 0);
    input.ki.time = 0;
    input.ki.dwExtraInfo = 0;
  }
}
