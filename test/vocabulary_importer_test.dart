import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:straight/core/storage/dictionary_store.dart';
import 'package:straight/core/storage/work_profile_store.dart';
import 'package:straight/core/vocabulary/vocabulary_importer.dart';

void main() {
  late Directory tempDirectory;

  setUpAll(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'straight-vocabulary-',
    );
    Hive.init(tempDirectory.path);
    await Hive.openBox('dictionary');
    await Hive.openBox('workProfiles');
  });

  setUp(() async {
    await Hive.box('dictionary').clear();
    await Hive.box('workProfiles').clear();
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDirectory.delete(recursive: true);
  });

  test('builds spoken aliases for technical names without changing output', () {
    expect(
      VocabularyImporter.aliasesForTerm('moonshine_wrapper.dll'),
      containsAll(<String>['moonshine wrapper dll', 'moonshinewrapperdll']),
    );
    expect(
      VocabularyImporter.aliasesForTerm('MoonshineEngine'),
      contains('Moonshine Engine'),
    );
  });

  test('imports names only and ignores model folders', () async {
    final root = await Directory(
      '${tempDirectory.path}${Platform.pathSeparator}project',
    ).create();
    await File(
      '${root.path}${Platform.pathSeparator}MoonshineEngine.dart',
    ).writeAsString('this contents must never become vocabulary');
    await Directory('${root.path}${Platform.pathSeparator}models').create();
    await File(
      '${root.path}${Platform.pathSeparator}models${Platform.pathSeparator}ignored.bin',
    ).writeAsString('ignored');

    final profileId = await WorkProfileStore.create('Coding');
    final result = await VocabularyImporter().importFolder(
      root.path,
      profileId: profileId,
    );

    final terms = DictionaryStore.getAll()
        .map((entry) => entry['replacement'])
        .toList();
    expect(result.added, greaterThanOrEqualTo(1));
    expect(terms, contains('MoonshineEngine.dart'));
    expect(terms, isNot(contains('ignored.bin')));
  });

  test('maps one application to exactly one enabled profile', () async {
    final codingId = await WorkProfileStore.create('Coding');
    final writingId = await WorkProfileStore.create('Writing');

    await WorkProfileStore.addAppExecutable(codingId, 'Code.exe');
    expect(WorkProfileStore.findForExecutable('code.exe')?['id'], codingId);

    await WorkProfileStore.addAppExecutable(writingId, 'Code.exe');
    expect(WorkProfileStore.findForExecutable('code.exe')?['id'], writingId);
  });
}
