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

  try {
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      size: Size(1240, 760),
      minimumSize: Size(860, 580),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  } catch (e) {
    debugPrint('window_manager init warning: $e');
  }

  await coordinator.bootstrap();

  runApp(const StraightApp());
}

class AppWindowListener with WindowListener {
  @override
  void onWindowClose() {
    windowManager.hide();
  }
}
