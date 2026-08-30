// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionConnect => 'Connect';

  @override
  String get actionCopy => 'Copy';

  @override
  String get actionCopyLink => 'Copy link';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionNext => 'Continue';

  @override
  String get actionRemove => 'Remove';

  @override
  String get actionRetry => 'Try again';

  @override
  String get actionSave => 'Save';

  @override
  String get actionSend => 'Send';

  @override
  String get actionSent => 'Sent';

  @override
  String get actionShare => 'Share link';

  @override
  String adviceCutScope(int percent) {
    return 'You only hit $percent% of your days. Take a habit out instead of carrying on failing — three certain days beat five planned ones.';
  }

  @override
  String adviceHalveTarget(String emoji, String habit) {
    return '$emoji $habit is not happening. Halve the target until it sticks again.';
  }

  @override
  String get adviceInviteSomeone =>
      'You have not connected anyone yet. Going it alone is measurably harder — invite someone.';

  @override
  String adviceMilestoneAhead(
      String emoji, String habit, int days, String milestone) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return '$emoji $habit: $_temp0 until \"$milestone\".';
  }

  @override
  String adviceRaiseTarget(String emoji, String habit, int days) {
    return '$emoji $habit has been running for $days days. Raise the daily target by 20%.';
  }

  @override
  String get aiBackendMissing =>
      'The rule-based coach is running. It needs no model, works offline and answers instantly — the language is just less varied.';

  @override
  String get aiBackendPresent =>
      'An inference engine is wired in. With a model installed it writes your daily line.';

  @override
  String aiGigabytes(String size) {
    return '$size GB';
  }

  @override
  String get aiInstallBody =>
      'Download the GGUF file on a computer and put it in this folder:';

  @override
  String get aiInstallTitle => 'Installing a model';

  @override
  String get aiInstalled => 'installed';

  @override
  String get aiLoading => 'Loading …';

  @override
  String get aiModelGemmaDesc => 'A little stronger in German, needs more RAM.';

  @override
  String get aiModelQwenDesc =>
      'A good balance of quality and size. Runs on mid-range devices.';

  @override
  String get aiModelSmolDesc => 'Tiny and fast, for older devices.';

  @override
  String get aiNoAutoDownload =>
      'The app never downloads anything by itself — a gigabyte over mobile data is not something that should happen unasked.';

  @override
  String get aiNoNetworkBadge => 'no network access';

  @override
  String get aiSource => 'Source';

  @override
  String get aiSupportedModels => 'Supported models';

  @override
  String get aiTitle => 'On-device AI';

  @override
  String get aiWhatItSeesBody =>
      'Streak, day number, your habits and whether your friends were active today — as text, straight to the model on this device. No network call, no telemetry, no copy in anyone’s cloud.';

  @override
  String get aiWhatItSeesTitle => 'What the model sees';

  @override
  String get appTitle => '100 Days';

  @override
  String cheerRespectStreak(int streak) {
    String _temp0 = intl.Intl.pluralLogic(
      streak,
      locale: localeName,
      other: 'Respect, $streak days!',
      one: 'Respect, 1 day!',
    );
    return '$_temp0';
  }

  @override
  String get coachBadgeLlm => 'on-device AI';

  @override
  String get coachBadgeRule => 'Coach';

  @override
  String coachCelebrateGeneric(int day) {
    return '$day days in a row. That is the evidence, not the feeling.';
  }

  @override
  String get coachCelebrateHabitFormed =>
      '66 days — the average it takes for a behaviour to run automatically. You are through.';

  @override
  String coachCelebrateHundred(String tier) {
    return 'A hundred days. And now comes the part this app was built for: it does not stop here. Welcome to \"$tier\".';
  }

  @override
  String get coachCelebrateMonth =>
      '30 days. From now on you have to talk yourself into it less.';

  @override
  String get coachCelebrateWeek => 'One week. Most people stop exactly here.';

  @override
  String get coachCelebrateYear =>
      'A year. This is not a challenge any more, this is you.';

  @override
  String coachEngineModel(String model) {
    return '$model (on-device)';
  }

  @override
  String get coachEngineRuleBased => 'Rule-based (on-device)';

  @override
  String coachHeadAtStake(int streak) {
    String _temp0 = intl.Intl.pluralLogic(
      streak,
      locale: localeName,
      other: '$streak days are at stake',
      one: '1 day is at stake',
    );
    return '$_temp0';
  }

  @override
  String coachHeadCelebrate(int day) {
    return 'Day $day 🎉';
  }

  @override
  String coachHeadDayOf(int day, int total) {
    return 'Day $day of $total';
  }

  @override
  String get coachHeadDayStillOpen => 'Today is still open';

  @override
  String coachHeadFriendActive(String name) {
    return '$name was already out today';
  }

  @override
  String coachHeadFriendsActive(int count) {
    return '$count of your people were already out today';
  }

  @override
  String get coachHeadLastChance => 'Last chance';

  @override
  String coachHeadLeaderAhead(String name) {
    return '$name is ahead of you';
  }

  @override
  String get coachHeadNewDayOne => 'A new day 1';

  @override
  String coachHeadStreak(int streak) {
    String _temp0 = intl.Intl.pluralLogic(
      streak,
      locale: localeName,
      other: '$streak days streak',
      one: '1 day streak',
    );
    return '$_temp0';
  }

  @override
  String coachHeadTooSmooth(int streak) {
    String _temp0 = intl.Intl.pluralLogic(
      streak,
      locale: localeName,
      other: '$streak days — this is going too smoothly',
      one: '1 day — too smooth',
    );
    return '$_temp0';
  }

  @override
  String get coachHintAlcoholPattern =>
      'Write down where you were and who with. The pattern matters more than the one evening.';

  @override
  String get coachHintDigitalTrigger =>
      'Phone out of the bedroom tonight. That is the trigger, not your willpower.';

  @override
  String get coachHintSmallestVersion =>
      'Tomorrow, the smallest possible version. Just not zero.';

  @override
  String get coachHintSugarBreakfast =>
      'More protein at breakfast. Cravings are usually a breakfast problem.';

  @override
  String coachNamesMore(String names, int count) {
    return '$names and $count others';
  }

  @override
  String coachNamesTwo(String first, String second) {
    return '$first and $second';
  }

  @override
  String coachPressureHoursLeft(String names) {
    return '$names were already out today. You are still on zero. In two hours the day is over.';
  }

  @override
  String coachPressureLeaderBody(
      String emoji, String name, int peerStreak, int streak) {
    return '$emoji $name: $peerStreak days. You: $streak. Still catchable — today.';
  }

  @override
  String coachPressureLeaveIt(String names) {
    return '$names were already out today. You are still on zero. Going to leave it like that?';
  }

  @override
  String coachPressureTheySee(String names) {
    return '$names were already out today. You are still on zero. They can see your feed too.';
  }

  @override
  String get coachPressureYouLead =>
      'You are in front right now. Leading means not being the first to quit.';

  @override
  String coachRaiseBarHarder(int percent) {
    return 'You hit $percent% of your days. Time to make the goal harder: one more day a week, or a higher daily target.';
  }

  @override
  String coachRaiseBarNoEffort(int percent) {
    return 'You hit $percent% of your days. Habits that cost no effort stop producing any. Raise a number.';
  }

  @override
  String coachRaiseBarSecondFront(int percent) {
    return 'You hit $percent% of your days. Take on a second front. You have the capacity.';
  }

  @override
  String coachRecoverRelapse(String habit, String hint) {
    return 'Relapse on $habit. That is part of the curve, not the end of it. $hint';
  }

  @override
  String get coachRecoverStreakLost =>
      'The streak is gone, the 100 days are not. The difference between a relapse and quitting is exactly what you do in the next 24 hours.';

  @override
  String coachSteadyMilestoneConsistency(int days, int milestone) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days more days until day $milestone.',
      one: 'One more day until day $milestone.',
    );
    return '$_temp0 Consistency beats intensity. Always.';
  }

  @override
  String coachSteadyMilestoneNothingSpectacular(int days, int milestone) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days more days until day $milestone.',
      one: 'One more day until day $milestone.',
    );
    return '$_temp0 Nothing spectacular required — just do not stop.';
  }

  @override
  String coachSteadyMilestonePlanWorks(int days, int milestone) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days more days until day $milestone.',
      one: 'One more day until day $milestone.',
    );
    return '$_temp0 The plan works as long as you do it.';
  }

  @override
  String get coachSteadyRunning => 'Running. Same as yesterday.';

  @override
  String coachUrgentLastChance(int hours, int streak) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours hours left.',
      one: 'One hour left.',
    );
    return '$_temp0 $streak days of work against a few minutes. Do the maths.';
  }

  @override
  String get coachUrgentSmallestVersion =>
      'The day is nearly over and nothing is logged. Do the smallest version of it — it counts the same.';

  @override
  String get coachWelcomeCheckOff =>
      'The beginning is the easiest part and the most important one. One thing today: tick it off.';

  @override
  String coachWelcomeNobodySees(int day) {
    return 'Nobody sees day $day. Everyone sees day 100. One does not happen without the other.';
  }

  @override
  String coachWelcomeYourWords(String statement) {
    return 'You told yourself: \"$statement\". Today you turn that into the first piece of evidence.';
  }

  @override
  String get ctaAdjustGoal => 'Adjust the goal';

  @override
  String get ctaCheckInNow => 'Check in now';

  @override
  String get ctaKeepGoing => 'Keep going';

  @override
  String get ctaRescue => 'Rescue it';

  @override
  String get ctaRestart => 'Start over';

  @override
  String get ctaShare => 'Share';

  @override
  String errorGeneric(String message) {
    return 'Error: $message';
  }

  @override
  String get exerciseAbWheel => 'Ab wheel';

  @override
  String get exerciseBackSquat => 'Back squat (barbell)';

  @override
  String get exerciseBandPulldown => 'Band pulldown';

  @override
  String get exerciseBarbellRow => 'Barbell row';

  @override
  String get exerciseBenchPress => 'Bench press';

  @override
  String get exerciseBicepsCurl => 'Biceps curls';

  @override
  String get exerciseBulgarianSplitSquat => 'Bulgarian split squat';

  @override
  String get exerciseBurpee => 'Burpees';

  @override
  String get exerciseBwSquat => 'Bodyweight squat';

  @override
  String get exerciseCableRow => 'Cable row';

  @override
  String get exerciseCalfRaise => 'Calf raise';

  @override
  String get exerciseCueBackSquat =>
      'Chest up, knees over toes, controlled on the way down.';

  @override
  String get exerciseCueBenchPress =>
      'Shoulder blades together, bar to the lower chest.';

  @override
  String get exerciseCueBwSquat =>
      'Slow on the way down, brief pause at the bottom.';

  @override
  String get exerciseCueDeadlift => 'Flat back, bar travels along the shin.';

  @override
  String get exerciseCueGobletSquat =>
      'Dumbbell at the chest, deep and upright.';

  @override
  String get exerciseCuePullup => 'Shoulders down, chest to the bar.';

  @override
  String get exerciseCuePushup => 'Body stays a plank, elbows at 45 degrees.';

  @override
  String get exerciseCueRdl => 'Hips back, feel the stretch in the hamstrings.';

  @override
  String get exerciseDbBench => 'Dumbbell bench press';

  @override
  String get exerciseDbOhp => 'Overhead press (dumbbell)';

  @override
  String get exerciseDbRow => 'Dumbbell row';

  @override
  String get exerciseDeadBug => 'Dead bug';

  @override
  String get exerciseDeadlift => 'Deadlift';

  @override
  String get exerciseDiamondPushup => 'Diamond push-up';

  @override
  String get exerciseDip => 'Dips';

  @override
  String get exerciseFacePull => 'Face pull';

  @override
  String get exerciseFarmersWalk => 'Farmer\'s walk';

  @override
  String get exerciseGluteBridge => 'Glute bridge';

  @override
  String get exerciseGobletSquat => 'Goblet squat';

  @override
  String get exerciseHammerCurl => 'Hammer curls';

  @override
  String get exerciseHangingLegRaise => 'Hanging leg raise';

  @override
  String get exerciseHipThrust => 'Hip thrust';

  @override
  String get exerciseInvertedRow => 'Inverted row';

  @override
  String get exerciseJumpRope => 'Jump rope';

  @override
  String get exerciseKbSwing => 'Kettlebell swing';

  @override
  String get exerciseLatPulldown => 'Lat pulldown';

  @override
  String get exerciseLateralRaise => 'Lateral raise';

  @override
  String get exerciseLegCurl => 'Leg curl';

  @override
  String get exerciseLegPress => 'Leg press';

  @override
  String get exerciseNordicCurl => 'Nordic curl (assisted)';

  @override
  String get exerciseOhp => 'Overhead press (barbell)';

  @override
  String get exercisePikePushup => 'Pike push-up';

  @override
  String get exercisePlank => 'Plank';

  @override
  String get exercisePullup => 'Pull-up';

  @override
  String get exercisePushup => 'Push-up';

  @override
  String get exerciseRdl => 'Romanian deadlift';

  @override
  String get exerciseRowingErg => 'Rowing machine';

  @override
  String get exerciseStepUp => 'Step-up';

  @override
  String get exerciseTricepsPushdown => 'Triceps pushdown';

  @override
  String get exerciseWalkingLunge => 'Walking lunges';

  @override
  String feedAscended(String name) {
    return '$name moved up a tier';
  }

  @override
  String feedAscendedDetail(String tier) {
    return 'New tier: $tier';
  }

  @override
  String feedBackfilled(String date) {
    return 'backfilled for $date';
  }

  @override
  String get feedBackfilledBadge => 'backfilled';

  @override
  String feedCheckIn(String name, String habit) {
    return '$name: $habit done';
  }

  @override
  String get feedCheer => 'Cheer';

  @override
  String feedCheerReceived(String name) {
    return '$name is cheering you on';
  }

  @override
  String feedCheerSent(String name) {
    return 'You cheered $name';
  }

  @override
  String get feedCheered => 'Cheered';

  @override
  String get feedEmptyBody =>
      'As soon as you or your friends tick something off it shows up here — signed and checkable.';

  @override
  String get feedEmptyTitle => 'Nothing in the feed yet';

  @override
  String feedNudgeReceived(String name) {
    return '$name is nudging you';
  }

  @override
  String feedNudgeSent(String name) {
    return 'You nudged $name';
  }

  @override
  String feedRelapse(String name, String habit) {
    return '$name had a relapse on $habit';
  }

  @override
  String get feedSomeone => 'someone';

  @override
  String feedStarted(String name) {
    return '$name started the challenge';
  }

  @override
  String feedStreakDetail(int streak) {
    String _temp0 = intl.Intl.pluralLogic(
      streak,
      locale: localeName,
      other: '$streak days streak',
      one: '1 day streak',
    );
    return '$_temp0';
  }

  @override
  String get feedVerified => 'verified';

  @override
  String friendsConnected(String name) {
    return '$name connected.';
  }

  @override
  String friendsDayNumber(int day) {
    return 'Day $day';
  }

  @override
  String get friendsEmptyBody =>
      'The app works alone — but it only bites once someone is watching. Show a friend your QR code.';

  @override
  String get friendsEmptyTitle => 'Nobody connected yet';

  @override
  String get friendsFallbackName => 'Friend';

  @override
  String get friendsInvite => 'Invite';

  @override
  String friendsInviteInvalid(String message) {
    return 'Invalid invite: $message';
  }

  @override
  String get friendsNetworkNote =>
      'Connections run directly between your devices — instantly on the same Wi-Fi, otherwise the next time you meet. No server in between that knows your streaks.';

  @override
  String get friendsNoActivity => 'No activity yet';

  @override
  String get friendsNudgeSection => 'Nudge';

  @override
  String get friendsNudgeSubtitle => 'These people have not been out today.';

  @override
  String get friendsScan => 'Scan';

  @override
  String get friendsYourPeople => 'Your people';

  @override
  String get goalBuildMuscle => 'Build muscle';

  @override
  String get goalBuildMusclePitch =>
      'Get heavier, get stronger. Plan, protein, progression.';

  @override
  String get goalClarity => 'Clear your head';

  @override
  String get goalClarityPitch =>
      'Dopamine down, focus up. Less stimulus, more substance.';

  @override
  String get goalCustom => 'Your own goal';

  @override
  String get goalCustomPitch =>
      'You know what is due. Build yourself the plan.';

  @override
  String get goalDiscipline => 'Build discipline';

  @override
  String get goalDisciplinePitch =>
      '100 days, not up for negotiation. The streak is the goal.';

  @override
  String get goalGetFit => 'Get fit';

  @override
  String get goalGetFitPitch =>
      'Conditioning, strength, mobility. Back in shape.';

  @override
  String get goalLoseFat => 'Lose fat';

  @override
  String get goalLoseFatPitch =>
      'Hold the deficit, keep the muscle, week after week.';

  @override
  String get goalSober => 'Stay clean';

  @override
  String get goalSoberPitch =>
      'Alcohol, nicotine, sugar — every day counts on its own.';

  @override
  String get habitCardio => 'Cardio';

  @override
  String get habitCardioBlurb =>
      'Easy aerobic work. Zone 2 — do not wreck yourself.';

  @override
  String get habitColdShower => 'Cold shower';

  @override
  String get habitColdShowerBlurb =>
      'Two minutes cold. Win the first decision of the day.';

  @override
  String get habitCustom => 'Custom habit';

  @override
  String get habitCustomBlurb => 'Your thing. You define what counts.';

  @override
  String get habitDopamineDetox => 'Dopamine detox';

  @override
  String get habitDopamineDetoxBlurb =>
      'No endless scrolling, no shorts, no binge-watching.';

  @override
  String get habitGym => 'Training';

  @override
  String get habitGymBlurb =>
      'Strength training to a plan. Progressive overload, not guesswork.';

  @override
  String get habitJournaling => 'Journaling';

  @override
  String get habitJournalingBlurb =>
      'Three sentences will do. Clear your head, see the pattern.';

  @override
  String get habitMeditation => 'Meditation';

  @override
  String get habitMeditationBlurb => 'Sit still, breathe, endure it.';

  @override
  String get habitNoAlcohol => 'No alcohol';

  @override
  String get habitNoAlcoholBlurb => 'Zero alcohol. No \"just one beer\".';

  @override
  String get habitNoFap => 'NoFap';

  @override
  String get habitNoFapBlurb =>
      'No porn, no relapse. The streak counts every day.';

  @override
  String get habitNoNicotine => 'No nicotine';

  @override
  String get habitNoNicotineBlurb => 'No cigarette, no vape, no snus.';

  @override
  String get habitNoSugar => 'No sugar';

  @override
  String get habitNoSugarBlurb => 'No added sugar. Fruit is fine.';

  @override
  String get habitNutrition => 'Nutrition';

  @override
  String get habitNutritionBlurb => 'Calorie and protein target hit.';

  @override
  String get habitReading => 'Reading';

  @override
  String get habitReadingBlurb =>
      'Real pages, real book. The feed does not read itself.';

  @override
  String get habitSleep => 'Sleep';

  @override
  String get habitSleepBlurb =>
      'At least seven and a half hours. Everything else builds on it.';

  @override
  String get habitSteps => 'Steps';

  @override
  String get habitStepsBlurb =>
      'Ten thousand a day. Your watch counts them — you only have to move.';

  @override
  String get habitWater => 'Water';

  @override
  String get habitWaterBlurb =>
      'Eight glasses. The cheapest thing you can do for yourself.';

  @override
  String get healthAccessSection => 'Access';

  @override
  String get healthAutoImport => 'Import automatically';

  @override
  String get healthAutoImportBody =>
      'Runs when you open the app. Switched off, only the button below does anything.';

  @override
  String get healthBadge => 'Health';

  @override
  String get healthBadgeApple => 'Apple Health';

  @override
  String get healthBadgeConnect => 'Health Connect';

  @override
  String get healthDenied => 'Access refused';

  @override
  String get healthDeniedBody =>
      'Nothing can be read until you release the values in the system settings.';

  @override
  String healthFromDevice(String device) {
    return 'from $device';
  }

  @override
  String get healthGetHealthConnect => 'Get Health Connect';

  @override
  String get healthGrant => 'Allow access';

  @override
  String get healthGranted => 'Access granted';

  @override
  String get healthHabitsEmpty =>
      'None of the habits you picked can be read from a sensor. Training, cardio, steps, sleep, water and meditation can.';

  @override
  String get healthHabitsSection => 'Which habits get filled in';

  @override
  String get healthHonestyBody =>
      'Less than it looks like. The feed proves that an entry is yours, when it was written and that nobody altered it afterwards — it cannot prove a watch was involved, because nothing Apple or Google hands an app is signed in a way your friends\' phones could check. An imported entry is therefore labelled \"from Health\", never \"verified\".';

  @override
  String get healthHonestySection => 'What this proves';

  @override
  String get healthImportNow => 'Import now';

  @override
  String get healthImportSection => 'Import';

  @override
  String healthImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count check-ins written',
      one: '1 check-in written',
    );
    return '$_temp0';
  }

  @override
  String get healthImportedNothing =>
      'Nothing new — everything is already logged.';

  @override
  String get healthImporting => 'Reading…';

  @override
  String get healthIntroApple =>
      'Your iPhone and your Apple Watch write into Apple Health. The app reads from there — on the device, and only the values you release below.';

  @override
  String get healthIntroConnect =>
      'Fitbit, Pixel Watch, Samsung Health, Garmin and Strava all write into Health Connect. The app reads from there — on the device, and only the values you release below.';

  @override
  String get healthIntroNone =>
      'This device has no health store to read from. Everything stays manual, which works perfectly well.';

  @override
  String healthLastImport(String when) {
    return 'Last import: $when';
  }

  @override
  String get healthMetricCardio => 'cardio sessions';

  @override
  String get healthMetricMindful => 'mindfulness sessions';

  @override
  String get healthMetricSleep => 'sleep duration';

  @override
  String get healthMetricSteps => 'step count';

  @override
  String get healthMetricStrength => 'strength-training sessions';

  @override
  String get healthMetricWater => 'water intake';

  @override
  String get healthNever => 'never';

  @override
  String get healthNoNetworkBadge => 'Never leaves the device';

  @override
  String get healthNotOnPlatform => 'Not available on this platform';

  @override
  String get healthOpenSystem => 'Open system settings';

  @override
  String healthReads(String metric) {
    return 'Reads: $metric';
  }

  @override
  String get healthRuleAbstain =>
      'It never touches an abstinence habit. No sensor can show that you did not drink.';

  @override
  String healthRuleBackfill(int days) {
    return 'It reaches at most $days days back.';
  }

  @override
  String get healthRuleManual =>
      'It never overwrites a number you entered yourself.';

  @override
  String get healthRuleRelapse =>
      'It never writes on a day you logged a relapse.';

  @override
  String get healthRuleRest =>
      'It leaves rest days empty, so a walk cannot earn XP on a day off.';

  @override
  String get healthRuleUpwards =>
      'It only ever raises a value, never lowers one.';

  @override
  String get healthRulesSection => 'What the import will not do';

  @override
  String get healthTitle => 'Watch & health data';

  @override
  String get healthUnavailableBody =>
      'Health Connect comes with Android 14 and newer; on older phones it is a free app from the Play Store. Without it there is nothing here to read.';

  @override
  String get healthUnavailableTitle => 'Health Connect is missing';

  @override
  String get healthUnknown => 'Apple does not say';

  @override
  String get healthUnknownBody =>
      'iOS deliberately never tells an app whether reading was allowed — a refusal would otherwise give something away by itself. If nothing arrives, check the release in the Health app.';

  @override
  String get heatLess => 'less';

  @override
  String get heatMore => 'more';

  @override
  String homeAscendAction(String tier) {
    return 'On to $tier';
  }

  @override
  String homeAscendBody(String emoji, String tier) {
    return 'This is where most apps stop. Your next tier: $emoji $tier. Streak, XP and history all carry over.';
  }

  @override
  String homeAscendTitle(int days) {
    return 'Cycle complete: $days days.';
  }

  @override
  String homeCheckInToast(String emoji, String habit) {
    return '$emoji $habit logged.';
  }

  @override
  String get homeCheckOffToday => 'Check off today';

  @override
  String homeDayCompleteToast(int streak) {
    return '🔥 Day complete — streak is at $streak.';
  }

  @override
  String homeDayOfTotal(int day, int total) {
    return 'Day $day / $total';
  }

  @override
  String homeDoneOfTotal(int done, int total) {
    return '$done of $total done';
  }

  @override
  String homeExercisesCount(int count) {
    return '$count exercises';
  }

  @override
  String homeFreezeBody(int count) {
    return '$count left. Saves the streak but does not count as a completed day.';
  }

  @override
  String get homeFreezeTitle => 'Freeze the streak';

  @override
  String get homeFreezeUse => 'Use one';

  @override
  String homeLevelAndTier(String emoji, String tier, int level) {
    return '$emoji $tier · Level $level';
  }

  @override
  String homeMinutesApprox(int count) {
    return '≈ $count min';
  }

  @override
  String get homeOptional => 'Optional';

  @override
  String get homeOptionalSubtitle =>
      'Not scheduled today — still counts as XP.';

  @override
  String get homeRelapseBody =>
      'This resets the streak and is visible to your friends. Being honest is the whole point — but only if it is true.';

  @override
  String get homeRelapseConfirm => 'Log it';

  @override
  String homeRelapseTitle(String habit) {
    return 'Relapse on $habit?';
  }

  @override
  String get homeRestDay => 'Nothing scheduled today — rest day per the plan.';

  @override
  String homeSetsCount(int count) {
    return '$count sets';
  }

  @override
  String get homeStorageError => 'The app could not open its storage.';

  @override
  String homeStreakDays(int streak) {
    String _temp0 = intl.Intl.pluralLogic(
      streak,
      locale: localeName,
      other: 'days streak',
      one: 'day streak',
    );
    return '$_temp0';
  }

  @override
  String get homeTodaysMacros => 'Today\'s macros';

  @override
  String get homeTodaysWorkout => 'Today\'s training';

  @override
  String homeXp(int xp) {
    return '$xp XP';
  }

  @override
  String get inviteErrorMalformed => 'This invite is not valid.';

  @override
  String get inviteErrorSelf => 'That is you.';

  @override
  String get inviteHowTitle => 'How this works';

  @override
  String get inviteLinkCopied => 'Link copied.';

  @override
  String get inviteReachableAt => 'Reachable at';

  @override
  String get inviteShareSubject => '100 Days challenge';

  @override
  String inviteShareText(String link) {
    return 'Do the 100 days with me: $link';
  }

  @override
  String get inviteStep1 =>
      'The other person scans the code or opens the link.';

  @override
  String get inviteStep2 =>
      'You follow each other directly — no account, no phone number, no provider granting permission.';

  @override
  String get inviteStep3 =>
      'From then on your devices sync whenever they see each other: same Wi-Fi, same home, same gym.';

  @override
  String get inviteTitle => 'Invite friends';

  @override
  String get leagueActiveToday => 'Active today';

  @override
  String get leagueBronze => 'Bronze';

  @override
  String get leagueDiamond => 'Diamond';

  @override
  String get leagueFooter =>
      'XP comes per check-in, scaled by difficulty and streak. On Sunday the top places move up and the bottom ones move down.';

  @override
  String get leagueGold => 'Gold';

  @override
  String get leagueNothingToday => 'Nothing yet today';

  @override
  String get leagueObsidian => 'Obsidian';

  @override
  String get leaguePlatinum => 'Platinum';

  @override
  String get leagueSilver => 'Silver';

  @override
  String get leagueThisWeek => 'This week';

  @override
  String leagueTitle(String league) {
    return '$league league';
  }

  @override
  String get leagueTooSmall =>
      'A league with one person is just a list. Connect friends and the competition starts.';

  @override
  String leagueWeekAndPeople(String week, int count) {
    return 'Week $week · $count participants';
  }

  @override
  String get leagueWood => 'Wood';

  @override
  String leagueYouSuffix(String name) {
    return '$name (you)';
  }

  @override
  String get leagueYourRank => 'your place';

  @override
  String get mealBreakfast => 'Breakfast';

  @override
  String get mealDinner => 'Dinner';

  @override
  String get mealIdeaBreakfast1 => 'Skyr with berries, oats and flaxseed';

  @override
  String get mealIdeaBreakfast2 => 'Scrambled eggs (3) with wholegrain toast';

  @override
  String get mealIdeaBreakfast3 => 'Overnight oats with quark and banana';

  @override
  String get mealIdeaBreakfast4 => 'Protein porridge with peanut butter';

  @override
  String get mealIdeaDinner1 => 'Turkey pan with courgette and feta';

  @override
  String get mealIdeaDinner2 => 'Omelette with mushrooms and spinach';

  @override
  String get mealIdeaDinner3 => 'Chickpea curry with natural yoghurt';

  @override
  String get mealIdeaDinner4 => 'Tuna salad with beans and egg';

  @override
  String get mealIdeaLunch1 => 'Chicken breast, rice, broccoli';

  @override
  String get mealIdeaLunch2 => 'Lentil bolognese with wholegrain pasta';

  @override
  String get mealIdeaLunch3 => 'Salmon fillet with potatoes and salad';

  @override
  String get mealIdeaLunch4 => 'Beef strips with couscous and roast vegetables';

  @override
  String get mealIdeaSnack1 => 'Quark with honey and walnuts';

  @override
  String get mealIdeaSnack2 => 'Protein shake with banana';

  @override
  String get mealIdeaSnack3 => 'A handful of almonds and an apple';

  @override
  String get mealIdeaSnack4 => 'Cottage cheese on crispbread';

  @override
  String get mealLunch => 'Lunch';

  @override
  String get mealSnack => 'Snack';

  @override
  String get milestoneAlcohol14Body =>
      'Liver fat measurably drops, inflammation markers fall.';

  @override
  String get milestoneAlcohol14Title => 'Day 14 — the liver recovers';

  @override
  String get milestoneAlcohol1Body =>
      'Blood sugar and sleep are still all over the place. Drink a lot, go to bed early.';

  @override
  String get milestoneAlcohol1Title => 'Day 1 — the body starts clearing up';

  @override
  String get milestoneAlcohol30Body =>
      'Markedly better liver values, a few kilos down on average, visibly calmer skin.';

  @override
  String get milestoneAlcohol30Title => 'Day 30 — skin, sleep, weight';

  @override
  String get milestoneAlcohol3Body =>
      'REM sleep comes back. You wake up less often at night.';

  @override
  String get milestoneAlcohol3Title => 'Day 3 — sleep gets deeper';

  @override
  String get milestoneAlcohol7Body =>
      'No residual alcohol. Concentration and mood stabilise.';

  @override
  String get milestoneAlcohol7Title => 'Week 1 — a clear head in the morning';

  @override
  String get milestoneAlcohol90Body =>
      'The craving is no longer a daily negotiation. Blood pressure and immune system benefit for good.';

  @override
  String get milestoneAlcohol90Title => 'Day 90 — the new normal';

  @override
  String get milestoneDopamine1Body =>
      'You will want to reach for your phone hundreds of times. That is the habit, not you.';

  @override
  String get milestoneDopamine1Title => 'Day 1 — reaching for the phone';

  @override
  String get milestoneDopamine21Body =>
      'The automatic hand movement in a queue disappears.';

  @override
  String get milestoneDopamine21Title => 'Day 21 — the reflex is gone';

  @override
  String get milestoneDopamine3Body =>
      'Boredom is not a bug. It is the state ideas come from.';

  @override
  String get milestoneDopamine3Title => 'Day 3 — boredom comes back';

  @override
  String get milestoneDopamine60Body =>
      'Two focused hours on one thing are normal again.';

  @override
  String get milestoneDopamine60Title => 'Day 60 — deep work';

  @override
  String get milestoneDopamine7Body =>
      'You can sit through longer texts and longer conversations without looking away.';

  @override
  String get milestoneDopamine7Title => 'Week 1 — attention span grows';

  @override
  String get milestoneGeneric21Body =>
      'The decision costs less than it did last week.';

  @override
  String get milestoneGeneric21Title => 'Day 21 — automation begins';

  @override
  String get milestoneGeneric3Body =>
      'The novelty bonus is gone. Now the habit decides.';

  @override
  String get milestoneGeneric3Title => 'Day 3 — the first real test';

  @override
  String get milestoneGeneric66Body =>
      'On average a behaviour takes 66 days to run automatically. You are there.';

  @override
  String get milestoneGeneric66Title => 'Day 66 — habit';

  @override
  String get milestoneNicotine14Body =>
      'Up to 30% better lung function; stairs get easier.';

  @override
  String get milestoneNicotine14Title => 'Day 14 — lungs work better';

  @override
  String get milestoneNicotine1Body =>
      'After 12 hours CO levels are normal and oxygen rises.';

  @override
  String get milestoneNicotine1Title => 'Day 1 — carbon monoxide gone';

  @override
  String get milestoneNicotine3Body =>
      'Physical withdrawal peaks. It gets easier from here.';

  @override
  String get milestoneNicotine3Title => 'Day 3 — nicotine is out';

  @override
  String get milestoneNicotine90Body =>
      'Coughing and shortness of breath drop markedly.';

  @override
  String get milestoneNicotine90Title => 'Day 90 — cilia recovered';

  @override
  String get milestoneNoFap14Body =>
      'If you feel flat and empty: that is a known phase and it passes.';

  @override
  String get milestoneNoFap14Title => 'Day 14 — flatline possible';

  @override
  String get milestoneNoFap30Body =>
      'Fewer intrusive thoughts, more presence in everyday life.';

  @override
  String get milestoneNoFap30Title => 'Day 30 — the head gets quieter';

  @override
  String get milestoneNoFap3Body =>
      'Restlessness and irritability are normal. Movement helps more than willpower.';

  @override
  String get milestoneNoFap3Title => 'Day 3 — the first wave';

  @override
  String get milestoneNoFap7Body => 'More drive, often better sleep too.';

  @override
  String get milestoneNoFap7Title => 'Week 1 — energy rises';

  @override
  String get milestoneNoFap90Body =>
      'The classic reboot mark. From here it is lifestyle, not a fight.';

  @override
  String get milestoneNoFap90Title => 'Day 90 — the reboot';

  @override
  String get milestoneSugar14Body =>
      'Fruit suddenly tastes sweet. That is the sensor coming back.';

  @override
  String get milestoneSugar14Title => 'Day 14 — taste recalibrates';

  @override
  String get milestoneSugar2Body =>
      'Headaches and cravings peak here. Protein and water.';

  @override
  String get milestoneSugar2Title => 'Day 2 — sugar withdrawal';

  @override
  String get milestoneSugar30Body =>
      'Face and belly look flatter, inflammation markers drop.';

  @override
  String get milestoneSugar30Title => 'Day 30 — less water retention';

  @override
  String get milestoneSugar5Body =>
      'No more afternoon slump, because the blood sugar rollercoaster is gone.';

  @override
  String get milestoneSugar5Title => 'Day 5 — energy levels out';

  @override
  String get muscleBack => 'Back';

  @override
  String get muscleBiceps => 'Biceps';

  @override
  String get muscleCalves => 'Calves';

  @override
  String get muscleChest => 'Chest';

  @override
  String get muscleCore => 'Core';

  @override
  String get muscleFullBody => 'Full body';

  @override
  String get muscleGlutes => 'Glutes';

  @override
  String get muscleHamstrings => 'Hamstrings';

  @override
  String get muscleQuads => 'Quadriceps';

  @override
  String get muscleShoulders => 'Shoulders';

  @override
  String get muscleTriceps => 'Triceps';

  @override
  String get navFriends => 'Friends';

  @override
  String get navMore => 'More';

  @override
  String get navPlan => 'Plan';

  @override
  String get navSettingsTitle => 'Settings';

  @override
  String get navStats => 'Numbers';

  @override
  String get navToday => 'Today';

  @override
  String get notifChannelPressure => 'Friends & streak warnings';

  @override
  String get notifChannelPressureDesc =>
      'When friends have been active or your streak is on the line.';

  @override
  String get notifChannelReminder => 'Daily reminder';

  @override
  String get notifChannelReminderDesc =>
      'Reminds you of your habits for today.';

  @override
  String notifDayDone(int day) {
    return 'Day $day is in the bag. Again tomorrow.';
  }

  @override
  String notifDayOpenNoStreak(int day, int total) {
    return 'Day $day of $total. Start again today.';
  }

  @override
  String notifDayOpenWithStreak(int day, int total, int streak) {
    return 'Day $day of $total. $streak days of streak want defending.';
  }

  @override
  String notifFriendActive(String name) {
    return '$name was already out today';
  }

  @override
  String notifFriendsActive(int count) {
    return '$count of your people were already out today';
  }

  @override
  String get notifFriendsActiveBody =>
      'You are still on zero. The day is not over yet.';

  @override
  String notifStreakRiskBody(int streak) {
    return '$streak days. One forgotten evening and they are gone.';
  }

  @override
  String get notifStreakRiskTitle => 'Your streak is on the line';

  @override
  String nudgeCheerRespect(String emoji) {
    return 'Respect for $emoji';
  }

  @override
  String get nudgeDefaultPoke => 'I already went today. And you?';

  @override
  String get nudgeIWentDidYou => 'I already went today. And you?';

  @override
  String get nudgeNoPressure => 'No pressure. But I can see your feed.';

  @override
  String get nudgeReasonInactive => 'Inactive for two days';

  @override
  String get nudgeReasonNothingToday => 'Nothing done today';

  @override
  String nudgeStreakWatching(int day) {
    return 'Day $day. Your streak is looking at you.';
  }

  @override
  String get nudgeStrongToday => 'Strong today. Again tomorrow?';

  @override
  String nudgeYouWereInForDays(int streak) {
    String _temp0 = intl.Intl.pluralLogic(
      streak,
      locale: localeName,
      other: 'You were in for $streak days. Today too?',
      one: 'You were in for 1 day. Today too?',
    );
    return '$_temp0';
  }

  @override
  String get obActivityAthlete => 'Athlete';

  @override
  String get obActivityHigh => 'Very active';

  @override
  String get obActivityLight => 'Lightly active';

  @override
  String get obActivityModerate => 'Moderate';

  @override
  String get obActivitySedentary => 'Sedentary';

  @override
  String get obBodyActivity => 'Daily life & movement';

  @override
  String get obBodyAge => 'Age';

  @override
  String obBodyAgeValue(int years) {
    return '$years years';
  }

  @override
  String get obBodyEyebrow => 'Nutrition';

  @override
  String get obBodyHeight => 'Height';

  @override
  String get obBodyPreviewTitle => 'Your daily target';

  @override
  String get obBodySubtitle =>
      'Only for the calorie and protein calculation. All of it stays on this device.';

  @override
  String get obBodyTitle => 'A few numbers.';

  @override
  String get obBodyWeight => 'Weight';

  @override
  String get obCycleDays => 'days';

  @override
  String get obCycleLengthTitle => 'How long is one cycle?';

  @override
  String get obCycleNote =>
      'The cycle ending is not the end: your streak carries on and you move up to the next tier.';

  @override
  String get obEquipmentBodyweight => 'Bodyweight only';

  @override
  String get obEquipmentBodyweightBody => 'No equipment. Works anyway.';

  @override
  String get obEquipmentFullGym => 'Full gym';

  @override
  String get obEquipmentFullGymBody => 'Barbell, machines, cables.';

  @override
  String get obEquipmentHome => 'Home gym';

  @override
  String get obEquipmentHomeBody => 'Dumbbells, bands, pull-up bar.';

  @override
  String get obExample1Clarity => 'Halve my screen time, get my head back';

  @override
  String get obExample1Custom => 'My thing, my rules';

  @override
  String get obExample1Discipline => '100 days, no excuses';

  @override
  String get obExample1Fat => '8 kg down by summer';

  @override
  String get obExample1Fit => '5 km under 25 minutes';

  @override
  String get obExample1Muscle => '5 kg of muscle in 100 days';

  @override
  String get obExample1Sober => '100 days completely dry';

  @override
  String get obExample2Clarity => '100 days without doomscrolling';

  @override
  String get obExample2Discipline => 'Up at 6 every morning, no debate';

  @override
  String get obExample2Fat => 'Fit into my old jeans again';

  @override
  String get obExample2Fit => 'Up the stairs without stopping';

  @override
  String get obExample2Muscle => 'Finally 10 clean pull-ups';

  @override
  String get obExample2Sober => 'No sugar, no alcohol, no exceptions';

  @override
  String get obExperienceAdvanced => 'Experienced';

  @override
  String get obExperienceAdvancedBody =>
      'More than three years. Volume is your lever.';

  @override
  String get obExperienceBeginner => 'Beginner';

  @override
  String get obExperienceBeginnerBody =>
      'Under a year of consistency. Technique before weight.';

  @override
  String get obExperienceIntermediate => 'Intermediate';

  @override
  String get obExperienceIntermediateBody =>
      'One to three years. You know what RPE 8 feels like.';

  @override
  String get obGoalSubtitle =>
      'One goal. Everything else — training plan, nutrition plan, streak — is built from it.';

  @override
  String get obGoalTitle => 'What is this about?';

  @override
  String get obHabitDailyTarget => 'Daily target';

  @override
  String get obHabitRecommended => 'recommended';

  @override
  String get obHabitsSubtitlePreselected =>
      'What fits your goal is preselected. Change it however you like.';

  @override
  String get obHabitsSubtitleTooMany =>
      'That is a lot. Experience says people stick with three or four — better fewer and actually done.';

  @override
  String get obHabitsTitle => 'What counts every day?';

  @override
  String get obIdentityBoxBody =>
      'An Ed25519 key pair on this device, as a did:key. Every check-in is signed with it — which is why nobody can fake your streak and you do not have to trust anyone. The recovery key is in settings. Back it up.';

  @override
  String get obIdentityBoxTitle => 'Your identity';

  @override
  String get obIdentityNameHint => 'Your name';

  @override
  String get obIdentitySubtitle =>
      'No account, no email, no password. Your key pair is already on this device.';

  @override
  String get obIdentityTitle => 'How should your people see you?';

  @override
  String get obPointBeyondBody =>
      'After that it carries on — next tier, harder targets, same streak.';

  @override
  String get obPointBeyondTitle => 'Day 100 is not the end';

  @override
  String get obPointGoalBody =>
      'No goal, no plan. You say what this is about — the app builds training, nutrition or a streak around it.';

  @override
  String get obPointGoalTitle => 'The goal comes first';

  @override
  String get obPointPrivacyBody =>
      'No account, no server, no cloud. Your data stays on your device and goes straight to your friends.';

  @override
  String get obPointPrivacyTitle => 'Nobody else';

  @override
  String get obPointSocialBody =>
      'Not an anonymous counter. If Marcel was at the gym today and you were not, it says so. That is the point.';

  @override
  String get obPointSocialTitle => 'Your people see everything';

  @override
  String obSetsAndMinutes(int sets, int minutes) {
    return '$sets sets · $minutes min';
  }

  @override
  String get obSexFemale => 'female';

  @override
  String get obSexMale => 'male';

  @override
  String get obStartChallenge => 'Start the challenge';

  @override
  String obStartFailed(String message) {
    return 'Could not start: $message';
  }

  @override
  String get obStatementHint => 'I want to …';

  @override
  String get obStatementSubtitle =>
      'You will see this sentence on every hard day. So write the real one, not the presentable one.';

  @override
  String get obStatementTitle => 'Say it in one sentence.';

  @override
  String get obStep1 => 'Step 1';

  @override
  String get obStep2 => 'Step 2';

  @override
  String get obStep3 => 'Step 3';

  @override
  String get obStep4 => 'Step 4';

  @override
  String get obSummaryAlmostDone => 'Almost there';

  @override
  String get obSummaryDailySection => 'This counts daily';

  @override
  String obSummaryDayOne(String emoji, String goal, int days) {
    return '$emoji $goal · Day 1 of $days';
  }

  @override
  String get obSummaryEyebrow => 'Your plan';

  @override
  String get obSummaryFriendsNote =>
      'Next: connect friends. Almost nobody lasts 100 days alone — with an audience they do.';

  @override
  String get obSummaryMissing => 'A few details are still missing.';

  @override
  String get obSummaryNutritionSection => 'Nutrition plan';

  @override
  String obSummaryTitle(int days) {
    return '$days days, starting today.';
  }

  @override
  String get obSummaryTrainingSection => 'Training plan';

  @override
  String get obTrainingDaysPerWeek => 'Training days per week';

  @override
  String get obTrainingEquipment => 'Equipment';

  @override
  String get obTrainingExperience => 'Experience';

  @override
  String get obTrainingEyebrow => 'Training';

  @override
  String get obTrainingSubtitle =>
      'The app builds your split from this — including deload weeks, so you are not running on empty after six weeks.';

  @override
  String get obTrainingTitle => 'How often and with what?';

  @override
  String get obWelcomeEyebrow => '100 days and far beyond';

  @override
  String get obWelcomeSubtitle =>
      'Set a goal. Get a plan. After that only one thing counts: whether you showed up today — and whether your people can see it.';

  @override
  String get obWelcomeTitle => 'You do not need a new you.\nYou need 100 days.';

  @override
  String get peerActivityAscended => 'Reached the next tier';

  @override
  String peerActivityCheckIn(String emoji, String habit) {
    return '$emoji $habit done';
  }

  @override
  String get peerActivityFreeze => 'Streak frozen';

  @override
  String get peerActivityMissed => 'Missed a day';

  @override
  String get peerActivityNone => 'Nothing yet';

  @override
  String get peerActivityRelapse => 'Relapse logged';

  @override
  String get peerActivityStarted => 'Challenge started';

  @override
  String get planAdjustmentsNote =>
      'Worked out on this device, from your last few weeks. None of it leaves your phone.';

  @override
  String get planBmr => 'Basal metabolic rate (BMR)';

  @override
  String get planCarbs => 'Carbs';

  @override
  String get planCarbsShort => 'Carbs';

  @override
  String planCleanDays(int days) {
    return '$days days clean';
  }

  @override
  String get planContext => 'Context';

  @override
  String get planCurrentBadge => 'current';

  @override
  String get planDeloadBadge => 'deload';

  @override
  String get planExpectedChange => 'Expected change';

  @override
  String get planFat => 'Fat';

  @override
  String get planFiber => 'Fibre';

  @override
  String get planKcal => 'kcal';

  @override
  String planKcalPerDay(int kcal) {
    return '$kcal kcal per day';
  }

  @override
  String get planKcalPerDayShort => 'kcal / day';

  @override
  String planMealMacros(int kcal, int protein) {
    return '$kcal kcal · ${protein}g P';
  }

  @override
  String get planMeals => 'Meals';

  @override
  String planNutritionDeficit(int percent, int tdee) {
    return 'A $percent% deficit below your $tdee kcal expenditure. That is roughly 0.5 kg of fat a week — fast enough to see, slow enough to keep the muscle.';
  }

  @override
  String planNutritionMaintain(int tdee) {
    return 'Maintenance at $tdee kcal. Habit and performance first, body composition second.';
  }

  @override
  String planNutritionSideGoal(int tdee) {
    return 'Maintenance at $tdee kcal. Your goal is elsewhere — nutrition just should not slow you down.';
  }

  @override
  String planNutritionSurplus(int percent, int tdee) {
    return 'A $percent% surplus over your $tdee kcal expenditure. Lean bulk: enough to build, little enough that it is not just fat.';
  }

  @override
  String planPerWeek(String value) {
    return '$value kg/week';
  }

  @override
  String get planProtein => 'Protein';

  @override
  String get planTabAbstinence => 'Staying clean';

  @override
  String get planTabAdjustments => 'Adjustments';

  @override
  String get planTabNutrition => 'Nutrition';

  @override
  String get planTabTraining => 'Training';

  @override
  String get planTdee => 'Total expenditure (TDEE)';

  @override
  String get planWater => 'Water';

  @override
  String planWeekNumber(int week) {
    return 'Week $week';
  }

  @override
  String planWorkoutSummary(int sets, int minutes) {
    return '$sets sets · ≈ $minutes min';
  }

  @override
  String pressureBodyBehind(String activity, int streak) {
    String _temp0 = intl.Intl.pluralLogic(
      streak,
      locale: localeName,
      other: '$streak days streak',
      one: '1 day streak',
    );
    return '$activity · $_temp0. You are still on zero today.';
  }

  @override
  String get pressureBodyDone => 'You too. Keep it up.';

  @override
  String pressureManyActive(int count) {
    return '$count of your people were already out today';
  }

  @override
  String pressureOneActive(String name) {
    return '$name was already out today';
  }

  @override
  String get profileCheer => 'Cheer';

  @override
  String get profileCheerSent => 'Cheered.';

  @override
  String profileDaysCount(int days) {
    return '$days days';
  }

  @override
  String get profileDisconnect => 'Disconnect';

  @override
  String get profileHabits => 'Habits';

  @override
  String get profileHistory => 'History';

  @override
  String get profileNudge => 'Nudge';

  @override
  String get profileNudgeSent => 'Nudge sent.';

  @override
  String get profileRemoveBody =>
      'This deletes their entire history from your device. The only way back is to connect again.';

  @override
  String profileRemoveTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileUnknownBody =>
      'Nothing about this identity is on your device.';

  @override
  String get profileUnknownTitle => 'Unknown';

  @override
  String promptAdjustHabitLine(
      String habit, String target, int days, int streak) {
    return '- $habit: target $target, ${days}x per week, streak $streak';
  }

  @override
  String promptAdjustments(
      int day, int total, int percent, String statement, String habits) {
    return 'You are a training and habit coach. Write in English, second person.\nThe user is on day $day of $total.\nHit rate: $percent%.\nGoal: \"$statement\"\n\n$habits\n\nGive at most 4 concrete adjustments, one per line, at most 15 words each. No preamble, no numbering, no emoji.';
  }

  @override
  String promptBriefing(
      String persona,
      String statement,
      int day,
      int total,
      String tier,
      int streak,
      int longest,
      String doneToday,
      String hour,
      String habits,
      String peers) {
    return 'You are the coach in a 100-day challenge app. Write in English, second person.\n$persona\nTwo sentences at most. No emoji at the start of a line. No quotation marks.\n\nThe goal: \"$statement\"\nDay $day of $total (tier: $tier)\nCurrent streak: $streak days, longest: $longest\nDone today: $doneToday\nTime of day: $hour:00\n\nHabits:\n$habits\n\nFriends:\n$peers\n\nAnswer in exactly this format:\nTITLE: <at most 6 words>\nTEXT: <1-2 sentences>';
  }

  @override
  String promptHabitLine(String emoji, String habit, int streak, String unit) {
    return '- $emoji $habit: $streak $unit';
  }

  @override
  String get promptNo => 'no';

  @override
  String get promptNoFriends => '- no friends connected';

  @override
  String promptNudge(String name, int day, int streak) {
    return 'Write a single short taunt in English aimed at $name, who has done nothing for their own challenge today. The sender is on day $day with a $streak day streak. At most 12 words, cheeky but friendly, no bullying, no quotation marks. Output only the message.';
  }

  @override
  String get promptPeerActive => 'ALREADY active today';

  @override
  String get promptPeerInactive => 'nothing yet today';

  @override
  String promptPeerLine(String name, int streak, String status) {
    return '- $name: $streak day streak, $status';
  }

  @override
  String get promptPersonaCalm => 'You are calm and matter-of-fact.';

  @override
  String get promptPersonaCelebrate =>
      'You are brief and proud, without schmaltz.';

  @override
  String get promptPersonaDemanding => 'You are demanding and concrete.';

  @override
  String get promptPersonaDirect =>
      'You are direct and mildly provocative, never insulting.';

  @override
  String get promptPersonaRecover =>
      'You are sober and respectful. No pity, no blame.';

  @override
  String get promptUnitClean => 'days clean';

  @override
  String get promptUnitStreak => 'days streak';

  @override
  String get promptYes => 'yes';

  @override
  String get recoveryCopied => 'Key copied.';

  @override
  String get recoveryLookAround => 'Have a look around you first.';

  @override
  String get recoveryShow => 'Show the key';

  @override
  String get recoveryTip1 => 'A password manager — the best place for it.';

  @override
  String get recoveryTip2 =>
      'Write it down and put it in the drawer where your ID lives.';

  @override
  String get recoveryTip3 =>
      'Not into a chat, not into a cloud-synced notes app, not as a screenshot in your gallery.';

  @override
  String get recoveryTitle => 'Recovery key';

  @override
  String get recoveryWarning =>
      'Whoever has this key is you. They can sign check-ins in your name, and you cannot revoke it — there is no provider who could.';

  @override
  String get recoveryWhereTitle => 'Where to keep it';

  @override
  String relativeDays(int count) {
    return '$count days ago';
  }

  @override
  String relativeHours(int count) {
    return '$count h ago';
  }

  @override
  String get relativeJustNow => 'just now';

  @override
  String relativeMinutes(int count) {
    return '$count min ago';
  }

  @override
  String get relativeYesterday => 'yesterday';

  @override
  String ringDayOfTotal(int day, int total) {
    return 'Day $day / $total';
  }

  @override
  String ringDayStreak(int streak) {
    String _temp0 = intl.Intl.pluralLogic(
      streak,
      locale: localeName,
      other: 'days streak',
      one: 'day streak',
    );
    return '$_temp0';
  }

  @override
  String scanCameraUnavailableBody(String code) {
    return 'It works without the camera too: have the invite link sent to you and paste it below.\n\n$code';
  }

  @override
  String get scanCameraUnavailableTitle => 'Camera unavailable';

  @override
  String get scanHint => 'Point the camera at your friend’s QR code.';

  @override
  String get scanPasteInstead => 'Paste a link instead';

  @override
  String get scanPasteTitle => 'Invite link';

  @override
  String get scanTitle => 'Scan a code';

  @override
  String get setAboutBody =>
      'No account, no server, no ads, no tracking. Your data lives on this device and only goes to the friends you connected yourself. The source is open — check it instead of believing it.';

  @override
  String get setAboutSection => 'About';

  @override
  String get setAboutTitle => '100 days and far beyond';

  @override
  String get setCoachSection => 'Coach';

  @override
  String get setDidCopied => 'DID copied.';

  @override
  String setHealthConnected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count habits',
      one: '1 habit',
    );
    return 'Filling in $_temp0';
  }

  @override
  String get setHealthOff => 'Not connected';

  @override
  String get setHealthSection => 'Watch & health data';

  @override
  String get setHealthTitle => 'Apple Health and Health Connect';

  @override
  String get setIdentitySection => 'Identity & data';

  @override
  String get setLan => 'Local network';

  @override
  String get setLanOff => 'Not active.';

  @override
  String get setLanOn =>
      'Active — finds friends on the same Wi-Fi automatically.';

  @override
  String get setLanguage => 'App language';

  @override
  String get setLanguageEnglish => 'English';

  @override
  String get setLanguageGerman => 'Deutsch';

  @override
  String get setLanguageSection => 'Language';

  @override
  String get setLanguageSystem => 'System language';

  @override
  String setLanguageSystemSub(String language) {
    return 'Follows your phone. Currently: $language';
  }

  @override
  String get setNetworkSection => 'Network';

  @override
  String get setOnDeviceAi => 'On-device AI';

  @override
  String get setOnThisDevice => 'On this device';

  @override
  String setOnThisDeviceSub(int events, int friends) {
    return '$events own entries · $friends connected feeds';
  }

  @override
  String get setRecoveryKey => 'Recovery key';

  @override
  String get setRecoveryKeySub => 'The only way back into your account.';

  @override
  String setSyncFailed(String message) {
    return 'Last attempt failed: $message';
  }

  @override
  String setSyncLast(String peer, int received, int sent) {
    return 'Last with $peer: $received received, $sent sent.';
  }

  @override
  String get setSyncNever => 'No round has run yet.';

  @override
  String get setSyncNow => 'Sync now';

  @override
  String get setSyncPeerFallback => 'a peer';

  @override
  String get setSyncStarted => 'Sync round started.';

  @override
  String get setViewSource => 'View the source';

  @override
  String get setWipe => 'Delete everything';

  @override
  String get setWipeBody =>
      'Without your recovery key nothing can be restored afterwards — there is no server holding a copy. That is the price of nobody else holding one either.';

  @override
  String get setWipeSub => 'Remove identity, challenge and all friends.';

  @override
  String get setWipeTitle => 'Really delete everything?';

  @override
  String get socialTabFeed => 'Feed';

  @override
  String socialTabFriends(int count) {
    return 'Friends ($count)';
  }

  @override
  String get socialTabLeague => 'League';

  @override
  String get splitFullBodyThrice => 'Full body 3x';

  @override
  String get splitFullBodyTwice => 'Full body 2x';

  @override
  String get splitPplPlusUpperLower => 'Push / Pull / Legs + Upper / Lower';

  @override
  String get splitPplTwice => 'Push / Pull / Legs 2x';

  @override
  String get splitPreview2 => 'Full body 2x — every session hits everything.';

  @override
  String get splitPreview3 =>
      'Full body 3x — the best trade-off for most people.';

  @override
  String get splitPreview4 => 'Upper / Lower — upper body twice, legs twice.';

  @override
  String get splitPreview5 => 'Push / Pull / Legs plus Upper / Lower.';

  @override
  String get splitPreview6 => 'Push / Pull / Legs, twice a week.';

  @override
  String get splitUpperLower => 'Upper / Lower';

  @override
  String get statDay => 'Day';

  @override
  String get statRecord => 'Record';

  @override
  String get statStreak => 'Streak';

  @override
  String get statXp => 'XP';

  @override
  String get statsCurrentStreak => 'Current streak';

  @override
  String get statsFullDays => 'Full days';

  @override
  String statsHabitProgress(int done, int planned, int percent) {
    return '$done of $planned planned days ($percent %)';
  }

  @override
  String statsHistorySince(String date) {
    return 'Since $date';
  }

  @override
  String get statsHitRate => 'Hit rate';

  @override
  String get statsLevel => 'Level';

  @override
  String statsLevelNumber(int level) {
    return 'Level $level';
  }

  @override
  String get statsLongestStreak => 'Longest streak';

  @override
  String get statsNoXpYet => 'No XP yet. It arrives with the first tick.';

  @override
  String get statsPerHabit => 'Per habit';

  @override
  String statsPercent(String value) {
    return '$value %';
  }

  @override
  String get statsWeeklyXp => 'XP over recent weeks';

  @override
  String statsXpToNextLevel(int remaining, int level, int current, int total) {
    return '$remaining XP to level $level ($current / $total)';
  }

  @override
  String get targetClean => 'clean';

  @override
  String targetCount(int count) {
    return '${count}x';
  }

  @override
  String get targetDone => 'done';

  @override
  String targetGrams(int count) {
    return '$count g';
  }

  @override
  String targetKcal(int count) {
    return '$count kcal';
  }

  @override
  String targetMinutes(int count) {
    return '$count min';
  }

  @override
  String targetPages(int count) {
    return '$count pages';
  }

  @override
  String targetSteps(int count) {
    return '$count steps';
  }

  @override
  String get tier0 => 'The first 100';

  @override
  String get tier1 => 'Beyond the 100';

  @override
  String get tier2 => 'Three hundred';

  @override
  String get tier3 => 'The year';

  @override
  String get tier4 => 'Unbending';

  @override
  String get tier5 => 'Legend';

  @override
  String tierNumbered(int rank) {
    return 'Legend $rank';
  }

  @override
  String get tileCheckOff => 'Check off';

  @override
  String get tileCleanToday => 'Clean today';

  @override
  String get tileDone => 'Done';

  @override
  String tileDoneWith(String target) {
    return 'Done · $target';
  }

  @override
  String get tileLogAmount => 'Log';

  @override
  String get tileRelapse => 'Relapse';

  @override
  String get tileRelapseLogged => 'Relapse logged — start again tomorrow.';

  @override
  String get tileRestToday => 'Rest day today per the plan';

  @override
  String tileStreakBadge(int streak) {
    return '$streak 🔥';
  }

  @override
  String tileTarget(String target) {
    return 'Target: $target';
  }

  @override
  String get tileUpdateAmount => 'Update';

  @override
  String trainingPhaseBuild(int week, int block) {
    return 'Build $week/3 · Block $block';
  }

  @override
  String get trainingPhaseDeload => 'Deload';

  @override
  String trainingRationale(int days, String split) {
    return '$days training days a week as \"$split\". Three weeks of building, then a deload week — so you last 100 days without burning out.';
  }

  @override
  String get weekdayFri => 'FRI';

  @override
  String get weekdayMon => 'MON';

  @override
  String get weekdaySat => 'SAT';

  @override
  String get weekdayShortFri => 'Fr';

  @override
  String get weekdayShortMon => 'Mo';

  @override
  String get weekdayShortSun => 'Su';

  @override
  String get weekdayShortWed => 'We';

  @override
  String get weekdaySun => 'SUN';

  @override
  String get weekdayThu => 'THU';

  @override
  String get weekdayTue => 'TUE';

  @override
  String get weekdayWed => 'WED';

  @override
  String get workoutExercises => 'Exercises';

  @override
  String get workoutFullBodyA => 'Full body A';

  @override
  String get workoutFullBodyAFocus => 'Knee, push, pull';

  @override
  String get workoutFullBodyB => 'Full body B';

  @override
  String get workoutFullBodyBFocus => 'Hip, overhead, pull-up';

  @override
  String get workoutFullBodyC => 'Full body C';

  @override
  String get workoutFullBodyCFocus => 'Single leg, push, pull';

  @override
  String get workoutIntensity => 'Intensity';

  @override
  String get workoutLegs => 'Legs';

  @override
  String get workoutLegsFocus => 'Quads, hamstrings, glutes';

  @override
  String get workoutLower => 'Lower body';

  @override
  String get workoutLowerFocus => 'Legs and core';

  @override
  String get workoutMinutes => 'Minutes';

  @override
  String get workoutPull => 'Pull';

  @override
  String get workoutPullFocus => 'Back, biceps, rear delts';

  @override
  String get workoutPush => 'Push';

  @override
  String get workoutPushFocus => 'Chest, shoulders, triceps';

  @override
  String get workoutReps => 'Reps';

  @override
  String get workoutRest => 'Rest';

  @override
  String workoutRestSeconds(int seconds) {
    return '${seconds}s';
  }

  @override
  String workoutRpe(String value) {
    return 'RPE $value';
  }

  @override
  String get workoutRpeBody =>
      'RPE 8 means: after the set you could have done two more clean reps. Pick the weight that makes that true — not the one that was in the plan last week.';

  @override
  String get workoutRpeTitle => 'Understanding RPE';

  @override
  String get workoutSets => 'Sets';

  @override
  String get workoutUpper => 'Upper body';

  @override
  String get workoutUpperFocus => 'Push and pull';

  @override
  String get workoutWorkingSets => 'Working sets';
}
