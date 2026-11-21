import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One set row as it stands in the logger: what is typed, and whether it
/// is ticked off.
@immutable
class DraftSet {
  const DraftSet({required this.weight, required this.reps, this.done = false});

  final String weight;
  final String reps;
  final bool done;

  List<Object> toJson() => <Object>[weight, reps, if (done) 1 else 0];

  static DraftSet? fromJson(Object? json) {
    if (json is! List || json.length < 3) return null;
    final Object? weight = json[0];
    final Object? reps = json[1];
    if (weight is! String || reps is! String) return null;
    return DraftSet(weight: weight, reps: reps, done: json[2] == 1);
  }
}

@immutable
class DraftExercise {
  const DraftExercise({required this.exerciseId, required this.sets});

  final String exerciseId;
  final List<DraftSet> sets;
}

/// A workout while it is being logged, written to the device on every
/// change. Android kills a backgrounded app whenever it likes — between two
/// sets, say, while a message is answered — and the sets entered so far
/// have to survive that.
@immutable
class WorkoutDraft {
  const WorkoutDraft({required this.startedAt, required this.exercises});

  final DateTime startedAt;
  final List<DraftExercise> exercises;

  int get doneSets => exercises.fold(
      0,
      (int sum, DraftExercise e) =>
          sum + e.sets.where((DraftSet s) => s.done).length);

  String encode() => jsonEncode(<String, dynamic>{
        'started': startedAt.toIso8601String(),
        'ex': <Map<String, dynamic>>[
          for (final DraftExercise e in exercises)
            <String, dynamic>{
              'id': e.exerciseId,
              's': e.sets.map((DraftSet s) => s.toJson()).toList(),
            },
        ],
      });

  /// Null for anything that is not a draft this version wrote.
  static WorkoutDraft? decode(String raw) {
    try {
      final Object? json = jsonDecode(raw);
      if (json is! Map) return null;
      final DateTime? started =
          DateTime.tryParse(json['started'] as String? ?? '');
      final Object? ex = json['ex'];
      if (started == null || ex is! List) return null;
      return WorkoutDraft(
        startedAt: started,
        exercises: <DraftExercise>[
          for (final Object? e in ex)
            if (e is Map && e['id'] is String && e['s'] is List)
              DraftExercise(
                exerciseId: e['id'] as String,
                sets: (e['s'] as List<dynamic>)
                    .map(DraftSet.fromJson)
                    .whereType<DraftSet>()
                    .toList(),
              ),
        ],
      );
    } on FormatException {
      return null;
    }
  }
}

/// Where unfinished workouts wait: the device's preferences, one entry per
/// account, day and session — a draft is never offered to someone else, or
/// for another session of the plan.
///
/// Every call swallows storage errors. A draft is a safety net; failing to
/// write one must not stop anyone from logging the workout itself.
class WorkoutDraftStore {
  WorkoutDraftStore({Future<SharedPreferences> Function()? preferences})
      : _preferences = preferences ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _preferences;

  static const String _prefix = 'workoutDraft/';

  static String _key(String userId, DayKey day, int session) =>
      '$_prefix$userId/$day/$session';

  Future<WorkoutDraft?> load(String userId, DayKey day, int session) async {
    try {
      final String? raw =
          (await _preferences()).getString(_key(userId, day, session));
      return raw == null ? null : WorkoutDraft.decode(raw);
    } on Object {
      return null;
    }
  }

  Future<void> save(
    String userId,
    DayKey day,
    int session,
    WorkoutDraft draft,
  ) async {
    try {
      await (await _preferences())
          .setString(_key(userId, day, session), draft.encode());
    } on Object {
      // Nothing to do: the workout on screen is still there.
    }
  }

  Future<void> clear(String userId, DayKey day, int session) async {
    try {
      await (await _preferences()).remove(_key(userId, day, session));
    } on Object {
      // A stale draft is pruned with the others.
    }
  }

  /// Drops [userId]'s drafts from before [keepFrom]. A workout is finished
  /// the day it was started, or the day after at the latest; older drafts
  /// would only be offered for a day that is long gone.
  Future<void> prune(String userId, DayKey keepFrom) async {
    try {
      final SharedPreferences prefs = await _preferences();
      final String mine = '$_prefix$userId/';
      for (final String key in prefs.getKeys().toList()) {
        if (!key.startsWith(mine)) continue;
        final List<String> parts = key.substring(mine.length).split('/');
        final DayKey? day = _tryParseDay(parts.first);
        if (day == null || day.isBefore(keepFrom)) await prefs.remove(key);
      }
    } on Object {
      // Left for the next time.
    }
  }

  static DayKey? _tryParseDay(String raw) {
    try {
      return DayKey.parse(raw);
    } on FormatException {
      return null;
    }
  }
}

final Provider<WorkoutDraftStore> workoutDraftStoreProvider =
    Provider<WorkoutDraftStore>((Ref ref) => WorkoutDraftStore());
