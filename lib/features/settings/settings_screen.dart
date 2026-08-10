import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cet4_app/core/providers/settings_provider.dart';
import 'package:cet4_app/core/services/notification_service.dart';
import 'package:cet4_app/features/settings/widgets/quota_selector.dart';
import 'package:cet4_app/features/settings/widgets/settings_section.dart';
import 'package:cet4_app/features/settings/wordbook_browser_screen.dart';

/// 设置页面
///
/// 分组：
/// 1. 学习计划 — 每日学习量 / 当前词书 / 词书进度
/// 2. 每日提醒 — 开关 / 提醒时间
/// 3. 数据管理 — 重置进度 / 进度信息
/// 4. 关于 — 版本 / 应用名 / 简介
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    // 首帧后加载设置
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(settingsProvider.notifier).loadSettings();
    });
  }

  // ---------------------------------------------------------------------------
  // 确认重置对话框
  // ---------------------------------------------------------------------------

  Future<void> _showResetConfirmation() async {
    final bookLabel = ref.read(settingsProvider).bookLabel;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重置词书进度'),
        content: Text('确定要重置 $bookLabel 的全部学习数据吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('确认重置'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(settingsProvider.notifier).resetCurrentBook();
    }
  }

  // ---------------------------------------------------------------------------
  // 时间选择器
  // ---------------------------------------------------------------------------

  Future<void> _pickReminderTime() async {
    final current = ref.read(settingsProvider).reminderTime;

    final picked = await showTimePicker(context: context, initialTime: current);

    if (picked != null && mounted) {
      await ref.read(settingsProvider.notifier).setReminderTime(picked);
    }
  }

  // -- 状态：追踪通知权限是否被拒绝，以在 UI 上显示"未授权"提示 ------------

  Future<bool> _checkNotificationPermission() async {
    final hasPermission = await NotificationService().hasAndroidPermission;
    return hasPermission ?? true; // 无法判断时默认允许
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('设置'), centerTitle: true),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 32),
              children: [
                // ==============================================================
                // 1. 学习计划
                // ==============================================================
                SettingsSection(
                  title: '学习计划',
                  children: [
                    // 每日学习量
                    ListTile(
                      title: const Text('每日学习量'),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: QuotaSelector(
                          selectedQuota: state.dailyQuota,
                          onChanged: (q) => notifier.setDailyQuota(q),
                        ),
                      ),
                    ),

                    // 当前词书
                    ListTile(
                      title: const Text('当前词书'),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'cet4', label: Text('CET-4')),
                            ButtonSegment(value: 'cet6', label: Text('CET-6')),
                          ],
                          selected: {state.activeBook},
                          onSelectionChanged: (sel) {
                            notifier.setActiveBook(sel.first);
                          },
                          style: const ButtonStyle(
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ),
                    ),

                    // 词书进度信息
                    ListTile(
                      leading: const Icon(Icons.bar_chart_rounded),
                      title: const Text('词书进度信息'),
                      subtitle: Text(
                        '已学习 ${state.learnedCount} 词  |  '
                        '待复习 ${state.reviewCount} 词  |  '
                        '已掌握 ${state.masteredCount} 词',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    // 浏览当前词书
                    ListTile(
                      leading: const Icon(Icons.menu_book_outlined),
                      title: const Text('浏览词书'),
                      subtitle: Text('${state.bookLabel} 词汇列表'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const WordbookBrowserScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),

                // ==============================================================
                // 2. 每日提醒
                // ==============================================================
                SettingsSection(
                  title: '每日提醒',
                  children: [
                    // 开关
                    SwitchListTile(
                      title: const Text('开启每日提醒'),
                      value: state.reminderEnabled,
                      onChanged: (val) => notifier.setReminderEnabled(val),
                    ),

                    // 提醒时间
                    ListTile(
                      title: const Text('提醒时间'),
                      subtitle: _buildReminderSubtitle(state),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            state.reminderTime.format(context),
                            style: theme.textTheme.bodyLarge,
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.access_time, size: 20),
                        ],
                      ),
                      enabled: state.reminderEnabled,
                      onTap: state.reminderEnabled ? _pickReminderTime : null,
                    ),
                  ],
                ),

                // ==============================================================
                // 3. 数据管理
                // ==============================================================
                SettingsSection(
                  title: '数据管理',
                  children: [
                    // 重置当前词书进度
                    ListTile(
                      leading: const Icon(
                        Icons.delete_outline,
                        color: Colors.red,
                      ),
                      title: const Text(
                        '重置当前词书进度',
                        style: TextStyle(color: Colors.red),
                      ),
                      subtitle: Text(
                        '重置 ${state.bookLabel} 的全部学习数据',
                        style: theme.textTheme.bodySmall,
                      ),
                      onTap: _showResetConfirmation,
                    ),

                    // 词书进度信息
                    ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: const Text('词书进度信息'),
                      subtitle: Text(
                        '已学习 ${state.learnedCount} 词  |  '
                        '待复习 ${state.reviewCount} 词  |  '
                        '已掌握 ${state.masteredCount} 词',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),

                // ==============================================================
                // 4. 关于
                // ==============================================================
                SettingsSection(
                  title: '关于',
                  children: [
                    ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: const Text('版本'),
                      subtitle: const Text('1.0.2'),
                    ),
                    ListTile(
                      title: const Text('四六级背单词'),
                      subtitle: Text(
                        '一款专为四六级考生打造的离线背单词应用，'
                        '支持每日学习、间隔复习、生词本管理，'
                        '助你高效备战四六级考试。',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  /// 构建提醒时间下方的副标题。
  ///
  /// 当提醒开启但通知权限未授权时，显示"未授权"以提示用户前往系统设置。
  Widget? _buildReminderSubtitle(SettingsState state) {
    if (!state.reminderEnabled) return null;

    // 用 FutureBuilder 异步检查权限状态
    return FutureBuilder<bool>(
      future: _checkNotificationPermission(),
      builder: (context, snapshot) {
        final hasPermission = snapshot.data ?? true;
        if (!hasPermission) {
          return const Text(
            '未授权 — 请前往系统设置开启通知',
            style: TextStyle(color: Colors.orange, fontSize: 12),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}
