import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:straight/core/app_context.dart';
import 'package:straight/core/storage/dictionary_store.dart';
import 'package:straight/core/storage/settings_store.dart';
import 'package:straight/core/storage/work_profile_store.dart';
import 'package:straight/core/vocabulary/vocabulary_importer.dart';
import 'package:straight/shared/widgets/app_surface.dart';
import 'package:straight/shared/widgets/empty_state.dart';

class WorkProfilesPage extends StatefulWidget {
  const WorkProfilesPage({super.key});

  @override
  State<WorkProfilesPage> createState() => _WorkProfilesPageState();
}

class _WorkProfilesPageState extends State<WorkProfilesPage> {
  final VocabularyImporter _importer = VocabularyImporter();
  List<Map> _profiles = [];
  bool _automaticSwitching = SettingsStore.getAutomaticProfileSwitching();
  String? _busyProfileId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    if (!mounted) return;
    setState(() => _profiles = WorkProfileStore.getAll());
  }

  Future<void> _createProfile() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('NEW WORK PROFILE'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Coding'),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('CREATE'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    await WorkProfileStore.create(name);
    _load();
  }

  Future<void> _importFolder(Map profile) async {
    final path = await FilePicker.getDirectoryPath(
      dialogTitle: 'Choose a project folder',
      lockParentWindow: true,
    );
    if (path == null) return;
    await _runImport(
      profile,
      () => _importer.importFolder(path, profileId: profile['id'].toString()),
    );
  }

  Future<void> _importList(Map profile) async {
    final selection = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['txt', 'csv'],
      dialogTitle: 'Choose a word list',
      lockParentWindow: true,
    );
    final files = selection?.files;
    if (files == null || files.length != 1) return;
    final path = files.single.path;
    if (path == null) return;
    await _runImport(
      profile,
      () => _importer.importWordList(path, profileId: profile['id'].toString()),
    );
  }

  Future<void> _runImport(
    Map profile,
    Future<VocabularyImportResult> Function() action,
  ) async {
    setState(() => _busyProfileId = profile['id'].toString());
    try {
      final result = await action();
      await coordinator.refreshDictionary();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Added ${result.added} terms. Skipped ${result.skipped}.',
          ),
        ),
      );
      _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not import that local source.')),
      );
    } finally {
      if (mounted) setState(() => _busyProfileId = null);
    }
  }

  Future<void> _mapLastApp(Map profile) async {
    final app = coordinator.lastActiveApp;
    if (app == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dictate once into the target app first.'),
        ),
      );
      return;
    }
    await WorkProfileStore.addAppExecutable(profile['id'].toString(), app);
    _load();
  }

  Future<void> _deleteProfile(Map profile) async {
    await DictionaryStore.deleteForProfile(profile['id'].toString());
    await WorkProfileStore.delete(profile['id'].toString());
    await coordinator.refreshDictionary();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WORK PROFILES'),
        actions: [
          IconButton(
            tooltip: 'Create profile',
            onPressed: _createProfile,
            icon: const Icon(Icons.add),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppSurface(
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Automatic app profiles'),
              subtitle: const Text(
                'Use a mapped vocabulary when its app is active.',
              ),
              value: _automaticSwitching,
              onChanged: (value) async {
                setState(() => _automaticSwitching = value);
                await SettingsStore.setAutomaticProfileSwitching(value);
              },
            ),
          ),
          const SizedBox(height: 16),
          if (_profiles.isEmpty)
            const SizedBox(
              height: 320,
              child: EmptyState(
                icon: Icons.workspaces_outline,
                message: 'Create a profile for private work vocabulary.',
              ),
            ),
          for (final profile in _profiles) ...[
            _profileCard(profile),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _profileCard(Map profile) {
    final profileId = profile['id'].toString();
    final isBusy = _busyProfileId == profileId;
    final terms = DictionaryStore.getAll()
        .where((entry) => entry['profileId'] == profileId)
        .length;
    final apps = (profile['appExecutables'] as Iterable? ?? const [])
        .map((item) => item.toString())
        .toList();
    final sources =
        (profile['sourceFolders'] as Iterable? ?? const []).length +
        (profile['sourceLists'] as Iterable? ?? const []).length;

    return AppSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  profile['name'].toString(),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Switch(
                value: profile['enabled'] == true,
                onChanged: (value) async {
                  await WorkProfileStore.update(profileId, {'enabled': value});
                  _load();
                },
              ),
            ],
          ),
          Text('$terms terms from $sources local sources'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final app in apps)
                InputChip(
                  label: Text(app),
                  onDeleted: () async {
                    await WorkProfileStore.removeAppExecutable(profileId, app);
                    _load();
                  },
                ),
              if (apps.isEmpty) const Chip(label: Text('No mapped apps')),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: isBusy ? null : () => _importFolder(profile),
                icon: const Icon(Icons.folder_outlined),
                label: const Text('IMPORT FOLDER'),
              ),
              OutlinedButton.icon(
                onPressed: isBusy ? null : () => _importList(profile),
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('IMPORT LIST'),
              ),
              OutlinedButton.icon(
                onPressed: isBusy ? null : () => _mapLastApp(profile),
                icon: const Icon(Icons.apps_outlined),
                label: const Text('MAP LAST APP'),
              ),
              IconButton(
                tooltip: 'Delete profile',
                onPressed: isBusy ? null : () => _deleteProfile(profile),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          if (isBusy) ...[
            const SizedBox(height: 14),
            const LinearProgressIndicator(),
          ],
        ],
      ),
    );
  }
}
