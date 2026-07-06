import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

class TextInjector {
  void inject(String text) {
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
    if (count == 0) return;

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

    SendInput(count, ptr, sizeOf<INPUT>());
    calloc.free(ptr);
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
