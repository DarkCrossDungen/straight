import 'package:straight/core/hotkey/desktop_shortcut_service.dart';

// Verification harness for the desktop shortcut registration:
// dart run tool/desktop_shortcut_probe.dart
Future<void> main() async {
  print('supported: ${await DesktopShortcutService.isSupported()}');
  print('before: ${await DesktopShortcutService.registeredBinding()}');
  final ok = await DesktopShortcutService.register({
    'alt': true,
    'ctrl': false,
    'shift': false,
    'meta': false,
    'key': 'Space',
  });
  print('register ok: $ok');
  print('binding: ${await DesktopShortcutService.registeredBinding()}');
  print('command: ${await DesktopShortcutService.registeredCommand()}');
}
