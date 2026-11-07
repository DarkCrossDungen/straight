import 'dart:io';

Directory? _dataDir;

/// The directory Straight keeps its state in. `hive_flutter` resolves to
/// ~/Documents on Linux, so the Linux port picks the XDG data directory and
/// announces it during startup.
Directory get appDataDir => _dataDir ?? straightDataDir();

void useDataDir(Directory directory) => _dataDir = directory;

Directory straightDataDir() {
  final home = Platform.environment['HOME'] ?? Directory.systemTemp.path;
  final base = Platform.environment['XDG_DATA_HOME'] ?? '$home/.local/share';
  return Directory('$base${Platform.pathSeparator}straight');
}

/// Loopback port of the running instance, so an external shortcut can ask it
/// to start or stop dictation without owning a global key grab.
File get bubbleControlFile => File(
      '${appDataDir.path}${Platform.pathSeparator}bubble-control.port',
    );
