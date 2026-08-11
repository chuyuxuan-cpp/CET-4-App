import 'dart:async';

import 'package:flutter/material.dart';

import 'package:cet4_app/core/providers/notebook_provider.dart';

/// Displays a single notebook quiz question card.
///
/// Supports two modes:
/// - **en2cn** multiple choice: four option buttons labeled A/B/C/D.
/// - **cn2en** fill-in-blank: a text field with a submit button.
class NotebookQuizSheet extends StatefulWidget {
  /// The question to display.
  final NotebookQuestion question;

  /// The 1-based question number (for display).
  final int questionNumber;

  /// Total number of questions in the quiz.
  final int totalQuestions;

  /// The user's previously submitted answer, if any.
  final String? previousAnswer;

  /// Called when the user submits an answer.
  final void Function(String answer) onSubmit;

  /// Called when the user advances to the next question.
  final VoidCallback onNext;

  /// Whether this question has already been answered.
  final bool hasAnswered;

  const NotebookQuizSheet({
    super.key,
    required this.question,
    required this.questionNumber,
    required this.totalQuestions,
    required this.onSubmit,
    required this.onNext,
    this.previousAnswer,
    this.hasAnswered = false,
  });

  @override
  State<NotebookQuizSheet> createState() => _NotebookQuizSheetState();
}

class _NotebookQuizSheetState extends State<NotebookQuizSheet> {
  final _textController = TextEditingController();
  int? _selectedOptionIndex;
  Timer? _autoTimer;

  @override
  void initState() {
    super.initState();
    if (widget.previousAnswer != null && widget.previousAnswer!.isNotEmpty) {
      _textController.text = widget.previousAnswer!;
    }
  }

  @override
  void didUpdateWidget(NotebookQuizSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset local state when the question changes.
    if (widget.question.word.id != oldWidget.question.word.id) {
      _selectedOptionIndex = null;
      _textController.clear();
      _autoTimer?.cancel();
      _autoTimer = null;
    }
    // Auto-advance when hasAnswered flips to true.
    if (widget.hasAnswered && !oldWidget.hasAnswered) {
      _autoTimer?.cancel();
      _autoTimer = Timer(const Duration(milliseconds: 700), () => widget.onNext());
    }
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Progress indicator
          _buildProgressRow(theme),
          const SizedBox(height: 20),

          // Question display card
          _buildQuestionCard(theme),
          const SizedBox(height: 24),

          // Answer area
          Expanded(child: _buildAnswerArea(theme)),
        ],
      ),
    );
  }

  Widget _buildProgressRow(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '第 ${widget.questionNumber}/${widget.totalQuestions} 题',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: widget.question.isEn2Cn
                ? theme.colorScheme.tertiaryContainer
                : theme.colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            widget.question.isEn2Cn ? '英译中' : '中译英',
            style: theme.textTheme.labelSmall?.copyWith(
              color: widget.question.isEn2Cn
                  ? theme.colorScheme.onTertiaryContainer
                  : theme.colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionCard(ThemeData theme) {
    final cs = theme.colorScheme;
    final prompt = widget.question.isEn2Cn
        ? widget.question.word.word
        : widget.question.word.meaning ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            widget.question.isEn2Cn ? '请选择释义' : '请写出对应的英文单词',
            style: theme.textTheme.labelMedium?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            prompt,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.primary,
            ),
          ),
          if (widget.question.word.pos != null &&
              widget.question.word.pos!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                widget.question.word.pos!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
          if (widget.question.isEn2Cn &&
              widget.question.word.phonetic != null &&
              widget.question.word.phonetic!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                widget.question.word.phonetic!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAnswerArea(ThemeData theme) {
    if (widget.question.isEn2Cn) {
      return _buildMultipleChoice(theme);
    } else {
      return _buildFillBlank(theme);
    }
  }

  // ---------------------------------------------------------------------------
  // Multiple choice (en2cn)
  // ---------------------------------------------------------------------------

  static const _optionLabels = ['A', 'B', 'C', 'D'];

  Widget _buildMultipleChoice(ThemeData theme) {
    final cs = theme.colorScheme;

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.question.options.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final option = widget.question.options[index];
        final isSelected = _selectedOptionIndex == index;
        final isCorrectAnswer =
            widget.question.isCorrect == true && isSelected;
        final isWrongAnswer =
            widget.question.isCorrect == false && isSelected;

        // Determine button style.
        Color? backgroundColor;
        Color? foregroundColor;
        Widget? trailing;

        if (!widget.hasAnswered) {
          // Not yet answered.
          if (isSelected) {
            backgroundColor = cs.primaryContainer;
            foregroundColor = cs.onPrimaryContainer;
          } else {
            backgroundColor = cs.surfaceContainerHighest;
            foregroundColor = cs.onSurface;
          }
        } else if (isCorrectAnswer) {
          backgroundColor = Colors.green.shade100;
          foregroundColor = Colors.green.shade800;
          trailing = const Icon(Icons.check_circle_rounded, color: Colors.green);
        } else if (isWrongAnswer) {
          backgroundColor = Colors.red.shade100;
          foregroundColor = Colors.red.shade800;
          trailing = const Icon(Icons.cancel_rounded, color: Colors.red);
        } else {
          backgroundColor = cs.surfaceContainerHighest;
          foregroundColor = cs.onSurface.withValues(alpha: 0.4);
        }

        return SizedBox(
          height: 52,
          child: OutlinedButton(
            onPressed: widget.hasAnswered
                ? null
                : () {
                    setState(() => _selectedOptionIndex = index);
                    widget.onSubmit(option);
                  },
            style: OutlinedButton.styleFrom(
              backgroundColor: backgroundColor,
              foregroundColor: foregroundColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              side: BorderSide(
                color: isSelected && !widget.hasAnswered
                    ? cs.primary
                    : cs.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected && !widget.hasAnswered
                        ? cs.primary
                        : cs.surfaceContainerHighest,
                  ),
                  child: Text(
                    _optionLabels[index],
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: isSelected && !widget.hasAnswered
                          ? cs.onPrimary
                          : cs.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    option,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Fill blank (cn2en)
  // ---------------------------------------------------------------------------

  Widget _buildFillBlank(ThemeData theme) {
    final cs = theme.colorScheme;

    return Column(
      children: [
        TextField(
          controller: _textController,
          enabled: !widget.hasAnswered,
          autofocus: true,
          textCapitalization: TextCapitalization.none,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: '请输入英文单词...',
            filled: true,
            fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: cs.primary, width: 1.5),
            ),
            suffixIcon: widget.hasAnswered
                ? widget.question.isCorrect == true
                    ? const Icon(Icons.check_circle_rounded,
                        color: Colors.green)
                    : const Icon(Icons.cancel_rounded, color: Colors.red)
                : null,
            // Show the correct answer after submission if wrong.
            helperText: widget.hasAnswered && widget.question.isCorrect == false
                ? '正确答案: ${widget.question.correctAnswer}'
                : null,
            helperStyle: TextStyle(
              color: Colors.green.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
          onSubmitted: widget.hasAnswered
              ? null
              : (value) => widget.onSubmit(value.trim()),
        ),
        if (!widget.hasAnswered)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: FilledButton(
              onPressed: () =>
                  widget.onSubmit(_textController.text.trim()),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('确认提交'),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Quiz completed summary (separate widget for clarity)
// ---------------------------------------------------------------------------

/// Displays a summary after the notebook quiz is finished.
///
/// Shows accuracy percentage, correct/wrong counts, and buttons to review
/// or go back to the notebook list.
class NotebookQuizSummary extends StatelessWidget {
  final int correctCount;
  final int wrongCount;
  final List<NotebookQuestion> questions;
  final VoidCallback onBackToList;
  final VoidCallback onRetry;

  const NotebookQuizSummary({
    super.key,
    required this.correctCount,
    required this.wrongCount,
    required this.questions,
    required this.onBackToList,
    required this.onRetry,
  });

  double get accuracy {
    final total = correctCount + wrongCount;
    return total > 0 ? correctCount / total : 0.0;
  }

  String get accuracyText => '${(accuracy * 100).round()}%';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isGood = accuracy >= 0.6;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Emoji feedback
            Text(
              isGood ? '💪' : '📚',
              style: const TextStyle(fontSize: 56),
            ),
            const SizedBox(height: 16),

            Text(
              isGood ? '自测完成！' : '继续加油！',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '正确率 $accuracyText',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: isGood ? Colors.green.shade700 : Colors.orange.shade700,
              ),
            ),
            const SizedBox(height: 24),

            // Stats row
            _buildStatsRow(theme),
            const SizedBox(height: 12),

            // Accuracy bar
            _buildAccuracyBar(theme),
            const SizedBox(height: 32),

            // Buttons
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('重新测试'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onBackToList,
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('返回生词本'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _statChip(theme, Icons.check_circle_rounded, '正确',
            correctCount, Colors.green),
        const SizedBox(width: 24),
        _statChip(theme, Icons.cancel_rounded, '错误',
            wrongCount, Colors.red),
      ],
    );
  }

  Widget _statChip(ThemeData theme, IconData icon, String label,
      int count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 6),
        Text(
          '$label $count',
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildAccuracyBar(ThemeData theme) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LinearProgressIndicator(
        value: accuracy,
        minHeight: 10,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        valueColor: AlwaysStoppedAnimation<Color>(
          accuracy >= 0.6 ? Colors.green : Colors.orange,
        ),
      ),
    );
  }
}
