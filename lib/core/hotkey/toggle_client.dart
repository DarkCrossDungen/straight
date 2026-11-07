import 'dart:convert';
import 'dart:io';

import '../app_paths.dart';

/// Asks a running Straight instance to start or stop dictation.
///
/// Wayland refuses global key grabs, so the shortcut is registered with the
/// desktop instead and this is what the desktop runs.
Future<bool> sendToggleRequest({bool startIfMissing = false}) async {
  if (await _send()) return true;
  if (!startIfMissing) return false;

  // The recorded port belongs to an instance that is gone, so the shortcut was
  // pressed with nothing listening. Start one and wait for it to announce.
  final file = bubbleControlFile;
  if (await file.exists()) await file.delete();
  if (!await _isInstanceRunning()) await _launchInstance();

  // A cold start has to load the speech model before it answers to anything,
  // so give it room rather than reporting a dead shortcut too early.
  for (var attempt = 0; attempt < 120; attempt++) {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (await _send()) return true;
  }
  return false;
}

Future<bool> _isInstanceRunning() async {
  if (!Platform.isLinux) return false;
  try {
    final result = await Process.run('pgrep', ['-x', 'straight']);
    if (result.exitCode != 0) return false;
    // This request itself runs as a `straight` process, so ignore its pid.
    final pids = (result.stdout as String)
        .split('\n')
        .map(int.tryParse)
        .whereType<int>()
        .where((p) => p != pid);
    return pids.isNotEmpty;
  } catch (_) {
    return false;
  }
}

/// Whether another Straight main process is already alive. Used at login to
/// avoid starting a second instance when one is already listening.
Future<bool> isInstanceRunning() => _isInstanceRunning();

/// Brings the running instance's window up instead of starting a second one
/// (which would crash on the Hive lock). When the other instance is still
/// booting, waits for its control port rather than racing it.
Future<bool> showRunningInstance() async {
  if (await _send('show_main')) return true;
  if (!await _isInstanceRunning()) {
    // The port file can only outlive a dead instance; a live one always
    // answers or is still booting.
    final file = bubbleControlFile;
    if (await file.exists()) await file.delete();
    return false;
  }
  for (var attempt = 0; attempt < 40; attempt++) {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (await _send('show_main')) return true;
    if (!await _isInstanceRunning()) return false;
  }
  return false;
}

Future<void> _launchInstance() async {
  try {
    await Process.start(
      Platform.resolvedExecutable,
      const <String>[],
      workingDirectory: File(Platform.resolvedExecutable).parent.path,
      mode: ProcessStartMode.detached,
    );
  } catch (_) {
    // Reported by the caller as an undelivered request.
  }
}

Future<bool> _send([String method = 'toggle_dictation']) async {
  final file = bubbleControlFile;
  if (!await file.exists()) return false;

  final port = int.tryParse((await file.readAsString()).trim());
  if (port == null) return false;

  Socket? socket;
  try {
    socket = await Socket.connect(
      InternetAddress.loopbackIPv4,
      port,
      timeout: const Duration(seconds: 2),
    );
    socket.write('${jsonEncode({'method': method})}\n');
    await socket.flush();
    // Let the request reach the coordinator before the connection drops.
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return true;
  } catch (_) {
    return false;
  } finally {
    socket?.destroy();
  }
}
