import 'package:flutter/material.dart';
import 'package:straight/core/storage/dictionary_store.dart';
import 'package:straight/core/app_context.dart';
import 'package:straight/features/dictionary/add_word_dialog.dart';
import 'package:straight/core/storage/work_profile_store.dart';
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
  List<Map> _profiles = [];
  String _profileFilter = 'all';

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
      _profiles = WorkProfileStore.getAll();
      if (_profileFilter == 'global') {
        _entries = _entries
            .where((entry) => entry['profileId'] == null)
            .toList();
      } else if (_profileFilter != 'all') {
        _entries = _entries
            .where((entry) => entry['profileId'] == _profileFilter)
            .toList();
      }
      final query = _searchController.text.trim().toLowerCase();
      _filtered = query.isEmpty
          ? _entries
          : _entries.where((entry) {
              final word = entry['word']?.toString().toLowerCase() ?? '';
              final replacement =
                  entry['replacement']?.toString().toLowerCase() ?? '';
              return word.contains(query) || replacement.contains(query);
            }).toList();
    });
  }

  Future<void> _addWord() async {
    final result = await AddWordDialog.show(
      context,
      profiles: _profiles,
      initialProfileId: _profileFilter == 'all' || _profileFilter == 'global'
          ? null
          : _profileFilter,
    );
    if (result == null) return;
    await DictionaryStore.addWord(
      result['word'] as String,
      result['replacement'] as String,
      aliases: (result['aliases'] as List).cast<String>(),
      profileId: result['profileId'] as String?,
      source: result['source'] as String? ?? 'manual',
    );
    await coordinator.refreshDictionary();
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
          IconButton(
            tooltip: 'Work profiles',
            onPressed: () async {
              await Navigator.pushNamed(context, '/work-profiles');
              _load();
            },
            icon: const Icon(Icons.workspaces_outline),
          ),
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
                DropdownButton<String>(
                  value: _profileFilter,
                  items: [
                    const DropdownMenuItem(value: 'all', child: Text('All')),
                    const DropdownMenuItem(
                      value: 'global',
                      child: Text('Global'),
                    ),
                    for (final profile in _profiles)
                      DropdownMenuItem(
                        value: profile['id'].toString(),
                        child: Text(profile['name'].toString()),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _profileFilter = value);
                    _load();
                  },
                ),
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
          SizedBox(width: 90, child: AppSectionLabel('Source')),
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
            width: 90,
            child: Text(
              entry['profileId'] == null
                  ? 'Global'
                  : entry['source']?.toString() ?? 'Manual',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
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
