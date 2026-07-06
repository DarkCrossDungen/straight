import 'package:flutter/material.dart';
import 'package:straight/core/storage/history_store.dart';
import 'package:straight/shared/widgets/empty_state.dart';
import 'package:straight/shared/widgets/search_field.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<Map> _entries = [];
  Map _stats = {};
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
      _stats = HistoryStore.getStats();
      _entries = _searchController.text.isEmpty
          ? HistoryStore.getAll()
          : HistoryStore.search(_searchController.text);
    });
  }

  String _formatTimestamp(dynamic ts) {
    if (ts == null) return '';
    final dt = ts is int
        ? DateTime.fromMillisecondsSinceEpoch(ts)
        : DateTime.tryParse(ts.toString());
    if (dt == null) return ts.toString();
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${dt.month}/${dt.day}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CLEAR HISTORY',
                style: TextStyle(
                  fontFamily: 'SF Mono',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              const Text('Delete all history entries?\nThis cannot be undone.'),
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('CANCEL'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(ctx).colorScheme.error,
                    ),
                    child: const Text('DELETE ALL'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirm != true) return;
    await HistoryStore.clearAll();
    _load();
  }

  Future<void> _deleteEntry(Map entry) async {
    await HistoryStore.deleteEntry(entry['key']);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('HISTORY'),
        actions: [
          if (_entries.isNotEmpty)
            TextButton.icon(
              onPressed: _clearAll,
              icon: const Icon(Icons.delete_sweep, size: 16),
              label: const Text('CLEAR'),
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
                  'RECENT DICTATION',
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
                  'See what was spoken, what was inserted, and how much the app has used today.',
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
          if (_stats.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _statChip(colors, '${_stats['total'] ?? 0} TOTAL'),
                _statChip(colors, '${_stats['today'] ?? 0} TODAY'),
                _statChip(colors, '${_stats['thisWeek'] ?? 0} THIS WEEK'),
              ],
            ),
          const SizedBox(height: 16),
          SearchField(
            controller: _searchController,
            hintText: 'Search history...',
            onChanged: (_) => _load(),
          ),
          const SizedBox(height: 12),
          if (_entries.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 20),
              child: EmptyState(
                message: 'No dictation history yet.',
                icon: Icons.history,
              ),
            )
          else
            ..._entries.map((entry) {
              return Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: colors.onSurface, width: 1),
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                  title: Text(
                    entry['text'] ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14),
                  ),
                  subtitle: Text(
                    '${_formatTimestamp(entry['timestamp'])}${entry['app'] != null && (entry['app'] as String).isNotEmpty ? '  •  ${entry['app']}' : ''}',
                    style: const TextStyle(fontFamily: 'SF Mono', fontSize: 11),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed: () => _deleteEntry(entry),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _statChip(ColorScheme colors, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: colors.onSurface, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'SF Mono',
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: colors.onSurface,
        ),
      ),
    );
  }
}
