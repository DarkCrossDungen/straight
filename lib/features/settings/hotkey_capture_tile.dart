import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:straight/core/app_context.dart';
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

  String _formatHotkey(Map hk) {
    final parts = <String>[];
    if (hk['alt'] == true) parts.add('Alt');
    if (hk['ctrl'] == true) parts.add('Ctrl');
    if (hk['shift'] == true) parts.add('Shift');
    if (hk['meta'] == true) parts.add('Win');
    parts.add(hk['key'] ?? 'Space');
    return parts.join(' + ');
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _isRecording ? _handleKeyEvent : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 0),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
          leading: const Icon(Icons.keyboard, size: 20),
          title: Text(_isRecording ? 'Press your hotkey' : 'Hotkey'),
          subtitle: Text(
            _formatHotkey(_hotkey),
            style: TextStyle(
              fontFamily: 'SF Mono',
              fontSize: 14,
              fontWeight: FontWeight.w500,
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
        unawaited(coordinator.hotkeyService.reloadFromSettings());
      });
    }
    return KeyEventResult.handled;
  }
}
