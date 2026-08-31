import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cet4_app/core/database/database.dart';
import 'package:cet4_app/core/providers/app_data_events_provider.dart';
import 'package:cet4_app/core/providers/database_provider.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

/// Immutable snapshot of a study session.
@immutable
class StudyState {
  /// All words loaded for the current session.
  final List<Word> words;

  /// Index into [words] for the currently displayed card.
  final int currentIndex;

  /// Maximum new words the user wants to learn today (from settings).
  final int dailyQuota;

  /// Number of new words already learned today *before* this session started.
  final int wordsLearnedToday;

  /// Whether the card front-face is visible (false) or flipped to the back (true).
  final bool isFlipped;

  /// True while the initial load is in progress.
  final bool isLoading;

  /// Whether the current word is in the notebook (starred).
  final bool isBookmarked;

  /// Whether another extra batch can be loaded from the active book.
  final bool hasMoreNewWords;

  final String? errorMessage;

  const StudyState({
    required this.words,
    required this.currentIndex,
    required this.dailyQuota,
    required this.wordsLearnedToday,
    required this.isFlipped,
    required this.isLoading,
    required this.isBookmarked,
    required this.hasMoreNewWords,
    this.errorMessage,
  });

  factory StudyState.initial() => const StudyState(
    words: [],
    currentIndex: 0,
    dailyQuota: 20,
    wordsLearnedToday: 0,
    isFlipped: false,
    isLoading: true,
    isBookmarked: false,
    hasMoreNewWords: true,
  );

  StudyState copyWith({
    List<Word>? words,
    int? currentIndex,
    int? dailyQuota,
    int? wordsLearnedToday,
    bool? isFlipped,
    bool? isLoading,
    bool? isBookmarked,
    bool? hasMoreNewWords,
    String? errorMessage,
    bool clearError = false,
  }) {
    return StudyState(
      words: words ?? this.words,
      currentIndex: currentIndex ?? this.currentIndex,
      dailyQuota: dailyQuota ?? this.dailyQuota,
      wordsLearnedToday: wordsLearnedToday ?? this.wordsLearnedToday,
      isFlipped: isFlipped ?? this.isFlipped,
      isLoading: isLoading ?? this.isLoading,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      hasMoreNewWords: hasMoreNewWords ?? this.hasMoreNewWords,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  // -- derived properties ---------------------------------------------------

  bool get hasWords => words.isNotEmpty;

  /// True when the daily session is concluded (no more words in today's quota).
  bool get completed => (words.isEmpty && !isLoading) || (hasWords && currentIndex >= words.length);

  /// Human-readable progress string, e.g. "3/20".
  String get progress {
    if (!hasWords) return '0/0';
    final current = (currentIndex + 1).clamp(0, words.length);
    return '$current/${words.length}';
  }

  Word? get currentWord =>
      (hasWords && currentIndex < words.length) ? words[currentIndex] : null;
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class StudyNotifier extends Notifier<StudyState> {
  @override
  StudyState build() {
    ref.listen<int>(
      appDataEventsProvider.select((value) => value.settingsRevision),
      (_, revision) {
        if (revision > 0) {
          loadTodayWords();
        }
      },
    );
    return StudyState.initial();
  }

  // -- helpers --------------------------------------------------------------

  Future<AppDatabase> get _db => ref.read(databaseProvider.future);

  Future<int> _readQuota(AppDatabase db) async {
    final raw = await db.getSetting('daily_quota');
    return int.tryParse(raw ?? '') ?? 20;
  }

  Future<String> _readBook(AppDatabase db) async {
    return await db.getSetting('active_book') ?? 'cet4';
  }

  /// 另一本书已掌握（stage=99）的单词文本，用于跨书迁移跳过重复学习。
  Future<Set<String>> _readOtherBookMasteredTexts(
    AppDatabase db,
    String book,
  ) async {
    final otherBook = book == 'cet4' ? 'cet6' : 'cet4';
    return db.getMasteredWordTexts(otherBook);
  }

  DateTime get _today => DateTime.now();

  DateTime get _tomorrow {
    final t = _today;
    return DateTime(t.year, t.month, t.day + 1);
  }

  // -- public actions -------------------------------------------------------

  /// Load the words for today's study session.
  ///
  /// Reads [dailyQuota] and [activeBook] from settings, queries how many words
  /// have already been learned today, then fetches the remaining quota of
  /// unlearned words ordered by [seq].
  Future<void> loadTodayWords() async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      clearError: true,
    );

    try {
      final db = await _db;
      final quota = await _readQuota(db);
      final book = await _readBook(db);
      final todayCount = await db.getTodayNewCount(book, _today);

      final remaining = quota - todayCount;
      if (remaining <= 0) {
        final excludeTexts = await _readOtherBookMasteredTexts(db, book);
        final hasMoreNewWords =
            (await db.getNewWords(book, 1, excludeTexts: excludeTexts))
                .isNotEmpty;
        state = state.copyWith(
          words: [],
          currentIndex: 0,
          dailyQuota: quota,
          wordsLearnedToday: todayCount,
          isLoading: false,
          isFlipped: false,
          hasMoreNewWords: hasMoreNewWords,
        );
        return;
      }

      final excludeTexts = await _readOtherBookMasteredTexts(db, book);
      final newWords = await db.getNewWords(
        book,
        remaining,
        excludeTexts: excludeTexts,
      );

      state = state.copyWith(
        words: newWords,
        currentIndex: 0,
        dailyQuota: quota,
        wordsLearnedToday: todayCount,
        isLoading: false,
        isFlipped: false,
        isBookmarked: false,
        hasMoreNewWords: newWords.isNotEmpty,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: '加载失败：$e');
    }
  }

  /// Flip the card between front and back face.
  void flipCard() {
    state = state.copyWith(isFlipped: !state.isFlipped);
  }

  /// Load up to 10 additional unlearned words without changing daily quota.
  Future<void> loadExtraWords() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final db = await _db;
      final book = await _readBook(db);
      final excludeTexts = await _readOtherBookMasteredTexts(db, book);
      final extra = await db.getNewWords(book, 10, excludeTexts: excludeTexts);
      state = state.copyWith(
        words: extra,
        currentIndex: 0,
        isLoading: false,
        isFlipped: false,
        isBookmarked: false,
        hasMoreNewWords: extra.isNotEmpty,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: '加载额外单词失败：$e');
    }
  }

  /// Mark the current word as **known** and advance to the next word.
  Future<void> markKnown() async {
    final word = state.currentWord;
    if (word == null) return;

    try {
      final db = await _db;
      final book = await _readBook(db);
      await db.upsertProgress(word.id, book, 1, _tomorrow);
      ref.read(appDataEventsProvider.notifier).studyChanged();
      _advanceToNext();
    } catch (_) {
      state = state.copyWith(errorMessage: '保存失败，请重试');
    }
  }

  /// Mark the current word as **unknown**, add it to the notebook
  /// automatically (source = 'unknown'), and advance to the next word.
  Future<void> markUnknown() async {
    final word = state.currentWord;
    if (word == null) return;

    try {
      final db = await _db;
      final book = await _readBook(db);
      await db.upsertProgress(word.id, book, 1, _tomorrow);
      await db.addToNotebook(word.id, 'unknown');
      final events = ref.read(appDataEventsProvider.notifier);
      events.studyChanged();
      events.notebookChanged();
      _advanceToNext();
    } catch (_) {
      state = state.copyWith(errorMessage: '保存失败，请重试');
    }
  }

  /// Toggle the notebook (star / bookmark) status of the current word.
  Future<void> toggleBookmark() async {
    final word = state.currentWord;
    if (word == null) return;

    try {
      final db = await _db;
      if (state.isBookmarked) {
        await db.removeFromNotebook(word.id);
        state = state.copyWith(isBookmarked: false);
      } else {
        await db.addToNotebook(word.id, 'manual');
        state = state.copyWith(isBookmarked: true);
      }
      ref.read(appDataEventsProvider.notifier).notebookChanged();
    } catch (_) {
      state = state.copyWith(errorMessage: '保存失败，请重试');
    }
  }

  // -- internal -------------------------------------------------------------

  void _advanceToNext() {
    final nextIndex = state.currentIndex + 1;
    if (nextIndex >= state.words.length) {
      // Session complete.
      state = state.copyWith(currentIndex: nextIndex, isFlipped: false);
      return;
    }

    state = state.copyWith(
      currentIndex: nextIndex,
      isFlipped: false,
      isBookmarked: false,
    );

    // Check bookmark status for the new word in the background.
    _refreshBookmarkStatus();
  }

  Future<void> _refreshBookmarkStatus() async {
    final word = state.currentWord;
    if (word == null) return;
    try {
      final db = await _db;
      final inNotebook = await db.isInNotebook(word.id);
      // Only update if the current index hasn't changed underneath us.
      if (state.currentWord?.id == word.id) {
        state = state.copyWith(isBookmarked: inNotebook);
      }
    } catch (_) {
      // Ignore.
    }
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final studyProvider = NotifierProvider<StudyNotifier, StudyState>(
  StudyNotifier.new,
);
