import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// The handful of strings the notification layer needs, resolved by the caller
/// in whatever language the app is running in.
///
/// Passed in rather than looked up here so this file stays free of both
/// Flutter's widget tree and of any one language.
class NotificationCopy {
  const NotificationCopy({
    required this.appTitle,
    required this.reminderChannelName,
    required this.reminderChannelDescription,
    required this.pressureChannelName,
    required this.pressureChannelDescription,
    required this.streakRiskTitle,
  });

  final String appTitle;
  final String reminderChannelName;
  final String reminderChannelDescription;
  final String pressureChannelName;
  final String pressureChannelDescription;
  final String streakRiskTitle;
}

/// Local, on-device notifications.
///
/// Pushes from friends come through `PushService`; this is everything the
/// phone schedules or shows by itself: the daily reminder, the evening
/// warning and "a friend was already active" while the app is open.
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  static const int _dailyIdBase = 1000;
  static const int _riskIdBase = 2000;
  static const int _socialIdBase = 3000;

  /// Channel names show up in the system settings, so they are localized too.
  /// Android updates a channel's name when it is next used with a new one.
  static AndroidNotificationDetails _reminderChannel(
    NotificationCopy copy,
  ) =>
      AndroidNotificationDetails(
        'daily_reminder',
        copy.reminderChannelName,
        channelDescription: copy.reminderChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
      );

  static AndroidNotificationDetails _pressureChannel(
    NotificationCopy copy,
  ) =>
      AndroidNotificationDetails(
        'social_pressure',
        copy.pressureChannelName,
        channelDescription: copy.pressureChannelDescription,
        importance: Importance.max,
        priority: Priority.max,
      );

  Future<bool> initialize() async {
    if (_ready) return true;
    tzdata.initializeTimeZones();

    const InitializationSettings settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    try {
      // On iOS the plugin answers `false` whenever it was told not to ask for
      // permission yet — which is what we tell it. It is initialised all the
      // same; treating that `false` as failure silenced every notification.
      await _plugin.initialize(settings);
      _ready = true;
    } on Object {
      _ready = false;
    }
    return _ready;
  }

  /// Asks the system for permission — once the user has said yes to being
  /// reminded in the app's own words.
  Future<bool> requestPermission() async {
    if (!_ready) return false;
    try {
      if (Platform.isIOS) {
        return await _plugin
                .resolvePlatformSpecificImplementation<
                    IOSFlutterLocalNotificationsPlugin>()
                ?.requestPermissions(alert: true, badge: true, sound: true) ??
            false;
      }
      return await _plugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.requestNotificationsPermission() ??
          false;
    } on Object {
      return false;
    }
  }

  /// Whether notifications can reach the user right now.
  Future<bool> isPermitted() async {
    if (!_ready) return false;
    try {
      if (Platform.isIOS) {
        final NotificationsEnabledOptions? options = await _plugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.checkPermissions();
        return options?.isEnabled ?? false;
      }
      return await _plugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.areNotificationsEnabled() ??
          false;
    } on Object {
      return false;
    }
  }

  /// Schedules the next [days] daily reminders at [hour]:[minute].
  ///
  /// Explicit per-day scheduling instead of a repeating rule: the app rewrites
  /// these on every launch, which lets each day's text reflect the actual
  /// state ("day 41, your streak is holding") rather than a generic string, and
  /// sidesteps the timezone drift of a UTC-anchored repeat.
  Future<void> scheduleDailyReminders({
    required NotificationCopy copy,
    required int hour,
    required int minute,
    required String? Function(int dayOffset) messageBuilder,
    int days = 14,
  }) async {
    if (!_ready) return;
    await cancelDailyReminders(days: days);

    final now = DateTime.now();
    for (var i = 0; i < days; i++) {
      final target = DateTime(now.year, now.month, now.day + i, hour, minute);
      if (target.isBefore(now)) continue;
      // Null: nothing to remind of that day (a rest day, a frozen day).
      final String? body = messageBuilder(i);
      if (body == null) continue;
      await _schedule(
        id: _dailyIdBase + i,
        title: copy.appTitle,
        body: body,
        when: target,
        android: _reminderChannel(copy),
      );
    }
  }

  /// The evening "your streak dies at midnight" warning, for the days on
  /// which [bodyBuilder] says there is a streak on the line (null: none).
  Future<void> scheduleStreakRisk({
    required NotificationCopy copy,
    required int hour,
    required int minute,
    required String? Function(int dayOffset) bodyBuilder,
    int days = 7,
  }) async {
    if (!_ready) return;
    await cancelStreakRisk(days: days);

    final now = DateTime.now();
    for (var i = 0; i < days; i++) {
      final target = DateTime(now.year, now.month, now.day + i, hour, minute);
      if (target.isBefore(now)) continue;
      final String? body = bodyBuilder(i);
      if (body == null) continue;
      await _schedule(
        id: _riskIdBase + i,
        title: copy.streakRiskTitle,
        body: body,
        when: target,
        android: _pressureChannel(copy),
      );
    }
  }

  Future<void> cancelDailyReminders({int days = 14}) async {
    if (!_ready) return;
    for (var i = 0; i < days; i++) {
      await _plugin.cancel(_dailyIdBase + i);
    }
  }

  Future<void> cancelStreakRisk({int days = 7}) async {
    if (!_ready) return;
    for (var i = 0; i < days; i++) {
      await _plugin.cancel(_riskIdBase + i);
    }
  }

  /// Fires immediately — used when a sync brings in a friend's check-in or a
  /// nudge addressed to us.
  Future<void> showNow({
    required NotificationCopy copy,
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_ready) return;
    await _plugin.show(
      _socialIdBase + (id.abs() % 500),
      title,
      body,
      NotificationDetails(
        android: _pressureChannel(copy),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  Future<void> cancelAll() async {
    if (_ready) await _plugin.cancelAll();
  }

  Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    required AndroidNotificationDetails android,
  }) async {
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(when, tz.UTC),
      NotificationDetails(
        android: android,
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
