import 'package:hundred_core/hundred_core.dart';

import '../ui/mascot/mascot_mood.dart';
import 'generated/app_localizations.dart';

/// Funki's words, the flame's stages and what a completed day earned.
///
/// Every line is its own key rather than an index into a list, so a
/// translation can never quietly pull the wrong one — the same rule the coach
/// follows.
extension MascotL10n on AppLocalizations {
  String stageName(FlameStage stage) => switch (stage) {
        FlameStage.ember => stageEmber,
        FlameStage.spark => stageSpark,
        FlameStage.flicker => stageFlicker,
        FlameStage.flame => stageFlame,
        FlameStage.blaze => stageBlaze,
        FlameStage.inferno => stageInferno,
        FlameStage.blue => stageBlue,
        FlameStage.plasma => stagePlasma,
        FlameStage.nova => stageNova,
        FlameStage.galaxy => stageGalaxy,
      };

  /// Everything Funki may say in [mood]. Placeholders are filled from the
  /// actual day, so a line never claims a number that is not true — and a
  /// line about the hours left only appears when [hoursLeft] is known and at
  /// least one (pass 0 where the line would outlive the number, like on the
  /// home screen widget).
  List<String> mascotLines(
    MascotMood mood, {
    required int day,
    required int streak,
    required int hoursLeft,
  }) =>
      switch (mood) {
        MascotMood.hungry => <String>[
            mascotHungry1,
            mascotHungry2,
            mascotHungry3,
            mascotHungry4,
            mascotHungry5,
            mascotHungry6(day),
          ],
        MascotMood.worried => <String>[
            if (hoursLeft >= 1) mascotWorried1(hoursLeft),
            mascotWorried2(streak),
            mascotWorried3,
            mascotWorried4,
            mascotWorried5,
          ],
        MascotMood.happy => <String>[
            mascotHappy1,
            mascotHappy2,
            mascotHappy3,
            mascotHappy4(streak),
            mascotHappy5,
            mascotHappy6,
          ],
        MascotMood.sleepy => <String>[
            mascotSleepy1,
            mascotSleepy2,
            mascotSleepy3,
          ],
        MascotMood.hopeful => <String>[
            mascotHopeful1,
            mascotHopeful2,
            mascotHopeful3,
            mascotHopeful4,
          ],
        MascotMood.sad => <String>[mascotSad1, mascotSad2, mascotSad3],
        MascotMood.hyped => <String>[
            mascotHyped1,
            mascotHyped2,
            mascotHyped3,
            mascotHyped4,
          ],
      };

  /// The line for a day: stable for the whole day, different tomorrow.
  String mascotLineFor(
    MascotMood mood, {
    required int day,
    required int streak,
    required int hoursLeft,
  }) {
    final List<String> lines =
        mascotLines(mood, day: day, streak: streak, hoursLeft: hoursLeft);
    return lines[(day * 7 + mood.index).abs() % lines.length];
  }

  List<String> get mascotPokes => <String>[
        mascotPoke1,
        mascotPoke2,
        mascotPoke3,
        mascotPoke4,
        mascotPoke5,
        mascotPoke6,
      ];

  /// The short word on the bonus reel.
  String rewardBonusLabel(RewardHighlight highlight) => switch (highlight) {
        RewardHighlight.cycleComplete => celebrateBonusCycle,
        RewardHighlight.milestone => celebrateBonusMilestone,
        RewardHighlight.evolution => celebrateBonusEvolution,
        RewardHighlight.record => celebrateBonusRecord,
        RewardHighlight.levelUp => celebrateBonusLevel,
        RewardHighlight.perfectDay => celebrateBonusPerfect,
      };

  /// The full sentence for one highlight of [reward].
  String rewardHighlightText(
    RewardHighlight highlight,
    DayReward reward, {
    required int cycleLength,
  }) =>
      switch (highlight) {
        RewardHighlight.cycleComplete => celebrateHighlightCycle(cycleLength),
        RewardHighlight.milestone =>
          celebrateHighlightMilestone(reward.dayNumber),
        RewardHighlight.evolution =>
          celebrateHighlightEvolution(stageName(reward.stage)),
        RewardHighlight.record => celebrateHighlightRecord(reward.streak),
        RewardHighlight.levelUp => celebrateHighlightLevel(reward.level),
        RewardHighlight.perfectDay =>
          celebrateHighlightPerfect(kPerfectDayBonus),
      };

  /// Two letters for a weekday, Monday = 1.
  String weekdayLetters(int weekday) => switch (weekday) {
        DateTime.monday => weekdayShortMon,
        DateTime.tuesday => weekdayShortTue,
        DateTime.wednesday => weekdayShortWed,
        DateTime.thursday => weekdayShortThu,
        DateTime.friday => weekdayShortFri,
        DateTime.saturday => weekdayShortSat,
        _ => weekdayShortSun,
      };
}
