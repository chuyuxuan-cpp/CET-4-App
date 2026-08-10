import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release metadata declares version and iOS artifact', () async {
    final pubspec = await File('pubspec.yaml').readAsString();
    final iosWorkflow = await File('.github/workflows/build-ios.yml').readAsString();

    expect(pubspec, contains('version: 1.0.1+2'));
    expect(iosWorkflow, contains('name: CET4App-iOS-unsigned'));
    expect(iosWorkflow, contains('path: CET4App.ipa'));
  });

  test('seed database generator defines all Drift tables', () async {
    final generator = File('tools/generate_word_db.py');
    final source = await generator.readAsString();

    for (final table in [
      'words',
      'progress',
      'notebook',
      'quiz_records',
      'settings',
    ]) {
      expect(source, contains('CREATE TABLE $table'));
    }
  });
}
