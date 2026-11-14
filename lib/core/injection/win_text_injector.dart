import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import 'text_injector_platform.dart';

class WinTextInjector implements TextInjectorPlatform {
  @override
  void captureFocus() {}

  @override
  Future<bool> inject(String text) async {
    if (!Platform.isWindows) return false;

    final user32 = DynamicLibrary.process();

    final _GetForegroundWindow =
        user32.lookupFunction<Int64 Function(), int Function()>(
      'GetForegroundWindow',
    );
    final _GetWindowTextLengthA =
        user32.lookupFunction<Int32 Function(Pointer<Void>), int Function(
      Pointer<Void>,
    )>('GetWindowTextLengthA');
    final _GetWindowTextA = user32.lookupFunction<
        Int32 Function(Pointer<Void>, Pointer<Utf8>, Int32),
        int Function(Pointer<Void>, Pointer<Utf8>, int)>('GetWindowTextA');

    // Avoid typing into the desktop or back into Straight's own overlay.
    final foreground = _GetForegroundWindow();
    if (foreground == 0) return false;

    final titleLength = _GetWindowTextLengthA(Pointer<Void>.fromAddress(foreground));
    if (titleLength == 0) return false;
    final title = calloc<Uint8>(titleLength + 1);
    try {
      _GetWindowTextA(
        Pointer<Void>.fromAddress(foreground),
        title.cast<Utf8>(),
        titleLength + 1,
      );
      final targetTitle = title.cast<Utf8>().toDartString();
      if (targetTitle.toLowerCase().contains('straight') ||
          targetTitle == 'Program Manager') {
        return false;
      }
    } finally {
      calloc.free(title);
    }

    // INPUT struct is 40 bytes on 64-bit Windows (type: 4 + union: 16 + padding).
    const inputSize = 40;

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

    final ptr = calloc<Uint8>(count * inputSize);

    final _SendInput =
        user32.lookupFunction<Int32 Function(Int32, Pointer<Void>, Int32),
            int Function(int, Pointer<Void>, int)>('SendInput');

    int i = 0;
    for (final rune in text.runes) {
      final offset = i * inputSize;
      if (rune == 0x0A || rune == 0x0D) {
        // KEYBDINPUT: wVk=VK_RETURN(0x0D), dwFlags=0 then KEYEVENTF_KEYUP(0x0002)
        // type(4) + wVk(2) + wScan(2) + dwFlags(4) + time(4) + dwExtraInfo(8) = 24 bytes per event on 64-bit
        // Using INPUT size 40 for safety with padding
        _writeKeyboardInput(ptr, offset, 0x0D, 0);
        i++;
        _writeKeyboardInput(ptr, offset + inputSize, 0x0D, 0x0002);
        i++;
      } else if (rune <= 0xFFFF) {
        _writeUnicodeInput(ptr, offset, rune, false);
        i++;
        _writeUnicodeInput(ptr, offset + inputSize, rune, true);
        i++;
      } else {
        final high = 0xD800 + ((rune - 0x10000) >> 10);
        final low = 0xDC00 + ((rune - 0x10000) & 0x3FF);
        _writeUnicodeInput(ptr, offset, high, false);
        i++;
        _writeUnicodeInput(ptr, offset + inputSize, high, true);
        i++;
        _writeUnicodeInput(ptr, offset + inputSize * 2, low, false);
        i++;
        _writeUnicodeInput(ptr, offset + inputSize * 3, low, true);
        i++;
      }
    }

    final sent = _SendInput(count, ptr.cast<Void>(), inputSize);
    calloc.free(ptr);
    return sent == count;
  }

  void _writeKeyboardInput(Pointer<Uint8> base, int offset, int vk, int flags) {
    // INPUT struct layout on 64-bit Windows:
    //   type (DWORD, 4 bytes) at offset 0
    //   UNION (16 bytes) at offset 8 (after 4 bytes padding)
    //   KEYBDINPUT inside union:
    //     wVk (WORD, 2 bytes) at union offset 0
    //     wScan (WORD, 2 bytes) at union offset 2
    //     dwFlags (DWORD, 4 bytes) at union offset 4
    //     time (DWORD, 4 bytes) at union offset 8
    //     dwExtraInfo (ULONG_PTR, 8 bytes) at union offset 16
    final addr = base.address + offset;
    // type = INPUT_KEYBOARD (1)
    Pointer<Uint32>.fromAddress(addr).value = 1;
    // wVk
    Pointer<Uint16>.fromAddress(addr + 8).value = vk;
    // wScan = 0
    Pointer<Uint16>.fromAddress(addr + 10).value = 0;
    // dwFlags
    Pointer<Uint32>.fromAddress(addr + 12).value = flags;
    // time = 0
    Pointer<Uint32>.fromAddress(addr + 16).value = 0;
    // dwExtraInfo = 0
    Pointer<Uint64>.fromAddress(addr + 24).value = 0;
  }

  void _writeUnicodeInput(
      Pointer<Uint8> base, int offset, int codeUnit, bool keyUp) {
    final flags = 0x0004 | (keyUp ? 0x0002 : 0); // KEYEVENTF_UNICODE | KEYEVENTF_KEYUP
    _writeKeyboardInput(base, offset, 0, flags);
    // wScan = codeUnit (overwrites wVk at offset 8)
    Pointer<Uint16>.fromAddress(base.address + offset + 8).value = codeUnit;
  }
}
