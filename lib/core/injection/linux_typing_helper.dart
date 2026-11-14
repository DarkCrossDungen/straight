import 'dart:io';

import 'package:flutter/foundation.dart';

/// Result of asking a bundled typing helper to send keys.
enum TypingResult { typed, pasted, missingCharacter, noTarget, unavailable }

/// Runs the bundled XTEST (`xtype`) and uinput (`ktype`) helpers.
///
/// AT-SPI is tried first, but it only works when the target app publishes an
/// editable object. GTK4 builds here link no AT-SPI bridge and Chromium and
/// Electron apps publish no document tree, so the helpers carry the rest:
/// XTEST reaches X11 and XWayland clients, and the kernel-level helper reaches
/// native Wayland clients.
class LinuxTypingHelper {
  LinuxTypingHelper._();

  /// Waits for a helper to finish so the caller can act on the outcome.
  static const _timeout = Duration(seconds: 8);

  static File? _helper(String name) {
    final file = File(
      '${File(Platform.resolvedExecutable).parent.path}${Platform.pathSeparator}'
      '$name',
    );
    return file.existsSync() ? file : null;
  }

  /// True when the XTEST helper can send keys to an X display.
  static bool get xtypeUsable => _helper('xtype') != null;

  /// True when the kernel-level helper can reach `/dev/uinput`.
  static bool get ktypeUsable {
    final file = _helper('ktype');
    if (file == null) return false;
    try {
      File('/dev/uinput').openSync(mode: FileMode.write).close();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Types [text] as keystrokes into the focused window. When [pid] is given the
  /// window owned by that process is focused first.
  static Future<TypingResult> xtype(String text, {int? pid}) async {
    final helper = _helper('xtype');
    if (helper == null) return TypingResult.unavailable;
    final args = <String>[
      if (pid != null) '--focus-pid',
      if (pid != null) '$pid',
      text,
    ];
    final line = await _run(helper.path, args);
    if (line == null) return TypingResult.unavailable;
    return _classify(line);
  }

  /// Sends Ctrl+V, for text the caller already placed on the clipboard.
  static Future<TypingResult> paste() async {
    final helper = _helper('xtype');
    if (helper == null) return TypingResult.unavailable;
    final line = await _run(helper.path, const ['--paste']);
    if (line == null) return TypingResult.unavailable;
    return _classify(line);
  }

  static Future<TypingResult> ktype(String text) async {
    final helper = _helper('ktype');
    if (helper == null) return TypingResult.unavailable;
    final line = await _run(helper.path, [text]);
    if (line == null) return TypingResult.unavailable;
    return _classify(line);
  }

  static TypingResult _classify(String line) {
    if (line.startsWith('TYPED')) return TypingResult.typed;
    if (line.startsWith('PASTED')) return TypingResult.pasted;
    if (line.startsWith('MISSING')) return TypingResult.missingCharacter;
    if (line.startsWith('NOFOCUS')) return TypingResult.noTarget;
    return TypingResult.unavailable;
  }

  static Future<String?> _run(String executable, List<String> args) async {
    try {
      final result = await Process.run(executable, args).timeout(_timeout);
      if (result.exitCode != 0) {
        debugPrint('typing helper ${args.first} failed: '
            '${(result.stdout as String).trim()} ${(result.stderr as String).trim()}');
        return null;
      }
      final stdout = (result.stdout as String).trim();
      if (stdout.isEmpty) return null;
      final first = stdout.split('\n').first.trim();
      if (first == 'NOPERM' || first == 'NODISPLAY') {
        debugPrint('typing helper unavailable: $first');
      }
      return first;
    } catch (error) {
      debugPrint('typing helper error: $error');
      return null;
    }
  }
}
