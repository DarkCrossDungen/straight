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
    size: _BubbleChrome.windowSize,
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
      await _placeAtBottomCenter(_BubbleChrome.windowSize);
      await windowManager.setOpacity(_BubbleChrome.compactOpacity);
      await windowManager.show();
    }),
  );
  runApp(_DesktopBubbleApp(port: port));
}

Future<void> _placeAtBottomCenter(Size size) async {
  final bounds = await _visibleBounds();
  await windowManager.setPosition(
    Offset(
      bounds.left + (bounds.width - size.width) / 2,
      bounds.bottom - size.height - _BubbleChrome.edgeGap,
    ),
  );
}

Future<Rect> _visibleBounds() async {
  final display = await screenRetriever.getPrimaryDisplay();
  final origin = display.visiblePosition ?? Offset.zero;
  final size = display.visibleSize ?? display.size;
  return origin & size;
}

enum _BubblePhase { idle, listening, processing, copyFallback }

class _BubbleChrome {
  // The native host stays at the largest visual size from startup. Windows
  // transparent popup windows can clip Flutter content when resized between a
  // small pill and a transcript card during dictation.
  static const windowSize = Size(420, 148);
  static const idleVisualSize = Size(44, 8);
  static const listeningVisualSize = Size(72, 30);
  static const processingVisualSize = Size(52, 9);
  static const edgeGap = 16.0;

  static const compactOpacity = 0.94;

  static const surface = Color(0xFF727272);
  static const activeSurface = Color(0xFF000000);
  static const copySurface = Color(0xFF000000);
  static const accent = Color(0xFFFF6C4C);
}

class _DesktopBubbleApp extends StatelessWidget {
  const _DesktopBubbleApp({required this.port});

  final int port;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: _BubbleChrome.accent),
        useMaterial3: true,
      ),
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
    with TickerProviderStateMixin {
  late final AnimationController _motion;
  late final AnimationController _copyCountdown;
  _BubblePhase _phase = _BubblePhase.idle;
  String? _copyText;
  Socket? _socket;
  double _speechLevel = 0;
  bool _copyConfirmed = false;
  bool _copyCollapsing = false;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1180),
    )..repeat();
    _copyCountdown =
        AnimationController(vsync: this, duration: const Duration(seconds: 8))
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              unawaited(_dismissCopy());
            }
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
              _setPhase(switch (value) {
                'listening' => _BubblePhase.listening,
                'processing' => _BubblePhase.processing,
                _ => _BubblePhase.idle,
              });
            case 'copy':
              final text = data['text'] as String?;
              if (text != null && text.trim().isNotEmpty) _showCopy(text);
            case 'level':
              final value = (data['value'] as num?)?.toDouble();
              if (value != null && mounted) {
                setState(() => _speechLevel = value.clamp(0, 1).toDouble());
              }
            case 'hide':
              unawaited(windowManager.hide());
            case 'show':
              _showIdle();
          }
        });
    _sendToMain('bubble_ready');
  }

  void _sendToMain(String method, [Map<String, dynamic>? arguments]) {
    _socket?.write('${jsonEncode({'method': method, ...?arguments})}\n');
  }

  void _setPhase(_BubblePhase phase) {
    if (!mounted) return;
    final wasCopyFallback = _phase == _BubblePhase.copyFallback;
    _copyCountdown.stop();
    setState(() {
      _phase = phase;
      _copyText = null;
      _copyConfirmed = false;
      _copyCollapsing = false;
      if (phase != _BubblePhase.listening) _speechLevel = 0;
    });
    if (wasCopyFallback && phase != _BubblePhase.copyFallback) {
      unawaited(_placeAtBottomCenter(_BubbleChrome.windowSize));
      unawaited(windowManager.setOpacity(_BubbleChrome.compactOpacity));
    } else if (phase != _BubblePhase.copyFallback) {
      unawaited(_keepAboveOtherWindows());
    }
  }

  void _showCopy(String text) {
    if (!mounted) return;
    setState(() {
      _phase = _BubblePhase.copyFallback;
      _copyText = text;
      _copyConfirmed = false;
      _copyCollapsing = false;
    });
    unawaited(_placeAtBottomCenter(_BubbleChrome.windowSize));
    unawaited(windowManager.setOpacity(1));
    unawaited(_keepAboveOtherWindows());
    _copyCountdown.forward(from: 0);
  }

  void _showIdle() => _setPhase(_BubblePhase.idle);

  Future<void> _keepAboveOtherWindows() async {
    await windowManager.setAlwaysOnTop(true);
    await windowManager.show();
  }

  Future<void> _toggleDictation() async {
    if (_phase != _BubblePhase.processing &&
        _phase != _BubblePhase.copyFallback) {
      _sendToMain('toggle_dictation');
    }
  }

  Future<void> _openSettings() async => _sendToMain('show_settings');

  Future<void> _copyAndDismiss() async {
    final text = _copyText;
    if (text == null || _copyCollapsing) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    setState(() => _copyConfirmed = true);
    await Future<void>.delayed(const Duration(milliseconds: 420));
    await _dismissCopy();
  }

  Future<void> _dismissCopy() async {
    if (!mounted || _phase != _BubblePhase.copyFallback || _copyCollapsing) {
      return;
    }
    _copyCountdown.stop();
    setState(() => _copyCollapsing = true);
    await Future<void>.delayed(const Duration(milliseconds: 320));
    if (mounted && _phase == _BubblePhase.copyFallback) _showIdle();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Align(
        alignment: Alignment.bottomCenter,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _toggleDictation,
          onSecondaryTap: _openSettings,
          child: AnimatedBuilder(
            animation: _motion,
            builder: (context, _) => switch (_phase) {
              _BubblePhase.idle => _idle(),
              _BubblePhase.listening => _listening(),
              _BubblePhase.processing => _processing(),
              _BubblePhase.copyFallback => _copyCard(),
            },
          ),
        ),
      ),
    );
  }

  Widget _pill({
    required Size size,
    required Widget child,
    Color surface = _BubbleChrome.surface,
  }) {
    return Container(
      width: size.width,
      height: size.height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(size.height),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _idle() {
    return _pill(
      size: _BubbleChrome.idleVisualSize,
      child: _wave(
        width: 27,
        height: 5,
        count: 7,
        range: 0.05,
        opacity: 0.72,
        mode: _WaveMode.idle,
      ),
    );
  }

  Widget _listening() {
    return _pill(
      size: _BubbleChrome.listeningVisualSize,
      surface: _BubbleChrome.activeSurface,
      child: _wave(
        width: 50,
        height: 13,
        count: 13,
        range: 0.78,
        speechLevel: _speechLevel,
        mode: _WaveMode.speech,
      ),
    );
  }

  Widget _processing() {
    return _pill(
      size: _BubbleChrome.processingVisualSize,
      child: _wave(
        width: 31,
        height: 5,
        count: 9,
        range: 0.04,
        opacity: 0.72,
        mode: _WaveMode.processing,
      ),
    );
  }

  Widget _wave({
    required double width,
    required double height,
    required int count,
    required double range,
    required _WaveMode mode,
    double opacity = 1,
    double speechLevel = 0,
  }) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: WaveformPainter(
          amplitudes: _amplitudes(count, range, mode, speechLevel),
          color: Colors.white.withValues(alpha: opacity),
        ),
      ),
    );
  }

  Widget _copyCard() {
    return AnimatedScale(
      scale: _copyCollapsing ? 0.11 : 1,
      alignment: Alignment.bottomCenter,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOutCubic,
      child: AnimatedOpacity(
        opacity: _copyCollapsing ? 0.18 : 1,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        child: Container(
          decoration: BoxDecoration(
            color: _BubbleChrome.copySurface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(18, 13, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.graphic_eq_rounded,
                    color: Colors.white70,
                    size: 16,
                  ),
                  const SizedBox(width: 9),
                  const Expanded(
                    child: Text(
                      'Select a text box first, then dictate',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.10),
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: _dismissCopy,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: Text(
                  _copyText ?? '',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFE3E3E3),
                    fontSize: 15,
                    height: 1.28,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomRight,
                child: TextButton.icon(
                  onPressed: _copyAndDismiss,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: const Color(0xFF949494),
                    minimumSize: const Size(64, 33),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    child: Icon(
                      _copyConfirmed ? Icons.check_rounded : Icons.copy_rounded,
                      key: ValueKey(_copyConfirmed),
                      size: 15,
                    ),
                  ),
                  label: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    child: Text(
                      _copyConfirmed ? 'Copied' : 'Copy',
                      key: ValueKey(_copyConfirmed),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<double> _amplitudes(
    int count,
    double range,
    _WaveMode mode,
    double speechLevel,
  ) {
    final t = _motion.value * math.pi * 2;
    return List<double>.generate(count, (index) {
      final centerBias = 1 - ((index - (count - 1) / 2).abs() / count);
      final organic =
          (math.sin(t * 0.9 + index * 0.52) + 1) * 0.28 +
          (math.sin(t * 1.6 + index * 0.23) + 1) * 0.16;
      return switch (mode) {
        _WaveMode.idle => 0.18 + math.sin(t + index * 0.42).abs() * range,
        _WaveMode.speech =>
          0.12 +
              organic *
                  range *
                  (0.2 + speechLevel * 1.05) *
                  (0.7 + centerBias * 0.56),
        _WaveMode.processing =>
          0.18 +
              math.sin(t * 0.8 + index * 0.35).abs() * range +
              centerBias * 0.06,
      };
    });
  }
}

enum _WaveMode { idle, speech, processing }
