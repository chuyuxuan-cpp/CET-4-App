import 'package:flutter/material.dart';

/// 选项按钮状态
enum OptionState {
  /// 默认：可点击
  normal,

  /// 正确：绿色高亮
  correct,

  /// 错误：红色高亮
  wrong,

  /// 禁用：灰色（其他选项在作答后置灰）
  disabled,
}

/// 选择题选项按钮
///
/// 显示 A/B/C/D 标签 + 中文释义，支持四种状态的颜色过渡
class QuizOptionButton extends StatelessWidget {
  final String label;
  final String text;
  final OptionState optionState;
  final VoidCallback? onTap;

  const QuizOptionButton({
    super.key,
    required this.label,
    required this.text,
    required this.optionState,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _resolveColors();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          color: colors.background,
          border: Border.all(color: colors.border, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: optionState == OptionState.normal ? onTap : null,
            borderRadius: BorderRadius.circular(12),
            splashColor: colors.border.withValues(alpha: 0.2),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // 选项标签（A/B/C/D 圆圈）
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.border, width: 1.5),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colors.foreground,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // 选项文本（中文释义）
                  Expanded(
                    child: Text(
                      text,
                      style: TextStyle(
                        fontSize: 16,
                        color: colors.foreground,
                        height: 1.4,
                      ),
                    ),
                  ),

                  // 结果图标
                  if (colors.icon != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Icon(colors.icon, color: colors.foreground, size: 22),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  _ResolvedColors _resolveColors() {
    switch (optionState) {
      case OptionState.correct:
        return _ResolvedColors(
          background: Colors.green.shade50,
          border: Colors.green,
          foreground: Colors.green.shade800,
          icon: Icons.check_circle,
        );
      case OptionState.wrong:
        return _ResolvedColors(
          background: Colors.red.shade50,
          border: Colors.red,
          foreground: Colors.red.shade800,
          icon: Icons.cancel,
        );
      case OptionState.disabled:
        return _ResolvedColors(
          background: Colors.grey.shade100,
          border: Colors.grey.shade300,
          foreground: Colors.grey,
        );
      case OptionState.normal:
        return _ResolvedColors(
          background: Colors.transparent,
          border: Colors.grey.shade400,
          foreground: Colors.black87,
        );
    }
  }
}

class _ResolvedColors {
  final Color background;
  final Color border;
  final Color foreground;
  final IconData? icon;

  const _ResolvedColors({
    required this.background,
    required this.border,
    required this.foreground,
    this.icon,
  });
}
