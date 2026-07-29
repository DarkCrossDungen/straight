import 'dart:io';

import '../storage/dictionary_store.dart';
import '../storage/work_profile_store.dart';

class VocabularyImportResult {
  const VocabularyImportResult({required this.added, required this.skipped});

  final int added;
  final int skipped;
}

class VocabularyImporter {
  static const _ignoredFolders = {
    '.git',
    '.dart_tool',
    'build',
    'models',
    'node_modules',
    '.idea',
    '.vscode',
  };
  static const _maxEntries = 10000;

  Future<VocabularyImportResult> importFolder(
    String path, {
    required String profileId,
  }) async {
    final names = <String>[];
    try {
      await for (final entity in Directory(
        path,
      ).list(recursive: true, followLinks: false)) {
        if (names.length >= _maxEntries) break;
        final relative = entity.path
            .substring(path.length)
            .replaceAll('\\', '/');
        final segments = relative.split('/').where((part) => part.isNotEmpty);
        if (segments.any(_shouldIgnoreSegment)) continue;
        final name = _nameFromPath(entity.path);
        if (_shouldIgnoreSegment(name)) continue;
        names.add(name);
      }
    } on FileSystemException {
      rethrow;
    }

    final result = await _saveTerms(
      names,
      profileId: profileId,
      source: 'folder',
    );
    await WorkProfileStore.addSource(profileId, path, folder: true);
    return result;
  }

  Future<VocabularyImportResult> importWordList(
    String path, {
    required String profileId,
  }) async {
    final file = File(path);
    final lines = await file.readAsLines();
    final terms = <_ImportedTerm>[];
    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final cells = line.split(',').map((cell) => cell.trim()).toList();
      final term = cells.first;
      if (term.isEmpty) continue;
      terms.add(_ImportedTerm(term, cells.skip(1)));
    }

    final result = await _saveImportedTerms(
      terms,
      profileId: profileId,
      source: 'wordList',
    );
    await WorkProfileStore.addSource(profileId, path, folder: false);
    return result;
  }

  static List<String> aliasesForTerm(String term) {
    final spaced = term
        .replaceAllMapped(
          RegExp(r'([a-z0-9])([A-Z])'),
          (match) => '${match[1]} ${match[2]}',
        )
        .replaceAll(RegExp(r'[_.\\/-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final compact = spaced.replaceAll(' ', '');
    return <String>{
      term,
      spaced,
      compact,
    }.where((value) => value.isNotEmpty && value != term).toList();
  }

  Future<VocabularyImportResult> _saveTerms(
    Iterable<String> names, {
    required String profileId,
    required String source,
  }) {
    return _saveImportedTerms(
      names
          .where((name) => name.trim().length >= 3)
          .map(
            (name) => _ImportedTerm(name.trim(), aliasesForTerm(name.trim())),
          ),
      profileId: profileId,
      source: source,
    );
  }

  Future<VocabularyImportResult> _saveImportedTerms(
    Iterable<_ImportedTerm> terms, {
    required String profileId,
    required String source,
  }) async {
    var added = 0;
    var skipped = 0;
    final seen = <String>{};
    final existing = DictionaryStore.getAll()
        .where((entry) => entry['profileId'] == profileId)
        .map((entry) => entry['replacement']?.toString().toLowerCase() ?? '')
        .toSet();
    for (final term in terms) {
      final key = term.value.toLowerCase();
      if (!seen.add(key) || !existing.add(key)) {
        skipped++;
        continue;
      }
      await DictionaryStore.addWord(
        term.value,
        term.value,
        profileId: profileId,
        source: source,
        aliases: <String>{...aliasesForTerm(term.value), ...term.aliases},
      );
      added++;
    }
    return VocabularyImportResult(added: added, skipped: skipped);
  }

  static bool _shouldIgnoreSegment(String segment) =>
      segment.startsWith('.') ||
      _ignoredFolders.contains(segment.toLowerCase());

  static String _nameFromPath(String path) {
    final parts = path.split(RegExp(r'[\\/]'));
    return parts.isEmpty ? path : parts.last;
  }
}

class _ImportedTerm {
  const _ImportedTerm(this.value, this.aliases);

  final String value;
  final Iterable<String> aliases;
}
