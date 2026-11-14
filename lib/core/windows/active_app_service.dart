import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

class ActiveAppService {
  /// Full path of the app that owns the foreground window, or null when the
  /// desktop cannot or will not say.
  ///
  /// Win32 has no equivalent on Linux, and loading user32 there throws the
  /// moment anything calls this. AT-SPI already tells us what has the caret, so
  /// a null here only costs the vocabulary profile selection.
  String? foregroundExecutable() {
    if (!Platform.isWindows) return null;

    final window = GetForegroundWindow();
    if (window == 0) return null;

    final processId = calloc<Uint32>();
    try {
      GetWindowThreadProcessId(window, processId);
      if (processId.value == 0) return null;

      final process = OpenProcess(
        PROCESS_QUERY_LIMITED_INFORMATION,
        FALSE,
        processId.value,
      );
      if (process == 0) return null;
      try {
        final path = wsalloc(MAX_PATH);
        final size = calloc<Uint32>()..value = MAX_PATH;
        try {
          if (QueryFullProcessImageName(process, 0, path, size) == 0) {
            return null;
          }
          final fullPath = path.toDartString();
          final parts = fullPath.split(RegExp(r'[\\/]'));
          return parts.isEmpty ? null : parts.last;
        } finally {
          free(path);
          calloc.free(size);
        }
      } finally {
        CloseHandle(process);
      }
    } finally {
      calloc.free(processId);
    }
  }
}
