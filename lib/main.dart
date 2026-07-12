import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:window_manager/window_manager.dart';
import 'core/app_context.dart';
import 'core/coordinator.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await Hive.openBox('settings');
  await Hive.openBox('dictionary');
  await Hive.openBox('history');
  await Hive.openBox('snippets');

  coordinator = StraightCoordinator();

  await windowManager.ensureInitialized();
  await windowManager.setSize(const Size(1240, 760));
  await windowManager.setMinimumSize(const Size(860, 580));
  await windowManager.setResizable(true);
  await windowManager.center();
  if (!kDebugMode) {
    await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setSkipTaskbar(true);
    await windowManager.setPreventClose(true);
    windowManager.addListener(AppWindowListener());
  }

  runApp(const StraightApp());
  unawaited(coordinator.bootstrap());
}

class AppWindowListener with WindowListener {
  @override
  void onWindowClose() {
    windowManager.hide();
  }
}




