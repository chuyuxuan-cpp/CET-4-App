import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cet4_app/core/database/database.dart';
import 'package:cet4_app/core/database/db_initializer.dart';

/// Provides a singleton [AppDatabase] instance.
/// The database is opened lazily after the DB initializer copies the word-bank
/// file from assets into the documents directory.
final databaseProvider = FutureProvider<AppDatabase>((ref) async {
  await DatabaseInitializer.initialize();
  return AppDatabase();
});
