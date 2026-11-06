/// How the flame feels about your day.
enum MascotMood {
  /// No streak yet — small, glowing, waiting for the first day.
  hopeful,

  /// Today is open. Big eyes, looking at you.
  hungry,

  /// Today is open and the evening is running out.
  worried,

  /// Fed. Grinning.
  happy,

  /// A celebration. Bouncing.
  hyped,

  /// Rest day: nothing to do but glow.
  sleepy,

  /// A relapse today. Small and honest about it.
  sad,
}

/// The mood for today, from the facts on the home screen. The order is the
/// order of importance: an honest relapse first, a fed flame second.
MascotMood moodForToday({
  required bool doneToday,
  required bool restDay,
  required bool frozenToday,
  required bool relapseToday,
  required int streak,
  required DateTime now,
}) {
  if (relapseToday) return MascotMood.sad;
  if (doneToday) return MascotMood.happy;
  if (restDay || frozenToday) return MascotMood.sleepy;
  if (streak == 0) return MascotMood.hopeful;
  // From eight in the evening the day is visibly running out.
  if (now.hour >= 20) return MascotMood.worried;
  return MascotMood.hungry;
}
