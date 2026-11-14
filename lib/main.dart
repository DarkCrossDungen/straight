import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';
import 'core/app_context.dart';
import 'core/app_paths.dart';
import 'core/coordinator.dart';
import 'core/hotkey/desktop_shortcut_service.dart';
import 'core/hotkey/toggle_client.dart';
import 'core/injection/text_injector.dart';
import 'core/startup/startup_service.dart';
import 'core/storage/settings_store.dart';
import 'features/bubble/desktop_bubble.dart';
import 'features/bubble/desktop_bubble_service.dart';
import 'app.dart';

void main(List<String> args) async {
  if (args.contains('--toggle')) {
    final delivered = await sendToggleRequest(startIfMissing: true);
    if (!delivered) {
      stderr.writeln('Straight could not be reached or started. Shortcut port '
          'file: ${bubbleControlFile.path}');
    }
    exit(delivered ? 0 : 1);
  }

  // Types [text] into whatever app currently has focus and reports what the
  // injector managed. Diagnosing "no text arrived" in the field needs the real
  // helper paths, which only exist beside the shipped executable.
  final injectNow = args.where((a) => a.startsWith('--inject-now='));
  if (injectNow.isNotEmpty) {
    final text = injectNow.first.substring('--inject-now='.length);
    WidgetsFlutterBinding.ensureInitialized();
    final injector = TextInjector();
    injector.captureFocus();
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final delivered = await injector.inject(text);
    stderr.writeln(delivered ? 'INJECT DELIVERED' : 'INJECT FAILED');
    exit(delivered ? 0 : 1);
  }

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

  // Double-clicking the icon while Straight is already running must bring the
  // existing window up, not start a second instance that dies on the Hive lock.
  if (!args.contains('--register-shortcut')) {
    if (args.contains('--launch-at-login')) {
      if (await isInstanceRunning()) exit(0);
    } else if (await showRunningInstance()) {
      exit(0);
    }
  }

  if (Platform.isLinux) {
    // hive_flutter resolves to ~/Documents on Linux, which is not where a
    // database belongs.
    final dataDir = straightDataDir()..createSync(recursive: true);
    Hive.init(dataDir.path);
    useDataDir(dataDir);
  } else {
    await Hive.initFlutter();
    useDataDir(await getApplicationDocumentsDirectory());
  }
  try {
    await _openBoxes();
  } on FileSystemException catch (error) {
    // The other instance is still booting and owns the boxes. Wait for its
    // control port instead of crashing.
    if (!error.message.contains('lock failed')) rethrow;
    if (await showRunningInstance()) exit(0);
    rethrow;
  }

  if (args.contains('--register-shortcut')) {
    // Used by the Linux installer: Straight is closed here, so the desktop
    // entry can point at this exact executable without a window running.
    final registered = await DesktopShortcutService.register(
      SettingsStore.getHotkey(),
    );
    if (!registered) {
      stderr.writeln(
        'Could not register the desktop shortcut. Add it in Keyboard settings '
        'as: ${DesktopShortcutService.toggleCommand}',
      );
    }
    exit(registered ? 0 : 1);
  }

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

  await DesktopShortcutService.ensureCommandCurrent();

  runApp(const StraightApp());
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_startBackgroundServices(args));
  });
}

Future<void> _openBoxes() async {
  await Hive.openBox('settings');
  await Hive.openBox('dictionary');
  await Hive.openBox('history');
  await Hive.openBox('snippets');
  await Hive.openBox('workProfiles');
}

Future<void> _startBackgroundServices(List<String> args) async {
  await DesktopBubbleService.instance.initialize(
    coordinator: coordinator,
    launchedAtLogin: args.contains('--launch-at-login'),
  );
  try {
    await coordinator.bootstrap();
  } finally {
    // Even a failed bootstrap must publish the port, otherwise every shortcut
    // press would spawn another instance trying to replace a silent one.
    await DesktopBubbleService.instance.markReady();
  }
}

class _MainWindowListener extends WindowListener {
  @override
  void onWindowClose() => unawaited(windowManager.hide());
}
