import 'dart:io';

import 'package:hive/hive.dart';

/// Prints the raw settings box so setup state can be verified without the UI.
Future<void> main() async {
  Hive.init('/home/dark/.local/share/straight');
  final box = await Hive.openBox('settings');
  for (final key in box.keys) {
    stdout.writeln('$key => ${box.get(key)}');
  }
  await box.close();
}
