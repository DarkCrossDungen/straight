import 'package:flutter/material.dart';

import 'package:straight/core/injection/typing_access.dart';

/// Straight's own authorization window for typing into other apps. Flipping
/// the accessibility switch is a per-user gsettings change — no password, no
/// restart, nothing written to disk.
Future<bool> requestTypingAccess(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _TypingPrompt(),
  );
  if (confirmed != true) return false;
  return await TypingAccess.enable() == true;
}

class _TypingPrompt extends StatelessWidget {
  const _TypingPrompt();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Turn typing access back on'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Straight types your words through your desktop\'s '
              'accessibility channel. The switch is currently off, so nothing '
              'will be typed into other apps.',
            ),
            const SizedBox(height: 16),
            Text(
              'Turn it on in one click — Straight does the rest.',
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('NOT NOW'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('TURN IT ON'),
        ),
      ],
    );
  }
}
