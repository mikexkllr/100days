import 'dart:math' as math;

/// The streak, given a body.
///
/// The flame on the home screen and on the home screen widget grows with the
/// current streak and changes colour at fixed thresholds — an evolution you
/// can see coming and do not want to lose. It is a pure function of the
/// streak, so it is exactly as honest as the streak is: no stage can be
/// bought, skipped or kept after a break.
///
/// Every threshold is also a milestone day, so the two celebrations line up
/// for anyone who never broke their streak.
enum FlameStage {
  /// No streak. A glowing coal, waiting for the first day.
  ember(0),

  /// The first completed day.
  spark(1),
  flicker(3),
  flame(7),
  blaze(14),
  inferno(30),

  /// Hot enough to burn blue.
  blue(50),
  plasma(100),
  nova(200),
  sun(365);

  const FlameStage(this.minStreak);

  /// The streak at which this stage is reached.
  final int minStreak;

  /// The stage after this one, or null at the top.
  FlameStage? get next => index + 1 < FlameStage.values.length
      ? FlameStage.values[index + 1]
      : null;
}

/// The stage a streak of [streak] days has reached.
FlameStage flameStageFor(int streak) {
  var stage = FlameStage.ember;
  for (final candidate in FlameStage.values) {
    if (streak >= candidate.minStreak) stage = candidate;
  }
  return stage;
}

/// Completed days still missing until the next stage, or null at the top.
int? daysToNextStage(int streak) {
  final next = flameStageFor(streak).next;
  return next == null ? null : next.minStreak - math.max(streak, 0);
}

/// How far through its current stage a streak is, 0 to 1 — the bar under
/// the flame. 1 at the top stage.
double stageProgress(int streak) {
  final stage = flameStageFor(streak);
  final next = stage.next;
  if (next == null) return 1;
  final span = next.minStreak - stage.minStreak;
  return ((streak - stage.minStreak) / span).clamp(0.0, 1.0);
}
