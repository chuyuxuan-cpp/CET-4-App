import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cet4_app/core/database/database.dart';
import 'package:cet4_app/core/providers/database_provider.dart';
import 'package:cet4_app/core/services/notification_service.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

/// 设置页的不可变状态快照。
@immutable
class SettingsState {
  final int dailyQuota;
  final String activeBook;
  final bool reminderEnabled;
  final TimeOfDay reminderTime;
  final bool isLoading;

  // 词书进度统计
  final int learnedCount;
  final int reviewCount;
  final int masteredCount;

  const SettingsState({
    required this.dailyQuota,
    required this.activeBook,
    required this.reminderEnabled,
    required this.reminderTime,
    required this.isLoading,
    this.learnedCount = 0,
    this.reviewCount = 0,
    this.masteredCount = 0,
  });

  factory SettingsState.initial() => const SettingsState(
        dailyQuota: 20,
        activeBook: 'cet4',
        reminderEnabled: false,
        reminderTime: TimeOfDay(hour: 20, minute: 0),
        isLoading: false,
        learnedCount: 0,
        reviewCount: 0,
        masteredCount: 0,
      );

  SettingsState copyWith({
    int? dailyQuota,
    String? activeBook,
    bool? reminderEnabled,
    TimeOfDay? reminderTime,
    bool? isLoading,
    int? learnedCount,
    int? reviewCount,
    int? masteredCount,
    bool clearProgress = false,
  }) {
    return SettingsState(
      dailyQuota: dailyQuota ?? this.dailyQuota,
      activeBook: activeBook ?? this.activeBook,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderTime: reminderTime ?? this.reminderTime,
      isLoading: isLoading ?? this.isLoading,
      learnedCount:
          clearProgress ? 0 : (learnedCount ?? this.learnedCount),
      reviewCount:
          clearProgress ? 0 : (reviewCount ?? this.reviewCount),
      masteredCount:
          clearProgress ? 0 : (masteredCount ?? this.masteredCount),
    );
  }

  /// 词书名称的中文标签。
  String get bookLabel => activeBook == 'cet6' ? 'CET-6' : 'CET-4';

  /// 正在学习中的单词数（stage 为 1/3/7 的单词）。
  int get inProgressCount =>
      (learnedCount - reviewCount - masteredCount).clamp(0, learnedCount);
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class SettingsNotifier extends Notifier<SettingsState> {
  @override
  SettingsState build() => SettingsState.initial();

  // -- helpers ----------------------------------------------------------------

  Future<AppDatabase> get _db => ref.read(databaseProvider.future);

  // -- 从数据库加载设置 --------------------------------------------------------

  Future<void> loadSettings() async {
    state = state.copyWith(isLoading: true);
    try {
      final db = await _db;

      // 读取各项设置，缺失时使用默认值
      final rawQuota = await db.getSetting('daily_quota');
      final dailyQuota = _parseInt(rawQuota, 20);

      final activeBook = await db.getSetting('active_book') ?? 'cet4';

      final rawReminder = await db.getSetting('reminder_enabled');
      final reminderEnabled = rawReminder == 'true';

      final rawTime = await db.getSetting('reminder_time');
      final reminderTime = _parseTimeOfDay(rawTime);

      // 加载当前词书进度
      final progressCounts = await _loadBookProgress(db, activeBook);

      state = state.copyWith(
        dailyQuota: dailyQuota,
        activeBook: activeBook,
        reminderEnabled: reminderEnabled,
        reminderTime: reminderTime,
        isLoading: false,
        learnedCount: progressCounts['learned'],
        reviewCount: progressCounts['review'],
        masteredCount: progressCounts['mastered'],
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
      debugPrint('SettingsNotifier.loadSettings 失败: $e');
    }
  }

  // -- 每日学习量 --------------------------------------------------------------

  Future<void> setDailyQuota(int quota) async {
    // 每日学习量只允许 10 / 20 / 30 / 50
    const validQuotas = {10, 20, 30, 50};
    if (!validQuotas.contains(quota)) return;

    state = state.copyWith(dailyQuota: quota);
    try {
      final db = await _db;
      await db.setSetting('daily_quota', quota.toString());
    } catch (e) {
      debugPrint('setDailyQuota 失败: $e');
    }
  }

  // -- 当前词书 ----------------------------------------------------------------

  Future<void> setActiveBook(String book) async {
    if (book != 'cet4' && book != 'cet6') return;

    state = state.copyWith(isLoading: true, activeBook: book);
    try {
      final db = await _db;
      await db.setSetting('active_book', book);

      // 加载新词书的进度
      final progressCounts = await _loadBookProgress(db, book);

      state = state.copyWith(
        isLoading: false,
        learnedCount: progressCounts['learned'],
        reviewCount: progressCounts['review'],
        masteredCount: progressCounts['mastered'],
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
      debugPrint('setActiveBook 失败: $e');
    }
  }

  // -- 每日提醒开关 ------------------------------------------------------------

  Future<void> setReminderEnabled(bool enabled) async {
    state = state.copyWith(reminderEnabled: enabled);
    try {
      final db = await _db;
      await db.setSetting('reminder_enabled', enabled.toString());

      if (enabled) {
        await _scheduleNotification();
      } else {
        await _cancelNotification();
      }
    } catch (e) {
      debugPrint('setReminderEnabled 失败: $e');
    }
  }

  // -- 提醒时间 ----------------------------------------------------------------

  Future<void> setReminderTime(TimeOfDay time) async {
    state = state.copyWith(reminderTime: time);
    try {
      final db = await _db;
      // 储存格式：HH:mm
      final formatted =
          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      await db.setSetting('reminder_time', formatted);

      // 如果当前提醒已开启，重新安排通知
      if (state.reminderEnabled) {
        await _scheduleNotification();
      }
    } catch (e) {
      debugPrint('setReminderTime 失败: $e');
    }
  }

  // -- 重置当前词书进度 --------------------------------------------------------

  Future<void> resetCurrentBook() async {
    final book = state.activeBook;
    try {
      final db = await _db;
      await db.resetBook(book);

      // 清空进度展示
      state = state.copyWith(
        clearProgress: true,
        learnedCount: 0,
        reviewCount: 0,
        masteredCount: 0,
      );
    } catch (e) {
      debugPrint('resetCurrentBook 失败: $e');
    }
  }

  // -- 通知调度 ----------------------------------------------------------------

  Future<void> _scheduleNotification() async {
    try {
      final service = NotificationService();
      await service.scheduleDailyReminder(state.reminderTime);
    } catch (e) {
      debugPrint('通知调度失败: $e');
    }
  }

  Future<void> _cancelNotification() async {
    try {
      final service = NotificationService();
      await service.cancelAllReminders();
    } catch (e) {
      debugPrint('通知取消失败: $e');
    }
  }

  /// 公开给 UI 层：手动请求并检查 Android 通知权限。
  Future<bool?> checkAndroidPermission() async {
    final service = NotificationService();
    return service.hasAndroidPermission;
  }

  // -- 内部辅助 ----------------------------------------------------------------

  int _parseInt(String? raw, int fallback) {
    if (raw == null) return fallback;
    return int.tryParse(raw) ?? fallback;
  }

  TimeOfDay _parseTimeOfDay(String? raw) {
    if (raw == null) return const TimeOfDay(hour: 20, minute: 0);
    final parts = raw.split(':');
    if (parts.length != 2) return const TimeOfDay(hour: 20, minute: 0);
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return const TimeOfDay(hour: 20, minute: 0);
    }
    return TimeOfDay(hour: hour, minute: minute);
  }

  /// 查询当前词书的进度统计：
  /// - learned: 所有有 progress 记录的单词数
  /// - review:   待复习单词数（stage != 99）
  /// - mastered: stage 为 99 的已掌握单词数
  Future<Map<String, int>> _loadBookProgress(
      AppDatabase db, String book) async {
    try {
      // 直接查所有该词书的 progress 记录，数据量小（CET-4 最多约 4000 条）
      final allProgress = await (db.select(db.progress)
        ..where((t) => t.book.equals(book)))
          .get();

      final learned = allProgress.length;
      final review = allProgress.where((p) => p.stage != 99).length;
      final mastered = allProgress.where((p) => p.stage == 99).length;

      return {
        'learned': learned,
        'review': review,
        'mastered': mastered,
      };
    } catch (e) {
      debugPrint('_loadBookProgress 失败: $e');
      return {'learned': 0, 'review': 0, 'mastered': 0};
    }
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final settingsProvider =
    NotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);
