import 'package:meta/meta.dart';

import '../domain/challenge.dart';
import '../domain/outlook.dart';

/// Which sentence Funki sends. Each phrasing is its own value, so the app
/// owns the wording in every language and the rules stay testable without
/// asserting on prose.
enum FunkiPushTemplate {
  // The day is open and a streak is alive.
  feedMe,
  hungry,
  yesterdayToo,
  twoMinutes,

  /// The day is a milestone of the challenge.
  milestone,

  // The day is open and there is no streak: a first day.
  firstSpark,
  startSmall,

  // The streak went out — one message a day, each quieter than the last,
  // and then none: a reminder nobody answers is noise.
  flameOut,
  inTheDark,
  dayOneAgain,
  goodbye,

  // The evening of an open day with a streak at stake.
  lastCallFlicker,
  lastCallMath,
  lastCallSmallest,
}

/// One notification from Funki and the numbers its sentence needs.
@immutable
class FunkiPush {
  const FunkiPush(
    this.template, {
    required this.dayNumber,
    required this.totalDays,
    this.streak = 0,
    this.lostStreak = 0,
  });

  final FunkiPushTemplate template;

  /// The day of the challenge the notification is for.
  final int dayNumber;
  final int totalDays;

  /// The streak alive that day.
  final int streak;

  /// The streak that went out before it, for the days after.
  final int lostStreak;
}

/// After how many days without a streak Funki says goodbye and falls
/// silent.
const int kFunkiGoodbyeDay = 5;

const List<FunkiPushTemplate> _kKeepGoing = <FunkiPushTemplate>[
  FunkiPushTemplate.feedMe,
  FunkiPushTemplate.hungry,
  FunkiPushTemplate.yesterdayToo,
  FunkiPushTemplate.twoMinutes,
];

const List<FunkiPushTemplate> _kLastCalls = <FunkiPushTemplate>[
  FunkiPushTemplate.lastCallFlicker,
  FunkiPushTemplate.lastCallMath,
  FunkiPushTemplate.lastCallSmallest,
];

/// Funki's daily reminder for each day of [outlook] — the days to come if
/// nothing more is logged, which is exactly when a reminder fires. Null:
/// nothing to say that day.
///
/// A day that is done, resting or frozen gets none. While a streak is alive
/// the sentences take turns, so the same one does not come two days
/// running; a milestone day says so. Once the streak is out he asks for a
/// new first day, a little quieter each day, says goodbye on day
/// [kFunkiGoodbyeDay] and then leaves the user alone.
List<FunkiPush?> funkiReminders(List<StreakOutlook> outlook, Challenge challenge) {
  final List<FunkiPush?> pushes = <FunkiPush?>[];
  // The streak that was alive before the cold days began, and how many of
  // them there have been.
  int lost = 0;
  int cold = 0;
  for (final StreakOutlook day in outlook) {
    final int number = challenge.dayNumber(day.day);
    FunkiPush push(FunkiPushTemplate template) => FunkiPush(
          template,
          dayNumber: number,
          totalDays: challenge.lengthDays,
          streak: day.streak,
          lostStreak: lost,
        );
    switch (day.state) {
      case OutlookState.done:
      case OutlookState.rest:
      case OutlookState.frozen:
        pushes.add(null);
      case OutlookState.open:
        cold = 0;
        if (day.streak > 0) lost = day.streak;
        pushes.add(push(
          // The first days are milestones too, but nobody needs to be
          // told that day 1 is one.
          kMilestoneDays.contains(number) && number >= 7 && day.streak > 0
              ? FunkiPushTemplate.milestone
              : day.streak > 0
                  ? _kKeepGoing[number % _kKeepGoing.length]
                  : number.isEven
                      ? FunkiPushTemplate.startSmall
                      : FunkiPushTemplate.firstSpark,
        ));
      case OutlookState.cold:
        cold++;
        pushes.add(switch (cold) {
          1 => push(lost > 0
              ? FunkiPushTemplate.flameOut
              : FunkiPushTemplate.firstSpark),
          2 => push(lost > 0
              ? FunkiPushTemplate.inTheDark
              : FunkiPushTemplate.startSmall),
          3 => push(FunkiPushTemplate.dayOneAgain),
          kFunkiGoodbyeDay => push(FunkiPushTemplate.goodbye),
          _ => null,
        });
    }
  }
  return pushes;
}

/// Funki's last call for each evening of [outlook]: only for an open day
/// with at least [minStreak] days at stake — never for a day that is done,
/// resting or held by a freeze.
List<FunkiPush?> funkiLastCalls(
  List<StreakOutlook> outlook,
  Challenge challenge, {
  int minStreak = 2,
}) =>
    <FunkiPush?>[
      for (final StreakOutlook day in outlook)
        day.state == OutlookState.open && day.streak >= minStreak
            ? FunkiPush(
                _kLastCalls[day.streak % _kLastCalls.length],
                dayNumber: challenge.dayNumber(day.day),
                totalDays: challenge.lengthDays,
                streak: day.streak,
              )
            : null,
    ];
