import 'package:meta/meta.dart';

import '../domain/habit.dart';

/// Which payoff schedule applies to a habit.
///
/// Quitting alcohol and quitting doomscrolling both have a well-documented
/// day-by-day arc, but they are different arcs, so each abstinence habit maps
/// to a track and every track has its own set of days.
enum AbstinenceTrack { alcohol, dopamine, noFap, sugar, nicotine, generic }

/// A day-indexed thing that happens when you stop.
///
/// This is the payoff schedule for abstinence habits: on day 3 the app can
/// tell you *why* it feels bad and that it is on time, which is the difference
/// between "this isn't working" and "this is working exactly as expected".
///
/// The text lives in the app's localizations under `track` and `day`; only the
/// schedule itself is here.
@immutable
class AbstinenceMilestone {
  const AbstinenceMilestone({required this.track, required this.day});

  final AbstinenceTrack track;
  final int day;

  /// Stable key the app looks the wording up by, e.g. `alcohol_14`.
  String get id => '${track.name}_$day';

  @override
  bool operator ==(Object other) =>
      other is AbstinenceMilestone &&
      other.track == track &&
      other.day == day;

  @override
  int get hashCode => Object.hash(track, day);
}

const Map<AbstinenceTrack, List<int>> _milestoneDays =
    <AbstinenceTrack, List<int>>{
  AbstinenceTrack.alcohol: <int>[1, 3, 7, 14, 30, 90],
  AbstinenceTrack.dopamine: <int>[1, 3, 7, 21, 60],
  AbstinenceTrack.noFap: <int>[3, 7, 14, 30, 90],
  AbstinenceTrack.sugar: <int>[2, 5, 14, 30],
  AbstinenceTrack.nicotine: <int>[1, 3, 14, 90],
  AbstinenceTrack.generic: <int>[3, 21, 66],
};

AbstinenceTrack trackFor(HabitCategory category) {
  switch (category) {
    case HabitCategory.noAlcohol:
      return AbstinenceTrack.alcohol;
    case HabitCategory.dopamineDetox:
      return AbstinenceTrack.dopamine;
    case HabitCategory.noFap:
      return AbstinenceTrack.noFap;
    case HabitCategory.noSugar:
      return AbstinenceTrack.sugar;
    case HabitCategory.noNicotine:
      return AbstinenceTrack.nicotine;
    default:
      return AbstinenceTrack.generic;
  }
}

List<AbstinenceMilestone> milestonesFor(HabitCategory category) {
  final track = trackFor(category);
  return <AbstinenceMilestone>[
    for (final int day in _milestoneDays[track]!)
      AbstinenceMilestone(track: track, day: day),
  ];
}

/// The milestone the user has most recently passed, if any.
AbstinenceMilestone? currentMilestone(HabitCategory category, int streakDays) {
  AbstinenceMilestone? found;
  for (final m in milestonesFor(category)) {
    if (m.day <= streakDays) found = m;
  }
  return found;
}

/// The one they are walking towards.
AbstinenceMilestone? nextMilestone(HabitCategory category, int streakDays) {
  for (final m in milestonesFor(category)) {
    if (m.day > streakDays) return m;
  }
  return null;
}
