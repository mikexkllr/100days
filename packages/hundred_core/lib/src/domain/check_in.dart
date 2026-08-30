import 'package:meta/meta.dart';

import '../health/health_provenance.dart';
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
    this.eventHash,
    this.health,
  });

  factory CheckIn.fromPayload(
    Map<String, dynamic> payload, {
    required DateTime loggedAt,
    String? eventHash,
  }) =>
      CheckIn(
        habitId: payload['habitId'] as String,
        category: HabitCategory.values.byName(payload['category'] as String),
        day: DayKey.parse(payload['day'] as String),
        value: payload['value'] as num,
        loggedAt: loggedAt,
        note: payload['note'] as String?,
        relapse: payload['relapse'] as bool? ?? false,
        eventHash: eventHash,
        health: HealthProvenance.fromPayload(
          payload['health'] == null
              ? null
              : Map<String, dynamic>.from(payload['health'] as Map),
        ),
      );

  final String habitId;
  final HabitCategory category;
  final DayKey day;
  final num value;
  final DateTime loggedAt;
  final String? note;

  /// For abstinence habits: this entry is a confessed relapse, not a win.
  final bool relapse;

  final String? eventHash;

  /// Set when the entry was read out of Apple Health or Health Connect rather
  /// than tapped in. Null means a person entered it, which is also what every
  /// event written before health import existed looks like.
  final HealthProvenance? health;

  bool get isFromHealth => health != null;

  /// True when the entry was logged on the day it claims. Backfilling
  /// yesterday is allowed but never gets the verified badge.
  bool get isLive => DayKey.fromDateTime(loggedAt) == day;

  Map<String, dynamic> toPayload() => <String, dynamic>{
        'habitId': habitId,
        'category': category.name,
        'day': day.toString(),
        'value': value,
        if (note != null) 'note': note,
        if (relapse) 'relapse': true,
        if (health != null) 'health': health!.toPayload(),
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
