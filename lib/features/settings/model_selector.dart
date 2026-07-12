import 'package:flutter/material.dart';
import 'package:straight/core/app_context.dart';
import 'package:straight/core/storage/settings_store.dart';

class ModelSelector extends StatefulWidget {
  const ModelSelector({super.key});

  @override
  State<ModelSelector> createState() => _ModelSelectorState();
}

class _ModelSelectorState extends State<ModelSelector> {
  static const _sttOptions = <_ModelOption>[
    _ModelOption(
      id: 'whisper-base',
      title: 'Whisper Base',
      subtitle: 'Safer start, lighter memory',
    ),
    _ModelOption(
      id: 'whisper-small',
      title: 'Whisper Small',
      subtitle: 'Better accuracy, more RAM',
    ),
    _ModelOption(
      id: 'whisper-medium',
      title: 'Whisper Medium',
      subtitle: 'Best accuracy, heaviest',
    ),
    _ModelOption(
      id: 'qwen3-asr-0.6b',
      title: 'Qwen3-ASR 0.6B',
      subtitle: 'Target model for the final build',
    ),
  ];

  static const _llmOptions = <_ModelOption>[
    _ModelOption(
      id: 'none',
      title: 'Rules only',
      subtitle: 'Fastest and safest',
    ),
    _ModelOption(
      id: 'qwen2.5-0.5b',
      title: 'Qwen2.5 0.5B',
      subtitle: 'Small helper model for polish',
    ),
  ];

  String _sttModel = SettingsStore.getSttModel();
  String _llmModel = SettingsStore.getLlmModel();

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
      leading: const Icon(Icons.model_training, size: 20),
      title: const Text('Models'),
      subtitle: Text('Speech: ${_labelFor(_sttOptions, _sttModel)}  |  Cleanup: ${_labelFor(_llmOptions, _llmModel)}'),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: _showModelDialog,
    );
  }

  String _labelFor(List<_ModelOption> options, String id) {
    for (final option in options) {
      if (option.id == id) return option.title;
    }
    return options.first.title;
  }

  Future<void> _showModelDialog() async {
    final stt = await showDialog<String>(
      context: context,
      builder: (_) => _ChoiceDialog(
        title: 'SPEECH MODEL',
        options: _sttOptions,
        selectedId: _sttModel,
      ),
    );

    if (!mounted || stt == null) return;

    final llm = await showDialog<String>(
      context: context,
      builder: (_) => _ChoiceDialog(
        title: 'CLEANUP MODE',
        options: _llmOptions,
        selectedId: _llmModel,
      ),
    );

    if (!mounted || llm == null) return;

    setState(() {
      _sttModel = stt;
      _llmModel = llm;
    });

    await SettingsStore.setSttModel(_sttModel);
    await SettingsStore.setLlmModel(_llmModel);
    await coordinator.refreshSpeechModel();
    await coordinator.refreshCleanupModel();
  }
}

class _ChoiceDialog extends StatefulWidget {
  final String title;
  final List<_ModelOption> options;
  final String selectedId;

  const _ChoiceDialog({
    required this.title,
    required this.options,
    required this.selectedId,
  });

  @override
  State<_ChoiceDialog> createState() => _ChoiceDialogState();
}

class _ChoiceDialogState extends State<_ChoiceDialog> {
  late String _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.selectedId;
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
            Text(
              widget.title,
              style: const TextStyle(
                fontFamily: 'SF Mono',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),
            RadioGroup<String>(
              groupValue: _selectedId,
              onChanged: (value) {
                if (value == null) return;
                setState(() => _selectedId = value);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final option in widget.options)
                    RadioListTile<String>(
                      value: option.id,
                      title: Text(option.title),
                      subtitle: Text(option.subtitle),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
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
                  onPressed: () => Navigator.pop(context, _selectedId),
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

class _ModelOption {
  final String id;
  final String title;
  final String subtitle;

  const _ModelOption({
    required this.id,
    required this.title,
    required this.subtitle,
  });
}
