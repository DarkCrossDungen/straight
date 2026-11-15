import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'package:straight/core/app_context.dart';
import 'package:straight/core/hotkey/desktop_shortcut_service.dart';
import 'package:straight/core/storage/settings_store.dart';

class HotkeyCaptureTile extends StatefulWidget {
  const HotkeyCaptureTile({super.key});

  @override
  State<HotkeyCaptureTile> createState() => _HotkeyCaptureTileState();
}

class _HotkeyCaptureTileState extends State<HotkeyCaptureTile> {
  Map _hotkey = {};
  bool _isRecording = false;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _hotkey = SettingsStore.getHotkey();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _isRecording ? _handleKeyEvent : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 0,
                vertical: 2,
              ),
              leading: const Icon(Icons.keyboard, size: 20),
              title: Text(_isRecording ? 'Press your hotkey' : 'Hotkey'),
              subtitle: Text(
                formatHotkey(_hotkey),
                style: TextStyle(
                  fontFamily: 'Space Mono',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _isRecording ? colors.primary : colors.onSurface,
                ),
              ),
              trailing: _isRecording
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.edit, size: 16),
              onTap: _startRecording,
            ),
          ),
          // Wayland will not hand a global key grab to an app, so the desktop
          // owns the shortcut and Straight is told when it is pressed.
          if (Platform.isLinux) _DesktopShortcutRow(hotkey: _hotkey),
        ],
      ),
    );
  }

  void _startRecording() {
    setState(() => _isRecording = true);
    _focusNode.requestFocus();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent && event is! KeyRepeatEvent) {
      final hw = HardwareKeyboard.instance;
      final key = event.logicalKey;

      if (key == LogicalKeyboardKey.alt ||
          key == LogicalKeyboardKey.control ||
          key == LogicalKeyboardKey.shift ||
          key == LogicalKeyboardKey.meta) {
        return KeyEventResult.handled;
      }

      final hotkey = {
        'alt': hw.isAltPressed,
        'ctrl': hw.isControlPressed,
        'shift': hw.isShiftPressed,
        'meta': hw.isMetaPressed,
        'key': key.keyLabel,
      };

      setState(() {
        _hotkey = hotkey;
        _isRecording = false;
      });
      SettingsStore.setHotkey(hotkey).then((_) {
        unawaited(coordinator.reloadHotkey());
        if (Platform.isLinux) {
          // Keep the desktop shortcut in step with the captured hotkey.
          unawaited(DesktopShortcutService.register(hotkey));
        }
      });
    }
    return KeyEventResult.handled;
  }
}

String formatHotkey(Map hk) {
  final parts = <String>[];
  if (hk['alt'] == true) parts.add('Alt');
  if (hk['ctrl'] == true) parts.add('Ctrl');
  if (hk['shift'] == true) parts.add('Shift');
  if (hk['meta'] == true) parts.add('Win');
  parts.add(hk['key'] ?? 'Space');
  return parts.join(' + ');
}

/// Reports whether the desktop shortcut is live, and makes it live in one
/// click. Only shown on Linux, where apps may not grab keys themselves.
class _DesktopShortcutRow extends StatefulWidget {
  const _DesktopShortcutRow({required this.hotkey});

  final Map hotkey;

  @override
  State<_DesktopShortcutRow> createState() => _DesktopShortcutRowState();
}

class _DesktopShortcutRowState extends State<_DesktopShortcutRow> {
  bool? _supported;
  String? _binding;
  String? _command;
  String? _conflict;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_probe());
  }

  @override
  void didUpdateWidget(_DesktopShortcutRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hotkey != widget.hotkey) unawaited(_probe());
  }

  Future<void> _probe() async {
    final supported = await DesktopShortcutService.isSupported();
    final binding = DesktopShortcutService.bindingFor(widget.hotkey);
    final registered = supported
        ? await DesktopShortcutService.registeredBinding()
        : null;
    final command = supported
        ? await DesktopShortcutService.registeredCommand()
        : null;
    final conflict = supported
        ? await DesktopShortcutService.findConflict(binding)
        : null;
    if (!mounted) return;
    setState(() {
      _supported = supported;
      _binding = registered;
      _command = command;
      _conflict = conflict;
    });
  }

  Future<void> _register() async {
    setState(() => _busy = true);
    final ok = await DesktopShortcutService.register(widget.hotkey);
    await _probe();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = ok
          ? null
          : 'The desktop refused to store the shortcut. Use the manual steps '
                'below.';
    });
  }

  bool get _isLive {
    if (_binding == null || _command == null) return false;
    return _binding == DesktopShortcutService.bindingFor(widget.hotkey) &&
        _command == DesktopShortcutService.toggleCommand;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_supported == null) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(52, 0, 16, 12),
        child: SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final needsSetup = !_isLive || _conflict != null;
    final status = !_supported!
        ? 'This desktop keeps its shortcuts somewhere Straight cannot write. '
              'Follow the manual steps below once.'
        : _isLive && _conflict != null
        ? 'Working, but ${_conflict!} also uses '
              '${formatHotkey(widget.hotkey)}. Fix the shortcut to hand the '
              'key to Straight.'
        : _isLive
        ? 'Shortcut is live — press ${formatHotkey(widget.hotkey)} in any app.'
        : _binding == null
        ? 'Not registered yet. One click adds it to your desktop.'
        : 'Registered, but not for this hotkey or this copy of Straight.';

    return Padding(
      padding: const EdgeInsets.fromLTRB(52, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                needsSetup ? Icons.error_outline : Icons.check_circle,
                size: 16,
                color: needsSetup ? scheme.tertiary : Colors.green.shade400,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurface.withValues(alpha: 0.72),
                  ),
                ),
              ),
              if (needsSetup && _supported!)
                _busy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : FilledButton.tonal(
                        onPressed: _register,
                        child: Text(
                          _binding == null ? 'Set up shortcut' : 'Fix shortcut',
                        ),
                      ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _error!,
                style: TextStyle(fontSize: 12, color: scheme.error),
              ),
            ),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 4),
              iconColor: scheme.onSurface.withValues(alpha: 0.6),
              collapsedIconColor: scheme.onSurface.withValues(alpha: 0.6),
              title: Text(
                'Set it up yourself',
                style: TextStyle(fontSize: 12, color: scheme.onSurface),
              ),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '1. Open Keyboard settings (button below).\n'
                    '2. Add a Custom Shortcut.\n'
                    '3. Name it: Straight dictation\n'
                    '4. Command: copy the line below.\n'
                    '5. Shortcut: press ${formatHotkey(widget.hotkey)}.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: scheme.onSurface.withValues(alpha: 0.72),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  DesktopShortcutService.toggleCommand,
                  style: TextStyle(
                    fontFamily: 'Space Mono',
                    fontSize: 11,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: DesktopShortcutService.openKeyboardSettings,
                  child: const Text('Open keyboard settings'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
