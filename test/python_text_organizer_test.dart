import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:straight/core/app_paths.dart';
import 'package:straight/core/pipeline/python_text_organizer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temporaryData;

  setUp(() async {
    temporaryData = await Directory.systemTemp.createTemp('straight-organizer-');
    useDataDir(temporaryData);
  });

  tearDown(() async {
    useDataDir(null);
    await temporaryData.delete(recursive: true);
  });

  test('organizes STT text using the packaged Python asset', () async {
    final organizer = PythonTextOrganizer();
    final result = await organizer.organize(
      'First improve clarity, second fix grammar, finally remove filler words.',
    );

    expect(
      result,
      '1. Improve clarity\n2. Fix grammar\n3. Remove filler words.',
    );
  });
}
