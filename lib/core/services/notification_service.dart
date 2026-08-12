import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// 本地通知服务：负责每日学习提醒的调度与取消。
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // ---------------------------------------------------------------------------
  // 初始化
  // ---------------------------------------------------------------------------

  /// 在应用启动时调用一次，配置 Android 通知渠道与 iOS 权限。
  Future<void> initialize() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(initSettings);

    // 初始化时区数据（zonedSchedule 需要）
    tz_data.initializeTimeZones();

    // Android 13+ 需要运行时请求通知权限
    await _requestAndroidPermission();

    // iOS 主动请求通知权限
    await _requestIosPermission();
  }

  Future<void> _requestIosPermission() async {
    final iosPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    if (iosPlugin == null) return;
    await iosPlugin.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  /// 请求 Android 13+ 通知权限；已授权或更低版本为 no-op。
  Future<bool> requestAndroidPermission() => _requestAndroidPermission();

  Future<bool> _requestAndroidPermission() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return true; // 非 Android 平台
    final granted = await androidPlugin.requestNotificationsPermission();
    return granted ?? false;
  }

  /// 检查 Android 通知权限是否已授予。
  /// 返回 `null` 时表示平台不支持或无需检查。
  Future<bool?> get hasAndroidPermission async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return null;
    return androidPlugin.areNotificationsEnabled();
  }

  /// 检查 iOS 通知权限是否已授予。
  Future<bool?> get hasIosPermission async {
    final iosPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    if (iosPlugin == null) return null;
    return iosPlugin.requestPermissions(
        alert: false, badge: false, sound: false);
  }

  // ---------------------------------------------------------------------------
  // 每日提醒
  // ---------------------------------------------------------------------------

  /// 安排在每天的 [time] 触发本地通知，用于每日学习提醒。
  ///
  /// 如果已经存在同 ID 的提醒，旧提醒会被自动替换。
  Future<void> scheduleDailyReminder(TimeOfDay time) async {
    const androidDetails = AndroidNotificationDetails(
      'daily_reminder_channel',
      '每日学习提醒',
      channelDescription: '四六级背单词每日学习提醒',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final now = DateTime.now();
    var scheduledDate = DateTime(
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    // 如果今天的目标时间已经过去，则从明天开始
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      0, // notification id — fixed, since we only have one reminder
      '该背单词啦！',
      '今天的学习任务还没完成，快来打卡吧！',
      tz.TZDateTime.from(scheduledDate, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // 每天重复
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// 取消所有已安排的本地通知。
  Future<void> cancelAllReminders() async {
    await _plugin.cancelAll();
  }

  /// 显示一条即时通知（通常用于调试确认）。
  Future<void> showImmediate({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'daily_reminder_channel',
      '每日学习提醒',
      channelDescription: '四六级背单词每日学习提醒',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(1, title, body, details);
  }
}
