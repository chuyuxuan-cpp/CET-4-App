import 'package:flutter/material.dart';

/// 中译英填空组件
///
/// 包含文本输入框、提交按钮和作答后的结果展示
class QuizFillBlank extends StatefulWidget {
  /// 中文释义
  final String meaning;

  /// 是否已作答
  final bool isAnswered;

  /// 作答结果（null = 尚未作答）
  final bool? isCorrect;

  /// 正确答案（英文单词）
  final String correctAnswer;

  /// 提交答案回调
  final ValueChanged<String>? onSubmit;

  const QuizFillBlank({
    super.key,
    required this.meaning,
    this.isAnswered = false,
    this.isCorrect,
    this.correctAnswer = '',
    this.onSubmit,
  });

  @override
  State<QuizFillBlank> createState() => _QuizFillBlankState();
}

class _QuizFillBlankState extends State<QuizFillBlank> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSubmit?.call(text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 题目提示
          Text(
            '请拼写中文意思「${widget.meaning}」对应的英文单词：',
            style: theme.textTheme.titleMedium?.copyWith(fontSize: 18, height: 1.5),
          ),
          const SizedBox(height: 28),

          // 文本输入
          TextField(
            controller: _controller,
            focusNode: _focusNode,
            enabled: !widget.isAnswered,
            textInputAction: TextInputAction.done,
            onSubmitted: widget.isAnswered ? null : (_) => _handleSubmit(),
            style: const TextStyle(fontSize: 22, letterSpacing: 2),
            textAlign: TextAlign.center,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              hintText: '输入英文单词...',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade400),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade400),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 提交按钮（仅作答前显示）
          if (!widget.isAnswered)
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _handleSubmit,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('提交', style: TextStyle(fontSize: 16)),
              ),
            ),

          const SizedBox(height: 20),

          // 结果展示（仅作答后显示）
          if (widget.isAnswered) _buildResult(theme),
        ],
      ),
    );
  }

  Widget _buildResult(ThemeData theme) {
    if (widget.isCorrect == true) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 26),
            const SizedBox(width: 12),
            Text(
              '正确！',
              style: TextStyle(
                color: Colors.green.shade800,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    } else {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cancel, color: Colors.red, size: 26),
                const SizedBox(width: 12),
                Text(
                  '回答错误',
                  style: TextStyle(
                    color: Colors.red.shade800,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '正确答案：${widget.correctAnswer}',
              style: TextStyle(
                color: Colors.green.shade700,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }
  }
}
