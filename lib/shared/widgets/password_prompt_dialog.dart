import 'package:flutter/material.dart';
import 'package:straight/core/hotkey/input_access.dart';

/// Straight's own authorization window. The password goes to sudo for
/// validation and is wiped as soon as the dialog closes; it is never written
/// to disk or kept in memory beyond the attempt.
Future<bool> requestInputAccess(BuildContext context) async {
  String? error;
  while (true) {
    if (!context.mounted) return false;
    final password = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _PasswordPrompt(error: error),
    );
    if (password == null || password.isEmpty) return false;
    final result = await InputAccess.grantWithPassword(password);
    switch (result) {
      case InputGrantResult.granted:
        return true;
      case InputGrantResult.wrongPassword:
        error = 'That password was not accepted. Try again.';
      case InputGrantResult.failed:
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not apply the change on this system.'),
            ),
          );
        }
        return false;
    }
  }
}

class _PasswordPrompt extends StatefulWidget {
  final String? error;
  const _PasswordPrompt({this.error});

  @override
  State<_PasswordPrompt> createState() => _PasswordPromptState();
}

class _PasswordPromptState extends State<_PasswordPrompt> {
  final _controller = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_controller.text.isEmpty) return;
    setState(() => _busy = true);
    Navigator.pop(context, _controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Allow keyboard access'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Straight needs to read the keyboard once, so it can tell holding '
              'the shortcut from tapping it. Your password unlocks exactly '
              'this change:',
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: scheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '• Add your user to the "input" group\n'
              '• Let your user read the keyboard devices',
              style: TextStyle(
                fontSize: 13,
                height: 1.6,
                color: scheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your password is checked by the system and never saved.',
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              obscureText: true,
              autofocus: true,
              enabled: !_busy,
              decoration: InputDecoration(
                labelText: 'Your password',
                errorText: widget.error,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('NOT NOW'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: const Text('AUTHORIZE'),
        ),
      ],
    );
  }
}