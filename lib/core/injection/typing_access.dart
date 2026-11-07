import 'dart:io';

/// The switch that lets Straight type into other apps on Linux.
///
/// AT-SPI (the accessibility bus) only exposes an app's text fields when the
/// desktop's toolkit-accessibility setting is on. Flipping it is a per-user
/// gsettings change — no password, no restart of the session.
class TypingAccess {
  static const _schema = 'org.gnome.desktop.interface';
  static const _key = 'toolkit-accessibility';

  static bool get isSupported => Platform.isLinux;

  /// Whether the desktop exposes app text trees to the accessibility bus.
  /// Null when the desktop does not use this schema (KDE, XFCE, ...).
  static Future<bool?> isEnabled() async {
    try {
      final result = await Process.run('gsettings', ['get', _schema, _key]);
      if (result.exitCode != 0) return null;
      return (result.stdout as String).trim() == 'true';
    } catch (_) {
      return null;
    }
  }

  /// Turns the setting on. Returns the new state, or null when unsupported.
  static Future<bool?> enable() async {
    try {
      final result = await Process.run(
        'gsettings',
        ['set', _schema, _key, 'true'],
      );
      if (result.exitCode != 0) return null;
      return await isEnabled();
    } catch (_) {
      return null;
    }
  }
}