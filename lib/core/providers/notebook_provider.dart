import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cet4_app/core/database/database.dart';
import 'package:cet4_app/core/providers/app_data_events_provider.dart';
import 'package:cet4_app/core/providers/database_provider.dart';

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

/// A single question in a notebook quiz session.
class NotebookQuestion {
  final Word word;
  final bool isEn2Cn; // true = en2cn multiple choice, false = cn2en fill blank
  final List<String> options; // for en2cn only
  final String correctAnswer;
  String? userAnswer;
  bool? isCorrect;

  NotebookQuestion({
    required this.word,
    required this.isEn2Cn,
    required this.options,
    required this.correctAnswer,
    this.userAnswer,
    this.isCorrect,
  });
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

/// Immutable snapshot of the notebook screen state.
@immutable
class NotebookState {
  /// Words currently displayed in the notebook list.
  final List<NotebookWord> words;

  /// Sort order: 'time' (addedAt desc) or 'alpha' (word asc).
  final String sortBy;

  /// Quiz word range: 'week' (last 7 days) or 'all' (all notebook words).
  final String quizRange;

  /// True while an async load is in progress.
  final bool isLoading;

  // -- quiz mode fields ------------------------------------------------------

  /// Whether the screen is in quiz mode.
  final bool isQuizMode;

  /// Questions generated for the current quiz session.
  final List<NotebookQuestion> questions;

  /// Index into [questions] for the currently displayed question.
  final int currentQuizIndex;

  /// Running tally of correct answers in the current quiz.
  final int correctCount;

  /// Running tally of wrong answers in the current quiz.
  final int wrongCount;

  /// True after all quiz questions have been answered.
  final bool isQuizFinished;

  /// Non-null when an async operation fails.
  final String? errorMessage;

  const NotebookState({
    required this.words,
    required this.sortBy,
    required this.isLoading,
    required this.isQuizMode,
    required this.questions,
    required this.currentQuizIndex,
    required this.correctCount,
    required this.wrongCount,
    required this.isQuizFinished,
    required this.quizRange,
    this.errorMessage,
  });

  factory NotebookState.initial() => const NotebookState(
    words: [],
    sortBy: 'time',
    isLoading: true,
    isQuizMode: false,
    questions: [],
    currentQuizIndex: 0,
    correctCount: 0,
    wrongCount: 0,
    isQuizFinished: false,
    quizRange: 'week',
  );

  NotebookState copyWith({
    List<NotebookWord>? words,
    String? sortBy,
    String? quizRange,
    bool? isLoading,
    bool? isQuizMode,
    List<NotebookQuestion>? questions,
    int? currentQuizIndex,
    int? correctCount,
    int? wrongCount,
    bool? isQuizFinished,
    String? errorMessage,
    bool clearError = false,
  }) {
    return NotebookState(
      words: words ?? this.words,
      sortBy: sortBy ?? this.sortBy,
      quizRange: quizRange ?? this.quizRange,
      isLoading: isLoading ?? this.isLoading,
      isQuizMode: isQuizMode ?? this.isQuizMode,
      questions: questions ?? this.questions,
      currentQuizIndex: currentQuizIndex ?? this.currentQuizIndex,
      correctCount: correctCount ?? this.correctCount,
      wrongCount: wrongCount ?? this.wrongCount,
      isQuizFinished: isQuizFinished ?? this.isQuizFinished,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  // -- derived properties ----------------------------------------------------

  /// Number of words in the notebook.
  int get wordCount => words.length;

  /// Whether the quiz has questions loaded.
  bool get hasQuizQuestions => questions.isNotEmpty;

  /// The question currently being displayed, or null.
  NotebookQuestion? get currentQuestion =>
      hasQuizQuestions && currentQuizIndex < questions.length
      ? questions[currentQuizIndex]
      : null;

  /// Human-readable quiz progress, e.g. "3/20".
  String get quizProgress {
    final total = questions.length;
    if (total == 0) return '0/0';
    final current = (currentQuizIndex + 1).clamp(0, total);
    return '$current/$total';
  }

  /// Quiz accuracy as a fraction between 0.0 and 1.0.
  double get quizAccuracy {
    final total = correctCount + wrongCount;
    return total > 0 ? correctCount / total : 0.0;
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class NotebookNotifier extends Notifier<NotebookState> {
  @override
  NotebookState build() {
    ref.listen<int>(
      appDataEventsProvider.select((value) => value.notebookRevision),
      (_, int revision) {
        if (revision > 0 && !state.isQuizMode) {
          unawaited(loadWords());
        }
      },
    );
    return NotebookState.initial();
  }

  final _random = Random();

  // -- helpers ---------------------------------------------------------------

  Future<AppDatabase> get _db => ref.read(databaseProvider.future);

  Future<String> _readBook(AppDatabase db) async {
    return await db.getSetting('active_book') ?? 'cet4';
  }

  // -- list mode actions -----------------------------------------------------

  /// Fetch notebook words from the database using the current sort order.
  Future<void> loadWords() async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      clearError: true,
    );

    try {
      final db = await _db;
      final words = await db.getNotebookWords(sortBy: state.sortBy);
      state = state.copyWith(words: words, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: '加载生词本失败：$e');
    }
  }

  /// Sort by added time (newest first) and reload.
  Future<void> sortByTime() async {
    state = state.copyWith(sortBy: 'time');
    await loadWords();
  }

  /// Sort alphabetically by word and reload.
  Future<void> sortByAlpha() async {
    state = state.copyWith(sortBy: 'alpha');
    await loadWords();
  }

  /// Set the quiz word range filter.
  void setQuizRange(String range) {
    state = state.copyWith(quizRange: range);
  }

  /// Remove a word from the notebook and update the local list.
  Future<void> removeWord(int wordId) async {
    try {
      final db = await _db;
      await db.removeFromNotebook(wordId);
      state = state.copyWith(
        words: state.words.where((w) => w.word.id != wordId).toList(),
      );
    } catch (_) {
      // Silently ignore DB errors.
    }
  }

  // -- quiz mode actions -----------------------------------------------------

  /// Generate a quiz from up to 20 randomly selected notebook words.
  ///
  /// Each word gets a randomly assigned direction (en2cn multiple-choice
  /// or cn2en fill-in-the-blank). Distractors for en2cn questions are
  /// sampled from the word bank, excluding all quiz-word IDs.
  Future<void> startQuiz() async {
    if (state.words.isEmpty) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final db = await _db;
      final book = await _readBook(db);

      // Select up to 20 words at random.
      final sourceWords = List<NotebookWord>.from(state.words);
      sourceWords.shuffle(_random);

      // Filter by quiz range: 'week' limits to words added in the last 7 days.
      final filteredWords = state.quizRange == 'week'
          ? sourceWords
              .where((nw) => nw.addedAt
                  .isAfter(DateTime.now().subtract(const Duration(days: 7))))
              .toList()
          : sourceWords;

      if (filteredWords.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: '最近7天没有新增生词',
        );
        return;
      }

      final selected = filteredWords.take(20).toList();

      // Randomly assign en2cn / cn2en direction.
      final directions = <bool>[];
      int en2cnCount = 0;
      for (int i = 0; i < selected.length; i++) {
        final isEn2Cn = _random.nextBool();
        directions.add(isEn2Cn);
        if (isEn2Cn) en2cnCount++;
      }

      // Pre-fetch distractors for en2cn questions.
      final questionWordIds = selected.map((w) => w.word.id).toList();
      final distractorWords = en2cnCount > 0
          ? await db.getRandomWords(book, en2cnCount * 3, questionWordIds)
          : <Word>[];

      // Build question objects.
      final questions = <NotebookQuestion>[];
      int distractorIdx = 0;

      for (int i = 0; i < selected.length; i++) {
        final nw = selected[i];
        if (directions[i]) {
          // en2cn: multiple choice with 4 options.
          final correctMeaning = nw.word.meaning ?? '';
          final options = <String>[correctMeaning];
          for (int j = 0; j < 3; j++) {
            if (distractorIdx < distractorWords.length) {
              options.add(distractorWords[distractorIdx++].meaning ?? '');
            } else {
              options.add('---');
            }
          }
          options.shuffle(_random);
          questions.add(
            NotebookQuestion(
              word: nw.word,
              isEn2Cn: true,
              options: options,
              correctAnswer: correctMeaning,
            ),
          );
        } else {
          // cn2en: fill in the blank.
          questions.add(
            NotebookQuestion(
              word: nw.word,
              isEn2Cn: false,
              options: [],
              correctAnswer: nw.word.word,
            ),
          );
        }
      }

      state = state.copyWith(
        isLoading: false,
        isQuizMode: true,
        questions: questions,
        currentQuizIndex: 0,
        correctCount: 0,
        wrongCount: 0,
        isQuizFinished: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: '生成自测题目失败：$e');
    }
  }

  /// Check the user's [answer] for question at [index] and update state.
  ///
  /// For en2cn questions the answer is matched by trimmed text equality;
  /// for cn2en it is case-insensitive and trimmed.
  Future<void> submitQuizAnswer(int index, String answer) async {
    if (index < 0 || index >= state.questions.length) return;

    final question = state.questions[index];
    if (question.isCorrect != null) return; // already answered

    final isCorrect = _checkAnswer(question, answer);

    // Mutable fields on NotebookQuestion allow in-place update, but we
    // replace the list entry to produce a proper state change.
    question.userAnswer = answer;
    question.isCorrect = isCorrect;

    final updatedQuestions = List<NotebookQuestion>.from(state.questions);
    updatedQuestions[index] = question;

    state = state.copyWith(
      questions: updatedQuestions,
      correctCount: state.correctCount + (isCorrect ? 1 : 0),
      wrongCount: state.wrongCount + (isCorrect ? 0 : 1),
    );
  }

  /// Compare [answer] against the correct answer for [question].
  bool _checkAnswer(NotebookQuestion question, String answer) {
    if (question.isEn2Cn) {
      // Multiple choice: exact match on the option text.
      return answer.trim() == question.correctAnswer.trim();
    } else {
      // Fill in blank: case-insensitive, trimmed.
      return answer.trim().toLowerCase() ==
          question.correctAnswer.trim().toLowerCase();
    }
  }

  /// Advance to the next quiz question.
  ///
  /// If this was the last question, sets [isQuizFinished] to true.
  void nextQuizQuestion() {
    final nextIdx = state.currentQuizIndex + 1;
    if (nextIdx >= state.questions.length) {
      state = state.copyWith(currentQuizIndex: nextIdx, isQuizFinished: true);
    } else {
      state = state.copyWith(currentQuizIndex: nextIdx);
    }
  }

  /// Persist all quiz results to the database and reset quiz state.
  ///
  /// Quiz results are saved to [QuizRecords] with quizType = 'notebook'.
  /// Progress table is **not** updated.
  Future<void> endQuiz() async {
    try {
      final db = await _db;
      for (final q in state.questions) {
        if (q.isCorrect != null) {
          await db.recordQuiz(
            q.word.id,
            'notebook',
            q.isEn2Cn ? 'en2cn' : 'cn2en',
            q.isCorrect!,
          );
        }
      }
    } catch (_) {
      // Silently ignore DB errors.
    }

    state = state.copyWith(
      isQuizMode: false,
      isQuizFinished: false,
      questions: [],
      currentQuizIndex: 0,
      correctCount: 0,
      wrongCount: 0,
    );
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final notebookProvider = NotifierProvider<NotebookNotifier, NotebookState>(
  NotebookNotifier.new,
);
