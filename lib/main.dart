import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:window_manager/window_manager.dart';
import 'core/app_context.dart';
import 'core/coordinator.dart';
import 'core/startup/startup_service.dart';
import 'core/storage/settings_store.dart';
import 'features/bubble/desktop_bubble.dart';
import 'features/bubble/desktop_bubble_service.dart';
import 'app.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  if (args.contains('--bubble-window')) {
    final portArgument = args.where(
      (argument) => argument.startsWith('--bubble-port='),
    );
    if (portArgument.isEmpty) return;
    final port = int.tryParse(portArgument.first.split('=').last);
    if (port == null) return;
    await runDesktopBubble(port);
    return;
  }

  await hotKeyManager.unregisterAll();

  await Hive.initFlutter();
  await Hive.openBox('settings');
  await Hive.openBox('dictionary');
  await Hive.openBox('history');
  await Hive.openBox('snippets');

  coordinator = StraightCoordinator();

  await windowManager.setSize(const Size(1240, 760));
  await windowManager.setMinimumSize(const Size(860, 580));
  await windowManager.setResizable(true);
  await windowManager.center();
  if (!kDebugMode) {
    await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
  }
  await windowManager.setPreventClose(true);
  windowManager.addListener(_MainWindowListener());

  StartupService.initialize();
  if (SettingsStore.getStartOnBoot()) {
    await StartupService.setEnabled(true);
  }

  runApp(const StraightApp());
  await DesktopBubbleService.instance.initialize(
    coordinator: coordinator,
    launchedAtLogin: args.contains('--launch-at-login'),
  );
  unawaited(coordinator.bootstrap());
}

class _MainWindowListener extends WindowListener {
  @override
  void onWindowClose() => unawaited(windowManager.hide());
}
