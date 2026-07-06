import 'package:flutter/material.dart';
import 'package:straight/core/storage/dictionary_store.dart';
import 'package:straight/features/dictionary/add_word_dialog.dart';
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
    await DictionaryStore.updateWord(entry['id'], {'enabled': !(entry['enabled'] ?? true)});
    _load();
  }

  Future<void> _deleteWord(Map entry) async {
    await DictionaryStore.deleteWord(entry['id']);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('DICTIONARY'),
        actions: [
          TextButton.icon(
            onPressed: _addWord,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('ADD'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: colors.onSurface, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CUSTOM WORDS',
                  style: TextStyle(
                    fontFamily: 'SF Mono',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface.withValues(alpha: 0.55),
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add replacements for names, acronyms, and terms you want Straight to remember.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: colors.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SearchField(
            controller: _searchController,
            hintText: 'Search dictionary...',
            onChanged: (_) => _load(),
          ),
          const SizedBox(height: 12),
          if (_filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 20),
              child: EmptyState(
                message: 'No dictionary entries yet.\nTap ADD to create one.',
                icon: Icons.book_outlined,
              ),
            )
          else
            ..._filtered.map((entry) {
              final enabled = entry['enabled'] ?? true;
              return Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: colors.onSurface, width: 1),
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                  title: Text(
                    entry['word'] ?? '',
                    style: TextStyle(
                      fontFamily: 'SF Mono',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      decoration: enabled ? null : TextDecoration.lineThrough,
                      color: enabled ? colors.onSurface : colors.onSurface.withValues(alpha: 0.45),
                    ),
                  ),
                  subtitle: Text(
                    entry['replacement'] ?? '',
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                  trailing: Wrap(
                    spacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Switch(
                        value: enabled,
                        onChanged: (_) => _toggleEnabled(entry),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        onPressed: () => _deleteWord(entry),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
