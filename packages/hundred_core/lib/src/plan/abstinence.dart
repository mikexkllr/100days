import 'package:meta/meta.dart';

import '../domain/habit.dart';

/// A day-indexed thing that happens when you stop.
///
/// These are the payoff schedule for abstinence habits: on day 3 the app can
/// tell you *why* it feels bad and that it is on time, which is the difference
/// between "this isn't working" and "this is working exactly as expected".
@immutable
class AbstinenceMilestone {
  const AbstinenceMilestone({
    required this.day,
    required this.titleDe,
    required this.bodyDe,
  });

  final int day;
  final String titleDe;
  final String bodyDe;
}

const List<AbstinenceMilestone> _alcohol = <AbstinenceMilestone>[
  AbstinenceMilestone(
    day: 1,
    titleDe: 'Tag 1 — Der Körper räumt auf',
    bodyDe: 'Blutzucker und Schlaf sind noch durcheinander. Viel trinken, '
        'früh ins Bett.',
  ),
  AbstinenceMilestone(
    day: 3,
    titleDe: 'Tag 3 — Schlaf wird tiefer',
    bodyDe: 'Der REM-Schlaf kommt zurück. Du wachst seltener nachts auf.',
  ),
  AbstinenceMilestone(
    day: 7,
    titleDe: 'Woche 1 — Klarer Kopf am Morgen',
    bodyDe: 'Kein Restalkohol mehr. Konzentration und Stimmung stabilisieren '
        'sich.',
  ),
  AbstinenceMilestone(
    day: 14,
    titleDe: 'Tag 14 — Leber erholt sich',
    bodyDe: 'Leberfett geht messbar zurück, Entzündungswerte sinken.',
  ),
  AbstinenceMilestone(
    day: 30,
    titleDe: 'Tag 30 — Haut, Schlaf, Gewicht',
    bodyDe: 'Leberwerte deutlich besser, im Schnitt ein paar Kilo weniger, '
        'Haut sichtbar ruhiger.',
  ),
  AbstinenceMilestone(
    day: 90,
    titleDe: 'Tag 90 — Neue Normalität',
    bodyDe: 'Das Verlangen ist keine tägliche Verhandlung mehr. '
        'Blutdruck und Immunsystem profitieren dauerhaft.',
  ),
];

const List<AbstinenceMilestone> _dopamine = <AbstinenceMilestone>[
  AbstinenceMilestone(
    day: 1,
    titleDe: 'Tag 1 — Der Griff zum Handy',
    bodyDe: 'Du wirst hunderte Male zum Handy greifen wollen. Das ist die '
        'Gewohnheit, nicht du.',
  ),
  AbstinenceMilestone(
    day: 3,
    titleDe: 'Tag 3 — Langeweile kommt zurück',
    bodyDe: 'Langeweile ist kein Fehler. Sie ist der Zustand, aus dem Ideen '
        'kommen.',
  ),
  AbstinenceMilestone(
    day: 7,
    titleDe: 'Woche 1 — Aufmerksamkeitsspanne wächst',
    bodyDe: 'Du hältst längere Texte und längere Gespräche aus, ohne '
        'wegzuschauen.',
  ),
  AbstinenceMilestone(
    day: 21,
    titleDe: 'Tag 21 — Der Reflex ist weg',
    bodyDe: 'Die automatische Handbewegung in der Warteschlange verschwindet.',
  ),
  AbstinenceMilestone(
    day: 60,
    titleDe: 'Tag 60 — Tiefe Arbeit',
    bodyDe: 'Zwei Stunden konzentriert an einer Sache sind wieder normal.',
  ),
];

const List<AbstinenceMilestone> _noFap = <AbstinenceMilestone>[
  AbstinenceMilestone(
    day: 3,
    titleDe: 'Tag 3 — Erste Welle',
    bodyDe: 'Unruhe und Reizbarkeit sind normal. Bewegung hilft mehr als '
        'Willenskraft.',
  ),
  AbstinenceMilestone(
    day: 7,
    titleDe: 'Woche 1 — Energie steigt',
    bodyDe: 'Mehr Antrieb, oft auch besserer Schlaf.',
  ),
  AbstinenceMilestone(
    day: 14,
    titleDe: 'Tag 14 — Flatline möglich',
    bodyDe: 'Wenn du dich flach und leer fühlst: das ist eine bekannte Phase '
        'und sie geht vorbei.',
  ),
  AbstinenceMilestone(
    day: 30,
    titleDe: 'Tag 30 — Kopf wird ruhiger',
    bodyDe: 'Weniger Zwangsgedanken, mehr Präsenz im Alltag.',
  ),
  AbstinenceMilestone(
    day: 90,
    titleDe: 'Tag 90 — Der Reboot',
    bodyDe: 'Die klassische Reboot-Marke. Ab hier ist es Lebensstil, '
        'nicht Kampf.',
  ),
];

const List<AbstinenceMilestone> _sugar = <AbstinenceMilestone>[
  AbstinenceMilestone(
    day: 2,
    titleDe: 'Tag 2 — Zuckerentzug',
    bodyDe: 'Kopfschmerzen und Heißhunger sind der Peak. Protein und Wasser.',
  ),
  AbstinenceMilestone(
    day: 5,
    titleDe: 'Tag 5 — Energie wird gleichmäßig',
    bodyDe: 'Kein Nachmittagstief mehr, weil die Blutzuckerachterbahn fehlt.',
  ),
  AbstinenceMilestone(
    day: 14,
    titleDe: 'Tag 14 — Geschmack kalibriert sich',
    bodyDe: 'Obst schmeckt plötzlich süß. Das ist der Sensor, der zurückkommt.',
  ),
  AbstinenceMilestone(
    day: 30,
    titleDe: 'Tag 30 — Weniger Wassereinlagerungen',
    bodyDe: 'Gesicht und Bauch wirken flacher, Entzündungsmarker sinken.',
  ),
];

const List<AbstinenceMilestone> _nicotine = <AbstinenceMilestone>[
  AbstinenceMilestone(
    day: 1,
    titleDe: 'Tag 1 — Kohlenmonoxid weg',
    bodyDe: 'Nach 12 Stunden ist der CO-Spiegel normal, Sauerstoff steigt.',
  ),
  AbstinenceMilestone(
    day: 3,
    titleDe: 'Tag 3 — Nikotin ist raus',
    bodyDe: 'Der körperliche Entzug hat seinen Höhepunkt. Ab hier wird es '
        'leichter.',
  ),
  AbstinenceMilestone(
    day: 14,
    titleDe: 'Tag 14 — Lunge arbeitet besser',
    bodyDe: 'Bis zu 30 % bessere Lungenfunktion, Treppen fallen leichter.',
  ),
  AbstinenceMilestone(
    day: 90,
    titleDe: 'Tag 90 — Flimmerhärchen erholt',
    bodyDe: 'Husten und Kurzatmigkeit gehen deutlich zurück.',
  ),
];

const List<AbstinenceMilestone> _generic = <AbstinenceMilestone>[
  AbstinenceMilestone(
    day: 3,
    titleDe: 'Tag 3 — Der erste echte Test',
    bodyDe: 'Der Neuheitsbonus ist weg. Jetzt entscheidet die Gewohnheit.',
  ),
  AbstinenceMilestone(
    day: 21,
    titleDe: 'Tag 21 — Automatisierung beginnt',
    bodyDe: 'Die Entscheidung kostet weniger Kraft als noch letzte Woche.',
  ),
  AbstinenceMilestone(
    day: 66,
    titleDe: 'Tag 66 — Gewohnheit',
    bodyDe: 'Im Schnitt braucht ein Verhalten 66 Tage, bis es automatisch '
        'läuft. Du bist da.',
  ),
];

List<AbstinenceMilestone> milestonesFor(HabitCategory category) {
  switch (category) {
    case HabitCategory.noAlcohol:
      return _alcohol;
    case HabitCategory.dopamineDetox:
      return _dopamine;
    case HabitCategory.noFap:
      return _noFap;
    case HabitCategory.noSugar:
      return _sugar;
    case HabitCategory.noNicotine:
      return _nicotine;
    default:
      return _generic;
  }
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
