import 'package:flutter/material.dart';
import 'package:straight/shared/widgets/app_surface.dart';

class AddWordDialog extends StatefulWidget {
  const AddWordDialog({super.key});

  static Future<Map<String, String>?> show(BuildContext context) {
    return showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const AddWordDialog(),
    );
  }

  @override
  State<AddWordDialog> createState() => _AddWordDialogState();
}

class _AddWordDialogState extends State<AddWordDialog> {
  final _wordController = TextEditingController();
  final _replacementController = TextEditingController();

  @override
  void dispose() {
    _wordController.dispose();
    _replacementController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppSectionLabel('Add Word'),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            TextField(
              controller: _wordController,
              decoration: const InputDecoration(
                labelText: 'SPOKEN PHRASE',
                hintText: 'e.g. btw',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _replacementController,
              decoration: const InputDecoration(
                labelText: 'REPLACEMENT TEXT',
                hintText: 'e.g. by the way',
              ),
            ),
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CANCEL'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    final word = _wordController.text.trim();
                    final replacement = _replacementController.text.trim();
                    if (word.isEmpty || replacement.isEmpty) return;
                    Navigator.pop(context, {
                      'word': word,
                      'replacement': replacement,
                    });
                  },
                  child: const Text('SAVE'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
