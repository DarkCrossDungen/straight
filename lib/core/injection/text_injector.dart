import 'dart:io';

import 'atspi_text_injector.dart';
import 'text_injector_platform.dart';
import 'win_text_injector.dart';

class TextInjector {
  TextInjector()
      : _impl = Platform.isLinux ? AtspiTextInjector() : WinTextInjector();

  final TextInjectorPlatform _impl;

  void captureFocus() => _impl.captureFocus();

  bool inject(String text) => _impl.inject(text);
}
