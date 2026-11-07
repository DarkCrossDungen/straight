import 'dart:convert';
import 'dart:io';

/// The one-time permission that lets Straight tell a key hold from a tap.
///
/// Reading /dev/input is the only way to see a key *release* on Wayland, and
/// those devices belong to root's `input` group. Without it the app still
/// works, but the shortcut can only report presses.
class InputAccess {
  /// Whether this platform can watch raw key events at all.
  static bool get isSupported => Platform.isLinux;

  /// Whether at least one keyboard device opens for reading right now.
  static Future<bool> isReadable() async {
    for (var index = 0; index < 32; index++) {
      final file = File('/dev/input/event$index');
      if (!await file.exists()) continue;
      RandomAccessFile? handle;
      try {
        handle = await file.open();
        return true;
      } catch (_) {
        // Permission denied: the group and the ACL are both still missing.
      } finally {
        await handle?.close();
      }
    }
    return false;
  }

  /// Adds the user to the `input` group and opens the current devices for them,
  /// so the next reboot is not required. The password is handed to sudo over
  /// stdin — never stored, never passed as an argument — and sudo is what
  /// validates it. The script takes the username as a positional parameter and
  /// quotes it, so nothing here reaches a shell.
  static Future<InputGrantResult> grantWithPassword(String password) async {
    final user = Platform.environment['USER'] ?? '';
    if (user.isEmpty || password.isEmpty) return InputGrantResult.failed;
    try {
      // Drop any cached sudo timestamp so the typed password is really checked.
      await Process.run('sudo', ['-k']);
      final process = await Process.start('sudo', [
        '-S',
        '-p',
        '',
        'bash',
        '-c',
        _script,
        'straight',
        user,
      ]);
      process.stdin.writeln(password);
      await process.stdin.flush();
      await process.stdin.close();
      final error = await process.stderr.transform(utf8.decoder).join();
      final code = await process.exitCode;
      if (code == 0) return InputGrantResult.granted;
      final lower = error.toLowerCase();
      if (lower.contains('try again') ||
          lower.contains('incorrect password') ||
          lower.contains('authentication failure')) {
        return InputGrantResult.wrongPassword;
      }
      return InputGrantResult.failed;
    } catch (_) {
      return InputGrantResult.failed;
    }
  }

  static const _script =
      r'''
usermod -aG input "$1" || exit 1
for device in /dev/input/event*; do
  [ -e "$device" ] || continue
  setfacl -m "u:$1:rw" "$device" || exit 1
done
exit 0
''';
}

enum InputGrantResult { granted, wrongPassword, failed }