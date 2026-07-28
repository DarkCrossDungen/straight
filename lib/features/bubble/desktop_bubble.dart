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
    size: _BubbleChrome.idleSize,
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
      await _placeAtBottomCenter(_BubbleChrome.idleSize);
      await windowManager.setOpacity(_BubbleChrome.idleOpacity);
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

enum _BubblePhase { idle, ready, listening, processing, copyFallback }

enum _DockSide { bottom, left, right }

class _BubbleChrome {
  // The idle state is intentionally just a quiet companion, not a mini UI.
  static const idleSize = Size(50, 24);
  static const readySize = Size(78, 30);
  static const listeningSize = Size(110, 36);
  static const processingSize = Size(90, 30);
  static const copySize = Size(356, 116);
  static const edgeGap = 16.0;
  static const dockSnap = 44.0;

  static const idleOpacity = 0.46;
  static const readyOpacity = 1.0;
  static const listeningOpacity = 1.0;
  static const processingOpacity = 0.98;
  static const copyOpacity = 0.98;

  static const black = Color(0xFF050505);
  static const coral = Color(0xFFFF6C4C);
}

class _DesktopBubbleApp extends StatelessWidget {
  const _DesktopBubbleApp({required this.port});

  final int port;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: _BubbleChrome.coral),
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
  _DockSide _dockSide = _DockSide.bottom;
  String? _copyText;
  Socket? _socket;
  Timer? _frameDebounce;
  int _frameToken = 0;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1180),
    )..repeat();
    _copyCountdown =
        AnimationController(vsync: this, duration: const Duration(seconds: 6))
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) _showIdle();
          });
    unawaited(_registerCommands());
  }

  @override
  void dispose() {
    _frameDebounce?.cancel();
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
            case 'hide':
              unawaited(windowManager.hide());
            case 'show':
              _showIdle();
            case 'position':
              final x = (data['x'] as num?)?.toDouble();
              final y = (data['y'] as num?)?.toDouble();
              if (x != null && y != null) unawaited(_restorePosition(x, y));
          }
        });
    _sendToMain('bubble_ready');
  }

  void _sendToMain(String method, [Map<String, dynamic>? arguments]) {
    _socket?.write('${jsonEncode({'method': method, ...?arguments})}\n');
  }

  void _setPhase(_BubblePhase phase) {
    if (!mounted) return;
    _copyCountdown.stop();
    setState(() {
      _phase = phase;
      _copyText = null;
    });
    _scheduleFrame();
  }

  void _showCopy(String text) {
    if (!mounted) return;
    setState(() {
      _phase = _BubblePhase.copyFallback;
      _dockSide = _DockSide.bottom;
      _copyText = text;
    });
    _scheduleFrame();
    unawaited(_placeAtBottomCenter(_BubbleChrome.copySize));
    _copyCountdown.forward(from: 0);
  }

  void _showIdle() => _setPhase(_BubblePhase.idle);

  void _setHovering(bool hovering) {
    if (_phase != _BubblePhase.idle && _phase != _BubblePhase.ready) return;
    setState(() {
      _phase = hovering ? _BubblePhase.ready : _BubblePhase.idle;
    });
    _scheduleFrame();
  }

  void _scheduleFrame() {
    _frameDebounce?.cancel();
    _frameDebounce = Timer(
      const Duration(milliseconds: 12),
      () => unawaited(_applyFrame()),
    );
  }

  Future<void> _applyFrame() async {
    final token = ++_frameToken;
    final targetSize = _orientedSize(_targetBaseSize);
    final oldSize = await windowManager.getSize();
    final oldPosition = await windowManager.getPosition();
    final targetPosition = await _anchoredPosition(
      oldPosition,
      oldSize,
      targetSize,
    );

    await windowManager.setOpacity(_targetOpacity);
    if (!_shouldAnimate(oldSize, targetSize)) {
      await windowManager.setSize(targetSize);
      await windowManager.setPosition(targetPosition);
      await windowManager.show();
      return;
    }

    const frames = 7;
    for (var frame = 1; frame <= frames; frame++) {
      if (token != _frameToken) return;
      final t = Curves.easeOutCubic.transform(frame / frames);
      final size = Size(
        _lerp(oldSize.width, targetSize.width, t),
        _lerp(oldSize.height, targetSize.height, t),
      );
      await windowManager.setSize(size);
      await windowManager.setPosition(
        Offset(
          _lerp(oldPosition.dx, targetPosition.dx, t),
          _lerp(oldPosition.dy, targetPosition.dy, t),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 14));
    }
    await windowManager.show();
  }

  bool _shouldAnimate(Size oldSize, Size targetSize) {
    final delta =
        (oldSize.width - targetSize.width).abs() +
        (oldSize.height - targetSize.height).abs();
    return delta > 3;
  }

  Future<Offset> _anchoredPosition(
    Offset oldPosition,
    Size oldSize,
    Size targetSize,
  ) async {
    final raw = switch (_dockSide) {
      _DockSide.bottom => Offset(
        oldPosition.dx + (oldSize.width - targetSize.width) / 2,
        oldPosition.dy + oldSize.height - targetSize.height,
      ),
      _DockSide.left => Offset(
        oldPosition.dx,
        oldPosition.dy + (oldSize.height - targetSize.height) / 2,
      ),
      _DockSide.right => Offset(
        oldPosition.dx + oldSize.width - targetSize.width,
        oldPosition.dy + (oldSize.height - targetSize.height) / 2,
      ),
    };
    return _clampPosition(raw, targetSize);
  }

  Future<Offset> _clampPosition(Offset position, Size size) async {
    final bounds = await _visibleBounds();
    final x = position.dx.clamp(bounds.left, bounds.right - size.width);
    final y = position.dy.clamp(bounds.top, bounds.bottom - size.height);
    return Offset(x.toDouble(), y.toDouble());
  }

  Future<void> _restorePosition(double x, double y) async {
    final size = await windowManager.getSize();
    final position = await _clampPosition(Offset(x, y), size);
    _dockSide = await _nearestDock(position, size);
    await windowManager.setPosition(position);
    _scheduleFrame();
  }

  Future<void> _snapAndRememberPosition() async {
    final size = await windowManager.getSize();
    final position = await windowManager.getPosition();
    final bounds = await _visibleBounds();
    final dock = await _nearestDock(position, size);
    final snapped = switch (dock) {
      _DockSide.left => Offset(
        bounds.left + _BubbleChrome.edgeGap,
        position.dy
            .clamp(
              bounds.top + _BubbleChrome.edgeGap,
              bounds.bottom - size.height - _BubbleChrome.edgeGap,
            )
            .toDouble(),
      ),
      _DockSide.right => Offset(
        bounds.right - size.width - _BubbleChrome.edgeGap,
        position.dy
            .clamp(
              bounds.top + _BubbleChrome.edgeGap,
              bounds.bottom - size.height - _BubbleChrome.edgeGap,
            )
            .toDouble(),
      ),
      _DockSide.bottom => Offset(
        position.dx
            .clamp(
              bounds.left + _BubbleChrome.edgeGap,
              bounds.right - size.width - _BubbleChrome.edgeGap,
            )
            .toDouble(),
        bounds.bottom - size.height - _BubbleChrome.edgeGap,
      ),
    };
    setState(() => _dockSide = dock);
    await windowManager.setPosition(snapped);
    _sendToMain('bubble_moved', {'x': snapped.dx, 'y': snapped.dy});
    _scheduleFrame();
  }

  Future<_DockSide> _nearestDock(Offset position, Size size) async {
    final bounds = await _visibleBounds();
    final leftDistance = (position.dx - bounds.left).abs();
    final rightDistance = (bounds.right - position.dx - size.width).abs();
    final bottomDistance = (bounds.bottom - position.dy - size.height).abs();

    if (leftDistance <= _BubbleChrome.dockSnap &&
        leftDistance <= rightDistance) {
      return _DockSide.left;
    }
    if (rightDistance <= _BubbleChrome.dockSnap) return _DockSide.right;
    if (bottomDistance <= _BubbleChrome.dockSnap * 1.4) {
      return _DockSide.bottom;
    }
    return _DockSide.bottom;
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
    if (text == null) return;
    await Clipboard.setData(ClipboardData(text: text));
    _showIdle();
  }

  Size get _targetBaseSize => switch (_phase) {
    _BubblePhase.idle => _BubbleChrome.idleSize,
    _BubblePhase.ready => _BubbleChrome.readySize,
    _BubblePhase.listening => _BubbleChrome.listeningSize,
    _BubblePhase.processing => _BubbleChrome.processingSize,
    _BubblePhase.copyFallback => _BubbleChrome.copySize,
  };

  double get _targetOpacity => switch (_phase) {
    _BubblePhase.idle => _BubbleChrome.idleOpacity,
    _BubblePhase.ready => _BubbleChrome.readyOpacity,
    _BubblePhase.listening => _BubbleChrome.listeningOpacity,
    _BubblePhase.processing => _BubbleChrome.processingOpacity,
    _BubblePhase.copyFallback => _BubbleChrome.copyOpacity,
  };

  Size _orientedSize(Size size) {
    if (_phase == _BubblePhase.copyFallback || _dockSide == _DockSide.bottom) {
      return size;
    }
    return Size(size.height, size.width);
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  bool get _isSideDocked =>
      _dockSide == _DockSide.left || _dockSide == _DockSide.right;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: MouseRegion(
        onEnter: (_) => _setHovering(true),
        onExit: (_) => _setHovering(false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleDictation,
          onSecondaryTap: _openSettings,
          onPanStart: (_) => unawaited(windowManager.startDragging()),
          onPanEnd: (_) => unawaited(_snapAndRememberPosition()),
          child: AnimatedBuilder(
            animation: _motion,
            builder: (context, _) {
              final child = DecoratedBox(
                decoration: _decoration,
                child: switch (_phase) {
                  _BubblePhase.idle => _idle(),
                  _BubblePhase.ready => _ready(),
                  _BubblePhase.listening => _listening(),
                  _BubblePhase.processing => _processing(),
                  _BubblePhase.copyFallback => _copyCard(),
                },
              );
              if (!_isSideDocked || _phase == _BubblePhase.copyFallback) {
                return child;
              }
              return RotatedBox(
                quarterTurns: _dockSide == _DockSide.left ? 3 : 1,
                child: child,
              );
            },
          ),
        ),
      ),
    );
  }

  BoxDecoration get _decoration {
    final copy = _phase == _BubblePhase.copyFallback;
    return BoxDecoration(
      color: _BubbleChrome.black,
      borderRadius: BorderRadius.circular(copy ? 16 : 999),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: copy ? 0.34 : 0.14),
          blurRadius: copy ? 28 : 10,
          offset: Offset(0, copy ? 12 : 4),
        ),
      ],
    );
  }

  Widget _idle() {
    return Center(
      child: _wave(
        width: 25,
        height: 8,
        count: 7,
        range: 0.05,
        opacity: 0.72 + _pulse(0.08),
        mode: _WaveMode.idle,
      ),
    );
  }

  Widget _ready() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.mic_none_rounded, color: Colors.white, size: 14),
        const SizedBox(width: 7),
        _wave(
          width: 26,
          height: 10,
          count: 7,
          range: 0.16,
          opacity: 0.92,
          mode: _WaveMode.idle,
        ),
      ],
    );
  }

  Widget _listening() {
    return Stack(
      alignment: Alignment.center,
      children: [
        _wave(
          width: 70,
          height: 18,
          count: 17,
          range: 0.84,
          mode: _WaveMode.speech,
        ),
      ],
    );
  }

  Widget _processing() {
    return Stack(
      alignment: Alignment.center,
      children: [
        _wave(
          width: 50,
          height: 8,
          count: 13,
          range: 0.04,
          opacity: 0.72,
          mode: _WaveMode.processing,
        ),
        Positioned(
          right: 12,
          child: CustomPaint(
            size: const Size.square(7),
            painter: _ProcessingDotPainter(
              progress: _motion.value,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _wave({
    required double width,
    required double height,
    required int count,
    required double range,
    required _WaveMode mode,
    double opacity = 1,
  }) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: WaveformPainter(
          amplitudes: _amplitudes(count, range, mode),
          color: Colors.white.withValues(alpha: opacity),
        ),
      ),
    );
  }

  Widget _copyCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.mic_none_rounded,
                color: Colors.white70,
                size: 14,
              ),
              const SizedBox(width: 7),
              const Expanded(
                child: Text(
                  'Transcription ready',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
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
                        color: Colors.white60,
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
          const SizedBox(height: 7),
          Expanded(
            child: Text(
              _copyText ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                height: 1.3,
                fontWeight: FontWeight.w500,
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
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.copy_rounded, size: 13),
              label: const Text(
                'Copy',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _pulse(double amount) =>
      math.sin(_motion.value * math.pi * 2).abs() * amount;

  List<double> _amplitudes(int count, double range, _WaveMode mode) {
    final t = _motion.value * math.pi * 2;
    return List<double>.generate(count, (index) {
      final centerBias = 1 - ((index - (count - 1) / 2).abs() / count);
      final organic =
          (math.sin(t * 0.9 + index * 0.52) + 1) * 0.28 +
          (math.sin(t * 1.6 + index * 0.23) + 1) * 0.16;
      return switch (mode) {
        _WaveMode.idle => 0.18 + math.sin(t + index * 0.42).abs() * range,
        _WaveMode.speech => 0.14 + organic * range * (0.7 + centerBias * 0.56),
        _WaveMode.processing =>
          0.18 +
              math.sin(t * 0.8 + index * 0.35).abs() * range +
              centerBias * 0.06,
      };
    });
  }
}

enum _WaveMode { idle, speech, processing }

class _ProcessingDotPainter extends CustomPainter {
  const _ProcessingDotPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final pulse = math.sin(progress * math.pi * 2).abs();
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(
      center,
      2 + pulse * 1.2,
      Paint()..color = color.withValues(alpha: 0.42 + pulse * 0.36),
    );
    canvas.drawCircle(
      center,
      size.width / 2 - 0.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = color.withValues(alpha: 0.16 + pulse * 0.2),
    );
  }

  @override
  bool shouldRepaint(covariant _ProcessingDotPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
