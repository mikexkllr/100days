import 'package:meta/meta.dart';

import '../util/dates.dart';

/// How a habit is scored.
enum HabitKind {
  /// Something you do: a workout, pages read, meals hit. Missing a day breaks
  /// the streak but the day itself is neutral.
  build,

  /// Something you avoid: alcohol, sugar, porn, doomscrolling. Every day that
  /// passes without a relapse counts, and a relapse resets to zero.
  abstain,
}

/// The unit a daily target is measured in — drives which check-in control the
/// UI shows (a tick, a stepper, a duration picker).
enum HabitUnit { done, minutes, count, pages, grams, kilocalories, steps }

enum HabitCategory {
  gym,
  cardio,
  nutrition,
  noAlcohol,
  noSugar,
  dopamineDetox,
  noFap,
  noNicotine,
  reading,
  meditation,
  sleep,
  coldShower,
  water,
  journaling,
  custom,
}

/// Static description of a habit type: everything that is true of "no sugar"
/// regardless of which user picked it — and of which language they read it in.
///
/// There is no title or description here on purpose. Display text lives in the
/// app's localizations, keyed by [category]; this package stays language-free
/// so the same rules produce the same numbers for a German and an English
/// user.
@immutable
class HabitDefinition {
  const HabitDefinition({
    required this.category,
    required this.kind,
    required this.unit,
    required this.emoji,
    required this.defaultTarget,
    required this.difficulty,
    this.defaultDaysPerWeek = 7,
  });

  final HabitCategory category;
  final HabitKind kind;
  final HabitUnit unit;

  /// Emoji are the one piece of presentation that survives translation.
  final String emoji;

  final num defaultTarget;

  /// 1–5. Feeds the XP formula, so a 60-minute gym session is worth more than
  /// drinking water.
  final int difficulty;

  final int defaultDaysPerWeek;
}

/// The built-in catalogue. Adding a habit type to the app means adding an
/// entry here — the plan generator, XP maths and UI all read from it.
const Map<HabitCategory, HabitDefinition> kHabitCatalog =
    <HabitCategory, HabitDefinition>{
  HabitCategory.gym: HabitDefinition(
    category: HabitCategory.gym,
    kind: HabitKind.build,
    unit: HabitUnit.done,
    emoji: '🏋️',
    defaultTarget: 1,
    defaultDaysPerWeek: 4,
    difficulty: 5,
  ),
  HabitCategory.cardio: HabitDefinition(
    category: HabitCategory.cardio,
    kind: HabitKind.build,
    unit: HabitUnit.minutes,
    emoji: '🏃',
    defaultTarget: 30,
    defaultDaysPerWeek: 3,
    difficulty: 4,
  ),
  HabitCategory.nutrition: HabitDefinition(
    category: HabitCategory.nutrition,
    kind: HabitKind.build,
    unit: HabitUnit.done,
    emoji: '🥗',
    defaultTarget: 1,
    difficulty: 4,
  ),
  HabitCategory.noAlcohol: HabitDefinition(
    category: HabitCategory.noAlcohol,
    kind: HabitKind.abstain,
    unit: HabitUnit.done,
    emoji: '🚱',
    defaultTarget: 1,
    difficulty: 4,
  ),
  HabitCategory.noSugar: HabitDefinition(
    category: HabitCategory.noSugar,
    kind: HabitKind.abstain,
    unit: HabitUnit.done,
    emoji: '🍬',
    defaultTarget: 1,
    difficulty: 4,
  ),
  HabitCategory.dopamineDetox: HabitDefinition(
    category: HabitCategory.dopamineDetox,
    kind: HabitKind.abstain,
    unit: HabitUnit.done,
    emoji: '🧠',
    defaultTarget: 1,
    difficulty: 5,
  ),
  HabitCategory.noFap: HabitDefinition(
    category: HabitCategory.noFap,
    kind: HabitKind.abstain,
    unit: HabitUnit.done,
    emoji: '🛡️',
    defaultTarget: 1,
    difficulty: 5,
  ),
  HabitCategory.noNicotine: HabitDefinition(
    category: HabitCategory.noNicotine,
    kind: HabitKind.abstain,
    unit: HabitUnit.done,
    emoji: '🚭',
    defaultTarget: 1,
    difficulty: 5,
  ),
  HabitCategory.reading: HabitDefinition(
    category: HabitCategory.reading,
    kind: HabitKind.build,
    unit: HabitUnit.pages,
    emoji: '📚',
    defaultTarget: 20,
    difficulty: 3,
  ),
  HabitCategory.meditation: HabitDefinition(
    category: HabitCategory.meditation,
    kind: HabitKind.build,
    unit: HabitUnit.minutes,
    emoji: '🧘',
    defaultTarget: 10,
    difficulty: 3,
  ),
  HabitCategory.sleep: HabitDefinition(
    category: HabitCategory.sleep,
    kind: HabitKind.build,
    unit: HabitUnit.minutes,
    emoji: '😴',
    defaultTarget: 450,
    difficulty: 3,
  ),
  HabitCategory.coldShower: HabitDefinition(
    category: HabitCategory.coldShower,
    kind: HabitKind.build,
    unit: HabitUnit.minutes,
    emoji: '🧊',
    defaultTarget: 2,
    difficulty: 3,
  ),
  HabitCategory.water: HabitDefinition(
    category: HabitCategory.water,
    kind: HabitKind.build,
    unit: HabitUnit.count,
    emoji: '💧',
    defaultTarget: 8,
    difficulty: 1,
  ),
  HabitCategory.journaling: HabitDefinition(
    category: HabitCategory.journaling,
    kind: HabitKind.build,
    unit: HabitUnit.done,
    emoji: '✍️',
    defaultTarget: 1,
    difficulty: 2,
  ),
  HabitCategory.custom: HabitDefinition(
    category: HabitCategory.custom,
    kind: HabitKind.build,
    unit: HabitUnit.done,
    emoji: '⭐',
    defaultTarget: 1,
    difficulty: 3,
  ),
};

HabitDefinition habitDefinition(HabitCategory category) =>
    kHabitCatalog[category]!;

/// When a habit is required: [daysPerWeek] spread over the week the usual
/// way, or exactly [weekdays] — "every day but Sunday, my cheat day" — or
/// never, when it is [optional] and only counts as a bonus.
@immutable
class HabitSchedule {
  const HabitSchedule({
    required this.daysPerWeek,
    this.weekdays,
    this.optional = false,
  });

  /// How many days a week, when [weekdays] does not name them.
  final int daysPerWeek;

  /// The required weekdays, `DateTime.monday` to `DateTime.sunday`, sorted.
  /// Null for the usual spread of [daysPerWeek].
  final List<int>? weekdays;

  /// Never required: done or not, it neither builds nor breaks the day.
  final bool optional;

  /// [weekdays] as a schedule keeps them: each day once, in order, within a
  /// week. An empty list is no list.
  static List<int>? normalize(Iterable<int>? days) {
    if (days == null) return null;
    final sorted = days.where((int d) => d >= 1 && d <= 7).toSet().toList()..sort();
    return sorted.isEmpty ? null : List<int>.unmodifiable(sorted);
  }

  @override
  bool operator ==(Object other) =>
      other is HabitSchedule &&
      other.daysPerWeek == daysPerWeek &&
      other.optional == optional &&
      _sameDays(other.weekdays, weekdays);

  @override
  int get hashCode => Object.hash(daysPerWeek, optional, weekdays?.join(','));

  static bool _sameDays(List<int>? a, List<int>? b) {
    if (a == null || b == null) return a == b;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// A past schedule: what applied to every day before [until]. Kept so that
/// changing "4 days a week" to 5 — or a habit made optional — does not turn
/// every past Wednesday into a missed training day, or mend a missed one.
@immutable
class ScheduleChange {
  const ScheduleChange({
    required this.until,
    required this.daysPerWeek,
    this.weekdays,
    this.optional = false,
  });

  factory ScheduleChange.fromJson(Map<String, dynamic> json) => ScheduleChange(
        until: DayKey.parse(json['until'] as String),
        daysPerWeek: (json['days'] as num).toInt(),
        weekdays: HabitSchedule.normalize(
            (json['weekdays'] as List<dynamic>?)?.map((dynamic d) => (d as num).toInt())),
        optional: json['optional'] == true,
      );

  final DayKey until;
  final int daysPerWeek;
  final List<int>? weekdays;
  final bool optional;

  HabitSchedule get schedule => HabitSchedule(
        daysPerWeek: daysPerWeek,
        weekdays: weekdays,
        optional: optional,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'until': until.toString(),
        'days': daysPerWeek,
        if (weekdays != null) 'weekdays': weekdays,
        if (optional) 'optional': true,
      };
}

/// A past target: [target] applied to every day before [until]. Raising
/// "20 pages" to 30 must not turn every past day of 25 pages into a miss.
@immutable
class TargetChange {
  const TargetChange({required this.until, required this.target});

  factory TargetChange.fromJson(Map<String, dynamic> json) => TargetChange(
        until: DayKey.parse(json['until'] as String),
        target: json['target'] as num,
      );

  final DayKey until;
  final num target;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'until': until.toString(),
        'target': target,
      };
}

/// A habit as this user configured it.
@immutable
class Habit {
  const Habit({
    required this.id,
    required this.category,
    required this.target,
    required this.daysPerWeek,
    this.title,
    this.note,
    this.activeFrom,
    this.activeUntil,
    this.scheduleHistory = const <ScheduleChange>[],
    this.targetHistory = const <TargetChange>[],
    this.weekdays,
    this.optional = false,
  });

  factory Habit.fromJson(Map<String, dynamic> json) => Habit(
        id: json['id'] as String,
        category: HabitCategory.values.byName(json['category'] as String),
        target: json['target'] as num,
        daysPerWeek: (json['daysPerWeek'] as num).toInt(),
        title: json['title'] as String?,
        note: json['note'] as String?,
        activeFrom: json['from'] == null
            ? null
            : DayKey.parse(json['from'] as String),
        scheduleHistory: ((json['history'] as List<dynamic>?) ??
                const <dynamic>[])
            .map((dynamic e) =>
                ScheduleChange.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(growable: false),
        activeUntil: json['until'] == null
            ? null
            : DayKey.parse(json['until'] as String),
        targetHistory: ((json['targets'] as List<dynamic>?) ??
                const <dynamic>[])
            .map((dynamic e) =>
                TargetChange.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(growable: false),
        // Both arrived later; an older phone leaves them out and an older
        // app reading them falls back to [daysPerWeek].
        weekdays: HabitSchedule.normalize(
            (json['weekdays'] as List<dynamic>?)?.map((dynamic d) => (d as num).toInt())),
        optional: json['optional'] == true,
      );

  factory Habit.fromCategory(HabitCategory category, {String? id}) {
    final def = habitDefinition(category);
    return Habit(
      id: id ?? category.name,
      category: category,
      target: def.defaultTarget,
      daysPerWeek: def.defaultDaysPerWeek,
    );
  }

  final String id;
  final HabitCategory category;
  final num target;

  /// How many days a week this habit is expected. 7 for abstinence habits;
  /// fewer for training, where rest days are part of the plan and must not
  /// count as misses.
  final int daysPerWeek;

  final String? title;
  final String? note;

  /// First day this habit counts. Null means "since the challenge started";
  /// set when a habit is added — or made visible to friends — later on, so
  /// the days before it neither break nor build the streak.
  final DayKey? activeFrom;

  /// First day this habit no longer counts — set when it is taken out of a
  /// running challenge. The days before keep it, so taking a habit out
  /// neither mends nor breaks the past.
  final DayKey? activeUntil;

  /// Earlier weekly frequencies, oldest first.
  final List<ScheduleChange> scheduleHistory;

  /// Earlier targets, oldest first.
  final List<TargetChange> targetHistory;

  /// The weekdays it is required on, when the user picked them — see
  /// [HabitSchedule.weekdays]. Null for the usual spread of [daysPerWeek].
  final List<int>? weekdays;

  /// Never required, only a bonus — see [HabitSchedule.optional].
  final bool optional;

  /// When it is required from now on.
  HabitSchedule get schedule => HabitSchedule(
        daysPerWeek: daysPerWeek,
        weekdays: weekdays,
        optional: optional,
      );

  /// When it was required on [day].
  HabitSchedule scheduleOn(DayKey day) {
    for (final change in scheduleHistory) {
      if (day.isBefore(change.until)) return change.schedule;
    }
    return schedule;
  }

  HabitDefinition get definition => habitDefinition(category);

  HabitKind get kind => definition.kind;

  String get emoji => definition.emoji;

  bool get isDaily =>
      !optional && (weekdays?.length ?? daysPerWeek) >= 7;

  bool isActiveOn(DayKey day) {
    final from = activeFrom;
    final until = activeUntil;
    return (from == null || !day.isBefore(from)) &&
        (until == null || day.isBefore(until));
  }

  /// Taken out of the challenge (from [activeUntil] on).
  bool isRetiredOn(DayKey day) {
    final until = activeUntil;
    return until != null && !day.isBefore(until);
  }

  /// The target that applied on [day].
  num targetOn(DayKey day) {
    for (final change in targetHistory) {
      if (day.isBefore(change.until)) return change.target;
    }
    return target;
  }

  /// This habit with a new target from [from] on, the old one kept for
  /// every day before.
  Habit withTarget(num value, {required DayKey from}) {
    if (value == target) return this;
    return _copy(
      target: value,
      targetHistory: <TargetChange>[
        ...targetHistory.where((TargetChange c) => c.until.isBefore(from)),
        TargetChange(until: from, target: targetOn(from.addDays(-1))),
      ],
    );
  }

  /// This habit taken out of the challenge from [from] on.
  Habit retiredFrom(DayKey from) => _copy(activeUntil: from);

  Habit _copy({
    num? target,
    DayKey? activeUntil,
    List<TargetChange>? targetHistory,
  }) =>
      Habit(
        id: id,
        category: category,
        target: target ?? this.target,
        daysPerWeek: daysPerWeek,
        title: title,
        note: note,
        activeFrom: activeFrom,
        activeUntil: activeUntil ?? this.activeUntil,
        scheduleHistory: scheduleHistory,
        targetHistory: targetHistory ?? this.targetHistory,
        weekdays: weekdays,
        optional: optional,
      );

  /// The weekly frequency that applied on [day].
  int daysPerWeekOn(DayKey day) => scheduleOn(day).daysPerWeek;

  /// This habit at a new weekly frequency from [from] on, spread the usual
  /// way, with the old schedule kept for every day before.
  Habit withDaysPerWeek(int days, {required DayKey from}) {
    if (days == daysPerWeek && weekdays == null) return this;
    return withSchedule(
      HabitSchedule(daysPerWeek: days, optional: optional),
      from: from,
    );
  }

  /// This habit on [next] from [from] on — other weekdays, required or
  /// optional — with the old schedule kept for every day before.
  Habit withSchedule(HabitSchedule next, {required DayKey from}) {
    final days = HabitSchedule.normalize(next.weekdays);
    final normalized = HabitSchedule(
      daysPerWeek: days?.length ?? next.daysPerWeek,
      weekdays: days,
      optional: next.optional,
    );
    if (normalized == schedule) return this;
    final before = scheduleOn(from.addDays(-1));
    return Habit(
      id: id,
      category: category,
      target: target,
      daysPerWeek: normalized.daysPerWeek,
      title: title,
      note: note,
      activeFrom: activeFrom,
      activeUntil: activeUntil,
      scheduleHistory: <ScheduleChange>[
        ...scheduleHistory.where((ScheduleChange c) => c.until.isBefore(from)),
        ScheduleChange(
          until: from,
          daysPerWeek: before.daysPerWeek,
          weekdays: before.weekdays,
          optional: before.optional,
        ),
      ],
      targetHistory: targetHistory,
      weekdays: normalized.weekdays,
      optional: normalized.optional,
    );
  }

  Habit copyWith({
    num? target,
    int? daysPerWeek,
    String? title,
    String? note,
    DayKey? activeFrom,
  }) =>
      Habit(
        id: id,
        category: category,
        target: target ?? this.target,
        daysPerWeek: daysPerWeek ?? this.daysPerWeek,
        title: title ?? this.title,
        note: note ?? this.note,
        activeFrom: activeFrom ?? this.activeFrom,
        activeUntil: activeUntil,
        scheduleHistory: scheduleHistory,
        targetHistory: targetHistory,
        weekdays: weekdays,
        optional: optional,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'category': category.name,
        'target': target,
        'daysPerWeek': daysPerWeek,
        if (title != null) 'title': title,
        if (note != null) 'note': note,
        if (activeFrom != null) 'from': activeFrom.toString(),
        if (scheduleHistory.isNotEmpty)
          'history':
              scheduleHistory.map((ScheduleChange c) => c.toJson()).toList(),
        if (activeUntil != null) 'until': activeUntil.toString(),
        if (targetHistory.isNotEmpty)
          'targets': targetHistory.map((TargetChange c) => c.toJson()).toList(),
        if (weekdays != null) 'weekdays': weekdays,
        if (optional) 'optional': true,
      };
}
