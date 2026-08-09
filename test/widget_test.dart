import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
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
