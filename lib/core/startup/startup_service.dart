import 'dart:io';

import 'package:launch_at_startup/launch_at_startup.dart';

class StartupService {
  static void initialize() {
    launchAtStartup.setup(
      appName: 'Straight',
      appPath: Platform.resolvedExecutable,
      args: const ['--launch-at-login'],
    );
  }

  static Future<void> setEnabled(bool enabled) async {
    if (enabled) {
      await launchAtStartup.enable();
    } else {
      await launchAtStartup.disable();
    }
  }
}
