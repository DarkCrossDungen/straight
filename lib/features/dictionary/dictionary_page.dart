import 'package:flutter/material.dart';
import 'package:straight/core/storage/dictionary_store.dart';
import 'package:straight/features/dictionary/add_word_dialog.dart';
import 'package:straight/shared/widgets/app_surface.dart';
import 'package:straight/shared/widgets/empty_state.dart';
import 'package:straight/shared/widgets/search_field.dart';

class DictionaryPage extends StatefulWidget {
  const DictionaryPage({super.key});

  @override
  State<DictionaryPage> createState() => _DictionaryPageState();
}

class _DictionaryPageState extends State<DictionaryPage> {
  List<Map> _entries = [];
  List<Map> _filtered = [];
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _load() {
    setState(() {
      _entries = DictionaryStore.getAll();
      _filtered = _searchController.text.isEmpty
          ? _entries
          : DictionaryStore.search(_searchController.text);
    });
  }

  Future<void> _addWord() async {
    final result = await AddWordDialog.show(context);
    if (result == null) return;
    await DictionaryStore.addWord(result['word']!, result['replacement']!);
    _load();
  }

  Future<void> _toggleEnabled(Map entry) async {
    await DictionaryStore.updateWord(entry['id'], {
      'enabled': !(entry['enabled'] ?? true),
    });
    _load();
  }

  Future<void> _deleteWord(Map entry) async {
    await DictionaryStore.deleteWord(entry['id']);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('DICTIONARY'),
        actions: [
          ElevatedButton.icon(
            onPressed: _addWord,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('ADD'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                AppBadge(label: '${_entries.length} words'),
                const SizedBox(width: 10),
                Expanded(
                  child: SearchField(
                    controller: _searchController,
                    hintText: 'Search words',
                    onChanged: (_) => _load(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AppSurface(
              padding: EdgeInsets.zero,
              shadowColor: scheme.secondary,
              child: _filtered.isEmpty
                  ? const SizedBox(
                      height: 280,
                      child: EmptyState(
                        message: 'No dictionary entries.',
                        icon: Icons.spellcheck,
                      ),
                    )
                  : Column(
                      children: [
                        _tableHeader(scheme),
                        for (final entry in _filtered) _entryRow(entry, scheme),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tableHeader(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.secondary,
        border: Border(bottom: BorderSide(color: scheme.onSurface, width: 1)),
      ),
      child: Row(
        children: const [
          Expanded(flex: 2, child: AppSectionLabel('Word')),
          Expanded(flex: 3, child: AppSectionLabel('Replacement')),
          SizedBox(width: 104, child: AppSectionLabel('Active')),
        ],
      ),
    );
  }

  Widget _entryRow(Map entry, ColorScheme scheme) {
    final enabled = entry['enabled'] ?? true;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.onSurface, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              entry['word'] ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Space Mono',
                fontWeight: FontWeight.w700,
                decoration: enabled ? null : TextDecoration.lineThrough,
                color: enabled
                    ? scheme.onSurface
                    : scheme.onSurface.withValues(alpha: 0.45),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              entry['replacement'] ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface.withValues(
                  alpha: enabled ? 0.78 : 0.42,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 104,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Switch(value: enabled, onChanged: (_) => _toggleEnabled(entry)),
                IconButton(
                  tooltip: 'Delete word',
                  icon: const Icon(Icons.delete_outline, size: 19),
                  onPressed: () => _deleteWord(entry),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
