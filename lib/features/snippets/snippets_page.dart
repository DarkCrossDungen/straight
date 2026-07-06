import 'package:flutter/material.dart';
import 'package:straight/core/storage/snippets_store.dart';
import 'package:straight/features/snippets/add_snippet_dialog.dart';
import 'package:straight/shared/widgets/empty_state.dart';
import 'package:straight/shared/widgets/search_field.dart';
import 'package:straight/core/injection/text_injector.dart';
import 'package:flutter/services.dart';

class SnippetsPage extends StatefulWidget {
  const SnippetsPage({super.key});

  @override
  State<SnippetsPage> createState() => _SnippetsPageState();
}

class _SnippetsPageState extends State<SnippetsPage> {
  List<Map> _entries = [];
  List<Map> _filtered = [];
  final _searchController = TextEditingController();
  final _textInjector = TextInjector();

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
      _entries = SnippetsStore.getAll();
      _filtered = _searchController.text.isEmpty
          ? _entries
          : SnippetsStore.search(_searchController.text);
    });
  }

  Future<void> _addSnippet() async {
    final result = await AddSnippetDialog.show(context);
    if (result == null) return;
    await SnippetsStore.addSnippet(result['name']!, result['content']!);
    _load();
  }

  Future<void> _editSnippet(Map snippet) async {
    final result = await AddSnippetDialog.show(
      context,
      initialName: snippet['name'] as String?,
      initialContent: snippet['content'] as String?,
    );
    if (result == null) return;
    await SnippetsStore.updateSnippet(snippet['id'], {
      'name': result['name'],
      'content': result['content'],
    });
    _load();
  }

  Future<void> _deleteSnippet(Map snippet) async {
    await SnippetsStore.deleteSnippet(snippet['id']);
    _load();
  }

  void _insertSnippet(Map snippet) {
    final content = snippet['content'] as String? ?? '';
    if (content.isEmpty) return;
    _textInjector.inject(content);
    Clipboard.setData(ClipboardData(text: content));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Snippet inserted'),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(label: 'OK', onPressed: () {}),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('SNIPPETS'),
        actions: [
          TextButton(
            onPressed: _addSnippet,
            child: const Text('+ ADD'),
          ),
        ],
      ),
      body: Column(
        children: [
          SearchField(
            controller: _searchController,
            hintText: 'Search snippets...',
            onChanged: (_) => _load(),
          ),
          Expanded(
            child: _filtered.isEmpty
                ? const EmptyState(
                    message: 'No snippets yet.\nTap + ADD to create one.',
                    icon: Icons.content_paste,
                  )
                : ListView.builder(
                    itemCount: _filtered.length,
                    itemBuilder: (ctx, i) {
                      final snippet = _filtered[i];
                      return Container(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: colors.onSurface, width: 1),
                          ),
                        ),
                        child: ListTile(
                          onTap: () => _insertSnippet(snippet),
                          onLongPress: () => _editSnippet(snippet),
                          title: Text(
                            snippet['name'] ?? '',
                            style: const TextStyle(
                              fontFamily: 'SF Mono',
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            snippet['content'] ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: colors.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            onPressed: () => _deleteSnippet(snippet),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
