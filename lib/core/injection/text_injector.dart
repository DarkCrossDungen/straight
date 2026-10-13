import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';
import 'package:win32/win32.dart';

class TextInjector {
  // Threshold above which long text is pasted instantly via clipboard
  static const int pasteThreshold = 45;

  Future<void> inject(String text) async {
    if (text.isEmpty) return;

    // Fast path: for short phrases without newlines, simulate keystrokes directly
    if (text.length < pasteThreshold && !text.contains('\n')) {
      _injectViaSendInput(text);
      return;
    }

    // Long text / paragraphs: instant paste via clipboard with state restore
    await _injectViaClipboard(text);
  }

  Future<void> _injectViaClipboard(String text) async {
    ClipboardData? previous;
    try {
      previous = await Clipboard.getData(Clipboard.kTextPlain);
    } catch (_) {}

    try {
      // 1. Stage target text into clipboard
      await Clipboard.setData(ClipboardData(text: text));

      // 2. Synthesize Ctrl + V
      _sendCtrlV();

      // 3. Short buffer for target app to consume clipboard contents
      await Future.delayed(const Duration(milliseconds: 100));
    } catch (_) {
      // Fallback to SendInput if clipboard is locked by another process
      _injectViaSendInput(text);
    } finally {
      // 4. Transparently restore user's prior clipboard data
      if (previous != null) {
        try {
          await Clipboard.setData(previous);
        } catch (_) {}
      }
    }
  }

  void _sendCtrlV() {
    final ptr = calloc<INPUT>(4);
    // Ctrl Down
    _setKeyboardInput(ptr[0], VK_CONTROL, 0, 0);
    // 'V' Down (0x56)
    _setKeyboardInput(ptr[1], 0x56, 0, 0);
    // 'V' Up
    _setKeyboardInput(ptr[2], 0x56, 0, KEYEVENTF_KEYUP);
    // Ctrl Up
    _setKeyboardInput(ptr[3], VK_CONTROL, 0, KEYEVENTF_KEYUP);

    SendInput(4, ptr, sizeOf<INPUT>());
    calloc.free(ptr);
  }

  void _injectViaSendInput(String text) {
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
