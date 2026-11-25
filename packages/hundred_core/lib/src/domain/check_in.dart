import 'package:meta/meta.dart';

import '../util/dates.dart';
import 'habit.dart';

/// A single habit logged for a single day.
///
/// Note the two timestamps: [day] is what the user claims, [loggedAt] is when
/// they actually pressed the button. Friends see both, which is why
/// retroactive check-ins are visibly retroactive.
@immutable
class CheckIn {
  const CheckIn({
    required this.habitId,
    required this.category,
    required this.day,
    required this.value,
    required this.loggedAt,
    this.note,
    this.relapse = false,
    this.tracked = false,
    this.eventId,
    this.utcOffsetMinutes,
  });

  factory CheckIn.fromPayload(
    Map<String, dynamic> payload, {
    required DateTime loggedAt,
    String? eventId,
  }) =>
      CheckIn(
        habitId: payload['habitId'] as String,
        category: HabitCategory.values.byName(payload['category'] as String),
        day: DayKey.parse(payload['day'] as String),
        value: payload['value'] as num,
        loggedAt: loggedAt,
        note: payload['note'] as String?,
        relapse: payload['relapse'] as bool? ?? false,
        tracked: payload['tracked'] as bool? ?? false,
        eventId: eventId,
        utcOffsetMinutes: (payload['tz'] as num?)?.toInt(),
      );

  final String habitId;
  final HabitCategory category;
  final DayKey day;
  final num value;
  final DateTime loggedAt;
  final String? note;

  /// For abstinence habits: this entry is a confessed relapse, not a win.
  final bool relapse;

  /// Backed by the full tool rather than a tick: a workout logged set by set,
  /// or a food diary closed on target. Earns the plan bonus in XP.
  final bool tracked;

  final String? eventId;

  /// The writer's offset from UTC when they logged it. Lets every device
  /// judge [isLive] by the writer's clock rather than its own: a check-in at
  /// 22:00 in Los Angeles is live, even to a friend for whom it is already
  /// tomorrow. Null for entries written before the offset was recorded.
  final int? utcOffsetMinutes;

  /// True when the entry was logged on the day it claims. Backfilling
  /// yesterday is allowed but never gets the verified badge.
  bool get isLive => _writerDay(loggedAt) == day;

  DayKey _writerDay(DateTime at) {
    final offset = utcOffsetMinutes;
    if (offset == null) return DayKey.fromDateTime(at);
    final shifted = at.toUtc().add(Duration(minutes: offset));
    return DayKey(shifted.year, shifted.month, shifted.day);
  }

  Map<String, dynamic> toPayload() => <String, dynamic>{
        'habitId': habitId,
        'category': category.name,
        'day': day.toString(),
        'value': value,
        if (note != null) 'note': note,
        if (relapse) 'relapse': true,
        if (tracked) 'tracked': true,
        if (utcOffsetMinutes != null) 'tz': utcOffsetMinutes,
      };
}

/// Everything logged on one day, for one person.
@immutable
class DayLog {
  const DayLog({required this.day, required this.entries});

  final DayKey day;
  final List<CheckIn> entries;

  bool hasHabit(String habitId) =>
      entries.any((CheckIn e) => e.habitId == habitId && !e.relapse);

  CheckIn? entryFor(String habitId) {
    for (final entry in entries) {
      if (entry.habitId == habitId) return entry;
    }
    return null;
  }

  bool get hasRelapse => entries.any((CheckIn e) => e.relapse);

  bool get isEmpty => entries.isEmpty;
}
