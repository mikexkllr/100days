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
    String emoji,
    String habit,
    int days,
    String milestone,
  ) {
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
      'The rule-based coach is running. It needs no model, works offline and answers instantly — the language is just less varied. Download a model below and it switches over by itself.';

  @override
  String get aiBackendPresent =>
      'The model runs on this phone with llama.cpp. It writes your daily line, estimates meals and proposes nutrition targets — and falls back to the rule-based coach whenever it is too slow.';

  @override
  String aiCoachStaysRuleBased(String model) {
    return '$model estimates meals and proposes nutrition targets — answers the app checks before you confirm them. The coach\'s daily line stays rule-based with it: in tests a model this small wandered off topic too often.';
  }

  @override
  String aiDeviceLine(String model, int ram) {
    return '$model · $ram GB RAM';
  }

  @override
  String get aiDeviceUnknown => 'Phone not recognised — assuming a modest one.';

  @override
  String get aiDeviceUnsupported =>
      'This phone cannot run a language model locally. The coach stays rule-based — it works just as well, it only talks with less variety.';

  @override
  String get aiDownloadFailed =>
      'The download stopped. Tap to continue where it left off.';

  @override
  String get aiDownloadNote =>
      'Best on Wi-Fi. Keeps running while you finish the setup; afterwards the model runs offline and nothing you type leaves the phone.';

  @override
  String aiDownloadNow(String size) {
    return 'Download now ($size GB)';
  }

  @override
  String get aiDownloadResume => 'Continue download';

  @override
  String aiDownloadThis(String size) {
    return 'Get · $size GB';
  }

  @override
  String aiDownloading(String received, String total) {
    return '$received of $total GB';
  }

  @override
  String get aiFits => 'fits';

  @override
  String aiGigabytes(String size) {
    return '$size GB';
  }

  @override
  String get aiInstalled => 'installed';

  @override
  String get aiLargerModels => 'Larger';

  @override
  String get aiLargerModelsSub =>
      'Fits this phone, but takes more storage and is slower to answer.';

  @override
  String get aiLoading => 'Loading …';

  @override
  String get aiModelBalancedDesc =>
      'Small and quick, good German and English. Estimates meals and proposes targets; the coach stays rule-based with it.';

  @override
  String get aiModelE2bMobileDesc =>
      'Google\'s phone model in its compact mobile cut, with 2-bit layers mixed in: half a gigabyte smaller than the full version, but noticeably rougher — in tests its meal estimates often missed.';

  @override
  String get aiModelLightDesc =>
      'The smallest, for phones nothing else fits. It helps little: the coach stays rule-based, and in tests its meal estimates mostly failed the plausibility check, so you will often enter meals yourself.';

  @override
  String get aiModelMaxDesc =>
      'The strongest model that runs on a phone, in its mobile cut. For flagships with 12 GB or more; takes longer to answer.';

  @override
  String get aiModelStrongDesc =>
      'Google\'s phone model, trained for 4-bit: close to full quality at 2.6 GB. Clearly better meal estimates and coaching; needs 8 GB of RAM.';

  @override
  String get aiNoAutoDownload =>
      'The app downloads a model only when you tap the button — from a fixed version on Hugging Face, checked against its SHA-256 before it is used. After that, no network.';

  @override
  String get aiNoNetworkBadge => 'no network access';

  @override
  String get aiNoRecommendation =>
      'This phone has little memory for a language model. The app works fully without one — the coach is rule-based, meals come from the food table. If you want to try anyway:';

  @override
  String get aiOneAtATime =>
      'Only one model stays on the phone: a new one replaces the old one once it has finished downloading.';

  @override
  String get aiOptionalModels => 'Optional';

  @override
  String get aiRecommended => 'recommended';

  @override
  String get aiRemove => 'Remove';

  @override
  String get aiSmallerModels => 'Smaller and quicker';

  @override
  String get aiSmallerModelsSub =>
      'Less storage and battery, quicker answers — the sentences get simpler.';

  @override
  String get aiSource => 'Source';

  @override
  String get aiSupportedModels => 'Supported models';

  @override
  String get aiSwitchSmaller => 'Switch to a smaller one';

  @override
  String get aiTitle => 'On-device AI';

  @override
  String get aiTooBig => 'too big';

  @override
  String get aiTooBigModels => 'Too big for this phone';

  @override
  String get aiTooBigModelsSub =>
      'Needs more memory than this phone has. It may load, or the system may close the app.';

  @override
  String get aiVerifying => 'Checking the file …';

  @override
  String get aiWhatItSeesBody =>
      'Streak, day number, your habits and whether your friends were active today — as text, straight to the model on this device. No network call, no telemetry, no copy in anyone’s cloud.';

  @override
  String get aiWhatItSeesTitle => 'What the model sees';

  @override
  String get appTitle => '100 Days';

  @override
  String get celebrateBonusCycle => 'CYCLE';

  @override
  String get celebrateBonusEvolution => 'EVOLVED';

  @override
  String get celebrateBonusLevel => 'LEVEL UP';

  @override
  String get celebrateBonusMilestone => 'MILESTONE';

  @override
  String get celebrateBonusPerfect => 'PERFECT';

  @override
  String get celebrateBonusRecord => 'RECORD';

  @override
  String get celebrateContinue => 'Keep burning';

  @override
  String celebrateHighlightCycle(int days) {
    return 'Cycle complete: $days days';
  }

  @override
  String celebrateHighlightEvolution(String stage) {
    return 'New form: $stage';
  }

  @override
  String celebrateHighlightLevel(int level) {
    return 'Level $level reached';
  }

  @override
  String celebrateHighlightMilestone(int day) {
    return 'Milestone: day $day';
  }

  @override
  String celebrateHighlightPerfect(int xp) {
    return 'Perfect day: +$xp XP bonus';
  }

  @override
  String celebrateHighlightRecord(int streak) {
    String _temp0 = intl.Intl.pluralLogic(
      streak,
      locale: localeName,
      other: '$streak days',
      one: '1 day',
    );
    return 'New record: $_temp0';
  }

  @override
  String get celebrateJackpot => 'JACKPOT!';

  @override
  String celebrateNextLevel(int level, int xp) {
    return 'Level $level in $xp XP';
  }

  @override
  String celebrateNextMilestone(int day, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return 'Day $day in $_temp0';
  }

  @override
  String get celebrateNextUp => 'Next up';

  @override
  String get celebrateReelBonus => 'BONUS';

  @override
  String get celebrateReelStreak => 'STREAK';

  @override
  String get celebrateReelXp => 'XP TODAY';

  @override
  String get celebrateShare => 'Brag about it';

  @override
  String celebrateShareText(int streak, int day) {
    String _temp0 = intl.Intl.pluralLogic(
      streak,
      locale: localeName,
      other: '🔥 $streak days streak',
      one: '🔥 1 day streak',
    );
    return '$_temp0, day $day of my challenge. Catch me if you can.';
  }

  @override
  String get celebrateSkip => 'Tap to skip';

  @override
  String get celebrateTitle => 'DAY COMPLETE!';

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
    String emoji,
    String name,
    int peerStreak,
    int streak,
  ) {
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
  String get diaryClose => 'Close the day';

  @override
  String get diaryCloseOnTarget => 'Close the day — on target';

  @override
  String get diaryClosedPlain => 'Day ticked off.';

  @override
  String get diaryClosedTracked =>
      'Day closed on target — tracked, with the plan bonus.';

  @override
  String diaryEatenOfTarget(int eaten, int target) {
    return '$eaten of $target kcal eaten';
  }

  @override
  String diaryEntryKcal(int kcal) {
    return '$kcal kcal';
  }

  @override
  String get diaryKcalLeft => 'kcal left';

  @override
  String get diaryKcalOver => 'kcal over';

  @override
  String diaryMealKcal(int eaten, int target) {
    return '$eaten / $target kcal';
  }

  @override
  String diaryOffTargetBody(int delta) {
    return 'You are $delta kcal off your target. You can still tick the day off — just without the plan bonus.';
  }

  @override
  String get diaryOffTargetConfirm => 'Tick off anyway';

  @override
  String get diaryOffTargetTitle => 'Not quite on target';

  @override
  String get diarySuggestions => 'IDEAS THAT FIT';

  @override
  String get diaryTitle => 'Food diary';

  @override
  String get diaryToday => 'Today';

  @override
  String get dietOmnivore => 'Everything';

  @override
  String get dietVegan => 'Vegan';

  @override
  String get dietVegetarian => 'Vegetarian';

  @override
  String get editorAddExercise => 'Add exercise';

  @override
  String get editorDaysNote =>
      'Applies from today — past days stay as they were.';

  @override
  String get editorMoveDown => 'Move down';

  @override
  String get editorMoveUp => 'Move up';

  @override
  String get editorRepsHigh => 'Reps, top of range';

  @override
  String get editorRepsLow => 'Reps, bottom of range';

  @override
  String get editorReset => 'Restore the suggestion';

  @override
  String get editorRest => 'Rest';

  @override
  String get editorRir => 'Reps in reserve (RIR)';

  @override
  String get editorRirHelp =>
      'RIR 2 means stopping two clean reps before failure. Lower is harder.';

  @override
  String get editorSaved => 'Training plan saved';

  @override
  String get editorSessionEmpty => 'No exercise yet — add one.';

  @override
  String get editorSessionsSubtitle =>
      'Tap an exercise to change sets, reps and effort, or to swap it.';

  @override
  String get editorSessionsTitle => 'Exercises per session';

  @override
  String get editorSets => 'Sets';

  @override
  String editorSetsReps(int sets, String reps, int rir) {
    return '$sets × $reps · RIR $rir';
  }

  @override
  String get editorSplitTitle => 'Split';

  @override
  String get editorSwap => 'Swap for';

  @override
  String get editorTitle => 'Edit training plan';

  @override
  String errorGeneric(String message) {
    return 'Error: $message';
  }

  @override
  String get evolutionCurrent => 'You are here';

  @override
  String get evolutionLocked => 'Locked';

  @override
  String get evolutionOpen => 'See all forms';

  @override
  String get evolutionSubtitle =>
      'Your streak decides the form. A break takes it back.';

  @override
  String get evolutionTitle => 'Flame evolution';

  @override
  String get evolutionUnlocked => 'Unlocked';

  @override
  String get exerciseAbWheel => 'Ab wheel';

  @override
  String get exerciseArnoldPress => 'Arnold press';

  @override
  String get exerciseAssistedPullup => 'Assisted pull-up';

  @override
  String get exerciseBackExtension => 'Back extension';

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
  String get exerciseCableCrunch => 'Cable crunch';

  @override
  String get exerciseCableCurl => 'Cable curl';

  @override
  String get exerciseCableFly => 'Cable fly';

  @override
  String get exerciseCableLateralRaise => 'Cable lateral raise';

  @override
  String get exerciseCableRow => 'Cable row';

  @override
  String get exerciseCalfRaise => 'Calf raise';

  @override
  String get exerciseChestPressMachine => 'Chest press machine';

  @override
  String get exerciseChestSupportedRow => 'Chest-supported row';

  @override
  String get exerciseChinUp => 'Chin-up';

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
  String get exerciseDbFly => 'Dumbbell fly';

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
  String get exerciseFrontSquat => 'Front squat';

  @override
  String get exerciseGluteBridge => 'Glute bridge';

  @override
  String get exerciseGobletSquat => 'Goblet squat';

  @override
  String get exerciseHackSquat => 'Hack squat';

  @override
  String get exerciseHammerCurl => 'Hammer curls';

  @override
  String get exerciseHangingLegRaise => 'Hanging leg raise';

  @override
  String get exerciseHipAbduction => 'Hip abduction machine';

  @override
  String get exerciseHipThrust => 'Hip thrust';

  @override
  String get exerciseInclineBench => 'Incline bench press';

  @override
  String get exerciseInclineDbPress => 'Incline dumbbell press';

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
  String get exerciseLegExtension => 'Leg extension';

  @override
  String get exerciseLegPress => 'Leg press';

  @override
  String get exerciseMachineShoulderPress => 'Shoulder press machine';

  @override
  String get exerciseNordicCurl => 'Nordic curl (assisted)';

  @override
  String get exerciseOhp => 'Overhead press (barbell)';

  @override
  String get exerciseOverheadTricepsExtension => 'Overhead triceps extension';

  @override
  String get exercisePecDeck => 'Pec deck';

  @override
  String get exercisePikePushup => 'Pike push-up';

  @override
  String get exercisePlank => 'Plank';

  @override
  String get exercisePreacherCurl => 'Preacher curl';

  @override
  String get exercisePullup => 'Pull-up';

  @override
  String get exercisePushup => 'Push-up';

  @override
  String get exerciseRdl => 'Romanian deadlift';

  @override
  String get exerciseRearDeltFly => 'Rear delt fly';

  @override
  String get exerciseRowingErg => 'Rowing machine';

  @override
  String get exerciseSeatedCalfRaise => 'Seated calf raise';

  @override
  String get exerciseSkullCrusher => 'Skull crusher';

  @override
  String get exerciseStepUp => 'Step-up';

  @override
  String get exerciseTBarRow => 'T-bar row';

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
  String feedWorkout(String name, String workout) {
    return '$name: $workout done';
  }

  @override
  String feedWorkoutDetail(int sets, String tonnes) {
    return '$sets sets · $tonnes t moved';
  }

  @override
  String foodAddAll(int count, int kcal) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Add $count entries · $kcal kcal',
      one: 'Add 1 entry · $kcal kcal',
    );
    return '$_temp0';
  }

  @override
  String foodAddTo(String meal) {
    return 'Add to $meal';
  }

  @override
  String foodAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries added',
      one: 'Added to the diary',
    );
    return '$_temp0';
  }

  @override
  String get foodAiFailed =>
      'The model could not make sense of that. Try simpler words, or enter it manually.';

  @override
  String get foodAiNotInstalled =>
      'Recognises foods from the table. With an on-device model (Settings → On-device AI) it also estimates dishes it does not know.';

  @override
  String get foodAmountLabel => 'Amount';

  @override
  String foodAmountPiece(int grams) {
    return '1 piece ($grams g)';
  }

  @override
  String foodAmountPortion(int grams) {
    return 'Portion ($grams g)';
  }

  @override
  String foodAmountResult(int kcal, int protein, int carbs, int fat) {
    return '$kcal kcal · $protein g protein · $carbs g carbs · $fat g fat';
  }

  @override
  String get foodAskAi => 'Estimate with AI';

  @override
  String get foodBarcodeLabel => 'Or type the barcode number (EAN)';

  @override
  String get foodBarcodeNoNutrition =>
      'Found the product, but without nutrition values. Enter it manually.';

  @override
  String get foodBarcodeNotFound =>
      'This product is not in Open Food Facts yet. Enter it manually — the numbers are on the label.';

  @override
  String get foodBarcodeOffline =>
      'No connection to Open Food Facts. Try again later or enter it manually.';

  @override
  String get foodBarcodePrivacy =>
      'The lookup sends only the barcode number to Open Food Facts, the open product database — no account, no diary, nothing about you.';

  @override
  String get foodDescribeHint =>
      'What did you eat? e.g. \"2 eggs, a slice of wholegrain bread and a cappuccino\"';

  @override
  String get foodManualAdd => 'Add';

  @override
  String get foodManualCarbs => 'Carbs in g (optional)';

  @override
  String get foodManualFat => 'Fat in g (optional)';

  @override
  String get foodManualGrams => 'Amount in g (optional)';

  @override
  String get foodManualKcal => 'Calories (kcal)';

  @override
  String get foodManualName => 'Name';

  @override
  String get foodManualProtein => 'Protein in g (optional)';

  @override
  String foodNotRecognised(String items) {
    return 'Not recognised: $items. Estimate them with AI, search for them, or enter them manually.';
  }

  @override
  String foodPer100(int kcal, int protein, int carbs, int fat) {
    return '$kcal kcal · $protein g P · $carbs g C · $fat g F per 100 g';
  }

  @override
  String get foodRecent => 'Recently logged';

  @override
  String get foodRecognise => 'Recognise';

  @override
  String get foodScanButton => 'Scan barcode';

  @override
  String get foodScanCameraUnavailable =>
      'The camera is not available. Type the barcode number instead.';

  @override
  String get foodScanHint => 'Hold the barcode inside the frame.';

  @override
  String get foodScanTitle => 'Scan a product';

  @override
  String get foodSearchHint => 'Food, e.g. oats, banana, pizza';

  @override
  String get foodSearchNothing =>
      'Nothing in the food table. Describe it instead, scan the barcode or enter the numbers yourself.';

  @override
  String get foodSourceAi => 'AI estimate';

  @override
  String get foodSourceBarcode => 'label';

  @override
  String get foodSourceDatabase => 'food table';

  @override
  String get foodSourceManual => 'entered';

  @override
  String get foodSourceParsed => 'recognised';

  @override
  String get foodTabBarcode => 'Barcode';

  @override
  String get foodTabDescribe => 'Describe';

  @override
  String get foodTabManual => 'Manual';

  @override
  String get foodTabSearch => 'Search';

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
      'Connections run directly between your devices — instantly on the same Wi-Fi, otherwise the next time you meet. Every connection proves who is on the other end, and only people you accepted get anything. No server in between that knows your streaks.';

  @override
  String get friendsNoActivity => 'No activity yet';

  @override
  String get friendsNudgeSection => 'Nudge';

  @override
  String get friendsNudgeSubtitle => 'These people have not been out today.';

  @override
  String get friendsRequestAccept => 'Accept';

  @override
  String get friendsRequestDecline => 'Decline';

  @override
  String friendsRequestFrom(String name) {
    return '$name';
  }

  @override
  String get friendsRequestsSub =>
      'They scanned your code. Nothing is shared until you accept.';

  @override
  String get friendsRequestsTitle => 'Wants to connect';

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
  String get goalsAiApply => 'Apply';

  @override
  String get goalsAiAsk => 'Get a proposal';

  @override
  String get goalsAiFailed =>
      'No usable proposal. Try putting it differently — or set the numbers yourself above.';

  @override
  String get goalsAiHint => 'e.g. \"fewer carbs, I train in the evening\"';

  @override
  String goalsAiProposal(int kcal, int protein, int carbs, int fat) {
    return '$kcal kcal · $protein % protein · $carbs % carbs · $fat % fat';
  }

  @override
  String get goalsAiSub =>
      'Describe what you want; the on-device model proposes new targets. Nothing changes until you apply it.';

  @override
  String get goalsAiTitle => 'Adjust with AI';

  @override
  String get goalsAiUnavailable =>
      'Needs an on-device model — set one up under Settings → On-device AI.';

  @override
  String get goalsBodySub =>
      'Only for the suggested target. They stay on this device and are never shared.';

  @override
  String get goalsBodyTitle => 'Body stats';

  @override
  String goalsFatRest(int percent) {
    return 'Fat: $percent % (the rest)';
  }

  @override
  String get goalsMacroTitle => 'Macro split';

  @override
  String get goalsOwnTarget => 'Set my own target';

  @override
  String get goalsOwnTargetSub =>
      'Your number wins. The suggestion stays visible next to it.';

  @override
  String get goalsSaved => 'Targets saved';

  @override
  String goalsSuggested(int kcal) {
    return 'Suggested: $kcal kcal a day';
  }

  @override
  String get goalsTargetTitle => 'Daily target';

  @override
  String get goalsTitle => 'Nutrition targets';

  @override
  String get goalsTooLow =>
      'That is more than 25% below your expenditure. Deficits that steep cost muscle and sleep — few people last 100 days on them.';

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
  String get habitWater => 'Water';

  @override
  String get habitWaterBlurb =>
      'Eight glasses. The cheapest thing you can do for yourself.';

  @override
  String get heatLess => 'less';

  @override
  String get heatMore => 'more';

  @override
  String heroBest(int days) {
    return 'Best: $days';
  }

  @override
  String heroCountdownFirst(String time) {
    return '$time left to light the first spark';
  }

  @override
  String heroCountdownSave(String time) {
    return '$time left to save your streak';
  }

  @override
  String get heroFedToday => 'Fed today. See you tomorrow.';

  @override
  String get heroFrozen => 'Frozen today. The streak holds.';

  @override
  String get heroRelapse => 'Relapse logged. Tomorrow is a fresh spark.';

  @override
  String get heroRestDay => 'Rest day. The streak waits.';

  @override
  String get heroThisWeek => 'This week';

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
  String get homeOpenDiary => 'Open the food diary';

  @override
  String get homeOptional => 'Optional';

  @override
  String get homeOptionalSubtitle =>
      'Not scheduled today — still counts as XP.';

  @override
  String get homeQuestsTitle => 'Today\'s quests';

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
  String homeStartWorkout(int percent) {
    return 'Start workout · +$percent % XP';
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
  String get homeWorkoutLogged => 'Logged today';

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
      'Only friends you connected yourself compete here — no strangers. XP comes per check-in, scaled by difficulty and streak, and tracked workouts and diary days count extra. On Sunday the top places move up and the bottom ones move down.';

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
  String get loggerAddSet => 'Add a set';

  @override
  String get loggerAdviceAddReps => 'Same weight, one more rep per set';

  @override
  String loggerAdviceAddWeight(String weight) {
    return 'Top of the range reached — go to $weight kg';
  }

  @override
  String loggerAdviceFirst(int rir) {
    return 'First time: pick a weight that leaves $rir reps in reserve';
  }

  @override
  String get loggerAdviceHold => 'Same weight — get every set into the range';

  @override
  String loggerAdviceReduce(String weight) {
    return 'Missed twice — reset to $weight kg and build back up';
  }

  @override
  String get loggerDiscard => 'Discard';

  @override
  String get loggerDiscardBody => 'The sets you entered will be lost.';

  @override
  String get loggerDiscardTitle => 'Discard this workout?';

  @override
  String get loggerFinish => 'Finish workout';

  @override
  String get loggerFinishNoSets => 'Tick off at least one set first.';

  @override
  String get loggerIntro =>
      'Log every set. Next time the app tells you what to beat: more reps at the same weight, then more weight.';

  @override
  String get loggerKg => 'kg';

  @override
  String loggerLastTime(String sets) {
    return 'Last time: $sets';
  }

  @override
  String get loggerReps => 'reps';

  @override
  String get loggerSaved => 'Workout saved — tracked, with the plan bonus.';

  @override
  String loggerSet(int number) {
    return 'Set $number';
  }

  @override
  String loggerTarget(String reps, int rir) {
    return 'Target: $reps reps · RIR $rir';
  }

  @override
  String get macroPresetAuto => 'Automatic';

  @override
  String get macroPresetAutoBlurb =>
      'Protein and fat per kilo of body weight, the rest carbs. The best default for training goals.';

  @override
  String get macroPresetBalanced => 'Balanced';

  @override
  String get macroPresetBalancedBlurb =>
      '50 % carbs, 20 % protein, 30 % fat — the classic split.';

  @override
  String get macroPresetCustom => 'Custom';

  @override
  String get macroPresetCustomBlurb =>
      'Set protein and carbs yourself; fat takes the rest.';

  @override
  String get macroPresetHighProtein => 'High protein';

  @override
  String get macroPresetHighProteinBlurb =>
      '35 % protein, 40 % carbs, 25 % fat. Keeps you full in a deficit.';

  @override
  String get macroPresetLowCarb => 'Low carb';

  @override
  String get macroPresetLowCarbBlurb => '30 % protein, 20 % carbs, 50 % fat.';

  @override
  String get mascotHappy1 => 'Fed. I\'m burning for you.';

  @override
  String get mascotHappy2 => 'Done. That\'s how legends are made.';

  @override
  String get mascotHappy3 => 'Another day in the bag. See you tomorrow.';

  @override
  String mascotHappy4(int streak) {
    String _temp0 = intl.Intl.pluralLogic(
      streak,
      locale: localeName,
      other: '$streak days',
      one: 'One day',
    );
    return '$_temp0. It\'s getting hot in here.';
  }

  @override
  String get mascotHappy5 => 'You did it. Again. I love that for us.';

  @override
  String get mascotHappy6 => 'Rest now. Tomorrow I\'m hungry again.';

  @override
  String get mascotHopeful1 => 'Every fire starts with a spark. Today?';

  @override
  String get mascotHopeful2 => 'I\'m just an ember. Make me a flame.';

  @override
  String get mascotHopeful3 => 'Zero is just a starting number.';

  @override
  String get mascotHopeful4 => 'One day. Then we\'ll talk.';

  @override
  String get mascotHungry1 => 'I\'m hungry. Feed me one day.';

  @override
  String get mascotHungry2 => 'Today counts. Only today.';

  @override
  String get mascotHungry3 => 'One tap and I grow. Your move.';

  @override
  String get mascotHungry4 => 'Your future self is watching. So am I.';

  @override
  String get mascotHungry5 => 'Show up. That\'s the whole trick.';

  @override
  String mascotHungry6(int day) {
    return 'Day $day. Let\'s make it count.';
  }

  @override
  String get mascotHyped1 => 'YES! You\'re on fire. Literally.';

  @override
  String get mascotHyped2 => 'Look at me burn!';

  @override
  String get mascotHyped3 => 'That\'s what I\'m talking about!';

  @override
  String get mascotHyped4 => 'Unstoppable. Same again tomorrow.';

  @override
  String get mascotName => 'Funki';

  @override
  String get mascotPoke1 => 'Hey! That tickles.';

  @override
  String get mascotPoke2 => 'Careful, hot!';

  @override
  String get mascotPoke3 => 'Again! 🔥';

  @override
  String get mascotPoke4 => 'Poke me less, check in more.';

  @override
  String get mascotPoke5 => 'I don\'t bite. I burn.';

  @override
  String get mascotPoke6 => 'Boop.';

  @override
  String get mascotPokeCombo => 'Okay, okay, I\'m burning already!';

  @override
  String get mascotSad1 => 'It happens. Honest beats perfect.';

  @override
  String get mascotSad2 => 'Down, not out. Tomorrow we go again.';

  @override
  String get mascotSad3 => 'I\'m small today. I\'ll be back.';

  @override
  String get mascotSemantics => 'Funki, your flame. Tap to poke.';

  @override
  String get mascotSleepy1 => 'Rest day. I\'m just glowing quietly.';

  @override
  String get mascotSleepy2 => 'Nothing scheduled. Recharging. Zzz.';

  @override
  String get mascotSleepy3 => 'Rest is part of the plan. The streak waits.';

  @override
  String mascotWorried1(int hours) {
    return 'Psst. $hours h left. I\'m getting cold.';
  }

  @override
  String mascotWorried2(int streak) {
    String _temp0 = intl.Intl.pluralLogic(
      streak,
      locale: localeName,
      other: '$streak days',
      one: 'One day',
    );
    return '$_temp0. Don\'t let me go out tonight.';
  }

  @override
  String get mascotWorried3 => 'Don\'t let me go out. Please?';

  @override
  String get mascotWorried4 => 'Midnight doesn\'t negotiate. You still can.';

  @override
  String get mascotWorried5 => 'I\'m flickering. That\'s not a good sign.';

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
  String get mealIdeaBreakfast5 => 'Tofu scramble with wholegrain bread';

  @override
  String get mealIdeaDinner1 => 'Turkey pan with courgette and feta';

  @override
  String get mealIdeaDinner2 => 'Omelette with mushrooms and spinach';

  @override
  String get mealIdeaDinner3 => 'Chickpea curry with natural yoghurt';

  @override
  String get mealIdeaDinner4 => 'Tuna salad with beans and egg';

  @override
  String get mealIdeaDinner5 => 'Bean and vegetable chili';

  @override
  String get mealIdeaDinner6 => 'Wholegrain wrap with chicken and salad';

  @override
  String get mealIdeaLunch1 => 'Chicken breast, rice, broccoli';

  @override
  String get mealIdeaLunch2 => 'Lentil bolognese with wholegrain pasta';

  @override
  String get mealIdeaLunch3 => 'Salmon fillet with potatoes and salad';

  @override
  String get mealIdeaLunch4 => 'Beef strips with couscous and roast vegetables';

  @override
  String get mealIdeaLunch5 => 'Tofu and vegetable stir-fry with rice';

  @override
  String get mealIdeaSnack1 => 'Quark with honey and walnuts';

  @override
  String get mealIdeaSnack2 => 'Protein shake with banana';

  @override
  String get mealIdeaSnack3 => 'A handful of almonds and an apple';

  @override
  String get mealIdeaSnack4 => 'Cottage cheese on crispbread';

  @override
  String get mealIdeaSnack5 => 'Hummus with vegetable sticks';

  @override
  String get mealIdeaSnack6 => 'Rice cakes with peanut butter';

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
  String get obAiEyebrow => 'Coach';

  @override
  String get obAiLater =>
      'Optional. Without a model everything works too — the coach is then rule-based. You can download it later under Settings → On-device AI.';

  @override
  String get obAiSubtitle =>
      'The coach and the meal estimates can run on a small language model — on this phone, offline, without any prompt leaving it. We picked the one that fits your phone.';

  @override
  String get obAiTitle => 'AI on your phone.';

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
  String get obKcalEyebrow => 'Nutrition';

  @override
  String get obKcalSubtitle =>
      'Computed from your numbers — or set your own. You can change both at any time.';

  @override
  String get obKcalTitle => 'Your daily target.';

  @override
  String obPlanBonus(int percent) {
    return '+$percent % XP';
  }

  @override
  String get obPlanNutrition => 'With nutrition plan';

  @override
  String get obPlanNutritionBody =>
      'A calorie target and a food diary with meal ideas. Optional — without it you just tick off the day.';

  @override
  String get obPlanTraining => 'With training plan';

  @override
  String get obPlanTrainingBody =>
      'Your own split and exercises, every set logged with progression tips. Optional — without it you just tick off the workout.';

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
  String get obPrivacyEyebrow => 'Privacy';

  @override
  String get obPrivacySubtitle =>
      'Only friends you connect yourself ever see anything — no strangers, no public profile. And of that, only what you switch on here.';

  @override
  String get obPrivacyTitle => 'Who sees what.';

  @override
  String obSetsAndMinutes(int sets, int minutes) {
    return '$sets sets · $minutes min';
  }

  @override
  String get obSexFemale => 'female';

  @override
  String get obSexMale => 'male';

  @override
  String get obSplitEyebrow => 'Training plan';

  @override
  String get obSplitSubtitle =>
      'Pick how your week is arranged. We suggest exercises for it — change any of them.';

  @override
  String get obSplitTitle => 'Your split.';

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
  String obSummaryBonusNutrition(int percent) {
    return 'Nutrition plan on: +$percent % XP for every day closed on target';
  }

  @override
  String get obSummaryBonusSection => 'Bonus';

  @override
  String obSummaryBonusTraining(int percent) {
    return 'Training plan on: +$percent % XP for every logged workout';
  }

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
  String get obSummaryPrivacyAllShared =>
      'All habits and your streak. Body stats and the food diary stay on this phone.';

  @override
  String get obSummaryPrivacySection => 'Shared with friends';

  @override
  String obSummaryPrivacySome(String habits) {
    return 'Your streak and habits — except $habits, which stays private. Body stats and the food diary stay on this phone.';
  }

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
  String get obTrainingNoPlanHint =>
      'Without a plan the app only counts whether you trained.';

  @override
  String obTrainingSplitHint(String split) {
    return 'Suggested for this: $split. You choose on the next page.';
  }

  @override
  String get obTrainingSubtitle =>
      'Training days count for the streak. With the training plan you also choose a split and your exercises on the next page.';

  @override
  String get obTrainingTitle => 'How often and with what?';

  @override
  String get obWelcomeEyebrow => '100 days and far beyond';

  @override
  String get obWelcomeMascot =>
      'Hi, I\'m Funki, your flame. Feed me one day at a time and watch me grow.';

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
  String get planEditTraining => 'Edit split and exercises';

  @override
  String get planEnableNutrition => 'Turn on the nutrition plan';

  @override
  String planEnableNutritionBody(int percent) {
    return 'Set a calorie target and keep a food diary — every day closed on target earns +$percent % XP.';
  }

  @override
  String get planEnableTraining => 'Turn on the training plan';

  @override
  String planEnableTrainingBody(int percent) {
    return 'Choose a split, adjust the exercises and log every set — each logged workout earns +$percent % XP.';
  }

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
  String get planNothingBody =>
      'Your habits need no plan — check them off on Today. Training, nutrition and abstinence habits get one here.';

  @override
  String get planNothingTitle => 'Nothing to plan';

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
  String get privacyAlwaysPrivate =>
      'Always private, no switch needed: body stats, calorie targets and the food diary. They are sealed in your own feed — friends store the encrypted bytes as a backup but cannot read them.';

  @override
  String get privacyFromNowOn =>
      'Changes apply from now on. What friends already received stays with them — a habit you make private disappears for new entries, not for old ones.';

  @override
  String get privacyHabitsSub =>
      'A private habit is invisible to friends — its check-ins and relapses too. Your streak for them counts the shared ones.';

  @override
  String get privacyHabitsTitle => 'Habits';

  @override
  String get privacyMoreTitle => 'More';

  @override
  String get privacyPrivate => 'Only you';

  @override
  String get privacySaved => 'Privacy settings saved';

  @override
  String get privacyShared => 'Friends see it';

  @override
  String get privacyStatement => 'Goal sentence';

  @override
  String get privacyStatementSub =>
      'Your goal in your own words, shown on your profile.';

  @override
  String get privacyTitle => 'Privacy';

  @override
  String get privacyWorkouts => 'Workout details';

  @override
  String get privacyWorkoutsSub =>
      'Session, sets and weights. Off: friends only see that you trained.';

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
    String habit,
    String target,
    int days,
    int streak,
  ) {
    return '- $habit: target $target, ${days}x per week, streak $streak';
  }

  @override
  String promptAdjustTargets(
    int kcal,
    int protein,
    int carbs,
    int fat,
    int tdee,
    String wish,
    int min,
    int max,
    String format,
  ) {
    return 'You are a nutrition coach. Current daily target: $kcal kcal, $protein g protein, $carbs g carbs, $fat g fat. Energy expenditure: $tdee kcal.\nThe user wants: \"$wish\"\n\nPropose new targets. Stay between $min and $max kcal and never more than 25% below the expenditure.\nAnswer with JSON only, exactly in this form, the reason in English:\n$format';
  }

  @override
  String promptAdjustments(
    int day,
    int total,
    int percent,
    String statement,
    String habits,
  ) {
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
    String peers,
  ) {
    return 'You are the coach in a 100-day challenge app. Write in English, second person.\n$persona\nTwo sentences at most. No emoji at the start of a line. No quotation marks.\n\nThe goal: \"$statement\"\nDay $day of $total (tier: $tier)\nCurrent streak: $streak days, longest: $longest\nDone today: $doneToday\nTime of day: $hour:00\n\nHabits:\n$habits\n\nFriends:\n$peers\n\nAnswer in exactly this format:\nTITLE: <at most 6 words>\nTEXT: <1-2 sentences>';
  }

  @override
  String promptFoodEstimate(String text, String format) {
    return 'You are a nutrition assistant. Estimate what this person ate:\n\"$text\"\n\nFor each food, estimate the total weight in grams (2 eggs are about 110 g, not 2) and the calories and macros of that whole amount.\nAnswer with JSON only, in this form, names in English:\n$format';
  }

  @override
  String promptHabitLine(String emoji, String habit, int streak, String unit) {
    return '- $emoji $habit: $streak $unit';
  }

  @override
  String promptMealIdeas(String meal, int kcal, int protein, String wish) {
    return 'Suggest 3 simple ideas for $meal with about $kcal kcal and at least $protein g protein each. Wish: $wish\nOne idea per line, at most 12 words each, with the estimated kcal at the end. In English. No numbering, no preamble.';
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
  String get setPrivacy => 'Privacy';

  @override
  String get setPrivacySub => 'What your friends see';

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
  String get splitBlurbBroSplit =>
      'Chest, back, legs, shoulders, arms — one muscle group per day. For five days or more.';

  @override
  String get splitBlurbFullBody =>
      'Every session hits everything. The best trade-off on two or three days.';

  @override
  String get splitBlurbPplUpperLower =>
      'Five sessions: PPL plus an upper and a lower day. Made for five days.';

  @override
  String get splitBlurbPushPullLegs =>
      'Pushing, pulling, legs — rotating. Strong on three or six days.';

  @override
  String get splitBlurbUpperLower =>
      'Upper body and legs alternate. Ideal on four days.';

  @override
  String get splitBroSplit => 'Body-part split';

  @override
  String get splitFullBody => 'Full body';

  @override
  String get splitPplUpperLower => 'Push / Pull / Legs + Upper / Lower';

  @override
  String get splitPushPullLegs => 'Push / Pull / Legs';

  @override
  String get splitRecommended => 'recommended';

  @override
  String get splitUpperLower => 'Upper / Lower';

  @override
  String get stageBlaze => 'Bonfire';

  @override
  String get stageBlue => 'Blue flame';

  @override
  String get stageEmber => 'Ember';

  @override
  String get stageFinal => 'Final form. Nothing left but to keep burning.';

  @override
  String get stageFlame => 'Flame';

  @override
  String get stageFlicker => 'Little flame';

  @override
  String stageFrom(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'From $days days',
      one: 'From 1 day',
      zero: 'No streak',
    );
    return '$_temp0';
  }

  @override
  String get stageGalaxy => 'Galaxy';

  @override
  String get stageInferno => 'Inferno';

  @override
  String stageNext(String stage, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return '$stage in $_temp0';
  }

  @override
  String get stageNova => 'Supernova';

  @override
  String get stagePlasma => 'Plasma';

  @override
  String get stageSpark => 'Spark';

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
  String get statsFlameTitle => 'Your flame';

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
  String get tileHoldHint => 'Hold';

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
  String get weekdayShortSat => 'Sa';

  @override
  String get weekdayShortSun => 'Su';

  @override
  String get weekdayShortThu => 'Th';

  @override
  String get weekdayShortTue => 'Tu';

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
  String get widgetCold => 'Light the first spark today.';

  @override
  String get widgetDone => 'Fed today ✓';

  @override
  String get widgetFrozen => 'Frozen. The streak is safe.';

  @override
  String get widgetGoesOutIn => 'Goes out in';

  @override
  String get widgetOpen => 'Feed me before midnight!';

  @override
  String get widgetPromoAction => 'Add widget';

  @override
  String get widgetPromoBody =>
      'See Funki every time you unlock your phone. Fed, hungry or about to go out.';

  @override
  String get widgetPromoManual =>
      'Long-press your home screen, tap Widgets and pick 100 Days.';

  @override
  String get widgetPromoTitle => 'Your streak on the home screen';

  @override
  String get widgetRest => 'Rest day. I\'m saving energy.';

  @override
  String get workoutArms => 'Arms';

  @override
  String get workoutArmsFocus => 'Biceps and triceps';

  @override
  String get workoutBack => 'Back';

  @override
  String get workoutBackFocus => 'Lats, upper back and biceps';

  @override
  String get workoutChest => 'Chest';

  @override
  String get workoutChestFocus => 'Chest and triceps';

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
  String workoutRir(int rir) {
    return 'RIR $rir';
  }

  @override
  String get workoutRpeBody =>
      'RIR 2 means: after the set you could have done two more clean reps. Pick the weight that makes that true — the logger then tells you each time whether to add reps or weight.';

  @override
  String get workoutRpeTitle => 'Understanding RIR';

  @override
  String get workoutSets => 'Sets';

  @override
  String get workoutShoulders => 'Shoulders';

  @override
  String get workoutShouldersFocus =>
      'All three heads of the shoulder, plus core';

  @override
  String get workoutStart => 'Start workout';

  @override
  String get workoutUpper => 'Upper body';

  @override
  String get workoutUpperFocus => 'Push and pull';

  @override
  String get workoutWorkingSets => 'Working sets';
}
