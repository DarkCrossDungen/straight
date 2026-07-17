import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:straight/core/app_navigation.dart';
import 'package:straight/core/coordinator.dart';
import 'package:straight/core/storage/settings_store.dart';
import 'package:window_manager/window_manager.dart';

class DesktopBubbleService {
  DesktopBubbleService._();

  static final instance = DesktopBubbleService._();

  StraightCoordinator? _coordinator;
  ServerSocket? _server;
  Socket? _bubbleSocket;
  Timer? _startupDelay;
  bool _bubbleReady = false;

  Future<void> initialize({
    required StraightCoordinator coordinator,
    required bool launchedAtLogin,
  }) async {
    _coordinator = coordinator;
    coordinator.addListener(_syncDictationState);

    if (!SettingsStore.getDesktopBubbleEnabled()) return;
    if (launchedAtLogin) {
      _startupDelay = Timer(const Duration(minutes: 2), () {
        unawaited(show());
      });
    } else {
      await show();
    }
  }

  Future<void> setEnabled(bool enabled) async {
    await SettingsStore.setDesktopBubbleEnabled(enabled);
    if (enabled) {
      await show();
    } else {
      _startupDelay?.cancel();
      _startupDelay = null;
      _send('hide');
    }
  }

  Future<void> show() async {
    if (!SettingsStore.getDesktopBubbleEnabled()) return;
    if (_bubbleSocket != null) {
      _send('show');
      return;
    }

    await _ensureServer();
    await Process.start(
      Platform.resolvedExecutable,
      ['--bubble-window', '--bubble-port=${_server!.port}'],
      workingDirectory: File(Platform.resolvedExecutable).parent.path,
      mode: ProcessStartMode.detached,
    );
  }

  Future<void> _ensureServer() async {
    if (_server != null) return;
    _server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen(_acceptBubble);
  }

  void _acceptBubble(Socket socket) {
    _bubbleSocket?.destroy();
    _bubbleSocket = socket;
    _bubbleReady = false;
    socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) {
            final data = jsonDecode(line) as Map<String, dynamic>;
            switch (data['method'] as String?) {
              case 'bubble_ready':
                _bubbleReady = true;
                _sendSavedPosition();
                unawaited(_syncDictationState());
              case 'show_main':
                unawaited(_showMainWindow());
              case 'toggle_dictation':
                _coordinator?.toggleDictation();
              case 'show_settings':
                unawaited(_showSettings());
              case 'bubble_moved':
                final x = (data['x'] as num?)?.toDouble();
                final y = (data['y'] as num?)?.toDouble();
                if (x != null && y != null) {
                  unawaited(SettingsStore.setDesktopBubblePosition(x, y));
                }
            }
          },
          onDone: () {
            if (identical(_bubbleSocket, socket)) {
              _bubbleSocket = null;
              _bubbleReady = false;
            }
          },
          onError: (Object error) {
            debugPrint('Desktop bubble connection failed: $error');
          },
          cancelOnError: true,
        );
  }

  Future<void> _syncDictationState() async {
    if (!_bubbleReady || !SettingsStore.getDesktopBubbleEnabled()) return;
    final coordinator = _coordinator;
    if (coordinator == null) return;
    _send('state', {'value': coordinator.state.name});
    final fallback = coordinator.takeCopyFallbackText();
    if (fallback != null) _send('copy', {'text': fallback});
  }

  Future<void> _showMainWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> _showSettings() async {
    await _showMainWindow();
    appNavigatorKey.currentState?.pushNamed('/settings');
  }

  void _sendSavedPosition() {
    final position = SettingsStore.getDesktopBubblePosition();
    final x = position?['x'];
    final y = position?['y'];
    if (x is num && y is num) {
      _send('position', {'x': x.toDouble(), 'y': y.toDouble()});
    }
  }

  void _send(String method, [Map<String, dynamic>? arguments]) {
    if (!_bubbleReady && method != 'hide') return;
    try {
      _bubbleSocket?.write(
        '${jsonEncode({'method': method, ...?arguments})}\n',
      );
    } catch (error) {
      _bubbleReady = false;
      debugPrint('Desktop bubble command failed: $error');
    }
  }
}
