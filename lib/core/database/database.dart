import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

part 'database.g.dart';

/// 词库表（只读，预置）
class Words extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get word => text().withLength(min: 1, max: 100)();
  TextColumn get phonetic => text().nullable()();
  TextColumn get pos => text().nullable()();
  TextColumn get meaning => text().nullable()();
  TextColumn get example => text().nullable()();
  TextColumn get book => text().withDefault(const Constant('cet4'))();
  IntColumn get seq => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 学习进度表
class Progress extends Table {
  IntColumn get wordId => integer().references(Words, #id)();
  TextColumn get book => text().withDefault(const Constant('cet4'))();
  DateTimeColumn get firstLearnedAt => dateTime().nullable()();
  IntColumn get stage => integer().withDefault(const Constant(1))(); // 1/3/7/99
  DateTimeColumn get nextReviewAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {wordId, book};
}

/// 生词本
class Notebook extends Table {
  IntColumn get wordId => integer().references(Words, #id)();
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get source =>
      text().withDefault(const Constant('manual'))(); // manual / unknown

  @override
  Set<Column> get primaryKey => {wordId};
}

/// 答题记录
class QuizRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get answeredAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get wordId => integer().references(Words, #id)();
  TextColumn get quizType => text()(); // review / notebook
  TextColumn get direction => text()(); // en2cn / cn2en
  BoolColumn get correct => boolean()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 设置（单条记录表）
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [Words, Progress, Notebook, QuizRecords, Settings])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
      },
    );
  }

  // --- Words Queries ---

  /// 获取当前词书中未学习的单词，按 seq 排序，限制数量
  Future<List<Word>> getNewWords(String book, int limit) {
    final progressSubquery = selectOnly(progress)
      ..addColumns([progress.wordId]);
    progressSubquery.where(progress.book.equals(book));

    return (select(words)
          ..where(
            (t) => t.book.equals(book) & t.id.isNotInQuery(progressSubquery),
          )
          ..orderBy([(t) => OrderingTerm(expression: t.seq)])
          ..limit(limit))
        .get();
  }

  /// Returns a stable page of words, optionally filtered by word or meaning.
  Future<List<Word>> getWordbookPage({
    required String book,
    String? query,
    required int offset,
    required int limit,
  }) {
    if (offset < 0) {
      throw ArgumentError.value(offset, 'offset', 'Must not be negative');
    }
    if (limit <= 0) {
      throw ArgumentError.value(limit, 'limit', 'Must be greater than zero');
    }

    final normalizedQuery = query?.trim() ?? '';
    final statement = select(words)..where((t) => t.book.equals(book));
    if (normalizedQuery.isNotEmpty) {
      final pattern = '%$normalizedQuery%';
      statement.where((t) => t.word.like(pattern) | t.meaning.like(pattern));
    }

    return (statement
          ..orderBy([
            (t) => OrderingTerm(expression: t.seq),
            (t) => OrderingTerm(expression: t.id),
          ])
          ..limit(limit, offset: offset))
        .get();
  }

  /// 获取今日需要复习的单词 ID 列表
  Future<List<int>> getReviewWordIds(String book, DateTime today) {
    final cutoff = DateTime(today.year, today.month, today.day + 1);
    return (selectOnly(progress)
          ..addColumns([progress.wordId])
          ..where(
            progress.book.equals(book) &
                progress.nextReviewAt.isSmallerThanValue(cutoff) &
                progress.stage.isNotValue(99),
          ))
        .map((row) => row.read(progress.wordId)!)
        .get();
  }

  /// 获取复习单词的详细信息
  Future<List<Word>> getReviewWords(List<int> wordIds) {
    return (select(words)..where((t) => t.id.isIn(wordIds))).get();
  }

  /// 获取指定单词的当前复习阶段，返回 wordId → stage 的映射
  Future<Map<int, int>> getReviewStages(String book, List<int> wordIds) {
    return (selectOnly(progress)
          ..addColumns([progress.wordId, progress.stage])
          ..where(progress.book.equals(book) & progress.wordId.isIn(wordIds)))
        .map(
          (row) =>
              MapEntry(row.read(progress.wordId)!, row.read(progress.stage)!),
        )
        .get()
        .then((entries) {
          final result = <int, int>{};
          for (final e in entries) {
            result[e.key] = e.value;
          }
          return result;
        });
  }

  /// 根据 ID 获取单词
  Future<Word?> getWordById(int id) {
    return (select(words)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// 获取随机单词（用于干扰项），排除指定 IDs
  Future<List<Word>> getRandomWords(
    String book,
    int count,
    List<int> excludeIds,
  ) {
    final q = select(words)
      ..where((t) => t.book.equals(book) & t.id.isNotIn(excludeIds));
    return q.get().then((all) {
      all.shuffle();
      return all.take(count).toList();
    });
  }

  /// 获取今日新词学习数量
  Future<int> getTodayNewCount(String book, DateTime today) {
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = DateTime(today.year, today.month, today.day + 1);
    return (selectOnly(progress)
          ..addColumns([progress.wordId])
          ..where(
            progress.book.equals(book) &
                progress.firstLearnedAt.isBetweenValues(startOfDay, endOfDay),
          ))
        .map((row) => row.read(progress.wordId)!)
        .get()
        .then((rows) => rows.length);
  }

  // --- Progress Mutations ---

  /// 创建或更新学习进度
  Future<void> upsertProgress(
    int wordId,
    String book,
    int stage,
    DateTime nextReview,
  ) {
    return into(progress).insertOnConflictUpdate(
      ProgressCompanion(
        wordId: Value(wordId),
        book: Value(book),
        stage: Value(stage),
        nextReviewAt: Value(nextReview),
        firstLearnedAt: Value(DateTime.now()),
      ),
    );
  }

  // --- Notebook Mutations ---

  /// 添加到生词本
  Future<void> addToNotebook(int wordId, String source) {
    return into(notebook).insertOnConflictUpdate(
      NotebookCompanion(
        wordId: Value(wordId),
        source: Value(source),
        addedAt: Value(DateTime.now()),
      ),
    );
  }

  /// 从生词本移除
  Future<void> removeFromNotebook(int wordId) {
    return (delete(notebook)..where((t) => t.wordId.equals(wordId))).go();
  }

  /// 判断是否在生词本中
  Future<bool> isInNotebook(int wordId) {
    return (selectOnly(notebook)
          ..addColumns([notebook.wordId])
          ..where(notebook.wordId.equals(wordId)))
        .map((row) => row.read(notebook.wordId))
        .getSingleOrNull()
        .then((r) => r != null);
  }

  /// 获取生词本列表
  Future<List<NotebookWord>> getNotebookWords({String sortBy = 'time'}) {
    final joined = select(
      notebook,
    ).join([innerJoin(words, words.id.equalsExp(notebook.wordId))]);
    if (sortBy == 'alpha') {
      joined.orderBy([OrderingTerm.asc(words.word)]);
    } else {
      joined.orderBy([OrderingTerm.desc(notebook.addedAt)]);
    }
    return joined.map((row) {
      return NotebookWord(
        word: row.readTable(words),
        addedAt: row.readTable(notebook).addedAt,
        source: row.readTable(notebook).source,
      );
    }).get();
  }

  // --- Quiz Records ---

  /// 记录答题
  Future<void> recordQuiz(
    int wordId,
    String quizType,
    String direction,
    bool correct,
  ) {
    return into(quizRecords).insert(
      QuizRecordsCompanion(
        wordId: Value(wordId),
        quizType: Value(quizType),
        direction: Value(direction),
        correct: Value(correct),
        answeredAt: Value(DateTime.now()),
      ),
    );
  }

  // --- Settings ---

  Future<String?> getSetting(String key) {
    return (selectOnly(settings)
          ..addColumns([settings.value])
          ..where(settings.key.equals(key)))
        .map((row) => row.read(settings.value))
        .getSingleOrNull();
  }

  Future<void> setSetting(String key, String value) {
    return into(settings).insertOnConflictUpdate(
      SettingsCompanion(key: Value(key), value: Value(value)),
    );
  }

  /// 重置当前词书的学习数据，不影响其他词书关联的生词本和答题记录。
  Future<void> resetBook(String book) {
    return transaction(() async {
      final wordIds = selectOnly(words)
        ..addColumns([words.id])
        ..where(words.book.equals(book));
      await (delete(progress)..where((t) => t.book.equals(book))).go();
      await (delete(
        quizRecords,
      )..where((t) => t.wordId.isInQuery(wordIds))).go();
      await (delete(notebook)..where((t) => t.wordId.isInQuery(wordIds))).go();
    });
  }
}

/// 生词本单词（join 结果）
class NotebookWord {
  final Word word;
  final DateTime addedAt;
  final String source;

  NotebookWord({
    required this.word,
    required this.addedAt,
    required this.source,
  });
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'cet4_user.db'));
    return NativeDatabase.createInBackground(file);
  });
}
