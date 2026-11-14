import 'dart:io';

import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:straight/core/app_context.dart';
import 'package:straight/core/hotkey/desktop_shortcut_service.dart';
import 'package:straight/core/hotkey/input_access.dart';
import 'package:straight/core/injection/typing_access.dart';
import 'package:straight/core/startup/startup_service.dart';
import 'package:straight/core/storage/settings_store.dart';
import 'package:straight/features/bubble/bubble_overlay.dart';
import 'package:straight/shared/widgets/app_surface.dart';
import 'package:straight/shared/widgets/password_prompt_dialog.dart';

/// First-launch setup. Straight does everything it is allowed to do by itself
/// and stops only for the one change that needs the user's password, which is
/// typed into Straight's own window and checked by the system.
class SetupPage extends StatefulWidget {
  const SetupPage({super.key});

  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  final _controller = PageController();
  late final List<Widget> _pages;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pages = [
      const _WelcomeStep(),
      if (Platform.isLinux) ...[
        const _KeyboardStep(),
        const _TypingStep(),
        const _ShortcutStep(),
      ],
      const _MicrophoneStep(),
      const _DoneStep(),
    ];
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    } else {
      _finish();
    }
  }

  void _back() {
    if (_currentPage > 0) {
      _controller.previousPage(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _finish() async {
    await SettingsStore.setSetupCompleted(true);
    if (!mounted) return;
    // Replace setup with the app directly. Navigating by name risked handing
    // back the setup route (the '/'-loop that kept the app in setup forever).
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const BubbleOverlay()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLast = _currentPage == _pages.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemCount: _pages.length,
                itemBuilder: (context, index) => _pages[index],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
              child: AppSurface(
                shadow: false,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    if (_currentPage > 0)
                      TextButton(onPressed: _back, child: const Text('BACK'))
                    else
                      const SizedBox(width: 72),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_pages.length, (i) {
                          final active = i == _currentPage;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: active ? 26 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: active
                                  ? scheme.primary
                                  : scheme.onSurface.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),
                    ),
                    if (!isLast)
                      TextButton(
                        onPressed: () =>
                            _controller.jumpToPage(_pages.length - 1),
                        child: const Text('SKIP'),
                      ),
                    ElevatedButton(
                      onPressed: _next,
                      child: Text(isLast ? 'GET STARTED' : 'NEXT'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared layout: icon, title, one plain-language explanation, status/action.
class _StepFrame extends StatelessWidget {
  final IconData icon;
  final bool done;
  final String title;
  final String description;
  final Widget child;

  const _StepFrame({
    required this.icon,
    required this.title,
    required this.description,
    required this.child,
    this.done = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: done
                      ? scheme.primary.withValues(alpha: 0.12)
                      : scheme.surface,
                  border: Border.all(
                    color: done
                        ? scheme.primary
                        : scheme.onSurface.withValues(alpha: 0.25),
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  done ? Icons.check_rounded : icon,
                  size: 40,
                  color: done ? scheme.primary : scheme.onSurface,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.55,
                  color: scheme.onSurface.withValues(alpha: 0.72),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final bool good;
  const _StatusChip({required this.label, required this.good});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = good ? Colors.green.shade400 : scheme.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(
          color: good ? color : scheme.onSurface.withValues(alpha: 0.25),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            good ? Icons.check_circle : Icons.info_outline,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep();

  @override
  Widget build(BuildContext context) {
    return _StepFrame(
      icon: Icons.mic_none_rounded,
      title: 'Welcome to Straight',
      description:
          'Speak naturally — Straight cleans up your words and types them '
          'into the app in front of you.\n\n'
          'Everything runs on this computer. No account, no cloud, no '
          'subscription. Setup takes about a minute.',
      child: const AppBadge(label: 'Offline dictation'),
    );
  }
}

class _KeyboardStep extends StatefulWidget {
  const _KeyboardStep();

  @override
  State<_KeyboardStep> createState() => _KeyboardStepState();
}

class _KeyboardStepState extends State<_KeyboardStep> {
  bool _checking = true;
  bool _granted = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final readable = await InputAccess.isReadable();
    if (!mounted) return;
    setState(() {
      _checking = false;
      _granted = readable;
    });
  }

  Future<void> _grant() async {
    setState(() => _busy = true);
    final granted = await requestInputAccess(context);
    if (granted) await coordinator.enableHoldToRecord();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _granted = granted;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _StepFrame(
      icon: Icons.keyboard_outlined,
      done: _granted,
      title: 'Hold-to-record',
      description:
          'So you can hold the shortcut to talk and release to stop, Straight '
          'needs to see key releases. Linux keeps that behind a one-time '
          'permission.\n\n'
          'This is the only step that asks for your password — typed into '
          'Straight\'s own window, checked by the system, never saved. '
          'Skip it and tap-to-talk still works.',
      child: _checking || _busy
          ? const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : _granted
          ? const _StatusChip(label: 'Keyboard access is on', good: true)
          : FilledButton.icon(
              onPressed: _grant,
              icon: const Icon(Icons.lock_open, size: 16),
              label: const Text('ENABLE HOLD-TO-RECORD'),
            ),
    );
  }
}

class _TypingStep extends StatefulWidget {
  const _TypingStep();

  @override
  State<_TypingStep> createState() => _TypingStepState();
}

class _TypingStepState extends State<_TypingStep> {
  bool _checking = true;
  bool? _enabled;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final enabled = await TypingAccess.isEnabled();
    if (!mounted) return;
    setState(() {
      _checking = false;
      _enabled = enabled;
    });
  }

  Future<void> _enable() async {
    setState(() => _busy = true);
    final enabled = await TypingAccess.enable();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _enabled = enabled;
    });
  }

  @override
  Widget build(BuildContext context) {
    final done = _enabled == true;
    return _StepFrame(
      icon: Icons.text_fields_rounded,
      done: done && !_checking,
      title: 'Typing into your apps',
      description:
          'Straight writes your words through the accessibility channel that '
          'screen readers use — your cursor and undo history stay intact.\n\n'
          'One switch inside your desktop settings turns it on. Straight '
          'flips it for you; no password needed.',
      child: _checking || _busy
          ? const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : done
          ? _StatusChip(label: 'Typing access is on', good: true)
          : _enabled == null
          ? Column(
              children: [
                Text(
                  'This desktop does not expose an accessibility switch, so '
                  'Straight cannot confirm typing from here. It still writes '
                  'through the standard channel — to be sure, dictate one '
                  'word into any text field after setup.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    height: 1.5,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.62),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _check,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('CHECK AGAIN'),
                ),
              ],
            )
          : FilledButton.icon(
              onPressed: _enable,
              icon: const Icon(Icons.toggle_on_outlined, size: 16),
              label: const Text('TURN IT ON'),
            ),
    );
  }
}

class _ShortcutStep extends StatefulWidget {
  const _ShortcutStep();

  @override
  State<_ShortcutStep> createState() => _ShortcutStepState();
}

class _ShortcutStepState extends State<_ShortcutStep> {
  bool _checking = true;
  bool _registered = false;
  bool _busy = false;
  bool _supported = true;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final supported = await DesktopShortcutService.isSupported();
    final binding = supported
        ? await DesktopShortcutService.registeredBinding()
        : null;
    if (!mounted) return;
    setState(() {
      _checking = false;
      _supported = supported;
      _registered =
          binding == DesktopShortcutService.bindingFor(SettingsStore.getHotkey());
    });
  }

  Future<void> _register() async {
    setState(() => _busy = true);
    final registered = await DesktopShortcutService.register(
      SettingsStore.getHotkey(),
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _registered = registered;
    });
  }

  String get _label {
    final hotkey = SettingsStore.getHotkey();
    return [
      if (hotkey['ctrl'] == true) 'Ctrl',
      if (hotkey['alt'] == true) 'Alt',
      if (hotkey['shift'] == true) 'Shift',
      if (hotkey['meta'] == true) 'Super',
      (hotkey['key'] ?? 'Space').toString(),
    ].join(' + ');
  }

  @override
  Widget build(BuildContext context) {
    return _StepFrame(
      icon: Icons.keyboard_command_key_rounded,
      done: _registered,
      title: 'Your shortcut',
      description:
          '$_label starts and stops dictation from any app. Straight '
          'registers it with your desktop for you — no password needed.'
          '${_supported ? '' : '\n\nThis desktop keeps shortcuts elsewhere, so add it once in Keyboard settings with the command below.'}',
      child: _checking || _busy
          ? const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : _registered
          ? _StatusChip(label: '$_label is ready', good: true)
          : _supported
          ? FilledButton.icon(
              onPressed: _register,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: Text('REGISTER $_label'),
            )
          : Column(
              children: [
                SelectableText(
                  DesktopShortcutService.toggleCommand,
                  style: const TextStyle(fontSize: 11),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: DesktopShortcutService.openKeyboardSettings,
                  child: const Text('OPEN KEYBOARD SETTINGS'),
                ),
              ],
            ),
    );
  }
}

class _MicrophoneStep extends StatefulWidget {
  const _MicrophoneStep();

  @override
  State<_MicrophoneStep> createState() => _MicrophoneStepState();
}

class _MicrophoneStepState extends State<_MicrophoneStep> {
  bool _checking = true;
  bool _granted = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() => _checking = true);
    try {
      final granted = await AudioRecorder().hasPermission();
      if (!mounted) return;
      setState(() {
        _checking = false;
        _granted = granted;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _granted = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _StepFrame(
      icon: Icons.mic_none_rounded,
      done: _granted,
      title: 'Microphone',
      description: Platform.isWindows
          ? 'Straight needs microphone access to hear you. If Windows asks, '
                'choose Allow — nothing leaves this computer.'
          : 'Straight listens only while the shortcut is held. Say a few '
                'words after setup to see the bubble move.',
      child: _checking
          ? const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : _granted
          ? const _StatusChip(label: 'Microphone is ready', good: true)
          : Column(
              children: [
                const _StatusChip(
                  label: 'Microphone is not reachable',
                  good: false,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _check,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('CHECK AGAIN'),
                ),
              ],
            ),
    );
  }
}

class _DoneStep extends StatefulWidget {
  const _DoneStep();

  @override
  State<_DoneStep> createState() => _DoneStepState();
}

class _DoneStepState extends State<_DoneStep> {
  late bool _startOnBoot = SettingsStore.getStartOnBoot();
  bool _checking = true;
  bool _typingKnown = false;
  bool _typingOn = false;
  bool _keyboardOn = false;
  bool _shortcutOn = false;

  @override
  void initState() {
    super.initState();
    _recheck();
  }

  Future<void> _recheck() async {
    setState(() => _checking = true);
    final typingEnabled = await TypingAccess.isEnabled();
    final keyboard = await InputAccess.isReadable();
    final supported = await DesktopShortcutService.isSupported();
    final binding = supported
        ? await DesktopShortcutService.registeredBinding()
        : null;
    if (!mounted) return;
    setState(() {
      _checking = false;
      _typingKnown = typingEnabled != null;
      _typingOn = typingEnabled == true;
      _keyboardOn = keyboard;
      _shortcutOn = binding == DesktopShortcutService.bindingFor(SettingsStore.getHotkey());
    });
  }

  String get _hotkeyLabel {
    final hotkey = SettingsStore.getHotkey();
    return [
      if (hotkey['ctrl'] == true) 'Ctrl',
      if (hotkey['alt'] == true) 'Alt',
      if (hotkey['shift'] == true) 'Shift',
      if (hotkey['meta'] == true) 'Super',
      (hotkey['key'] ?? 'Space').toString(),
    ].join(' + ');
  }

  bool get _allOk =>
      (!_typingKnown || _typingOn) && _keyboardOn && _shortcutOn;

  Widget _row(String title, bool ok, String whenOff, {Widget? fix}) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.info_outline,
            size: 16,
            color: ok ? Colors.green.shade400 : scheme.onSurface,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 12.5))),
          if (whenOff.isNotEmpty) ...[
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                whenOff,
                style: const TextStyle(fontSize: 11.5)
                    .copyWith(color: Colors.grey),
              ),
            ),
          ],
          if (fix != null) ...[
            const SizedBox(width: 8),
            fix,
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final holdReady = Platform.isLinux && coordinator.holdToRecordReady;
    final label = _hotkeyLabel;

    return _StepFrame(
      icon: Icons.check_rounded,
      done: _allOk && !_checking,
      title: 'You\'re set',
      description: holdReady
          ? 'Hold $label, talk, release — your words appear in the app in '
                'front of you. Double-tap $label to keep listening until you '
                'tap again.'
          : 'Tap $label to start talking, tap again to stop — your words '
                'appear in the app in front of you. Double-tap to keep '
                'listening until the next tap.',
      child: Column(
        children: [
          if (_checking)
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else ...[
            _row(
              'Typing into your other apps',
              _typingOn,
              _typingKnown
                  ? 'Off — your words will be copied to the clipboard instead.'
                  : 'Could not be verified on this desktop.',
              fix: !_typingKnown || _typingOn
                  ? null
                  : FilledButton(
                      onPressed: () async {
                        await TypingAccess.enable();
                        await _recheck();
                      },
                      child: const Text('TURN IT ON'),
                    ),
            ),
            _row('Hold-to-record', _keyboardOn,
                'Off — the shortcut still works as tap-to-talk.'),
            _row('Shortcut registered', _shortcutOn,
                'Not registered — add it in Keyboard settings.'),
            if (Platform.isLinux)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Start Straight when I log in',
                  style: TextStyle(fontSize: 13),
                ),
                subtitle: Text(
                  'Keeps the first shortcut press instant',
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                value: _startOnBoot,
                onChanged: (value) async {
                  setState(() => _startOnBoot = value);
                  await SettingsStore.setStartOnBoot(value);
                  await StartupService.setEnabled(value);
                },
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                const SizedBox(width: 36),
                FilledButton.icon(
                  onPressed: _allOk ? null : _recheck,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('RE-CHECK'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}