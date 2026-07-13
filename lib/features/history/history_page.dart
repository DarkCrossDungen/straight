import 'package:flutter/material.dart';
import 'package:straight/core/storage/history_store.dart';
import 'package:straight/shared/theme/colors.dart';
import 'package:straight/shared/widgets/app_surface.dart';
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
      builder: (ctx) => AlertDialog(
        title: const Text('Clear history'),
        content: const Text('Delete every dictation entry?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('DELETE'),
          ),
        ],
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
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('HISTORY'),
        actions: [
          if (_entries.isNotEmpty)
            TextButton.icon(
              onPressed: _clearAll,
              icon: const Icon(Icons.delete_sweep, size: 18),
              label: const Text('CLEAR'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _statsBand(scheme),
            const SizedBox(height: 16),
            SearchField(
              controller: _searchController,
              hintText: 'Search history',
              onChanged: (_) => _load(),
            ),
            const SizedBox(height: 16),
            AppSurface(
              padding: EdgeInsets.zero,
              shadowColor: scheme.primary,
              child: _entries.isEmpty
                  ? const SizedBox(
                      height: 280,
                      child: EmptyState(
                        message: 'No dictation history.',
                        icon: Icons.schedule,
                      ),
                    )
                  : Column(
                      children: [
                        for (final entry in _entries) _entryRow(entry, scheme),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statsBand(ColorScheme scheme) {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            'Total',
            '${_stats['total'] ?? 0}',
            scheme.secondary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard('Today', '${_stats['today'] ?? 0}', scheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            'Week',
            '${_stats['thisWeek'] ?? 0}',
            scheme.surface,
          ),
        ),
      ],
    );
  }

  Widget _statCard(String label, String value, Color color) {
    final scheme = Theme.of(context).colorScheme;
    final useLightText = color == scheme.primary || color == scheme.onSurface;
    return AppSurface(
      color: color,
      shadow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionLabel(label),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: useLightText ? scheme.onPrimary : scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _entryRow(Map entry, ColorScheme scheme) {
    final app = entry['app'];
    final appLabel = app is String && app.isNotEmpty ? '  /  $app' : '';
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.onSurface, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry['text'] ?? '',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_formatTimestamp(entry['timestamp'])}$appLabel',
                  style: TextStyle(
                    fontFamily: 'Space Mono',
                    fontSize: 11,
                    color: scheme.onSurface.withValues(alpha: 0.62),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Delete entry',
            icon: const Icon(
              Icons.delete_outline,
              size: 19,
              color: AppColors.error,
            ),
            onPressed: () => _deleteEntry(entry),
          ),
        ],
      ),
    );
  }
}
