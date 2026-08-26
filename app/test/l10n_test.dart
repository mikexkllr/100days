import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:hundred_core/hundred_core.dart';
import 'package:hundred_days/l10n/l10n.dart';

import 'helpers.dart';

/// Every identifier the core package can hand the UI, so a missing switch case
/// fails here rather than showing an enum name to a user.
void main() {
  late AppLocalizations en;
  late AppLocalizations de;

  setUpAll(() async {
    en = await localizationsFor(const Locale('en'));
    de = await localizationsFor(const Locale('de'));
  });

  Map<String, dynamic> readArb(String name) => jsonDecode(
        File('lib/l10n/$name').readAsStringSync(),
      ) as Map<String, dynamic>;

  group('translation files', () {
    test('both languages define exactly the same keys', () {
      final Set<String> enKeys = readArb('app_en.arb')
          .keys
          .where((String k) => !k.startsWith('@'))
          .toSet();
      final Set<String> deKeys = readArb('app_de.arb')
          .keys
          .where((String k) => !k.startsWith('@'))
          .toSet();

      expect(
        enKeys.difference(deKeys),
        isEmpty,
        reason: 'missing German translations',
      );
      expect(
        deKeys.difference(enKeys),
        isEmpty,
        reason: 'German keys with no English original',
      );
    });

    test('no value is left empty', () {
      for (final String name in <String>['app_en.arb', 'app_de.arb']) {
        readArb(name).forEach((String key, dynamic value) {
          if (key.startsWith('@')) return;
          expect(
            (value as String).trim(),
            isNotEmpty,
            reason: '$name: $key is empty',
          );
        });
      }
    });

    test('placeholders match between the two languages', () {
      // A bare {name} or an ICU {name, plural, …}. Anything else in braces is
      // a plural branch body such as `=1{Respect, 1 day!}`.
      final RegExp braces = RegExp(
        r'\{([a-zA-Z][a-zA-Z0-9]*)\s*,\s*(?:plural|select|gender)\b'
        r'|\{([a-zA-Z][a-zA-Z0-9]*)\}',
      );
      final Map<String, dynamic> enArb = readArb('app_en.arb');
      final Map<String, dynamic> deArb = readArb('app_de.arb');

      for (final MapEntry<String, dynamic> entry in enArb.entries) {
        if (entry.key.startsWith('@')) continue;
        final Set<String> a = braces
            .allMatches(entry.value as String)
            .map((RegExpMatch m) => m.group(1) ?? m.group(2)!)
            .toSet();
        final Set<String> b = braces
            .allMatches(deArb[entry.key] as String)
            .map((RegExpMatch m) => m.group(1) ?? m.group(2)!)
            .toSet();
        expect(b, equals(a), reason: 'placeholder mismatch in ${entry.key}');
      }
    });
  });

  group('every core identifier has wording', () {
    void bothLanguages(String what, String Function(AppLocalizations) get) {
      for (final AppLocalizations l10n in <AppLocalizations>[en, de]) {
        expect(get(l10n).trim(), isNotEmpty, reason: '$what has no wording');
      }
    }

    test('habits', () {
      for (final HabitCategory category in HabitCategory.values) {
        bothLanguages('${category.name} title', (AppLocalizations l) =>
            l.habitTitle(category));
        bothLanguages('${category.name} blurb', (AppLocalizations l) =>
            l.habitBlurb(category));
      }
    });

    test('goals', () {
      for (final GoalArchetype archetype in GoalArchetype.values) {
        bothLanguages('${archetype.name} title', (AppLocalizations l) =>
            l.goalTitle(archetype));
        bothLanguages('${archetype.name} pitch', (AppLocalizations l) =>
            l.goalPitch(archetype));
        expect(en.goalExamples(archetype), isNotEmpty);
        expect(de.goalExamples(archetype), isNotEmpty);
      }
    });

    test('every exercise in the library is named', () {
      for (final Exercise exercise in kExerciseLibrary) {
        bothLanguages(exercise.id, (AppLocalizations l) =>
            l.exerciseName(exercise.id));
        // The name must be a real translation, not the id falling through.
        expect(en.exerciseName(exercise.id), isNot(exercise.id));
        expect(de.exerciseName(exercise.id), isNot(exercise.id));
        if (exercise.hasCue) {
          expect(en.exerciseCue(exercise.id), isNotNull);
          expect(de.exerciseCue(exercise.id), isNotNull);
        }
      }
    });

    test('muscles, workouts and splits', () {
      for (final MuscleGroup group in MuscleGroup.values) {
        bothLanguages(group.name, (AppLocalizations l) => l.muscleName(group));
      }
      for (final WorkoutKind kind in WorkoutKind.values) {
        bothLanguages(kind.name, (AppLocalizations l) => l.workoutName(kind));
        bothLanguages('${kind.name} focus', (AppLocalizations l) =>
            l.workoutFocus(kind));
      }
      for (final SplitKind split in SplitKind.values) {
        bothLanguages(split.name, (AppLocalizations l) => l.splitName(split));
      }
      for (int days = 2; days <= 6; days++) {
        bothLanguages('$days-day preview', (AppLocalizations l) =>
            l.splitPreview(days));
      }
    });

    test('meals', () {
      for (final MealSlotKind kind in MealSlotKind.values) {
        bothLanguages(kind.name, (AppLocalizations l) => l.mealName(kind));
        expect(en.mealIdeas(kind), isNotEmpty);
        expect(de.mealIdeas(kind), hasLength(en.mealIdeas(kind).length));
      }
    });

    test('every abstinence milestone on every track', () {
      for (final HabitCategory category in HabitCategory.values) {
        for (final AbstinenceMilestone m in milestonesFor(category)) {
          bothLanguages('${m.id} title', (AppLocalizations l) =>
              l.milestoneTitle(m));
          bothLanguages('${m.id} body', (AppLocalizations l) =>
              l.milestoneBody(m));
        }
      }
    });

    test('tiers, leagues and options', () {
      for (int cycle = 0; cycle < 10; cycle++) {
        bothLanguages('tier $cycle', (AppLocalizations l) =>
            l.tierName(tierForCycle(cycle)));
      }
      for (final League league in League.values) {
        bothLanguages(league.name, (AppLocalizations l) =>
            l.leagueName(league));
      }
      for (final TrainingExperience e in TrainingExperience.values) {
        bothLanguages(e.name, (AppLocalizations l) => l.experienceTitle(e));
        bothLanguages('${e.name} body', (AppLocalizations l) =>
            l.experienceBody(e));
      }
      for (final EquipmentAccess a in EquipmentAccess.values) {
        bothLanguages(a.name, (AppLocalizations l) => l.equipmentTitle(a));
        bothLanguages('${a.name} body', (AppLocalizations l) =>
            l.equipmentBody(a));
      }
      for (final ActivityLevel level in ActivityLevel.values) {
        bothLanguages(level.name, (AppLocalizations l) =>
            l.activityLevelTitle(level));
      }
    });

    test('every habit unit formats a target', () {
      for (final HabitCategory category in HabitCategory.values) {
        final Habit habit = Habit.fromCategory(category);
        bothLanguages('${category.name} target', (AppLocalizations l) =>
            l.formatTarget(habit));
      }
    });

    test('coach templates, calls to action and hints', () {
      for (final CoachTemplate template in CoachTemplate.values) {
        final CoachDirective directive = CoachDirective(
          tone: CoachTone.steady,
          template: template,
          cta: CoachCta.checkInNow,
          dayNumber: 41,
          totalDays: 100,
          streak: 12,
          completionPercent: 88,
          milestoneDay: 50,
          daysToMilestone: 9,
          hoursLeft: 2,
          statement: 'Ein Ziel',
          habitCategory: HabitCategory.noSugar,
          recoveryHint: RecoveryHint.sugarBreakfast,
          freeformHeadline: 'Head',
          freeformBody: 'Body',
          peers: const <PeerMention>[
            PeerMention(
              did: 'did:key:zA',
              displayName: 'Marcel',
              avatarEmoji: '🦍',
              streak: 30,
            ),
          ],
        );
        bothLanguages('${template.name} headline', (AppLocalizations l) =>
            l.coachHeadline(directive));
        bothLanguages('${template.name} body', (AppLocalizations l) =>
            l.coachBody(directive));
      }
      for (final CoachCta cta in CoachCta.values) {
        bothLanguages(cta.name, (AppLocalizations l) => l.ctaLabel(cta));
      }
      for (final RecoveryHint hint in RecoveryHint.values) {
        bothLanguages(hint.name, (AppLocalizations l) =>
            l.recoveryHintText(hint));
      }
    });

    test('nudges and plan advice', () {
      for (final NudgeTemplate template in NudgeTemplate.values) {
        final NudgeSuggestion nudge = NudgeSuggestion(
          targetDid: 'did:key:zA',
          template: template,
          reason: NudgeReason.nothingToday,
          dayNumber: 12,
          peerStreak: 5,
          text: 'Generated',
        );
        bothLanguages(template.name, (AppLocalizations l) =>
            l.nudgeText(nudge));
      }
      for (final NudgeReason reason in NudgeReason.values) {
        bothLanguages(reason.name, (AppLocalizations l) =>
            l.nudgeReasonText(reason));
      }
      for (final PlanAdviceKind kind in PlanAdviceKind.values) {
        final PlanAdvice advice = PlanAdvice(
          kind: kind,
          habitCategory: HabitCategory.noAlcohol,
          completionPercent: 42,
          daysToMilestone: 6,
          milestone: 'alcohol_14',
          streak: 25,
          text: 'Generated',
        );
        bothLanguages(kind.name, (AppLocalizations l) => l.adviceText(advice));
      }
    });

    test('peer activity and nutrition rationale', () {
      for (final PeerActivityKind kind in PeerActivityKind.values) {
        bothLanguages(kind.name, (AppLocalizations l) =>
            l.peerActivityLabel(PeerActivity(
              kind: kind,
              category: HabitCategory.gym,
            )));
      }
      for (final GoalArchetype archetype in GoalArchetype.values) {
        final NutritionPlan plan = buildNutritionPlan(Goal(
          archetype: archetype,
          statement: 'x',
          body: const BodyProfile(
            sex: BiologicalSex.male,
            ageYears: 30,
            heightCm: 180,
            weightKg: 80,
            activityLevel: ActivityLevel.moderate,
          ),
        ));
        bothLanguages('${archetype.name} rationale', (AppLocalizations l) =>
            l.nutritionRationale(plan));
      }
    });
  });

  group('the two languages actually differ', () {
    test('a sample of user-facing strings is translated, not copied', () {
      expect(en.habitNoSugar, isNot(de.habitNoSugar));
      expect(en.obGoalTitle, isNot(de.obGoalTitle));
      expect(en.exerciseBackSquat, isNot(de.exerciseBackSquat));
      expect(en.coachSteadyRunning, isNot(de.coachSteadyRunning));
      expect(en.milestoneAlcohol7Body, isNot(de.milestoneAlcohol7Body));
    });

    test('plurals inflect in both languages', () {
      expect(en.coachHeadStreak(1), contains('1 day streak'));
      expect(en.coachHeadStreak(9), contains('9 days streak'));
      expect(de.coachHeadStreak(1), contains('1 Tag Streak'));
      expect(de.coachHeadStreak(9), contains('9 Tage Streak'));
    });

    test('the model prompt is written in the reading language', () {
      expect(en.promptPersonaCalm, isNot(de.promptPersonaCalm));
      expect(en.promptBriefing('a', 'b', 1, 2, 'c', 3, 4, 'd', '5', 'e', 'f'),
          contains('TITLE:'));
      expect(de.promptBriefing('a', 'b', 1, 2, 'c', 3, 4, 'd', '5', 'e', 'f'),
          contains('TITEL:'));
    });
  });
}
