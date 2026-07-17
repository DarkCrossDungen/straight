import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:straight/features/bubble/waveform_painter.dart';
import 'package:window_manager/window_manager.dart';

Future<void> runDesktopBubble(int port) async {
  await windowManager.ensureInitialized();
  const options = WindowOptions(
    size: Size(58, 24),
    backgroundColor: Colors.transparent,
    skipTaskbar: true,
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: false,
  );
  unawaited(
    windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.setAlwaysOnTop(true);
      await windowManager.setResizable(false);
      await windowManager.setPreventClose(true);
      await _placeAtBottomCenter(const Size(58, 24));
      await windowManager.setOpacity(0.58);
      await windowManager.show();
    }),
  );
  runApp(_DesktopBubbleApp(port: port));
}

Future<void> _placeAtBottomCenter(Size size) async {
  final display = await screenRetriever.getPrimaryDisplay();
  final origin = display.visiblePosition ?? Offset.zero;
  final visibleSize = display.visibleSize ?? display.size;
  await windowManager.setPosition(
    Offset(
      origin.dx + (visibleSize.width - size.width) / 2,
      origin.dy + visibleSize.height - size.height - 16,
    ),
  );
}

enum _BubblePhase { idle, listening, processing, copy }

class _DesktopBubbleApp extends StatelessWidget {
  const _DesktopBubbleApp({required this.port});

  final int port;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: _DesktopBubble(port: port),
    );
  }
}

class _DesktopBubble extends StatefulWidget {
  const _DesktopBubble({required this.port});

  final int port;

  @override
  State<_DesktopBubble> createState() => _DesktopBubbleState();
}

class _DesktopBubbleState extends State<_DesktopBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion;
  late final AnimationController _copyCountdown;
  _BubblePhase _phase = _BubblePhase.idle;
  String? _copyText;
  Socket? _socket;
  bool _hovering = false;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1450),
    )..repeat();
    _copyCountdown =
        AnimationController(vsync: this, duration: const Duration(seconds: 6))
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) unawaited(_showIdle());
          });
    unawaited(_registerCommands());
  }

  @override
  void dispose() {
    _motion.dispose();
    _copyCountdown.dispose();
    _socket?.destroy();
    super.dispose();
  }

  Future<void> _registerCommands() async {
    final socket = await Socket.connect(
      InternetAddress.loopbackIPv4,
      widget.port,
    );
    _socket = socket;
    socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          final data = jsonDecode(line) as Map<String, dynamic>;
          switch (data['method'] as String?) {
            case 'state':
              final value = data['value'] as String? ?? 'idle';
              unawaited(
                _setPhase(switch (value) {
                  'listening' => _BubblePhase.listening,
                  'processing' => _BubblePhase.processing,
                  _ => _BubblePhase.idle,
                }),
              );
            case 'copy':
              final text = data['text'] as String?;
              if (text != null && text.trim().isNotEmpty) {
                unawaited(_showCopy(text));
              }
            case 'hide':
              unawaited(windowManager.hide());
            case 'show':
              unawaited(_showIdle());
            case 'position':
              final x = (data['x'] as num?)?.toDouble();
              final y = (data['y'] as num?)?.toDouble();
              if (x != null && y != null) {
                unawaited(windowManager.setPosition(Offset(x, y)));
              }
          }
        });
    _sendToMain('bubble_ready');
  }

  void _sendToMain(String method, [Map<String, dynamic>? arguments]) {
    _socket?.write('${jsonEncode({'method': method, ...?arguments})}\n');
  }

  Future<void> _setPhase(_BubblePhase phase) async {
    if (!mounted) return;
    _copyCountdown.stop();
    setState(() {
      _phase = phase;
      _copyText = null;
    });
    await _applyFrame();
  }

  Future<void> _showCopy(String text) async {
    if (!mounted) return;
    setState(() {
      _phase = _BubblePhase.copy;
      _copyText = text;
    });
    await _applyFrame();
    _copyCountdown.forward(from: 0);
  }

  Future<void> _showIdle() => _setPhase(_BubblePhase.idle);

  Future<void> _applyFrame() async {
    final size = switch (_phase) {
      _BubblePhase.idle => const Size(58, 24),
      _BubblePhase.listening => const Size(58, 24),
      _BubblePhase.processing => const Size(58, 24),
      _BubblePhase.copy => const Size(304, 118),
    };
    final oldSize = await windowManager.getSize();
    final oldPosition = await windowManager.getPosition();
    await windowManager.setSize(size);
    await windowManager.setPosition(
      Offset(
        oldPosition.dx + (oldSize.width - size.width) / 2,
        oldPosition.dy + oldSize.height - size.height,
      ),
    );
    await _applyOpacity();
    await windowManager.show();
  }

  Future<void> _toggleDictation() async {
    if (_phase != _BubblePhase.processing && _phase != _BubblePhase.copy) {
      _sendToMain('toggle_dictation');
    }
  }

  Future<void> _openSettings() async => _sendToMain('show_settings');

  Future<void> _rememberPosition() async {
    final position = await windowManager.getPosition();
    _sendToMain('bubble_moved', {'x': position.dx, 'y': position.dy});
  }

  Future<void> _applyOpacity() => windowManager.setOpacity(switch (_phase) {
    _BubblePhase.idle => _hovering ? 0.86 : 0.58,
    _BubblePhase.listening => 0.98,
    _BubblePhase.processing => 0.88,
    _BubblePhase.copy => 0.98,
  });

  Future<void> _copyAndDismiss() async {
    final text = _copyText;
    if (text == null) return;
    await Clipboard.setData(ClipboardData(text: text));
    await _showIdle();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: MouseRegion(
        onEnter: (_) {
          _hovering = true;
          unawaited(_applyOpacity());
        },
        onExit: (_) {
          _hovering = false;
          unawaited(_applyOpacity());
        },
        child: GestureDetector(
          onTap: _toggleDictation,
          onSecondaryTap: _openSettings,
          onPanStart: (_) => unawaited(windowManager.startDragging()),
          onPanEnd: (_) => unawaited(_rememberPosition()),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF050505),
              borderRadius: BorderRadius.circular(
                _phase == _BubblePhase.copy ? 14 : 999,
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            child: switch (_phase) {
              _BubblePhase.idle => _idle(),
              _BubblePhase.listening => _listening(),
              _BubblePhase.processing => _processing(),
              _BubblePhase.copy => _copyCard(),
            },
          ),
        ),
      ),
    );
  }

  Widget _idle() {
    return Center(
      child: SizedBox(
        width: 26,
        height: 9,
        child: AnimatedBuilder(
          animation: _motion,
          builder: (context, _) => CustomPaint(
            painter: WaveformPainter(
              amplitudes: _amplitudes(11, 0.16),
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _listening() {
    return Center(
      child: AnimatedBuilder(
        animation: _motion,
        builder: (context, _) => SizedBox(
          width: 40,
          height: 13,
          child: CustomPaint(
            painter: WaveformPainter(
              amplitudes: _amplitudes(17, 0.72),
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _processing() {
    return Center(
      child: AnimatedBuilder(
        animation: _motion,
        builder: (context, _) => SizedBox(
          width: 42,
          height: 8,
          child: CustomPaint(
            painter: WaveformPainter(
              amplitudes: _amplitudes(13, 0.10),
              color: Colors.white70,
            ),
          ),
        ),
      ),
    );
  }

  Widget _copyCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.graphic_eq_rounded,
                color: Colors.white70,
                size: 15,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Copy transcription',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ),
              AnimatedBuilder(
                animation: _copyCountdown,
                builder: (context, _) => SizedBox(
                  width: 22,
                  height: 22,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: 1 - _copyCountdown.value,
                        color: Colors.white54,
                        backgroundColor: Colors.white12,
                        strokeWidth: 2,
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 13,
                        ),
                        padding: EdgeInsets.zero,
                        onPressed: _showIdle,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              _copyText ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                height: 1.25,
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: TextButton.icon(
              onPressed: _copyAndDismiss,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF11110F),
                backgroundColor: Colors.white,
                minimumSize: const Size(0, 28),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              icon: const Icon(Icons.copy_rounded, size: 13),
              label: const Text('Copy', style: TextStyle(fontSize: 11)),
            ),
          ),
        ],
      ),
    );
  }

  List<double> _amplitudes(int count, double range) => List<double>.generate(
    count,
    (index) =>
        0.18 +
        math.sin(_motion.value * math.pi * 2 + index * 0.62).abs() * range,
  );
}
