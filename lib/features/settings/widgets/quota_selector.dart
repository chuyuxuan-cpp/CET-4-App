import 'package:flutter/material.dart';

/// 每日学习量选择器 — Material 3 SegmentedButton。
///
/// 提供 10 / 20 / 30 / 50 四个固定选项。
class QuotaSelector extends StatelessWidget {
  const QuotaSelector({
    super.key,
    required this.selectedQuota,
    required this.onChanged,
  });

  final int selectedQuota;
  final ValueChanged<int> onChanged;

  static const _quotas = [10, 20, 30, 50];

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<int>(
      segments: _quotas
          .map((q) => ButtonSegment<int>(
                value: q,
                label: Text('$q词'),
              ))
          .toList(),
      selected: {selectedQuota},
      onSelectionChanged: (selected) {
        onChanged(selected.first);
      },
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
