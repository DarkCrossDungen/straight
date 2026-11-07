// ignore_for_file: avoid_print

import 'package:straight/core/injection/atspi_text_injector.dart';

Future<void> main() async {
  final injector = AtspiTextInjector();
  injector.captureFocus();
  print('focused app: "${injector.targetApp}"');
  final ok = injector.inject(' typed by the AT-SPI injector');
  print('inject returned: $ok');
}
