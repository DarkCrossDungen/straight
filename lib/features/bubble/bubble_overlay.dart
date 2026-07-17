import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:straight/core/app_context.dart';
import 'package:straight/core/coordinator.dart';
import 'package:straight/core/storage/dictionary_store.dart';
import 'package:straight/core/storage/history_store.dart';
import 'package:straight/features/bubble/waveform_painter.dart';
import 'package:straight/features/dictionary/add_word_dialog.dart';
import 'package:straight/features/settings/model_selector.dart';
import 'package:straight/shared/theme/colors.dart';
import 'package:straight/shared/widgets/app_drawer.dart';
import 'package:straight/shared/widgets/app_surface.dart';

class BubbleOverlay extends StatefulWidget {
  const BubbleOverlay({super.key});

  @override
  State<BubbleOverlay> createState() => _BubbleOverlayState();
}

enum _WorkspaceSection { dictation, settings, dictionary, history }

class _BubbleOverlayState extends State<BubbleOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _motion;
  bool _railExpanded = false;
  _WorkspaceSection _section = _WorkspaceSection.dictation;
  List<Map> _recent = const [];

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat();
    _recent = HistoryStore.getAll(limit: 10);
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
    _recent = HistoryStore.getAll(limit: 10);
    if (mounted) setState(() {});
  }

  void _toggleDictation() => coordinator.toggleDictation();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      drawer: const AppDrawer(),
      body: Stack(
        children: [
          const Positioned.fill(
            child: CustomPaint(painter: _WisprBackdropPainter()),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 960;
                if (!wide) return _compactLayout();
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      _rail(),
                      const SizedBox(width: 20),
                      Expanded(child: _workspace()),
                      const SizedBox(width: 20),
                      SizedBox(width: 310, child: _recentPanel()),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactLayout() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              AppIconButton(
                icon: Icons.menu_rounded,
                tooltip: 'Open navigation',
                onPressed: () => Scaffold.maybeOf(context)?.openDrawer(),
              ),
              const SizedBox(width: 12),
              Expanded(child: _wordmark()),
              _stateDot(),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(child: _workspace()),
          const SizedBox(height: 16),
          SizedBox(height: 290, child: _recentPanel()),
        ],
      ),
    );
  }

  Widget _rail() {
    final width = _railExpanded ? 198.0 : 68.0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: width,
      child: AppSurface(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: _railExpanded
                  ? MainAxisAlignment.spaceBetween
                  : MainAxisAlignment.center,
              children: [
                if (_railExpanded) Expanded(child: _wordmark(compact: true)),
                IconButton(
                  tooltip: _railExpanded
                      ? 'Collapse navigation'
                      : 'Expand navigation',
                  onPressed: () =>
                      setState(() => _railExpanded = !_railExpanded),
                  icon: Icon(
                    _railExpanded ? Icons.close_rounded : Icons.menu_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _railItem(
              Icons.graphic_eq_rounded,
              'Dictation',
              () => setState(() => _section = _WorkspaceSection.dictation),
              selected: _section == _WorkspaceSection.dictation,
            ),
            _railItem(
              Icons.tune_rounded,
              'Settings',
              () => setState(() => _section = _WorkspaceSection.settings),
              selected: _section == _WorkspaceSection.settings,
            ),
            _railItem(
              Icons.menu_book_rounded,
              'Dictionary',
              () => setState(() => _section = _WorkspaceSection.dictionary),
              selected: _section == _WorkspaceSection.dictionary,
            ),
            _railItem(
              Icons.history_rounded,
              'History',
              () => setState(() => _section = _WorkspaceSection.history),
              selected: _section == _WorkspaceSection.history,
            ),
            const Spacer(),
            _railStatus(),
          ],
        ),
      ),
    );
  }

  Widget _railItem(
    IconData icon,
    String label,
    VoidCallback? onTap, {
    bool selected = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Tooltip(
        message: _railExpanded ? '' : label,
        child: Material(
          color: selected ? AppColors.primarySoft : Colors.transparent,
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          child: InkWell(
            onTap: onTap,
            borderRadius: const BorderRadius.all(Radius.circular(8)),
            child: SizedBox(
              height: 44,
              child: Row(
                mainAxisAlignment: _railExpanded
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: [
                  const SizedBox(width: 13),
                  Icon(
                    icon,
                    size: 20,
                    color: selected
                        ? scheme.primary
                        : scheme.onSurface.withValues(alpha: 0.62),
                  ),
                  if (_railExpanded) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        softWrap: false,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: selected ? scheme.primary : null,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _railStatus() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: _railExpanded ? 10 : 0,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: _railExpanded
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _stateDot(),
                    const SizedBox(width: 8),
                    Text(
                      _stateLabel(),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  width: double.infinity,
                  child: _voiceGlyph(),
                ),
                const SizedBox(height: 10),
                const AppSectionLabel('Active model'),
                const SizedBox(height: 4),
                Text(
                  _friendlyModel(coordinator.selectedSttModel),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 3),
                Text(
                  _friendlyCleanup(coordinator.selectedLlmModel),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.48),
                  ),
                ),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _stateDot(),
                const SizedBox(height: 9),
                SizedBox(width: 34, height: 34, child: _voiceGlyph()),
              ],
            ),
    );
  }

  Widget _voiceGlyph() {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _motion,
      builder: (context, _) => CustomPaint(
        painter: _VoiceToTextPainter(
          progress: _motion.value,
          color: scheme.primary,
          mutedColor: scheme.onSurface.withValues(alpha: 0.18),
        ),
      ),
    );
  }

  Widget _wordmark({bool compact = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Straight',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontSize: compact ? 24 : 29),
        ),
        if (!compact) ...[
          const SizedBox(height: 3),
          const AppSectionLabel('Private desktop dictation'),
        ],
      ],
    );
  }

  Widget _workspace() {
    return switch (_section) {
      _WorkspaceSection.dictation => _voiceWorkspace(),
      _WorkspaceSection.settings => _settingsWorkspace(),
      _WorkspaceSection.dictionary => _dictionaryWorkspace(),
      _WorkspaceSection.history => _historyWorkspace(),
    };
  }

  Widget _sectionShell({
    required String eyebrow,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return AppSurface(
      color: scheme.surface,
      padding: const EdgeInsets.all(30),
      shadow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionLabel(eyebrow),
          const SizedBox(height: 10),
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 28),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _settingsWorkspace() {
    final scheme = Theme.of(context).colorScheme;
    return _sectionShell(
      eyebrow: 'Preferences',
      title: 'Settings',
      subtitle:
          'Keep the essentials close. Everything else stays out of the way.',
      child: ListView(
        children: [
          AppSurface(
            color: AppColors.lightMuted,
            shadow: false,
            child: Row(
              children: [
                SizedBox(width: 86, height: 48, child: _voiceGlyph()),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppSectionLabel('Active speech model'),
                      const SizedBox(height: 5),
                      Text(
                        _friendlyModel(coordinator.selectedSttModel),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                ),
                AppBadge(label: _friendlyCleanup(coordinator.selectedLlmModel)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          AppSurface(
            shadow: false,
            child: Column(
              children: [
                const ModelSelector(),
                Divider(color: Theme.of(context).dividerColor),
                ListTile(
                  leading: const Icon(Icons.keyboard_command_key_rounded),
                  title: const Text('Dictation shortcut'),
                  subtitle: Text(_hotkeyLabel()),
                  trailing: const Icon(Icons.tune_rounded, size: 18),
                  onTap: () => Navigator.pushNamed(context, '/settings'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Straight works locally. Your audio and dictation history stay on this machine.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.56),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dictionaryWorkspace() {
    final words = DictionaryStore.getAll();
    return _sectionShell(
      eyebrow: 'Vocabulary',
      title: 'Dictionary',
      subtitle: 'Teach Straight the words and names that matter to you.',
      child: Column(
        children: [
          Row(
            children: [
              AppBadge(label: '${words.length} saved'),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _addDictionaryWord,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('ADD WORD'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: AppSurface(
              padding: EdgeInsets.zero,
              shadow: false,
              child: words.isEmpty
                  ? Center(
                      child: Text(
                        'Add a word to improve recognition.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    )
                  : ListView.separated(
                      itemCount: words.length,
                      separatorBuilder: (_, _) =>
                          Divider(color: Theme.of(context).dividerColor),
                      itemBuilder: (context, index) =>
                          _dictionaryRow(words[index]),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dictionaryRow(Map entry) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = entry['enabled'] ?? true;
    return ListTile(
      title: Text(entry['word']?.toString() ?? ''),
      subtitle: Text(entry['replacement']?.toString() ?? ''),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(
            value: enabled,
            onChanged: (value) async {
              await DictionaryStore.updateWord(entry['id'].toString(), {
                'enabled': value,
              });
              _syncState();
            },
          ),
          IconButton(
            tooltip: 'Delete word',
            onPressed: () async {
              await DictionaryStore.deleteWord(entry['id'].toString());
              _syncState();
            },
            icon: Icon(
              Icons.close_rounded,
              size: 18,
              color: scheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addDictionaryWord() async {
    final result = await AddWordDialog.show(context);
    if (result == null) return;
    await DictionaryStore.addWord(
      result['word'] as String,
      result['replacement'] as String,
      aliases: (result['aliases'] as List<String>? ?? const []),
    );
    _syncState();
  }

  Widget _historyWorkspace() {
    final entries = HistoryStore.getAll();
    return _sectionShell(
      eyebrow: 'Archive',
      title: 'History',
      subtitle: 'A local record of your completed dictations.',
      child: AppSurface(
        padding: EdgeInsets.zero,
        shadow: false,
        child: entries.isEmpty
            ? Center(
                child: Text(
                  'No dictations yet.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              )
            : ListView.separated(
                itemCount: entries.length,
                separatorBuilder: (_, _) =>
                    Divider(color: Theme.of(context).dividerColor),
                itemBuilder: (context, index) => _historyRow(entries[index]),
              ),
      ),
    );
  }

  Widget _historyRow(Map entry) {
    final text = (entry['appliedText'] ?? entry['text'] ?? '').toString();
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      title: Text(
        text.isEmpty ? 'Untitled dictation' : text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(_formatTimestamp(entry['timestamp'])),
    );
  }

  Widget _voiceWorkspace() {
    final scheme = Theme.of(context).colorScheme;
    final listening = coordinator.state == DictationState.listening;
    final processing = coordinator.state == DictationState.processing;
    return AppSurface(
      padding: const EdgeInsets.all(28),
      shadow: true,
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          fit: StackFit.expand,
          children: [
            Positioned(top: 0, right: 0, child: _stateBadge()),
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _motion,
                  builder: (context, _) => CustomPaint(
                    painter: _SpeechRibbonPainter(
                      progress: _motion.value,
                      color: listening ? scheme.primary : scheme.onSurface,
                      textColor: scheme.onSurface.withValues(alpha: 0.55),
                      active: listening,
                    ),
                  ),
                ),
              ),
            ),
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: math.min(530, constraints.maxWidth - 24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      processing
                          ? 'Working on it'
                          : listening
                          ? 'Listening'
                          : 'Speak when ready',
                      style: Theme.of(context).textTheme.headlineLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      processing
                          ? 'Cleaning your words before they are typed.'
                          : listening
                          ? 'Keep speaking. Straight will type when you stop.'
                          : 'Press the oval, or use your shortcut.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 38),
                    _voiceButton(listening, processing),
                    const SizedBox(height: 26),
                    _shortcutHint(),
                    const SizedBox(height: 20),
                    _voiceNotes(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _voiceButton(bool listening, bool processing) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: listening ? 'Stop dictation' : 'Start dictation',
      child: GestureDetector(
        onTap: processing ? null : _toggleDictation,
        child: AnimatedBuilder(
          animation: _motion,
          builder: (context, _) {
            final scale =
                1 +
                math.sin(_motion.value * math.pi * 2) *
                    (listening ? 0.012 : 0.004);
            return Transform.scale(
              scale: scale,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 334,
                height: 154,
                decoration: BoxDecoration(
                  color: listening ? scheme.primary : AppColors.primarySoft,
                  borderRadius: const BorderRadius.all(Radius.circular(88)),
                  border: Border.all(
                    color: listening
                        ? scheme.primary
                        : scheme.primary.withValues(alpha: 0.35),
                  ),
                ),
                child: processing
                    ? Center(
                        child: CircularProgressIndicator(
                          color: scheme.primary,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            listening
                                ? Icons.stop_rounded
                                : Icons.mic_none_rounded,
                            size: 30,
                            color: listening
                                ? AppColors.lightCard
                                : scheme.primary,
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: 150,
                            height: 30,
                            child: CustomPaint(
                              painter: WaveformPainter(
                                amplitudes: _amplitudes(listening),
                                color: listening
                                    ? AppColors.lightCard
                                    : scheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            listening ? 'Tap to stop' : 'Tap to speak',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: listening
                                      ? AppColors.lightCard
                                      : scheme.primary,
                                ),
                          ),
                        ],
                      ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _shortcutHint() {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Shortcut', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: const BorderRadius.all(Radius.circular(5)),
          ),
          child: Text(
            _hotkeyLabel(),
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      ],
    );
  }

  Widget _voiceNotes() {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 14,
      runSpacing: 8,
      children: [
        _voiceNote(Icons.lock_outline_rounded, 'On this device', scheme),
        _voiceNote(Icons.auto_fix_high_rounded, 'Clean as you speak', scheme),
        _voiceNote(Icons.graphic_eq_rounded, 'Whisper ready', scheme),
      ],
    );
  }

  Widget _voiceNote(IconData icon, String label, ColorScheme scheme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: scheme.onSurface.withValues(alpha: 0.42)),
        const SizedBox(width: 5),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.52),
          ),
        ),
      ],
    );
  }

  Widget _recentPanel() {
    final scheme = Theme.of(context).colorScheme;
    return AppSurface(
      padding: const EdgeInsets.fromLTRB(20, 20, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Recent dictation',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/history'),
                child: const Text('VIEW ALL'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Your last ten entries stay on this device.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _recent.isEmpty
                ? Center(
                    child: Text(
                      'Your dictations will appear here.',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: _recent.length,
                    separatorBuilder: (_, _) =>
                        Divider(color: Theme.of(context).dividerColor),
                    itemBuilder: (context, index) =>
                        _recentRow(_recent[index], scheme),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _recentRow(Map entry, ColorScheme scheme) {
    final text = (entry['appliedText'] ?? entry['text'] ?? '').toString();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text.isEmpty ? 'Untitled dictation' : text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 5),
          Text(
            _formatTimestamp(entry['timestamp']),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.44),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stateBadge() => AppBadge(
    label: _stateLabel(),
    color: coordinator.state == DictationState.listening
        ? AppColors.primarySoft
        : Theme.of(context).colorScheme.secondary,
    foregroundColor: coordinator.state == DictationState.listening
        ? Theme.of(context).colorScheme.primary
        : null,
  );

  Widget _stateDot() => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(
      color: coordinator.state == DictationState.listening
          ? Theme.of(context).colorScheme.primary
          : AppColors.success,
      shape: BoxShape.circle,
    ),
  );

  List<double> _amplitudes(bool active) {
    if (!active) {
      return List<double>.generate(18, (i) {
        final base = 0.18 + (i % 5) * 0.055;
        final drift = math.sin(_motion.value * math.pi * 2 + i * 0.6) * 0.055;
        return (base + drift).clamp(0.12, 0.48);
      });
    }
    return List<double>.generate(
      18,
      (i) =>
          0.25 + math.sin(_motion.value * math.pi * 2 + i * 0.78).abs() * 0.7,
    );
  }

  String _stateLabel() => switch (coordinator.state) {
    DictationState.idle => 'Ready',
    DictationState.listening => 'Recording',
    DictationState.processing => 'Processing',
  };

  String _formatTimestamp(dynamic value) {
    if (value is! int) {
      return 'Recently';
    }
    final time = DateTime.fromMillisecondsSinceEpoch(value);
    final difference = DateTime.now().difference(time);
    if (difference.inMinutes < 1) {
      return 'Just now';
    }
    if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    }
    if (difference.inDays == 0) {
      return '${difference.inHours}h ago';
    }
    return '${time.day}/${time.month}/${time.year}';
  }

  String _hotkeyLabel() {
    final hotkey = coordinator.hotkeyService.currentHotkey;
    final parts = <String>[];
    if (hotkey.modifiers?.contains(HotKeyModifier.alt) == true) {
      parts.add('Alt');
    }
    if (hotkey.modifiers?.contains(HotKeyModifier.control) == true) {
      parts.add('Ctrl');
    }
    if (hotkey.modifiers?.contains(HotKeyModifier.shift) == true) {
      parts.add('Shift');
    }
    final key = hotkey.key.keyLabel;
    parts.add(key.isEmpty ? 'Space' : key);
    return parts.join(' + ');
  }

  String _friendlyModel(String id) => switch (id) {
    'whisper-small' => 'Whisper Small',
    'whisper-medium' => 'Whisper Medium',
    'qwen3-asr-0.6b' => 'Qwen3-ASR 0.6B',
    _ => 'Whisper Base',
  };

  String _friendlyCleanup(String id) => switch (id) {
    'qwen2.5-0.5b' => 'Qwen2.5 cleanup',
    _ => 'Rules cleanup',
  };
}

class _VoiceToTextPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color mutedColor;

  const _VoiceToTextPainter({
    required this.progress,
    required this.color,
    required this.mutedColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.height / 2;
    final settle = (math.sin(progress * math.pi * 2) + 1) / 2;
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.4;

    for (var index = 0; index < 4; index++) {
      final y = center - 11 + index * 7.3;
      final amplitude = (1 - settle) * (5 + index * 1.2);
      final path = Path();
      for (var x = 0.0; x <= size.width; x += 2) {
        final wave =
            math.sin(
              (x / size.width * math.pi * 3) + progress * math.pi * 4 + index,
            ) *
            amplitude;
        if (x == 0) {
          path.moveTo(x, y + wave);
        } else {
          path.lineTo(x, y + wave);
        }
      }
      linePaint.color = index == 1 || index == 2
          ? color.withValues(alpha: 0.78)
          : mutedColor;
      canvas.drawPath(path, linePaint);
    }

    final ovalWidth = 13 + settle * 14;
    final oval = Rect.fromCenter(
      center: Offset(size.width * (0.23 + settle * 0.51), center),
      width: ovalWidth,
      height: 10 - settle * 4,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(oval, const Radius.circular(8)),
      Paint()..color = color.withValues(alpha: 0.92),
    );
  }

  @override
  bool shouldRepaint(covariant _VoiceToTextPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.mutedColor != mutedColor;
}

class _WisprBackdropPainter extends CustomPainter {
  const _WisprBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final wash = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.36);
    final stroke = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.42)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(54, size.shortestSide * 0.1);

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.15, size.height * 0.1),
        width: size.width * 0.56,
        height: size.height * 0.38,
      ),
      wash,
    );

    final left = Path()
      ..moveTo(-40, size.height * 0.84)
      ..cubicTo(
        size.width * 0.12,
        size.height * 0.42,
        size.width * 0.2,
        size.height * 0.58,
        size.width * 0.36,
        size.height * 0.24,
      );
    final right = Path()
      ..moveTo(size.width * 0.66, size.height * 0.96)
      ..cubicTo(
        size.width * 0.78,
        size.height * 0.55,
        size.width * 0.85,
        size.height * 0.72,
        size.width + 40,
        size.height * 0.18,
      );
    canvas.drawPath(left, stroke);
    canvas.drawPath(right, stroke);
  }

  @override
  bool shouldRepaint(covariant _WisprBackdropPainter oldDelegate) => false;
}

class _SpeechRibbonPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color textColor;
  final bool active;

  const _SpeechRibbonPainter({
    required this.progress,
    required this.color,
    required this.textColor,
    required this.active,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(-24, size.height * 0.72)
      ..cubicTo(
        size.width * 0.18,
        size.height * 0.62,
        size.width * 0.32,
        size.height * 0.84,
        size.width * 0.53,
        size.height * 0.72,
      )
      ..cubicTo(
        size.width * 0.69,
        size.height * 0.62,
        size.width * 0.79,
        size.height * 0.78,
        size.width + 24,
        size.height * 0.64,
      );
    final line = Paint()
      ..color = color.withValues(alpha: active ? 0.32 : 0.13)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, line);

    final metric = path.computeMetrics().first;
    const words = 'speaking naturally becomes clear writing  ';
    final start = (progress * metric.length) % 180;
    var cursor = -start;
    while (cursor < metric.length) {
      for (final character in words.split('')) {
        final tangent = metric.getTangentForOffset(
          cursor.clamp(0, metric.length),
        );
        if (tangent == null) break;
        final painter = TextPainter(
          text: TextSpan(
            text: character,
            style: TextStyle(
              fontFamily: 'Segoe UI',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor.withValues(alpha: active ? 1 : 0.42),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        if (cursor >= 0) {
          canvas.save();
          canvas.translate(tangent.position.dx, tangent.position.dy - 12);
          canvas.rotate(tangent.angle);
          painter.paint(
            canvas,
            Offset(-painter.width / 2, -painter.height / 2),
          );
          canvas.restore();
        }
        cursor += painter.width + 1.3;
        if (cursor > metric.length) break;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SpeechRibbonPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.textColor != textColor ||
      oldDelegate.active != active;
}
