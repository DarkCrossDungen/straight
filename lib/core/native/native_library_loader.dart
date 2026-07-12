import 'dart:ffi';
import 'dart:io';

DynamicLibrary openNativeLibrary(String windowsName, String unixName) {
  final relativePath = Platform.isWindows
      ? 'native${Platform.pathSeparator}prebuilt${Platform.pathSeparator}$windowsName'
      : 'native${Platform.pathSeparator}prebuilt${Platform.pathSeparator}$unixName';

  final executableDir = File(Platform.resolvedExecutable).parent;
  final candidates = <String>[
    relativePath,
    '${Directory.current.path}${Platform.pathSeparator}$relativePath',
    '${executableDir.path}${Platform.pathSeparator}$relativePath',
  ];

  var dir = executableDir;
  for (var i = 0; i < 6; i++) {
    candidates.add('${dir.path}${Platform.pathSeparator}$relativePath');
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }

  for (final path in candidates) {
    if (File(path).existsSync()) {
      return DynamicLibrary.open(path);
    }
  }

  return DynamicLibrary.open(relativePath);
}
