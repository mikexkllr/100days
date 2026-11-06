import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:hundred_core/hundred_core.dart';

import '../l10n/l10n.dart';
import '../ui/mascot/flame_painter.dart';
import 'app_repository.dart';

/// The streak on the home screen.
///
/// The native widget cannot run Dart and cannot read the feed, so the app
/// leaves it everything it needs, already decided and already translated: a
/// two-week timetable from [projectOutlook] — what to show on each day if
/// nothing more is logged — plus Funki, painted by the same [FlamePainter]
/// as in the app, once per form and mood the timetable needs. The widget
/// only picks today's row. Opening the app or checking in rewrites it.
class StreakWidgetSync {
  StreakWidgetSync();

  /// Class name of the Android `AppWidgetProvider`.
  static const String androidProvider = 'StreakWidgetProvider';

  /// The WidgetKit kind of the iOS widget.
  static const String iosKind = 'StreakWidget';

  /// Shared container between the app and the iOS widget extension.
  static const String appGroup = 'group.com.hundreddays.hundredDays';

  /// Where the timetable is stored; the native widgets read the same key.
  static const String outlookKey = 'streak_outlook';
  static const int _days = 14;

  String? _lastSignature;

  static bool get _supported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Rewrites the widget's timetable when anything it shows has changed.
  Future<void> publish(AppSnapshot snapshot, AppLocalizations l10n) async {
    final Challenge? challenge = snapshot.challenge;
    if (!_supported || challenge == null) return;
    final StreakStats streak = snapshot.me.streak;
    // Everything the timetable is computed from: an edited schedule moves
    // rest days, so the challenge itself is part of it.
    final String signature =
        '${snapshot.today}-${streak.current}-'
        '${streak.doneToday}-${snapshot.me.frozenDays.length}-'
        '${snapshot.me.logsByDay.length}-${l10n.localeName}-'
        '${challenge.toJson()}';
    if (signature == _lastSignature) return;

    try {
      if (Platform.isIOS) await HomeWidget.setAppGroupId(appGroup);
      final StreakWidgetPayload payload = buildStreakWidgetPayload(
        snapshot,
        l10n,
        days: _days,
      );
      for (final MapEntry<String, (FlameStage, MascotMood)> image
          in payload.images.entries) {
        await HomeWidget.saveFile(
          image.key,
          await renderFlamePng(image.value.$1, image.value.$2),
          extension: 'png',
        );
      }
      await HomeWidget.saveWidgetData<String>(
        outlookKey,
        jsonEncode(payload.json),
      );

      await HomeWidget.updateWidget(
        androidName: androidProvider,
        iOSName: iosKind,
      );
      if (Platform.isAndroid) await _scheduleFlips(snapshot.today);
      _lastSignature = signature;
    } on Object catch (error) {
      // No widget, no app group, no plugin (tests): the app works without.
      debugPrint('Streak widget not updated: $error');
    }
  }

  /// Midnight changes the day; eight in the evening changes Funki's face.
  /// Android only redraws widgets on its own every half hour at best.
  Future<void> _scheduleFlips(DayKey today) async {
    final List<DateTime> times = <DateTime>[];
    final DateTime now = DateTime.now();
    for (int i = 0; i < 7; i++) {
      final DateTime day = today.addDays(i).toDateTime();
      for (final DateTime at in <DateTime>[
        day.add(const Duration(hours: 20)),
        day.add(const Duration(days: 1, seconds: 20)),
      ]) {
        if (at.isAfter(now)) times.add(at);
      }
    }
    await HomeWidget.scheduleWidgetUpdates(times, androidName: androidProvider);
  }

  /// Whether the system can put the widget on the home screen for the user.
  Future<bool> canPin() async {
    if (!_supported || !Platform.isAndroid) return false;
    try {
      if (await HomeWidget.isRequestPinWidgetSupported() != true) return false;
      final List<HomeWidgetInfo> installed =
          await HomeWidget.getInstalledWidgets();
      return installed.isEmpty;
    } on Object {
      return false;
    }
  }

  Future<void> requestPin() async {
    try {
      await HomeWidget.requestPinWidget(androidName: androidProvider);
    } on Object catch (error) {
      debugPrint('Pinning the streak widget failed: $error');
    }
  }
}

/// What the widget is handed: the timetable as JSON, and the pictures of
/// Funki it refers to, by key.
class StreakWidgetPayload {
  const StreakWidgetPayload({required this.json, required this.images});

  final Map<String, Object> json;
  final Map<String, (FlameStage, MascotMood)> images;
}

/// The timetable for the coming [days]: one row per day with the state, the
/// streak still alive, the week strip, and every word already translated —
/// the native side has no strings of its own beyond the widget's name.
StreakWidgetPayload buildStreakWidgetPayload(
  AppSnapshot snapshot,
  AppLocalizations l10n, {
  int days = 14,
}) {
  final Challenge challenge = snapshot.challenge!;
  final List<StreakOutlook> outlook = projectOutlook(
    challenge: challenge,
    streak: snapshot.me.streak,
    today: snapshot.today,
    logsByDay: snapshot.me.logsByDay,
    frozenDays: snapshot.me.frozenDays,
    days: days,
  );

  final Map<String, (FlameStage, MascotMood)> images =
      <String, (FlameStage, MascotMood)>{};
  String image(FlameStage stage, MascotMood mood) {
    final String key = 'flame_${stage.name}_${mood.name}';
    images[key] = (stage, mood);
    return key;
  }

  final List<Map<String, Object>> rows = <Map<String, Object>>[
    for (final StreakOutlook day in outlook)
      _row(day, challenge.dayNumber(day.day), l10n, image),
  ];

  return StreakWidgetPayload(
    images: images,
    json: <String, Object>{
      'version': 1,
      'goesOutIn': l10n.widgetGoesOutIn,
      'weekdays': <String>[
        for (int d = DateTime.monday; d <= DateTime.sunday; d++)
          l10n.weekdayLetters(d),
      ],
      // Two weeks without opening the app: whatever streak there was is
      // gone, and the widget falls back to this.
      'fallback': <String, Object>{
        'status': l10n.widgetCold,
        'streakLabel': l10n.ringDayStreak(0),
        'line': l10n.mascotHopeful1,
        'image': image(FlameStage.ember, MascotMood.hopeful),
      },
      'days': rows,
    },
  );
}

Map<String, Object> _row(
  StreakOutlook day,
  int dayNumber,
  AppLocalizations l10n,
  String Function(FlameStage stage, MascotMood mood) image,
) {
  final MascotMood mood = switch (day.state) {
    OutlookState.done => MascotMood.happy,
    OutlookState.open => MascotMood.hungry,
    OutlookState.rest || OutlookState.frozen => MascotMood.sleepy,
    OutlookState.cold => MascotMood.hopeful,
  };
  return <String, Object>{
    ...day.toJson(),
    'dayNumber': dayNumber,
    'streakLabel': l10n.ringDayStreak(day.streak),
    'status': switch (day.state) {
      OutlookState.done => l10n.widgetDone,
      OutlookState.open => l10n.widgetOpen,
      OutlookState.rest => l10n.widgetRest,
      OutlookState.frozen => l10n.widgetFrozen,
      OutlookState.cold => l10n.widgetCold,
    },
    'stageName': l10n.stageName(day.stage),
    'image': image(day.stage, mood),
    // A row is shown for hours on end, so no line may name the hours left.
    'line': l10n.mascotLineFor(
      mood,
      day: dayNumber,
      streak: day.streak,
      hoursLeft: 0,
    ),
    // An open day turns worried in the evening; the widget switches by the
    // clock, so it gets that face and line too.
    if (day.state == OutlookState.open) ...<String, Object>{
      'lateImage': image(day.stage, MascotMood.worried),
      'lateLine': l10n.mascotLineFor(
        MascotMood.worried,
        day: dayNumber,
        streak: day.streak,
        hoursLeft: 0,
      ),
    },
  };
}

/// Funki as a PNG, for places Flutter does not draw: the home screen widget.
Future<Uint8List> renderFlamePng(
  FlameStage stage,
  MascotMood mood, {
  int pixels = 360,
}) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(recorder);
  final ui.Size size = ui.Size.square(pixels.toDouble());
  FlamePainter(
    stage: stage,
    mood: mood,
    // A moment that reads well standing still: tongues up, eyes open.
    seconds: 1.15,
    blink: false,
  ).paint(canvas, size);
  final ui.Image image = await recorder.endRecording().toImage(pixels, pixels);
  final ByteData? bytes = await image.toByteData(
    format: ui.ImageByteFormat.png,
  );
  image.dispose();
  if (bytes == null) throw StateError('could not encode the flame');
  return bytes.buffer.asUint8List(
    bytes.offsetInBytes,
    math.max(0, bytes.lengthInBytes),
  );
}
