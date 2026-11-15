import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../app_paths.dart';

class PythonTextOrganizer {
  static const _assetPath = 'tool/text_organizer.py';
  static const _timeout = Duration(seconds: 5);

  Future<File>? _scriptFile;

  Future<String> organize(String text) async {
    try {
      final script = await (_scriptFile ??= _extractScript());
      final commands = Platform.isWindows
          ? <(String, List<String>)>[
              ('python', const []),
              ('py', const ['-3']),
            ]
          : <(String, List<String>)>[
              ('python3', const []),
              ('python', const []),
            ];
      for (final (executable, prefixArgs) in commands) {
        try {
          final process = await Process.start(
            executable,
            [...prefixArgs, script.path, '--level', 'medium'],
          ).timeout(_timeout);
          final stdoutFuture = process.stdout.transform(utf8.decoder).join();
          final stderrFuture = process.stderr.transform(utf8.decoder).join();
          process.stdin.write(text);
          await process.stdin.close();
          final exitCode = await process.exitCode.timeout(_timeout);
          if (exitCode != 0) {
            debugPrint('Python text organizer failed: ${await stderrFuture}');
            continue;
          }

          final output = await stdoutFuture;
          return output.replaceFirst(RegExp(r'\r?\n$'), '');
        } on ProcessException {
          continue;
        }
      }
      return text;
    } catch (error) {
      debugPrint('Python text organizer unavailable: $error');
      return text;
    }
  }

  Future<File> _extractScript() async {
    final directory = Directory('${appDataDir.path}${Platform.pathSeparator}tools');
    await directory.create(recursive: true);
    final script = File('${directory.path}${Platform.pathSeparator}text_organizer.py');
    final bytes = await rootBundle.load(_assetPath);
    await script.writeAsBytes(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      flush: true,
    );
    return script;
  }
}
