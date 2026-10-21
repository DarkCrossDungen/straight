import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/app_context.dart';
import 'core/coordinator.dart';
import 'app.dart';

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('FlutterError: ${details.exceptionAsString()}');
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('PlatformDispatcher uncaught error: $error\n$stack');
      return true; // Mark as handled so the Flutter engine does not exit
    };

    try {
      await Hive.initFlutter();
      await Hive.openBox('settings');
      await Hive.openBox('dictionary');
      await Hive.openBox('history');
      await Hive.openBox('snippets');
    } catch (e) {
      debugPrint('Hive initialization error: $e');
    }

    coordinator = StraightCoordinator();
    try {
      await coordinator.bootstrap();
    } catch (e) {
      debugPrint('Coordinator bootstrap warning: $e');
    }

    runApp(const StraightApp());
  }, (error, stack) {
    debugPrint('Global zone caught error: $error\n$stack');
  });
}

