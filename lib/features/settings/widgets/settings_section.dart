import 'package:flutter/material.dart';

/// 设置页分组容器，Material 3 风格的圆角卡片列表。
///
/// 每页包含一个 `title` 标题头 + 一组 `children`，
/// 渲染时使用 Card + ListTile.divideTiles 拼接。
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 分组标题
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // Card 容器
          Card(
            elevation: 1,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: _buildDividedChildren(context, theme),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDividedChildren(BuildContext context, ThemeData theme) {
    // 过滤掉空 widget
    final valid = children.where((w) => w is! SizedBox).toList();
    if (valid.isEmpty) return [];

    final widgets = <Widget>[];
    for (int i = 0; i < valid.length; i++) {
      widgets.add(valid[i]);
      // 在每一项之间插入分割线（最后一项不加）
      if (i < valid.length - 1) {
        widgets.add(const Divider(height: 1, indent: 16));
      }
    }
    return widgets;
  }
}
