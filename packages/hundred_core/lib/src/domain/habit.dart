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
/// regardless of which user picked it.
@immutable
class HabitDefinition {
  const HabitDefinition({
    required this.category,
    required this.kind,
    required this.unit,
    required this.titleDe,
    required this.titleEn,
    required this.emoji,
    required this.defaultTarget,
    required this.difficulty,
    required this.blurbDe,
    this.defaultDaysPerWeek = 7,
  });

  final HabitCategory category;
  final HabitKind kind;
  final HabitUnit unit;
  final String titleDe;
  final String titleEn;
  final String emoji;
  final num defaultTarget;

  /// 1–5. Feeds the XP formula, so a 60-minute gym session is worth more than
  /// drinking water.
  final int difficulty;
  final String blurbDe;
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
    titleDe: 'Training',
    titleEn: 'Training',
    emoji: '🏋️',
    defaultTarget: 1,
    defaultDaysPerWeek: 4,
    difficulty: 5,
    blurbDe: 'Krafttraining nach Plan. Progressive Überlastung, kein Zufall.',
  ),
  HabitCategory.cardio: HabitDefinition(
    category: HabitCategory.cardio,
    kind: HabitKind.build,
    unit: HabitUnit.minutes,
    titleDe: 'Cardio',
    titleEn: 'Cardio',
    emoji: '🏃',
    defaultTarget: 30,
    defaultDaysPerWeek: 3,
    difficulty: 4,
    blurbDe: 'Ausdauer im lockeren Bereich. Zone 2, nicht kaputt machen.',
  ),
  HabitCategory.nutrition: HabitDefinition(
    category: HabitCategory.nutrition,
    kind: HabitKind.build,
    unit: HabitUnit.done,
    titleDe: 'Ernährung',
    titleEn: 'Nutrition',
    emoji: '🥗',
    defaultTarget: 1,
    difficulty: 4,
    blurbDe: 'Kalorien- und Proteinziel getroffen.',
  ),
  HabitCategory.noAlcohol: HabitDefinition(
    category: HabitCategory.noAlcohol,
    kind: HabitKind.abstain,
    unit: HabitUnit.done,
    titleDe: 'Kein Alkohol',
    titleEn: 'No alcohol',
    emoji: '🚱',
    defaultTarget: 1,
    difficulty: 4,
    blurbDe: 'Null Alkohol. Kein "nur ein Bier".',
  ),
  HabitCategory.noSugar: HabitDefinition(
    category: HabitCategory.noSugar,
    kind: HabitKind.abstain,
    unit: HabitUnit.done,
    titleDe: 'Kein Zucker',
    titleEn: 'No sugar',
    emoji: '🍬',
    defaultTarget: 1,
    difficulty: 4,
    blurbDe: 'Kein zugesetzter Zucker. Obst ist erlaubt.',
  ),
  HabitCategory.dopamineDetox: HabitDefinition(
    category: HabitCategory.dopamineDetox,
    kind: HabitKind.abstain,
    unit: HabitUnit.done,
    titleDe: 'Dopamin-Detox',
    titleEn: 'Dopamine detox',
    emoji: '🧠',
    defaultTarget: 1,
    difficulty: 5,
    blurbDe: 'Kein Endlos-Scrollen, keine Shorts, kein Binge-Watching.',
  ),
  HabitCategory.noFap: HabitDefinition(
    category: HabitCategory.noFap,
    kind: HabitKind.abstain,
    unit: HabitUnit.done,
    titleDe: 'NoFap',
    titleEn: 'NoFap',
    emoji: '🛡️',
    defaultTarget: 1,
    difficulty: 5,
    blurbDe: 'Kein Porno, kein Rückfall. Streak zählt jeden Tag.',
  ),
  HabitCategory.noNicotine: HabitDefinition(
    category: HabitCategory.noNicotine,
    kind: HabitKind.abstain,
    unit: HabitUnit.done,
    titleDe: 'Kein Nikotin',
    titleEn: 'No nicotine',
    emoji: '🚭',
    defaultTarget: 1,
    difficulty: 5,
    blurbDe: 'Keine Zigarette, kein Vape, kein Snus.',
  ),
  HabitCategory.reading: HabitDefinition(
    category: HabitCategory.reading,
    kind: HabitKind.build,
    unit: HabitUnit.pages,
    titleDe: 'Lesen',
    titleEn: 'Reading',
    emoji: '📚',
    defaultTarget: 20,
    difficulty: 3,
    blurbDe: 'Echte Seiten, echtes Buch. Feed liest sich nicht selbst.',
  ),
  HabitCategory.meditation: HabitDefinition(
    category: HabitCategory.meditation,
    kind: HabitKind.build,
    unit: HabitUnit.minutes,
    titleDe: 'Meditation',
    titleEn: 'Meditation',
    emoji: '🧘',
    defaultTarget: 10,
    difficulty: 3,
    blurbDe: 'Still sitzen, atmen, aushalten.',
  ),
  HabitCategory.sleep: HabitDefinition(
    category: HabitCategory.sleep,
    kind: HabitKind.build,
    unit: HabitUnit.minutes,
    titleDe: 'Schlaf',
    titleEn: 'Sleep',
    emoji: '😴',
    defaultTarget: 450,
    difficulty: 3,
    blurbDe: 'Mindestens 7,5 Stunden. Der Rest baut darauf auf.',
  ),
  HabitCategory.coldShower: HabitDefinition(
    category: HabitCategory.coldShower,
    kind: HabitKind.build,
    unit: HabitUnit.minutes,
    titleDe: 'Kalt duschen',
    titleEn: 'Cold shower',
    emoji: '🧊',
    defaultTarget: 2,
    difficulty: 3,
    blurbDe: 'Zwei Minuten kalt. Jeden Morgen die erste Entscheidung gewinnen.',
  ),
  HabitCategory.water: HabitDefinition(
    category: HabitCategory.water,
    kind: HabitKind.build,
    unit: HabitUnit.count,
    titleDe: 'Wasser',
    titleEn: 'Water',
    emoji: '💧',
    defaultTarget: 8,
    difficulty: 1,
    blurbDe: 'Acht Gläser. Das Billigste, was du für dich tun kannst.',
  ),
  HabitCategory.journaling: HabitDefinition(
    category: HabitCategory.journaling,
    kind: HabitKind.build,
    unit: HabitUnit.done,
    titleDe: 'Journaling',
    titleEn: 'Journaling',
    emoji: '✍️',
    defaultTarget: 1,
    difficulty: 2,
    blurbDe: 'Drei Sätze reichen. Kopf leeren, Muster sehen.',
  ),
  HabitCategory.custom: HabitDefinition(
    category: HabitCategory.custom,
    kind: HabitKind.build,
    unit: HabitUnit.done,
    titleDe: 'Eigene Gewohnheit',
    titleEn: 'Custom habit',
    emoji: '⭐',
    defaultTarget: 1,
    difficulty: 3,
    blurbDe: 'Dein Ding. Du definierst, was zählt.',
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

  String get displayTitle => title ?? definition.titleDe;

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

/// Formats a target for display, e.g. `20 Seiten`, `30 Min`, `erledigt`.
String formatHabitTarget(Habit habit) {
  final value = habit.target;
  final number = value == value.roundToDouble() || value is int
      ? value.round().toString()
      : value.toStringAsFixed(1);
  switch (habit.definition.unit) {
    case HabitUnit.done:
      return habit.kind == HabitKind.abstain ? 'clean' : 'erledigt';
    case HabitUnit.minutes:
      return '$number Min';
    case HabitUnit.count:
      return '${number}x';
    case HabitUnit.pages:
      return '$number Seiten';
    case HabitUnit.grams:
      return '$number g';
    case HabitUnit.kilocalories:
      return '$number kcal';
    case HabitUnit.steps:
      return '$number Schritte';
  }
}
