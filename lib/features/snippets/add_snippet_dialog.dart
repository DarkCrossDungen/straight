import 'package:flutter/material.dart';

class AddSnippetDialog extends StatefulWidget {
  final String? initialName;
  final String? initialContent;

  const AddSnippetDialog({super.key, this.initialName, this.initialContent});

  static Future<Map<String, String>?> show(
    BuildContext context, {
    String? initialName,
    String? initialContent,
  }) {
    return showDialog<Map<String, String>>(
      context: context,
      builder: (_) => AddSnippetDialog(
        initialName: initialName,
        initialContent: initialContent,
      ),
    );
  }

  @override
  State<AddSnippetDialog> createState() => _AddSnippetDialogState();
}

class _AddSnippetDialogState extends State<AddSnippetDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _contentController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _contentController = TextEditingController(text: widget.initialContent ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialName != null;
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isEditing ? 'EDIT SNIPPET' : 'ADD SNIPPET',
              style: const TextStyle(
                fontFamily: 'SF Mono',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'NAME',
                hintText: 'e.g. Email signature',
              ),
              autofocus: !isEditing,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contentController,
              decoration: const InputDecoration(
                labelText: 'CONTENT',
                hintText: 'e.g. Best regards,\nJohn Doe',
              ),
              maxLines: 4,
              autofocus: isEditing,
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
                    final name = _nameController.text.trim();
                    final content = _contentController.text.trim();
                    if (name.isEmpty || content.isEmpty) return;
                    Navigator.pop(context, {'name': name, 'content': content});
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
