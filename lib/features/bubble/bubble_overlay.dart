import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:straight/core/app_context.dart';
import 'package:straight/core/coordinator.dart';
import 'package:straight/features/bubble/waveform_painter.dart';
import 'package:straight/shared/theme/colors.dart';
import 'package:straight/shared/widgets/app_drawer.dart';
import 'package:straight/shared/widgets/app_surface.dart';
import 'package:straight/shared/widgets/background_shapes.dart';

class BubbleOverlay extends StatefulWidget {
  const BubbleOverlay({super.key});

  @override
  State<BubbleOverlay> createState() => _BubbleOverlayState();
}

class _BubbleOverlayState extends State<BubbleOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    coordinator.addListener(_syncState);
    _syncState();
  }

  @override
  void dispose() {
    coordinator.removeListener(_syncState);
    _motion.dispose();
    super.dispose();
  }

  void _syncState() {
    if (coordinator.state == DictationState.listening) {
      if (!_motion.isAnimating) _motion.repeat();
    } else {
      _motion.stop();
      _motion.reset();
    }
    if (mounted) setState(() {});
  }

  void _toggleDictation() => coordinator.toggleDictation();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      drawer: const AppDrawer(),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 980;
            return Padding(
              padding: EdgeInsets.all(isWide ? 18 : 14),
              child: isWide ? _desktop(scheme) : _stacked(scheme),
            );
          },
        ),
      ),
    );
  }

  Widget _desktop(ColorScheme scheme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: 232, child: _rail(scheme)),
        const SizedBox(width: 18),
        Expanded(child: _voiceStage(scheme)),
        const SizedBox(width: 18),
        SizedBox(width: 300, child: _statusPanel(scheme)),
      ],
    );
  }

  Widget _stacked(ColorScheme scheme) {
    return Column(
      children: [
        _mobileBar(scheme),
        const SizedBox(height: 14),
        Expanded(child: _voiceStage(scheme)),
        const SizedBox(height: 14),
        _statusPanel(scheme),
      ],
    );
  }

  Widget _mobileBar(ColorScheme scheme) {
    return Row(
      children: [
        AppIconButton(
          icon: Icons.menu,
          tooltip: 'Open navigation',
          onPressed: () => Scaffold.maybeOf(context)?.openDrawer(),
        ),
        const SizedBox(width: 12),
        Expanded(child: _brandBlock(scheme)),
        AppBadge(
          label: _stateLabel(),
          color: _stateColor(scheme),
          foregroundColor: _stateFg(scheme),
        ),
      ],
    );
  }

  Widget _rail(ColorScheme scheme) {
    return AppSurface(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkBg
          : AppColors.lightMuted,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _brandBlock(scheme),
          const SizedBox(height: 22),
          AppBadge(
            label: _stateLabel(),
            color: _stateColor(scheme),
            foregroundColor: _stateFg(scheme),
          ),
          const SizedBox(height: 22),
          _navTile(Icons.graphic_eq, 'Dictation', null),
          _navTile(
            Icons.tune,
            'Settings',
            () => Navigator.pushNamed(context, '/settings'),
          ),
          _navTile(
            Icons.spellcheck,
            'Dictionary',
            () => Navigator.pushNamed(context, '/dictionary'),
          ),
          _navTile(
            Icons.schedule,
            'History',
            () => Navigator.pushNamed(context, '/history'),
          ),
          const Spacer(),
          _miniMetric('Model', _friendlyModel(coordinator.selectedSttModel)),
          const SizedBox(height: 10),
          _miniMetric('Hotkey', _hotkeyLabel()),
        ],
      ),
    );
  }

  Widget _voiceStage(ColorScheme scheme) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stageColor = coordinator.state == DictationState.listening
        ? scheme.primary
        : (isDark ? AppColors.accentDark : AppColors.accentLight);
    const stageInk = AppColors.darkFg;
    return AppSurface(
      padding: EdgeInsets.zero,
      shadowColor: scheme.primary,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(decoration: BoxDecoration(color: stageColor)),
          BackgroundShapes(
            color: stageInk,
            blockColor: stageInk.withValues(alpha: 0.16),
            opacity: Theme.of(context).brightness == Brightness.dark
                ? 0.88
                : 0.95,
            cellSize: 22,
            strokeWidth: 2,
          ),
          Positioned.fill(
            child: _SpeechRibbon(
              motion: _motion,
              foregroundColor: stageInk,
              shadowColor: scheme.onSurface,
              textColor: stageInk,
              mutedTextColor: stageInk.withValues(alpha: 0.58),
              active: coordinator.state == DictationState.listening,
            ),
          ),
          Container(color: stageColor.withValues(alpha: 0.05)),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AppBadge(label: 'Voice', color: scheme.secondary),
                    const SizedBox(width: 8),
                    AppBadge(
                      label: _friendlyCleanup(coordinator.selectedLlmModel),
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.darkBg
                          : AppColors.lightCard,
                      foregroundColor: scheme.onSurface,
                    ),
                  ],
                ),
                const Spacer(),
                Center(child: _voiceControl(scheme)),
                const Spacer(),
                _stageFooter(scheme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _voiceControl(ColorScheme scheme) {
    final listening = coordinator.state == DictationState.listening;
    final processing = coordinator.state == DictationState.processing;
    return GestureDetector(
      onTap: _toggleDictation,
      child: AnimatedBuilder(
        animation: _motion,
        builder: (context, _) {
          final pulse = listening
              ? 1 + math.sin(_motion.value * math.pi * 2) * 0.035
              : 1.0;
          return Transform.scale(
            scale: pulse,
            child: SizedBox(
              width: 260,
              height: 260,
              child: CustomPaint(
                painter: _VoiceRingPainter(
                  progress: _motion.value,
                  active: listening,
                  color: scheme.onPrimary,
                  mutedColor: scheme.onPrimary.withValues(alpha: 0.28),
                ),
                child: Center(
                  child: Container(
                    width: 156,
                    height: 156,
                    decoration: BoxDecoration(
                      color: processing ? scheme.secondary : scheme.surface,
                      border: Border.all(color: scheme.onSurface, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: scheme.onSurface,
                          offset: const Offset(4, 4),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: processing
                        ? Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: AppColors.lightFg,
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                listening ? Icons.stop : Icons.mic,
                                size: 40,
                                color: listening
                                    ? scheme.primary
                                    : scheme.onSurface,
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: 94,
                                height: 34,
                                child: CustomPaint(
                                  painter: WaveformPainter(
                                    amplitudes: _amplitudes(listening),
                                    color: listening
                                        ? scheme.primary
                                        : scheme.onSurface.withValues(
                                            alpha: 0.55,
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _stageFooter(ColorScheme scheme) {
    return Row(
      children: [
        Expanded(
          child: Text(
            _headline(),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: AppColors.darkFg,
              fontSize: 26,
            ),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: _toggleDictation,
          icon: Icon(
            coordinator.state == DictationState.listening
                ? Icons.stop
                : Icons.play_arrow,
            size: 18,
          ),
          label: Text(
            coordinator.state == DictationState.listening ? 'STOP' : 'START',
          ),
        ),
      ],
    );
  }

  Widget _statusPanel(ColorScheme scheme) {
    return AppSurface(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppSectionLabel('Run State'),
          const SizedBox(height: 12),
          _statusRow('Status', coordinator.statusMessage),
          _statusRow('Speech', _friendlyModel(coordinator.selectedSttModel)),
          _statusRow('Cleanup', _friendlyCleanup(coordinator.selectedLlmModel)),
          _statusRow('Hotkey', _hotkeyLabel()),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/dictionary'),
                  icon: const Icon(Icons.spellcheck, size: 17),
                  label: const Text('WORDS'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/history'),
                  icon: const Icon(Icons.schedule, size: 17),
                  label: const Text('LOG'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: coordinator.refreshSpeechModel,
              icon: const Icon(Icons.refresh, size: 17),
              label: const Text('RELOAD MODEL'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _brandBlock(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'STRAIGHT',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontSize: 22),
        ),
        const SizedBox(height: 4),
        Text(
          'LOCAL DICTATION',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.58),
          ),
        ),
      ],
    );
  }

  Widget _navTile(IconData icon, String label, VoidCallback? onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 17),
        label: Align(
          alignment: Alignment.centerLeft,
          child: Text(label.toUpperCase()),
        ),
        style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft),
      ),
    );
  }

  Widget _miniMetric(String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionLabel(label),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _statusRow(String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.onSurface, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 82, child: AppSectionLabel(label)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  List<double> _amplitudes(bool active) {
    if (!active) return List<double>.filled(18, 0.16);
    return List<double>.generate(18, (i) {
      final wave = math.sin((_motion.value * math.pi * 2) + i * 0.72);
      return 0.28 + wave.abs() * 0.68;
    });
  }

  Color _stateColor(ColorScheme scheme) {
    switch (coordinator.state) {
      case DictationState.idle:
        return scheme.secondary;
      case DictationState.listening:
        return scheme.primary;
      case DictationState.processing:
        return scheme.onSurface;
    }
  }

  Color _stateFg(ColorScheme scheme) {
    switch (coordinator.state) {
      case DictationState.idle:
      case DictationState.listening:
        return AppColors.lightFg;
      case DictationState.processing:
        return Theme.of(context).scaffoldBackgroundColor;
    }
  }

  String _stateLabel() {
    switch (coordinator.state) {
      case DictationState.idle:
        return 'Ready';
      case DictationState.listening:
        return 'Recording';
      case DictationState.processing:
        return 'Processing';
    }
  }

  String _headline() {
    switch (coordinator.state) {
      case DictationState.idle:
        return 'Press to dictate';
      case DictationState.listening:
        return 'Voice is live';
      case DictationState.processing:
        return 'Cleaning text';
    }
  }

  String _friendlyModel(String id) {
    switch (id) {
      case 'whisper-small':
        return 'Whisper Small';
      case 'whisper-medium':
        return 'Whisper Medium';
      case 'qwen3-asr-0.6b':
        return 'Qwen3-ASR 0.6B';
      case 'whisper-base':
      default:
        return 'Whisper Base';
    }
  }

  String _friendlyCleanup(String id) {
    switch (id) {
      case 'qwen2.5-0.5b':
        return 'Qwen2.5';
      case 'none':
      default:
        return 'Rules';
    }
  }

  String _hotkeyLabel() {
    final hotkey = coordinator.hotkeyService.currentHotkey;
    final modifiers = <String>[];
    if (hotkey.modifiers?.contains(HotKeyModifier.alt) == true) {
      modifiers.add('Alt');
    }
    if (hotkey.modifiers?.contains(HotKeyModifier.control) == true) {
      modifiers.add('Ctrl');
    }
    if (hotkey.modifiers?.contains(HotKeyModifier.shift) == true) {
      modifiers.add('Shift');
    }
    if (hotkey.modifiers?.contains(HotKeyModifier.meta) == true) {
      modifiers.add('Win');
    }
    final keyLabel = hotkey.key.keyLabel;
    modifiers.add(keyLabel.isEmpty ? 'Space' : keyLabel);
    return modifiers.join(' + ');
  }
}

class _VoiceRingPainter extends CustomPainter {
  final double progress;
  final bool active;
  final Color color;
  final Color mutedColor;

  const _VoiceRingPainter({
    required this.progress,
    required this.active,
    required this.color,
    required this.mutedColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final baseRadius = size.shortestSide * 0.38;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.square;

    for (var i = 0; i < 3; i++) {
      final phase = (progress + i / 3) % 1;
      final radius = active ? baseRadius + phase * 42 : baseRadius + i * 13;
      paint.color = (active ? color : mutedColor).withValues(
        alpha: active ? 1 - phase : 0.42,
      );
      canvas.drawCircle(center, radius, paint);
    }

    paint
      ..color = color
      ..strokeWidth = 3;
    for (var i = 0; i < 24; i++) {
      final angle = i * math.pi * 2 / 24;
      final length = active ? 12 + math.sin(progress * math.pi * 2 + i) * 8 : 8;
      final start = Offset(
        center.dx + math.cos(angle) * (baseRadius + 54),
        center.dy + math.sin(angle) * (baseRadius + 54),
      );
      final end = Offset(
        center.dx + math.cos(angle) * (baseRadius + 54 + length),
        center.dy + math.sin(angle) * (baseRadius + 54 + length),
      );
      canvas.drawLine(start, end, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _VoiceRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.active != active ||
        oldDelegate.color != color ||
        oldDelegate.mutedColor != mutedColor;
  }
}

class _SpeechRibbon extends StatelessWidget {
  final Animation<double> motion;
  final Color foregroundColor;
  final Color shadowColor;
  final Color textColor;
  final Color mutedTextColor;
  final bool active;

  const _SpeechRibbon({
    required this.motion,
    required this.foregroundColor,
    required this.shadowColor,
    required this.textColor,
    required this.mutedTextColor,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: motion,
        builder: (context, _) {
          return CustomPaint(
            painter: _SpeechRibbonPainter(
              progress: active ? motion.value : 0,
              foregroundColor: foregroundColor,
              shadowColor: shadowColor,
              textColor: textColor,
              mutedTextColor: mutedTextColor,
              active: active,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _SpeechRibbonPainter extends CustomPainter {
  final double progress;
  final Color foregroundColor;
  final Color shadowColor;
  final Color textColor;
  final Color mutedTextColor;
  final bool active;

  const _SpeechRibbonPainter({
    required this.progress,
    required this.foregroundColor,
    required this.shadowColor,
    required this.textColor,
    required this.mutedTextColor,
    required this.active,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 420 || size.height < 320) return;

    final baseline = size.height * 0.72;
    final path = Path()
      ..moveTo(-40, baseline - 28)
      ..cubicTo(
        size.width * 0.20,
        baseline - 95,
        size.width * 0.30,
        baseline + 38,
        size.width * 0.48,
        baseline - 10,
      )
      ..cubicTo(
        size.width * 0.62,
        baseline - 48,
        size.width * 0.62,
        baseline + 52,
        size.width * 0.76,
        baseline + 8,
      )
      ..cubicTo(
        size.width * 0.88,
        baseline - 28,
        size.width * 1.02,
        baseline - 12,
        size.width + 40,
        baseline - 44,
      );

    final outline = Paint()
      ..color = shadowColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, outline);

    final inner = Paint()
      ..color = foregroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, inner);

    final samples = _samplePath(path, step: 18);
    if (samples.length < 2) return;

    final messy =
        " umm can you check if the notes from yesterday's meeting were sent out ";
    final clean = "polished text appears in the active app";
    final line = active
        ? "$messy  $clean  "
        : "press start and speak naturally  ";
    final offset = active ? progress * 320 : 0.0;
    double cursor = -offset % 320;

    while (cursor < _pathLength(samples)) {
      _drawTextOnPath(
        canvas,
        samples,
        line,
        cursor,
        active ? textColor : mutedTextColor,
        active ? FontWeight.w800 : FontWeight.w700,
      );
      cursor += 330;
    }
  }

  List<Offset> _samplePath(Path path, {required double step}) {
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return const [];
    final metric = metrics.first;
    final points = <Offset>[];
    for (double d = 0; d <= metric.length; d += step) {
      final tangent = metric.getTangentForOffset(d);
      if (tangent != null) points.add(tangent.position);
    }
    return points;
  }

  double _pathLength(List<Offset> points) {
    var length = 0.0;
    for (var i = 1; i < points.length; i++) {
      length += (points[i] - points[i - 1]).distance;
    }
    return length;
  }

  void _drawTextOnPath(
    Canvas canvas,
    List<Offset> points,
    String text,
    double start,
    Color color,
    FontWeight weight,
  ) {
    var distance = 0.0;
    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      final point = _pointAt(points, start + distance);
      final next = _pointAt(points, start + distance + 6);
      if (point == null || next == null) {
        distance += 8;
        continue;
      }
      final angle = math.atan2(next.dy - point.dy, next.dx - point.dx);
      final painter = TextPainter(
        text: TextSpan(
          text: char,
          style: TextStyle(
            fontFamily: 'DM Sans',
            color: color,
            fontSize: 15,
            fontWeight: weight,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      canvas.save();
      canvas.translate(point.dx, point.dy);
      canvas.rotate(angle);
      painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
      canvas.restore();
      distance += painter.width + 1.5;
    }
  }

  Offset? _pointAt(List<Offset> points, double target) {
    if (target < 0) return null;
    var walked = 0.0;
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final b = points[i];
      final segment = (b - a).distance;
      if (walked + segment >= target) {
        final t = (target - walked) / segment;
        return Offset.lerp(a, b, t);
      }
      walked += segment;
    }
    return null;
  }

  @override
  bool shouldRepaint(covariant _SpeechRibbonPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.active != active ||
        oldDelegate.foregroundColor != foregroundColor ||
        oldDelegate.shadowColor != shadowColor ||
        oldDelegate.textColor != textColor ||
        oldDelegate.mutedTextColor != mutedTextColor;
  }
}
