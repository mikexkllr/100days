import 'package:meta/meta.dart';

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
  steps,
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
  HabitCategory.steps: HabitDefinition(
    category: HabitCategory.steps,
    kind: HabitKind.build,
    unit: HabitUnit.steps,
    emoji: '👟',
    defaultTarget: 10000,
    difficulty: 2,
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
  });

  factory Habit.fromJson(Map<String, dynamic> json) => Habit(
        id: json['id'] as String,
        category: HabitCategory.values.byName(json['category'] as String),
        target: json['target'] as num,
        daysPerWeek: (json['daysPerWeek'] as num).toInt(),
        title: json['title'] as String?,
        note: json['note'] as String?,
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

  HabitDefinition get definition => habitDefinition(category);

  HabitKind get kind => definition.kind;

  String get emoji => definition.emoji;

  bool get isDaily => daysPerWeek >= 7;

  Habit copyWith({num? target, int? daysPerWeek, String? title, String? note}) =>
      Habit(
        id: id,
        category: category,
        target: target ?? this.target,
        daysPerWeek: daysPerWeek ?? this.daysPerWeek,
        title: title ?? this.title,
        note: note ?? this.note,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'category': category.name,
        'target': target,
        'daysPerWeek': daysPerWeek,
        if (title != null) 'title': title,
        if (note != null) 'note': note,
      };
}
