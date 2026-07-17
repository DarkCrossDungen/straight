import 'package:flutter/material.dart';
import 'package:straight/core/app_context.dart';
import 'package:straight/shared/widgets/app_surface.dart';

class AddWordDialog extends StatefulWidget {
  const AddWordDialog({super.key});

  static Future<Map<String, dynamic>?> show(BuildContext context) {
    return showDialog<Map<String, dynamic>>(
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
  final _aliasesController = TextEditingController();
  bool _isCapturing = false;
  String? _captureMessage;

  @override
  void dispose() {
    if (_isCapturing) coordinator.cancelPronunciationCapture();
    _wordController.dispose();
    _replacementController.dispose();
    _aliasesController.dispose();
    super.dispose();
  }

  Future<void> _capturePronunciation() async {
    if (_isCapturing) {
      coordinator.cancelPronunciationCapture();
      setState(() {
        _isCapturing = false;
        _captureMessage = 'Capture cancelled.';
      });
      return;
    }

    if (_replacementController.text.trim().isEmpty) {
      setState(() {
        _captureMessage = 'Enter the exact word Straight should type first.';
      });
      return;
    }

    setState(() {
      _isCapturing = true;
      _captureMessage = 'Use your normal hotkey, say the word, then release.';
    });
    final captured = await coordinator.capturePronunciation();
    if (!mounted) return;

    setState(() {
      _isCapturing = false;
      if (captured == null || captured.trim().isEmpty) {
        _captureMessage = 'No clear pronunciation was captured. Try again.';
        return;
      }

      final aliases = <String>{
        ..._aliasesController.text
            .split(',')
            .map((alias) => alias.trim())
            .where((alias) => alias.isNotEmpty),
        captured.trim(),
      };
      _aliasesController.text = aliases.join(', ');
      _captureMessage = 'Learned: "${captured.trim()}".';
    });
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
              controller: _replacementController,
              decoration: const InputDecoration(
                labelText: 'WORD TO TYPE',
                hintText: 'e.g. Khrisshy',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _wordController,
              decoration: const InputDecoration(
                labelText: 'SPOKEN PHRASE (OPTIONAL)',
                hintText: 'e.g. krishi',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _aliasesController,
              decoration: const InputDecoration(
                labelText: 'WHAT WHISPER HEARS (OPTIONAL)',
                hintText: 'e.g. krishi, crushy',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            Text(
              'Add the spelling Whisper gives for your pronunciation. Separate alternatives with commas.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _capturePronunciation,
              icon: Icon(_isCapturing ? Icons.stop_circle_outlined : Icons.mic_none),
              label: Text(_isCapturing ? 'CANCEL CAPTURE' : 'RECORD PRONUNCIATION'),
            ),
            if (_captureMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _captureMessage!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
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
                    final replacement = _replacementController.text.trim();
                    final word = _wordController.text.trim();
                    if (replacement.isEmpty) return;
                    Navigator.pop(context, {
                      'word': word.isEmpty ? replacement : word,
                      'replacement': replacement,
                      'aliases': _aliasesController.text
                          .split(',')
                          .map((alias) => alias.trim())
                          .where((alias) => alias.isNotEmpty)
                          .toList(),
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
