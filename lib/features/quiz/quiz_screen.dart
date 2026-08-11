import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cet4_app/core/providers/app_data_events_provider.dart';
import 'package:cet4_app/core/providers/quiz_provider.dart';
import 'package:cet4_app/features/quiz/widgets/quiz_fill_blank.dart';
import 'package:cet4_app/features/quiz/widgets/quiz_option_button.dart';

/// 自出卷页面
///
/// 按 1→3→7→99 间隔自动出题复习，题型包含英译中（四选一）和中译英（填空）
class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({super.key});

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  static const _labels = ['A', 'B', 'C', 'D'];
  int _lastSettingsRevision = 0;
  Timer? _autoAdvanceTimer;
  int _lastQuestionIndex = -1;

  @override
  void initState() {
    super.initState();
    // 页面初始化后异步加载题目
    Future.microtask(() => ref.read(quizProvider.notifier).loadQuiz());
  }

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    super.dispose();
  }

  // ==========================================================
  // Build
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(quizProvider);
    final settingsRevision =
        ref.watch(appDataEventsProvider.select((v) => v.settingsRevision));

    // Reload quiz when settings/active-book changes, but only if idle.
    if (settingsRevision != _lastSettingsRevision && mounted) {
      _lastSettingsRevision = settingsRevision;
      if (state.questions.isEmpty ||
          state.isFinished) {
        ref.read(quizProvider.notifier).loadQuiz();
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('自出卷'),
        centerTitle: true,
      ),
      body: _buildBody(state),
    );
  }

  Widget _buildBody(QuizState state) {
    // 加载中
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // 加载出错
    if (state.errorMessage != null) {
      return _buildError(state);
    }

    // 无待复习单词
    if (state.questions.isEmpty) {
      return _buildEmpty();
    }

    // 全部完成
    if (state.isFinished) {
      return _buildSummary(state);
    }

    // 答题中
    return _buildQuiz(state);
  }

  // ==========================================================
  // 错误状态
  // ==========================================================

  Widget _buildError(QuizState state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text(
              state.errorMessage!,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => ref.read(quizProvider.notifier).loadQuiz(),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // 空状态
  // ==========================================================

  Widget _buildEmpty() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.menu_book, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 24),
            Text(
              '今天没有需要复习的单词，休息一下吧 📚',
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            OutlinedButton(
              onPressed: () => ref.read(quizProvider.notifier).loadQuiz(),
              child: const Text('刷新'),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // 答题区
  // ==========================================================

  Widget _buildQuiz(QuizState state) {
    final question = state.questions[state.currentIndex];
    final isAnswered = state.answerResults.containsKey(state.currentIndex);
    final isCorrect = state.answerResults[state.currentIndex];

    // Cancel timer when question changes.
    if (state.currentIndex != _lastQuestionIndex) {
      _autoAdvanceTimer?.cancel();
      _autoAdvanceTimer = null;
      _lastQuestionIndex = state.currentIndex;
    }

    // Auto-advance after answer with a 1-second delay.
    if (isAnswered && _autoAdvanceTimer == null) {
      _autoAdvanceTimer = Timer(const Duration(milliseconds: 700), () {
        if (mounted) {
          ref.read(quizProvider.notifier).nextQuestion();
        }
      });
    }

    return Column(
      children: [
        // 进度条
        _buildProgressBar(state),

        const Divider(height: 1),

        // 题目区域
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 16),
            child: question.direction == QuizDirection.en2cn
                ? _buildEn2CnQuestion(question, state, isAnswered)
                : _buildCn2EnQuestion(question, isAnswered, isCorrect, state),
          ),
        ),

        // 下一题按钮（已移除——自动跳转）
        if (isAnswered) const SizedBox.shrink(),
      ],
    );
  }

  // ----------------------------------------------------------
  // 进度条
  // ----------------------------------------------------------

  Widget _buildProgressBar(QuizState state) {
    final theme = Theme.of(context);
    final current = state.currentIndex + 1;
    final total = state.totalQuestions;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '第 $current/$total 题',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                children: [
                  Text('✅ ${state.correctCount}', style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 14),
                  Text('❌ ${state.wrongCount}', style: const TextStyle(fontSize: 14)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: state.progress,
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // 英译中题目（四选一）
  // ----------------------------------------------------------

  Widget _buildEn2CnQuestion(
    QuizQuestion question,
    QuizState state,
    bool isAnswered,
  ) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 题干
          Text(
            '下面哪个是',
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              question.word.word,
              style: theme.textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '的中文意思？',
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),

          // 选项按钮
          ...question.options.asMap().entries.map((entry) {
            final idx = entry.key;
            final optionText = entry.value;

            return QuizOptionButton(
              label: idx < _labels.length ? _labels[idx] : '?',
              text: optionText,
              optionState: _resolveOptionState(
                optionText: optionText,
                question: question,
                state: state,
                isAnswered: isAnswered,
              ),
              onTap: isAnswered
                  ? null
                  : () => ref
                      .read(quizProvider.notifier)
                      .submitAnswer(state.currentIndex, optionText),
            );
          }),
        ],
      ),
    );
  }

  /// 确定某个选项的显示状态
  OptionState _resolveOptionState({
    required String optionText,
    required QuizQuestion question,
    required QuizState state,
    required bool isAnswered,
  }) {
    if (!isAnswered) return OptionState.normal;

    // 正确答案 → 绿色
    if (optionText == question.correctAnswer) {
      return OptionState.correct;
    }

    // 用户选错 → 红色
    final userAnswer = state.submittedAnswers[state.currentIndex];
    final isUserCorrect = state.answerResults[state.currentIndex] == true;
    if (optionText == userAnswer && !isUserCorrect) {
      return OptionState.wrong;
    }

    // 其他选项 → 灰色禁用
    return OptionState.disabled;
  }

  // ----------------------------------------------------------
  // 中译英题目（填空）
  // ----------------------------------------------------------

  Widget _buildCn2EnQuestion(
    QuizQuestion question,
    bool isAnswered,
    bool? isCorrect,
    QuizState state,
  ) {
    return QuizFillBlank(
      // 使用 currentIndex 作为 key，确保切换题目时重建 State
      key: ValueKey('fill_${state.currentIndex}'),
      meaning: question.word.meaning ?? '未知释义',
      pos: question.word.pos,
      isAnswered: isAnswered,
      isCorrect: isCorrect,
      correctAnswer: question.correctAnswer,
      onSubmit: isAnswered
          ? null
          : (answer) => ref
              .read(quizProvider.notifier)
              .submitAnswer(state.currentIndex, answer),
    );
  }

  // ==========================================================
  // 结果汇总页
  // ==========================================================

  Widget _buildSummary(QuizState state) {
    final theme = Theme.of(context);
    final total = state.totalQuestions;
    final correct = state.correctCount;
    final wrong = state.wrongCount;
    final ratio = total > 0 ? correct / total : 0.0;
    final accuracy = total > 0 ? (ratio * 100).toStringAsFixed(0) : '0';

    // 鼓励语
    final encouragement = _encouragement(ratio);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 20),

            // 正确率圆环
            _buildScoreRing(accuracy, ratio, theme),

            const SizedBox(height: 28),

            // 鼓励语
            Text(
              encouragement,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 32),

            // 统计卡片
            Row(
              children: [
                Expanded(
                  child: _buildStatCard('总题数', '$total', Colors.blue, theme),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStatCard('正确', '$correct', Colors.green, theme),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStatCard('错误', '$wrong', Colors.red, theme),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildStatCard('正确率', '$accuracy%', theme.colorScheme.primary, theme),

            const SizedBox(height: 40),

            // 再来一轮
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => ref.read(quizProvider.notifier).loadQuiz(),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('再来一轮', style: TextStyle(fontSize: 16)),
              ),
            ),

            const SizedBox(height: 12),

            // 返回
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('返回'),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------
  // 正确率圆环
  // ----------------------------------------------------------

  Widget _buildScoreRing(String accuracy, double ratio, ThemeData theme) {
    final ringColor = ratio >= 0.7
        ? Colors.green
        : ratio >= 0.5
            ? Colors.orange
            : Colors.red;

    return SizedBox(
      width: 150,
      height: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 150,
            height: 150,
            child: CircularProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              strokeWidth: 10,
              strokeCap: StrokeCap.round,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(ringColor),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$accuracy%',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: ringColor,
                ),
              ),
              Text(
                '正确率',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // 统计卡片
  // ----------------------------------------------------------

  Widget _buildStatCard(String label, String value, Color color, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // 鼓励语
  // ----------------------------------------------------------

  String _encouragement(double ratio) {
    if (ratio >= 0.9) return '太棒了！你已经掌握了大部分单词！🎉';
    if (ratio >= 0.7) return '不错！继续加油！💪';
    if (ratio >= 0.5) return '还需要多练习哦！📖';
    return '不要气馁，坚持就是胜利！🌟';
  }
}
