import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
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
  await coordinator.bootstrap();

  runApp(const StraightApp());
}

