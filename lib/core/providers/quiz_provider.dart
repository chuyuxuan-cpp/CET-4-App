import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cet4_app/core/database/database.dart';
import 'package:cet4_app/core/providers/database_provider.dart';

// ============================================================
// Models
// ============================================================

enum QuizDirection { en2cn, cn2en }

class QuizQuestion {
  final Word word;
  final QuizDirection direction;
  final List<String> options; // 4个选项（en2cn），空列表（cn2en）
  final String correctAnswer;

  const QuizQuestion({
    required this.word,
    required this.direction,
    required this.options,
    required this.correctAnswer,
  });
}

// ============================================================
// State
// ============================================================

class QuizState {
  final List<QuizQuestion> questions;
  final int currentIndex;
  final int correctCount;
  final int wrongCount;
  final bool isFinished;
  final bool isLoading;
  final String? errorMessage;
  final Map<int, String> submittedAnswers; // questionIndex → 用户答案
  final Map<int, bool> answerResults; // questionIndex → 是否正确
  final String book;
  final Map<int, int> wordStages; // wordId → 当前复习阶段

  const QuizState({
    this.questions = const [],
    this.currentIndex = 0,
    this.correctCount = 0,
    this.wrongCount = 0,
    this.isFinished = false,
    this.isLoading = false,
    this.errorMessage,
    this.submittedAnswers = const {},
    this.answerResults = const {},
    this.book = 'cet4',
    this.wordStages = const {},
  });

  int get totalQuestions => questions.length;

  /// 已完成进度的比例 (0.0 ~ 1.0)
  double get progress {
    if (isFinished) return 1.0;
    if (totalQuestions == 0) return 0.0;
    return currentIndex / totalQuestions;
  }

  /// 得分百分比 (0.0 ~ 1.0)
  double get score {
    if (totalQuestions == 0) return 0.0;
    return correctCount / totalQuestions;
  }

  QuizState copyWith({
    List<QuizQuestion>? questions,
    int? currentIndex,
    int? correctCount,
    int? wrongCount,
    bool? isFinished,
    bool? isLoading,
    Object? errorMessage = _nothing,
    Map<int, String>? submittedAnswers,
    Map<int, bool>? answerResults,
    String? book,
    Map<int, int>? wordStages,
  }) {
    return QuizState(
      questions: questions ?? this.questions,
      currentIndex: currentIndex ?? this.currentIndex,
      correctCount: correctCount ?? this.correctCount,
      wrongCount: wrongCount ?? this.wrongCount,
      isFinished: isFinished ?? this.isFinished,
      isLoading: isLoading ?? this.isLoading,
      errorMessage:
          identical(errorMessage, _nothing) ? this.errorMessage : errorMessage as String?,
      submittedAnswers: submittedAnswers ?? this.submittedAnswers,
      answerResults: answerResults ?? this.answerResults,
      book: book ?? this.book,
      wordStages: wordStages ?? this.wordStages,
    );
  }

  static const _nothing = Object();
}

// ============================================================
// Notifier
// ============================================================

/// 复习阶段递进表
const _stageProgression = <int, int>{1: 3, 3: 7, 7: 99};

/// 单日自出卷题量上限，避免单日复习计划过重
const _maxDailyQuestions = 120;

class QuizNotifier extends StateNotifier<QuizState> {
  final AppDatabase _db;

  QuizNotifier({required AppDatabase db}) : _db = db, super(const QuizState()); // ignore: prefer_initializing_formals

  // ----------------------------------------------------------
  // 加载题目
  // ----------------------------------------------------------
  Future<void> loadQuiz() async {
    final db = _db;

    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      isFinished: false,
    );

    try {
      // 1. 读取当前词书
      final book = await db.getSetting('active_book') ?? 'cet4';
      final today = DateTime.now();

      // 2. 获取待复习的单词 ID
      final wordIds = await db.getReviewWordIds(book, today);

      if (wordIds.isEmpty) {
        state = state.copyWith(isLoading: false, book: book);
        return;
      }

      // 3. 加载单词详情和当前复习阶段（题量封顶，避免单日计划过重）
      final words = await db.getReviewWords(wordIds);
      final stages = await db.getReviewStages(book, wordIds);

      // 单日自出卷最多 120 题，超出部分留待后续复习
      final cappedWords = words.take(_maxDailyQuestions).toList();

      // 4. 为每个单词生成题目
      final random = Random();
      final questions = <QuizQuestion>[];

      for (final word in cappedWords) {
        final isEn2Cn = random.nextBool();

        if (isEn2Cn) {
          questions.add(await _buildEn2CnQuestion(word, book, db, random));
        } else {
          questions.add(_buildCn2EnQuestion(word));
        }
      }

      // 5. 打乱题目顺序
      questions.shuffle(random);

      state = QuizState(
        questions: questions,
        currentIndex: 0,
        correctCount: 0,
        wrongCount: 0,
        isFinished: false,
        isLoading: false,
        book: book,
        wordStages: stages,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '加载题目失败：$e',
      );
    }
  }

  // ----------------------------------------------------------
  // 提交答案
  // ----------------------------------------------------------
  bool submitAnswer(int questionIndex, String answer) {
    if (questionIndex != state.currentIndex || state.isFinished) return false;
    if (state.questions.isEmpty) return false;

    final question = state.questions[questionIndex];
    final isCorrect = _checkAnswer(question, answer);
    final today = DateTime.now();

    // 播放答题音效
    SystemSound.play(
      isCorrect ? SystemSoundType.click : SystemSoundType.alert,
    );

    // 计算复习进度
    final currentStage = state.wordStages[question.word.id] ?? 1;
    final (nextStage, nextReview) = _calculateProgress(currentStage, isCorrect, today);

    // 写入数据库（异步写入，不阻塞 UI）
    _db.upsertProgress(question.word.id, state.book, nextStage, nextReview);
    _db.recordQuiz(
      question.word.id,
      'review',
      question.direction == QuizDirection.en2cn ? 'en2cn' : 'cn2en',
      isCorrect,
    );

    // 更新本地阶段缓存
    final newStages = Map<int, int>.from(state.wordStages);
    newStages[question.word.id] = nextStage;

    // 更新答题记录
    final newSubmitted = Map<int, String>.from(state.submittedAnswers);
    newSubmitted[questionIndex] = answer;

    final newResults = Map<int, bool>.from(state.answerResults);
    newResults[questionIndex] = isCorrect;

    state = state.copyWith(
      correctCount: state.correctCount + (isCorrect ? 1 : 0),
      wrongCount: state.wrongCount + (isCorrect ? 0 : 1),
      submittedAnswers: newSubmitted,
      answerResults: newResults,
      wordStages: newStages,
    );

    return isCorrect;
  }

  // ----------------------------------------------------------
  // 下一题
  // ----------------------------------------------------------
  void nextQuestion() {
    if (state.isFinished) return;

    final nextIndex = state.currentIndex + 1;
    if (nextIndex >= state.totalQuestions) {
      state = state.copyWith(currentIndex: nextIndex, isFinished: true);
    } else {
      state = state.copyWith(currentIndex: nextIndex);
    }
  }

  // ==========================================================
  // 私有方法
  // ==========================================================

  /// 英译中题目：1 个正确释义 + 3 个干扰项
  Future<QuizQuestion> _buildEn2CnQuestion(
    Word word,
    String book,
    AppDatabase db,
    Random random,
  ) async {
    final correctMeaning = word.meaning ?? '(释义缺失)';

    // 获取随机干扰词
    final randomWords = await db.getRandomWords(book, 5, [word.id]);
    final distractorMeanings = randomWords
        .map((w) => w.meaning)
        .where((m) => m != null && m != correctMeaning)
        .map((m) => m!)
        .toList();

    // 填充不足的干扰项
    while (distractorMeanings.length < 3) {
      distractorMeanings.add('——');
    }

    final options = <String>[correctMeaning, ...distractorMeanings.take(3)];
    options.shuffle(random);

    return QuizQuestion(
      word: word,
      direction: QuizDirection.en2cn,
      options: options,
      correctAnswer: correctMeaning,
    );
  }

  /// 中译英题目：无选项（填空）
  QuizQuestion _buildCn2EnQuestion(Word word) {
    return QuizQuestion(
      word: word,
      direction: QuizDirection.cn2en,
      options: const [],
      correctAnswer: word.word,
    );
  }

  /// 判断答案是否正确
  bool _checkAnswer(QuizQuestion question, String answer) {
    if (question.direction == QuizDirection.en2cn) {
      // 英译中：选项文本直接比较
      return answer.trim() == question.correctAnswer.trim();
    } else {
      // 中译英：大小写不敏感，去首尾空格后精确匹配
      return answer.trim().toLowerCase() == question.correctAnswer.toLowerCase();
    }
  }

  /// 计算下一阶段和下一次复习日期
  (int nextStage, DateTime nextReview) _calculateProgress(
    int currentStage,
    bool correct,
    DateTime today,
  ) {
    if (correct) {
      final nextStage = _stageProgression[currentStage] ?? 99;
      final nextReview = today.add(Duration(days: nextStage));
      return (nextStage, nextReview);
    } else {
      return (1, today.add(const Duration(days: 1)));
    }
  }
}

// ============================================================
// Provider
// ============================================================

/// 自出卷状态提供者
///
/// 依赖 databaseProvider（FutureProvider）——词库初始化在首屏完成，
/// 进入本页面时 Future 应已 resolve，因此 safe unwrap。
final quizProvider = StateNotifierProvider<QuizNotifier, QuizState>((ref) {
  final db = ref.watch(databaseProvider).requireValue;
  return QuizNotifier(db: db);
});
