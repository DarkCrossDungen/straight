import 'dart:io';

class WindowsStartup {
  static const String _appName = 'Straight';
  static const String _regKey = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';

  static Future<void> setEnabled(bool enable) async {
    if (!Platform.isWindows) return;

    try {
      if (enable) {
        final exePath = Platform.resolvedExecutable;
        await Process.run('reg', [
          'add',
          _regKey,
          '/v',
          _appName,
          '/t',
          'REG_SZ',
          '/d',
          '"$exePath"',
          '/f',
        ]);
      } else {
        await Process.run('reg', [
          'delete',
          _regKey,
          '/v',
          _appName,
          '/f',
        ]);
      }
    } catch (_) {
      // Ignore errors on non-Windows or restricted environments
    }
  }
}
