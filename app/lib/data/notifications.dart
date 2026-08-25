import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Local, on-device notifications.
///
/// There is no push server anywhere in this app — there is no server at all —
/// so "your friend just trained" reaches you the moment a peer sync brings
/// their signed event onto your device, and everything else is a locally
/// scheduled reminder.
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  static const int _dailyIdBase = 1000;
  static const int _riskIdBase = 2000;
  static const int _socialIdBase = 3000;

  static const AndroidNotificationDetails _reminderChannel =
      AndroidNotificationDetails(
    'daily_reminder',
    'Tägliche Erinnerung',
    channelDescription: 'Erinnert dich an deine Gewohnheiten für heute.',
    importance: Importance.high,
    priority: Priority.high,
  );

  static const AndroidNotificationDetails _pressureChannel =
      AndroidNotificationDetails(
    'social_pressure',
    'Freunde & Streak-Warnungen',
    channelDescription:
        'Wenn Freunde aktiv waren oder dein Streak auf der Kippe steht.',
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
    _ready = await _plugin.initialize(settings) ?? false;
    return _ready;
  }

  Future<bool> requestPermission() async {
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
  }

  /// Schedules the next [days] daily reminders at [hour]:[minute].
  ///
  /// Explicit per-day scheduling instead of a repeating rule: the app rewrites
  /// these on every launch, which lets each day's text reflect the actual
  /// state ("Tag 41, dein Streak steht") rather than a generic string, and
  /// sidesteps the timezone drift of a UTC-anchored repeat.
  Future<void> scheduleDailyReminders({
    required int hour,
    required int minute,
    required String Function(int dayOffset) messageBuilder,
    int days = 14,
    String title = '100 Tage',
  }) async {
    if (!_ready) return;
    for (var i = 0; i < days; i++) {
      await _plugin.cancel(_dailyIdBase + i);
    }

    final now = DateTime.now();
    for (var i = 0; i < days; i++) {
      final target = DateTime(now.year, now.month, now.day + i, hour, minute);
      if (target.isBefore(now)) continue;
      await _schedule(
        id: _dailyIdBase + i,
        title: title,
        body: messageBuilder(i),
        when: target,
        android: _reminderChannel,
      );
    }
  }

  /// The evening "your streak dies at midnight" warning.
  Future<void> scheduleStreakRisk({
    required int hour,
    required int minute,
    required String body,
    int days = 7,
  }) async {
    if (!_ready) return;
    for (var i = 0; i < days; i++) {
      await _plugin.cancel(_riskIdBase + i);
    }

    final now = DateTime.now();
    for (var i = 0; i < days; i++) {
      final target = DateTime(now.year, now.month, now.day + i, hour, minute);
      if (target.isBefore(now)) continue;
      await _schedule(
        id: _riskIdBase + i,
        title: 'Dein Streak steht auf dem Spiel',
        body: body,
        when: target,
        android: _pressureChannel,
      );
    }
  }

  /// Fires immediately — used when a sync brings in a friend's check-in or a
  /// nudge addressed to us.
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_ready) return;
    await _plugin.show(
      _socialIdBase + (id.abs() % 500),
      title,
      body,
      const NotificationDetails(
        android: _pressureChannel,
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  Future<void> cancelAll() => _plugin.cancelAll();

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
