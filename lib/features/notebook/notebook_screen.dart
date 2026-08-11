import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cet4_app/core/providers/notebook_provider.dart';
import 'package:cet4_app/features/notebook/widgets/notebook_quiz_sheet.dart';
import 'package:cet4_app/features/notebook/widgets/notebook_word_tile.dart';

/// The 生词本 (Notebook) screen.
///
/// Has two modes:
/// - **List mode** (default): shows all notebook words with sort toggles,
///   swipe-to-delete, pull-to-refresh, and a FAB to start a quiz.
/// - **Quiz mode**: displays quiz questions from up to 20 random notebook
///   words, mixing en2cn multiple choice and cn2en fill-in-the-blank.
class NotebookScreen extends ConsumerStatefulWidget {
  const NotebookScreen({super.key});

  @override
  ConsumerState<NotebookScreen> createState() => _NotebookScreenState();
}

class _NotebookScreenState extends ConsumerState<NotebookScreen> {
  @override
  void initState() {
    super.initState();
    // Load notebook words after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notebookProvider.notifier).loadWords();
    });
  }

  @override
  Widget build(BuildContext context) {
    final notebook = ref.watch(notebookProvider);

    return Scaffold(
      appBar: _buildAppBar(notebook),
      body: notebook.isQuizMode ? _buildQuizBody(notebook) : _buildListBody(notebook),
      floatingActionButton: !notebook.isQuizMode
          ? _buildFab(notebook)
          : null,
    );
  }

  // ---------------------------------------------------------------------------
  // AppBar
  // ---------------------------------------------------------------------------

  PreferredSizeWidget _buildAppBar(NotebookState state) {
    final theme = Theme.of(context);

    return AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('生词本', style: TextStyle(fontWeight: FontWeight.w700)),
          if (!state.isQuizMode && !state.isLoading) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${state.wordCount}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ],
      ),
      centerTitle: true,
      leading: state.isQuizMode
          ? IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: '返回生词本',
              onPressed: () => _confirmExitQuiz(),
            )
          : null,
    );
  }

  // ---------------------------------------------------------------------------
  // FAB
  // ---------------------------------------------------------------------------

  Widget? _buildFab(NotebookState state) {
    if (state.words.isEmpty && !state.isLoading) return null;

    return FloatingActionButton.extended(
      onPressed: () => ref.read(notebookProvider.notifier).startQuiz(),
      icon: const Icon(Icons.quiz_outlined),
      label: const Text('生词自测'),
    );
  }

  // ---------------------------------------------------------------------------
  // List mode
  // ---------------------------------------------------------------------------

  Widget _buildListBody(NotebookState state) {
    // Loading.
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Error.
    if (state.errorMessage != null) {
      return _buildErrorView(state.errorMessage!);
    }

    // Empty.
    if (state.words.isEmpty) {
      return _buildEmptyView();
    }

    // Word list.
    return RefreshIndicator(
      onRefresh: () => ref.read(notebookProvider.notifier).loadWords(),
      child: Column(
        children: [
          // Sort toggle chips.
          _buildSortChips(state),
          // Quiz range filter chips.
          _buildQuizRangeChips(state),
          // List.
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 80), // room for FAB
              itemCount: state.words.length,
              itemBuilder: (context, index) {
                final nw = state.words[index];
                return Dismissible(
                  key: ValueKey(nw.word.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    color: Colors.red,
                    child: const Icon(Icons.delete_rounded,
                        color: Colors.white),
                  ),
                  confirmDismiss: (_) async {
                    return await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('移出生词本'),
                        content: Text('确定要移除「${nw.word.word}」吗？'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('取消'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('移除'),
                          ),
                        ],
                      ),
                    );
                  },
                  onDismissed: (_) {
                    ref
                        .read(notebookProvider.notifier)
                        .removeWord(nw.word.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('已移出「${nw.word.word}」'),
                        action: SnackBarAction(
                          label: '撤销',
                          onPressed: () {
                            // Re-add through the database helper.
                            // We don't have a direct add-back here, so skip
                            // for now – the user can re-add from the study
                            // screen.
                          },
                        ),
                      ),
                    );
                  },
                  child: NotebookWordTile(
                    notebookWord: nw,
                    onRemove: () {
                      ref
                          .read(notebookProvider.notifier)
                          .removeWord(nw.word.id);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortChips(NotebookState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.sort_rounded, size: 18),
          const SizedBox(width: 8),
          FilterChip.elevated(
            label: const Text('按时间'),
            selected: state.sortBy == 'time',
            onSelected: (_) =>
                ref.read(notebookProvider.notifier).sortByTime(),
          ),
          const SizedBox(width: 8),
          FilterChip.elevated(
            label: const Text('按字母'),
            selected: state.sortBy == 'alpha',
            onSelected: (_) =>
                ref.read(notebookProvider.notifier).sortByAlpha(),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizRangeChips(NotebookState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.filter_list_rounded, size: 18),
          const SizedBox(width: 8),
          FilterChip.elevated(
            label: const Text('最近7天'),
            selected: state.quizRange == 'week',
            onSelected: (_) =>
                ref.read(notebookProvider.notifier).setQuizRange('week'),
          ),
          const SizedBox(width: 8),
          FilterChip.elevated(
            label: const Text('全部生词'),
            selected: state.quizRange == 'all',
            onSelected: (_) =>
                ref.read(notebookProvider.notifier).setQuizRange('all'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.book_outlined,
              size: 80,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 20),
            Text(
              '还没有生词，去学习中标记吧！📝',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '学习时点击星标，或标记"不认识"\n单词会自动加入生词本',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () =>
                  ref.read(notebookProvider.notifier).loadWords(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Quiz mode
  // ---------------------------------------------------------------------------

  Widget _buildQuizBody(NotebookState state) {
    // Loading (generating questions).
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Quiz finished – show summary.
    if (state.isQuizFinished) {
      return NotebookQuizSummary(
        correctCount: state.correctCount,
        wrongCount: state.wrongCount,
        questions: state.questions,
        onBackToList: () => ref.read(notebookProvider.notifier).endQuiz(),
        onRetry: () async {
          await ref.read(notebookProvider.notifier).endQuiz();
          ref.read(notebookProvider.notifier).startQuiz();
        },
      );
    }

    // Active quiz question.
    final question = state.currentQuestion;
    if (question == null) {
      return const Center(child: Text('暂无题目'));
    }

    return SafeArea(
      child: NotebookQuizSheet(
        question: question,
        questionNumber: state.currentQuizIndex + 1,
        totalQuestions: state.questions.length,
        previousAnswer: question.userAnswer,
        hasAnswered: question.isCorrect != null,
        onSubmit: (answer) {
          ref
              .read(notebookProvider.notifier)
              .submitQuizAnswer(state.currentQuizIndex, answer);
        },
        onNext: () {
          ref.read(notebookProvider.notifier).nextQuizQuestion();
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Dialogs & helpers
  // ---------------------------------------------------------------------------

  Future<void> _confirmExitQuiz() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出自测'),
        content: const Text('确定退出吗？未保存的答题结果将被丢弃。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('继续答题'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('退出'),
          ),
        ],
      ),
    );

    if (shouldExit == true && mounted) {
      ref.read(notebookProvider.notifier).endQuiz();
    }
  }
}
