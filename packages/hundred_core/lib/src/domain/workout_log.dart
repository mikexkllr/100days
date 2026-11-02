import 'dart:math' as math;

import 'package:meta/meta.dart';

import '../plan/exercises.dart';
import '../plan/training.dart';
import '../util/dates.dart';

/// One working set as it was actually done.
@immutable
class LoggedSet {
  const LoggedSet({required this.weightKg, required this.reps});

  /// 0 for bodyweight movements.
  final double weightKg;
  final int reps;

  double get volumeKg => weightKg * reps;

  List<num> toJson() => <num>[weightKg, reps];

  static LoggedSet? fromJson(Object? json) {
    if (json is! List || json.length < 2) return null;
    final weight = json[0];
    final reps = json[1];
    if (weight is! num || reps is! num) return null;
    return LoggedSet(weightKg: weight.toDouble(), reps: reps.toInt());
  }

  @override
  bool operator ==(Object other) =>
      other is LoggedSet && other.weightKg == weightKg && other.reps == reps;

  @override
  int get hashCode => Object.hash(weightKg, reps);
}

@immutable
class ExerciseLog {
  const ExerciseLog({required this.exerciseId, required this.sets});

  final String exerciseId;
  final List<LoggedSet> sets;

  double get topWeightKg =>
      sets.fold(0.0, (double best, LoggedSet s) => math.max(best, s.weightKg));

  double get volumeKg =>
      sets.fold(0.0, (double sum, LoggedSet s) => sum + s.volumeKg);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': exerciseId,
        's': sets.map((LoggedSet s) => s.toJson()).toList(),
      };

  static ExerciseLog? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final raw = json['s'];
    if (id is! String || raw is! List) return null;
    return ExerciseLog(
      exerciseId: id,
      sets: raw.map(LoggedSet.fromJson).whereType<LoggedSet>().toList(),
    );
  }
}

/// A finished session, logged set by set.
///
/// Written as its own event next to the gym check-in: the check-in is what
/// the streak counts, the log is what the next session's recommendation is
/// computed from — and it is what makes the check-in a *tracked* one.
@immutable
class WorkoutLog {
  const WorkoutLog({
    required this.day,
    required this.kind,
    required this.sessionIndex,
    required this.exercises,
    required this.loggedAt,
    this.durationMinutes,
  });

  factory WorkoutLog.fromPayload(
    Map<String, dynamic> payload, {
    required DateTime loggedAt,
  }) =>
      WorkoutLog(
        day: DayKey.parse(payload['day'] as String),
        kind: WorkoutKind.values.asNameMap()[payload['kind'] as String?] ??
            WorkoutKind.fullBodyA,
        sessionIndex: (payload['session'] as num?)?.toInt() ?? 0,
        exercises: ((payload['ex'] as List<dynamic>?) ?? const <dynamic>[])
            .map(ExerciseLog.fromJson)
            .whereType<ExerciseLog>()
            .toList(),
        durationMinutes: (payload['min'] as num?)?.toInt(),
        loggedAt: loggedAt,
      );

  final DayKey day;
  final WorkoutKind kind;
  final int sessionIndex;
  final List<ExerciseLog> exercises;
  final DateTime loggedAt;
  final int? durationMinutes;

  int get totalSets =>
      exercises.fold(0, (int sum, ExerciseLog e) => sum + e.sets.length);

  double get volumeKg =>
      exercises.fold(0.0, (double sum, ExerciseLog e) => sum + e.volumeKg);

  ExerciseLog? forExercise(String exerciseId) {
    for (final e in exercises) {
      if (e.exerciseId == exerciseId) return e;
    }
    return null;
  }

  Map<String, dynamic> toPayload() => <String, dynamic>{
        'day': day.toString(),
        'kind': kind.name,
        'session': sessionIndex,
        'ex': exercises
            .where((ExerciseLog e) => e.sets.isNotEmpty)
            .map((ExerciseLog e) => e.toJson())
            .toList(),
        if (durationMinutes != null) 'min': durationMinutes,
      };
}

/// What the recommender says about the next session of one exercise.
enum ProgressionAdvice {
  /// No history yet: pick a weight that leaves the target reps in reserve.
  firstTime,

  /// Every set reached the top of the rep range: add weight, restart at the
  /// bottom of the range.
  addWeight,

  /// Inside the range: same weight, one more rep per set.
  addReps,

  /// Below the range: same weight, consolidate at the bottom.
  hold,

  /// Below the range twice in a row: take 10 % off and build back up.
  reduce,
}

@immutable
class SetRecommendation {
  const SetRecommendation({
    required this.advice,
    required this.reps,
    this.weightKg,
  });

  final ProgressionAdvice advice;

  /// Null when there is nothing to base a weight on yet.
  final double? weightKg;

  /// Target reps per set.
  final List<int> reps;
}

/// Double progression: climb the rep range at a fixed weight, and once every
/// set reaches the top, add the smallest load jump and start at the bottom
/// again. It is the progression rule most hypertrophy programmes use, and it
/// needs nothing but the last session or two to work.
///
/// [history] is newest first and only contains this exercise's logs.
SetRecommendation recommendNext({
  required PlannedSet target,
  required List<ExerciseLog> history,
}) {
  final exercise = kExerciseById[target.exerciseId];
  final low = target.repsLow;
  final high = target.repsHigh;
  if (history.isEmpty || history.first.sets.isEmpty) {
    return SetRecommendation(
      advice: ProgressionAdvice.firstTime,
      reps: List<int>.filled(target.sets, low),
    );
  }

  final last = history.first;
  final weight = last.topWeightKg;
  final increment = exercise == null ? 2.5 : progressionIncrementKg(exercise);
  final topSets =
      last.sets.where((LoggedSet s) => s.weightKg >= weight).toList();
  final bodyweight = weight <= 0 || increment == 0;

  bool allAtLeast(List<LoggedSet> sets, int reps) =>
      sets.isNotEmpty && sets.every((LoggedSet s) => s.reps >= reps);

  // Reps to aim for at the same weight: one more than last time, per set,
  // capped at the top of the range.
  List<int> nextReps() => <int>[
        for (var i = 0; i < target.sets; i++)
          math.min(
            (i < topSets.length ? topSets[i].reps : topSets.last.reps) + 1,
            high,
          ).clamp(low, high),
      ];

  if (allAtLeast(topSets, high)) {
    if (bodyweight) {
      // No load to add: keep climbing reps past the range.
      return SetRecommendation(
        advice: ProgressionAdvice.addReps,
        reps: List<int>.filled(target.sets, high + 1),
      );
    }
    return SetRecommendation(
      advice: ProgressionAdvice.addWeight,
      weightKg: weight + increment,
      reps: List<int>.filled(target.sets, low),
    );
  }

  if (allAtLeast(topSets, low)) {
    return SetRecommendation(
      advice: ProgressionAdvice.addReps,
      weightKg: bodyweight ? null : weight,
      reps: nextReps(),
    );
  }

  final previous = history.length > 1 ? history[1] : null;
  final missedTwice = previous != null &&
      previous.topWeightKg >= weight &&
      !allAtLeast(
        previous.sets
            .where((LoggedSet s) => s.weightKg >= previous.topWeightKg)
            .toList(),
        low,
      );
  if (missedTwice && !bodyweight) {
    return SetRecommendation(
      advice: ProgressionAdvice.reduce,
      weightKg: _roundTo(weight * 0.9, increment),
      reps: List<int>.filled(target.sets, low),
    );
  }

  return SetRecommendation(
    advice: ProgressionAdvice.hold,
    weightKg: bodyweight ? null : weight,
    reps: List<int>.filled(target.sets, low),
  );
}

double _roundTo(double value, double step) {
  if (step <= 0) return value;
  return (value / step).round() * step;
}
