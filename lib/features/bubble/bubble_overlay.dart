import 'package:flutter/material.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:straight/core/app_context.dart';
import 'package:straight/core/coordinator.dart';
import 'package:straight/features/bubble/bubble_controller.dart';
import 'package:straight/features/bubble/waveform_painter.dart';
import 'package:straight/shared/theme/colors.dart';
import 'package:straight/shared/widgets/app_drawer.dart';

class BubbleOverlay extends StatefulWidget {
  const BubbleOverlay({super.key});

  @override
  State<BubbleOverlay> createState() => _BubbleOverlayState();
}

class _BubbleOverlayState extends State<BubbleOverlay>
    with SingleTickerProviderStateMixin {
  final _controller = BubbleController();
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    coordinator.addListener(_syncState);
    _syncState();
  }

  @override
  void dispose() {
    coordinator.removeListener(_syncState);
    _pulseController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _syncState() {
    switch (coordinator.state) {
      case DictationState.idle:
        _controller.setState(BubbleState.idle);
        _pulseController.stop();
        _pulseController.reset();
        break;
      case DictationState.listening:
        _controller.setState(BubbleState.listening);
        _pulseController.repeat(reverse: true);
        break;
      case DictationState.processing:
        _controller.setState(BubbleState.processing);
        _pulseController.stop();
        _pulseController.reset();
        break;
    }
    if (mounted) setState(() {});
  }

  void _toggleDictation() => coordinator.toggleDictation();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      drawer: const AppDrawer(),
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 1080;
            return Padding(
              padding: const EdgeInsets.all(16),
              child: isWide ? _buildDesktop(context, colors, isDark) : _buildStacked(context, colors, isDark),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDesktop(BuildContext context, ColorScheme colors, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: 250, child: _rail(colors)),
        const SizedBox(width: 16),
        Expanded(child: _mainStage(context, colors, isDark)),
        const SizedBox(width: 16),
        SizedBox(width: 290, child: _statusPanel(colors)),
      ],
    );
  }

  Widget _buildStacked(BuildContext context, ColorScheme colors, bool isDark) {
    return Column(
      children: [
        _topBar(context, colors, isDark),
        const SizedBox(height: 16),
        Expanded(child: _mainStage(context, colors, isDark)),
        const SizedBox(height: 16),
        _statusPanel(colors),
      ],
    );
  }

  Widget _topBar(BuildContext context, ColorScheme colors, bool isDark) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Scaffold.maybeOf(context)?.openDrawer(),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 1),
            ),
            child: Icon(Icons.menu, size: 20, color: colors.onSurface),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'STRAIGHT',
              style: TextStyle(
                fontFamily: 'SF Mono',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
                letterSpacing: 0,
              ),
            ),
            Text(
              'offline voice dictation',
              style: TextStyle(
                fontFamily: 'SF Mono',
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: colors.onSurface.withValues(alpha: 0.45),
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _rail(ColorScheme colors) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colors.onSurface, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'STRAIGHT',
              style: TextStyle(
                fontFamily: 'SF Mono',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'DICTATE. STRAIGHT.',
              style: TextStyle(
                fontFamily: 'SF Mono',
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: colors.onSurface.withValues(alpha: 0.45),
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 20),
            _stateLine('Speech', _stateLabel()),
            const SizedBox(height: 8),
            _stateLine('Model', _friendlyModel(coordinator.selectedSttModel)),
            const SizedBox(height: 8),
            _stateLine('Cleanup', _friendlyCleanup(coordinator.selectedLlmModel)),
            const SizedBox(height: 20),
            _navButton(Icons.home_outlined, 'Home', () {}),
            const SizedBox(height: 8),
            _navButton(Icons.settings_outlined, 'Settings', () => Navigator.pushNamed(context, '/settings')),
            const SizedBox(height: 8),
            _navButton(Icons.book_outlined, 'Dictionary', () => Navigator.pushNamed(context, '/dictionary')),
            const SizedBox(height: 8),
            _navButton(Icons.history, 'History', () => Navigator.pushNamed(context, '/history')),
            const Spacer(),
            Text(
              'local only',
              style: TextStyle(
                fontFamily: 'SF Mono',
                fontSize: 10,
                color: colors.onSurface.withValues(alpha: 0.35),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mainStage(BuildContext context, ColorScheme colors, bool isDark) {
    final isIdle = coordinator.state == DictationState.idle;
    final isListening = coordinator.state == DictationState.listening;
    final bubbleSize = isListening ? 250.0 : 190.0;
    final bubbleColor = isIdle
        ? (isDark ? AppColors.darkFg : AppColors.lightFg)
        : (isDark ? AppColors.primaryDark : AppColors.primaryLight);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colors.onSurface, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DICTATE STRAIGHT',
              style: TextStyle(
                fontFamily: 'SF Mono',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: colors.onSurface.withValues(alpha: 0.5),
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _headline(),
              style: TextStyle(
                fontFamily: 'SF Mono',
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _subhead(),
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: colors.onSurface.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Center(
                child: GestureDetector(
                  onTap: _toggleDictation,
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: coordinator.state == DictationState.listening ? _pulseAnimation.value : 1.0,
                        child: child,
                      );
                    },
                    child: Container(
                      width: bubbleSize,
                      height: bubbleSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: bubbleColor,
                        border: Border.all(color: colors.onSurface, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: bubbleColor.withValues(alpha: 0.25),
                            blurRadius: 0,
                            offset: const Offset(8, 8),
                          ),
                        ],
                      ),
                      child: _bubbleContent(isDark, colors),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _actionButton(Icons.play_arrow, 'Toggle', _toggleDictation),
                const SizedBox(width: 8),
                _actionButton(Icons.refresh, 'Reload model', () {
                  coordinator.refreshSpeechModel();
                }),
                const SizedBox(width: 8),
                _actionButton(Icons.settings_outlined, 'Settings', () => Navigator.pushNamed(context, '/settings')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusPanel(ColorScheme colors) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colors.onSurface, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SYSTEM',
              style: TextStyle(
                fontFamily: 'SF Mono',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: colors.onSurface.withValues(alpha: 0.55),
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            _statusBlock(colors, 'Status', coordinator.statusMessage),
            const SizedBox(height: 12),
            _statusBlock(colors, 'Speech model', _friendlyModel(coordinator.selectedSttModel)),
            const SizedBox(height: 12),
            _statusBlock(colors, 'Cleanup', _friendlyCleanup(coordinator.selectedLlmModel)),
            const SizedBox(height: 12),
            _statusBlock(colors, 'Hotkey', _hotkeyLabel()),
            const SizedBox(height: 20),
            Text(
              'WHAT THIS IS DOING',
              style: TextStyle(
                fontFamily: 'SF Mono',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: colors.onSurface.withValues(alpha: 0.55),
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Speech goes in, rules clean it up, and the result drops into the active app.',
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: colors.onSurface.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/dictionary'),
                    icon: const Icon(Icons.book_outlined, size: 16),
                    label: const Text('Dictionary'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/history'),
                    icon: const Icon(Icons.history, size: 16),
                    label: const Text('History'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _bubbleContent(bool isDark, ColorScheme colors) {
    switch (_controller.state) {
      case BubbleState.idle:
        return Center(
          child: Icon(Icons.mic, size: 42, color: isDark ? AppColors.darkBg : AppColors.lightBg),
        );
      case BubbleState.listening:
        return Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.mic, size: 28, color: isDark ? AppColors.darkFg : AppColors.lightFg),
              const SizedBox(height: 12),
              SizedBox(
                height: 56,
                child: CustomPaint(
                  painter: WaveformPainter(
                    amplitudes: _controller.waveformAmplitudes,
                    color: isDark ? AppColors.darkFg : AppColors.lightFg,
                  ),
                ),
              ),
            ],
          ),
        );
      case BubbleState.processing:
        return Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(isDark ? AppColors.darkFg : AppColors.lightFg),
            ),
          ),
        );
    }
  }

  Widget _statusBlock(ColorScheme colors, String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: colors.onSurface, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: 'SF Mono',
              fontSize: 10,
              color: colors.onSurface.withValues(alpha: 0.45),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: colors.onSurface,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stateLine(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'SF Mono',
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: 'SF Mono',
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
        ),
      ],
    );
  }

  Widget _navButton(IconData icon, String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(label),
      ),
    );
  }

  Widget _actionButton(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          alignment: Alignment.center,
        ),
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(label),
      ),
    );
  }

  String _stateLabel() {
    switch (coordinator.state) {
      case DictationState.idle:
        return 'idle';
      case DictationState.listening:
        return 'listening';
      case DictationState.processing:
        return 'processing';
    }
  }

  String _headline() {
    switch (coordinator.state) {
      case DictationState.idle:
        return 'Ready to speak';
      case DictationState.listening:
        return 'Listening now';
      case DictationState.processing:
        return 'Cleaning text';
    }
  }

  String _subhead() {
    switch (coordinator.state) {
      case DictationState.idle:
        return 'Press the hotkey or tap the bubble to start dictation. Everything stays local.';
      case DictationState.listening:
        return 'Keep talking. The app is collecting audio and waiting for silence.';
      case DictationState.processing:
        return 'Speech is being turned into text, then cleaned up before insertion.';
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
        return 'Rules + Qwen2.5 0.5B';
      case 'none':
      default:
        return 'Rules only';
    }
  }

  String _hotkeyLabel() {
    final hotkey = coordinator.hotkeyService.currentHotkey;
    final modifiers = <String>[];
    if (hotkey.modifiers?.contains(HotKeyModifier.alt) == true) modifiers.add('Alt');
    if (hotkey.modifiers?.contains(HotKeyModifier.control) == true) modifiers.add('Ctrl');
    if (hotkey.modifiers?.contains(HotKeyModifier.shift) == true) modifiers.add('Shift');
    if (hotkey.modifiers?.contains(HotKeyModifier.meta) == true) modifiers.add('Win');
    final keyLabel = hotkey.key.keyLabel;
    modifiers.add(keyLabel.isEmpty ? 'Space' : keyLabel);
    return modifiers.join(' + ');
  }
}
