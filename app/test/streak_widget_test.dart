import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hundred_core/hundred_core.dart';
import 'package:hundred_days/data/app_repository.dart';
import 'package:hundred_days/data/streak_widget.dart';
import 'package:hundred_days/l10n/l10n.dart';
import 'package:hundred_days/ui/mascot/mascot_mood.dart';

import 'helpers.dart';

/// The home screen widget shows only what the app hands it, so this is where
/// its honesty is checked: the same streak, the same rules, every word in the
/// reader's language.
void main() {
  late AppRepository repository;
  late AppLocalizations de;
  late AppLocalizations en;

  setUp(() async {
    repository = await testRepository();
    await repository.saveProfile(displayName: 'Mike', avatarEmoji: '🐺');
    de = await localizationsFor(const Locale('de'));
    en = await localizationsFor(const Locale('en'));
  });

  Future<Challenge> start() async {
    final Challenge challenge =
        testChallenge(habits: <HabitCategory>[HabitCategory.noSugar]);
    await repository.startChallenge(challenge);
    return challenge;
  }

  List<Map<String, Object?>> rows(StreakWidgetPayload payload) =>
      (payload.json['days']! as List<Object?>).cast<Map<String, Object?>>();

  test('an open first day: a hopeful ember and the invitation', () async {
    await start();
    final StreakWidgetPayload payload =
        buildStreakWidgetPayload(await repository.snapshot(), de, days: 3);
    final Map<String, Object?> today = rows(payload).first;

    expect(today['day'], DayKey.today().toString());
    expect(today['state'], 'cold');
    expect(today['streak'], 0);
    expect(today['status'], de.widgetCold);
    expect(today['image'], 'flame_ember_hopeful');
    expect(payload.images['flame_ember_hopeful'],
        (FlameStage.ember, MascotMood.hopeful));
  });

  test('a done day is fed today and at stake tomorrow', () async {
    final Challenge challenge = await start();
    await repository.checkIn(
      habit: challenge.habits.single,
      day: DayKey.today(),
      value: challenge.habits.single.target,
      challenge: challenge,
    );
    final AppSnapshot snapshot = await repository.snapshot();
    final List<Map<String, Object?>> days =
        rows(buildStreakWidgetPayload(snapshot, de, days: 3));

    expect(days[0]['state'], 'done');
    expect(days[0]['streak'], snapshot.me.streak.current);
    expect(days[0]['status'], de.widgetDone);
    expect(days[0]['image'], 'flame_spark_happy');

    // Tomorrow is open: the same one day is at stake, and the evening brings
    // the worried face and line.
    expect(days[1]['state'], 'open');
    expect(days[1]['streak'], 1);
    expect(days[1]['status'], de.widgetOpen);
    expect(days[1]['lateImage'], 'flame_spark_worried');
    // The evening line stays up for hours, so it never names how many.
    expect(
      de.mascotLines(MascotMood.worried, day: 2, streak: 1, hoursLeft: 0),
      contains(days[1]['lateLine']),
    );

    // Left untouched, it is gone the day after.
    expect(days[2]['state'], 'cold');
    expect(days[2]['streak'], 0);
  });

  test('every word is in the reader\'s language', () async {
    await start();
    final AppSnapshot snapshot = await repository.snapshot();
    final Map<String, Object> inGerman =
        buildStreakWidgetPayload(snapshot, de, days: 1).json;
    final Map<String, Object> inEnglish =
        buildStreakWidgetPayload(snapshot, en, days: 1).json;

    expect(inGerman['goesOutIn'], de.widgetGoesOutIn);
    expect(inEnglish['goesOutIn'], en.widgetGoesOutIn);
    expect(inGerman['goesOutIn'], isNot(inEnglish['goesOutIn']));
    expect((inGerman['weekdays']! as List<Object?>).first, 'Mo');
    expect((inGerman['weekdays']! as List<Object?>)[1], 'Di');
    expect((inEnglish['weekdays']! as List<Object?>)[1], 'Tu');
  });

  test('the timetable survives the trip through JSON', () async {
    await start();
    final StreakWidgetPayload payload =
        buildStreakWidgetPayload(await repository.snapshot(), en);
    final Map<String, dynamic> decoded =
        jsonDecode(jsonEncode(payload.json)) as Map<String, dynamic>;

    expect(decoded['days'], hasLength(14));
    for (final dynamic row in decoded['days'] as List<dynamic>) {
      expect((row as Map<String, dynamic>)['week'], hasLength(7));
      expect(payload.images.keys, contains(row['image']));
    }
    expect(payload.images.keys,
        contains((decoded['fallback'] as Map<String, dynamic>)['image']));
  });

  testWidgets('Funki renders to a PNG for the native side',
      (WidgetTester tester) async {
    final Uint8List? png = await tester.runAsync(
        () => renderFlamePng(FlameStage.blue, MascotMood.happy, pixels: 64));
    expect(png, isNotNull);
    // The PNG signature.
    expect(png!.sublist(0, 4), <int>[0x89, 0x50, 0x4E, 0x47]);
  });
}
