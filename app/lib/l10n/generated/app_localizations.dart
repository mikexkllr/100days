import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en')
  ];

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get actionConnect;

  /// No description provided for @actionCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get actionCopy;

  /// No description provided for @actionCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get actionCopyLink;

  /// No description provided for @actionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// No description provided for @actionNext.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get actionNext;

  /// No description provided for @actionRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get actionRemove;

  /// No description provided for @actionRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get actionRetry;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @actionSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get actionSend;

  /// No description provided for @actionSent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get actionSent;

  /// No description provided for @actionShare.
  ///
  /// In en, this message translates to:
  /// **'Share link'**
  String get actionShare;

  /// No description provided for @adviceCutScope.
  ///
  /// In en, this message translates to:
  /// **'You only hit {percent}% of your days. Take a habit out instead of carrying on failing — three certain days beat five planned ones.'**
  String adviceCutScope(int percent);

  /// No description provided for @adviceHalveTarget.
  ///
  /// In en, this message translates to:
  /// **'{emoji} {habit} is not happening. Halve the target until it sticks again.'**
  String adviceHalveTarget(String emoji, String habit);

  /// No description provided for @adviceInviteSomeone.
  ///
  /// In en, this message translates to:
  /// **'You have not connected anyone yet. Going it alone is measurably harder — invite someone.'**
  String get adviceInviteSomeone;

  /// No description provided for @adviceMilestoneAhead.
  ///
  /// In en, this message translates to:
  /// **'{emoji} {habit}: {days, plural, =1{1 day} other{{days} days}} until \"{milestone}\".'**
  String adviceMilestoneAhead(
      String emoji, String habit, int days, String milestone);

  /// No description provided for @adviceRaiseTarget.
  ///
  /// In en, this message translates to:
  /// **'{emoji} {habit} has been running for {days} days. Raise the daily target by 20%.'**
  String adviceRaiseTarget(String emoji, String habit, int days);

  /// No description provided for @aiBackendMissing.
  ///
  /// In en, this message translates to:
  /// **'The rule-based coach is running. It needs no model, works offline and answers instantly — the language is just less varied.'**
  String get aiBackendMissing;

  /// No description provided for @aiBackendPresent.
  ///
  /// In en, this message translates to:
  /// **'An inference engine is wired in. With a model installed it writes your daily line.'**
  String get aiBackendPresent;

  /// No description provided for @aiGigabytes.
  ///
  /// In en, this message translates to:
  /// **'{size} GB'**
  String aiGigabytes(String size);

  /// No description provided for @aiInstallBody.
  ///
  /// In en, this message translates to:
  /// **'Download the GGUF file on a computer and put it in this folder:'**
  String get aiInstallBody;

  /// No description provided for @aiInstallTitle.
  ///
  /// In en, this message translates to:
  /// **'Installing a model'**
  String get aiInstallTitle;

  /// No description provided for @aiInstalled.
  ///
  /// In en, this message translates to:
  /// **'installed'**
  String get aiInstalled;

  /// No description provided for @aiLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading …'**
  String get aiLoading;

  /// No description provided for @aiModelGemmaDesc.
  ///
  /// In en, this message translates to:
  /// **'A little stronger in German, needs more RAM.'**
  String get aiModelGemmaDesc;

  /// No description provided for @aiModelQwenDesc.
  ///
  /// In en, this message translates to:
  /// **'A good balance of quality and size. Runs on mid-range devices.'**
  String get aiModelQwenDesc;

  /// No description provided for @aiModelSmolDesc.
  ///
  /// In en, this message translates to:
  /// **'Tiny and fast, for older devices.'**
  String get aiModelSmolDesc;

  /// No description provided for @aiNoAutoDownload.
  ///
  /// In en, this message translates to:
  /// **'The app never downloads anything by itself — a gigabyte over mobile data is not something that should happen unasked.'**
  String get aiNoAutoDownload;

  /// No description provided for @aiNoNetworkBadge.
  ///
  /// In en, this message translates to:
  /// **'no network access'**
  String get aiNoNetworkBadge;

  /// No description provided for @aiSource.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get aiSource;

  /// No description provided for @aiSupportedModels.
  ///
  /// In en, this message translates to:
  /// **'Supported models'**
  String get aiSupportedModels;

  /// No description provided for @aiTitle.
  ///
  /// In en, this message translates to:
  /// **'On-device AI'**
  String get aiTitle;

  /// No description provided for @aiWhatItSeesBody.
  ///
  /// In en, this message translates to:
  /// **'Streak, day number, your habits and whether your friends were active today — as text, straight to the model on this device. No network call, no telemetry, no copy in anyone’s cloud.'**
  String get aiWhatItSeesBody;

  /// No description provided for @aiWhatItSeesTitle.
  ///
  /// In en, this message translates to:
  /// **'What the model sees'**
  String get aiWhatItSeesTitle;

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'100 Days'**
  String get appTitle;

  /// No description provided for @cheerRespectStreak.
  ///
  /// In en, this message translates to:
  /// **'{streak, plural, =1{Respect, 1 day!} other{Respect, {streak} days!}}'**
  String cheerRespectStreak(int streak);

  /// No description provided for @coachBadgeLlm.
  ///
  /// In en, this message translates to:
  /// **'on-device AI'**
  String get coachBadgeLlm;

  /// No description provided for @coachBadgeRule.
  ///
  /// In en, this message translates to:
  /// **'Coach'**
  String get coachBadgeRule;

  /// No description provided for @coachCelebrateGeneric.
  ///
  /// In en, this message translates to:
  /// **'{day} days in a row. That is the evidence, not the feeling.'**
  String coachCelebrateGeneric(int day);

  /// No description provided for @coachCelebrateHabitFormed.
  ///
  /// In en, this message translates to:
  /// **'66 days — the average it takes for a behaviour to run automatically. You are through.'**
  String get coachCelebrateHabitFormed;

  /// No description provided for @coachCelebrateHundred.
  ///
  /// In en, this message translates to:
  /// **'A hundred days. And now comes the part this app was built for: it does not stop here. Welcome to \"{tier}\".'**
  String coachCelebrateHundred(String tier);

  /// No description provided for @coachCelebrateMonth.
  ///
  /// In en, this message translates to:
  /// **'30 days. From now on you have to talk yourself into it less.'**
  String get coachCelebrateMonth;

  /// No description provided for @coachCelebrateWeek.
  ///
  /// In en, this message translates to:
  /// **'One week. Most people stop exactly here.'**
  String get coachCelebrateWeek;

  /// No description provided for @coachCelebrateYear.
  ///
  /// In en, this message translates to:
  /// **'A year. This is not a challenge any more, this is you.'**
  String get coachCelebrateYear;

  /// No description provided for @coachEngineModel.
  ///
  /// In en, this message translates to:
  /// **'{model} (on-device)'**
  String coachEngineModel(String model);

  /// No description provided for @coachEngineRuleBased.
  ///
  /// In en, this message translates to:
  /// **'Rule-based (on-device)'**
  String get coachEngineRuleBased;

  /// No description provided for @coachHeadAtStake.
  ///
  /// In en, this message translates to:
  /// **'{streak, plural, =1{1 day is at stake} other{{streak} days are at stake}}'**
  String coachHeadAtStake(int streak);

  /// No description provided for @coachHeadCelebrate.
  ///
  /// In en, this message translates to:
  /// **'Day {day} 🎉'**
  String coachHeadCelebrate(int day);

  /// No description provided for @coachHeadDayOf.
  ///
  /// In en, this message translates to:
  /// **'Day {day} of {total}'**
  String coachHeadDayOf(int day, int total);

  /// No description provided for @coachHeadDayStillOpen.
  ///
  /// In en, this message translates to:
  /// **'Today is still open'**
  String get coachHeadDayStillOpen;

  /// No description provided for @coachHeadFriendActive.
  ///
  /// In en, this message translates to:
  /// **'{name} was already out today'**
  String coachHeadFriendActive(String name);

  /// No description provided for @coachHeadFriendsActive.
  ///
  /// In en, this message translates to:
  /// **'{count} of your people were already out today'**
  String coachHeadFriendsActive(int count);

  /// No description provided for @coachHeadLastChance.
  ///
  /// In en, this message translates to:
  /// **'Last chance'**
  String get coachHeadLastChance;

  /// No description provided for @coachHeadLeaderAhead.
  ///
  /// In en, this message translates to:
  /// **'{name} is ahead of you'**
  String coachHeadLeaderAhead(String name);

  /// No description provided for @coachHeadNewDayOne.
  ///
  /// In en, this message translates to:
  /// **'A new day 1'**
  String get coachHeadNewDayOne;

  /// No description provided for @coachHeadStreak.
  ///
  /// In en, this message translates to:
  /// **'{streak, plural, =1{1 day streak} other{{streak} days streak}}'**
  String coachHeadStreak(int streak);

  /// No description provided for @coachHeadTooSmooth.
  ///
  /// In en, this message translates to:
  /// **'{streak, plural, =1{1 day — too smooth} other{{streak} days — this is going too smoothly}}'**
  String coachHeadTooSmooth(int streak);

  /// No description provided for @coachHintAlcoholPattern.
  ///
  /// In en, this message translates to:
  /// **'Write down where you were and who with. The pattern matters more than the one evening.'**
  String get coachHintAlcoholPattern;

  /// No description provided for @coachHintDigitalTrigger.
  ///
  /// In en, this message translates to:
  /// **'Phone out of the bedroom tonight. That is the trigger, not your willpower.'**
  String get coachHintDigitalTrigger;

  /// No description provided for @coachHintSmallestVersion.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow, the smallest possible version. Just not zero.'**
  String get coachHintSmallestVersion;

  /// No description provided for @coachHintSugarBreakfast.
  ///
  /// In en, this message translates to:
  /// **'More protein at breakfast. Cravings are usually a breakfast problem.'**
  String get coachHintSugarBreakfast;

  /// No description provided for @coachNamesMore.
  ///
  /// In en, this message translates to:
  /// **'{names} and {count} others'**
  String coachNamesMore(String names, int count);

  /// No description provided for @coachNamesTwo.
  ///
  /// In en, this message translates to:
  /// **'{first} and {second}'**
  String coachNamesTwo(String first, String second);

  /// No description provided for @coachPressureHoursLeft.
  ///
  /// In en, this message translates to:
  /// **'{names} were already out today. You are still on zero. In two hours the day is over.'**
  String coachPressureHoursLeft(String names);

  /// No description provided for @coachPressureLeaderBody.
  ///
  /// In en, this message translates to:
  /// **'{emoji} {name}: {peerStreak} days. You: {streak}. Still catchable — today.'**
  String coachPressureLeaderBody(
      String emoji, String name, int peerStreak, int streak);

  /// No description provided for @coachPressureLeaveIt.
  ///
  /// In en, this message translates to:
  /// **'{names} were already out today. You are still on zero. Going to leave it like that?'**
  String coachPressureLeaveIt(String names);

  /// No description provided for @coachPressureTheySee.
  ///
  /// In en, this message translates to:
  /// **'{names} were already out today. You are still on zero. They can see your feed too.'**
  String coachPressureTheySee(String names);

  /// No description provided for @coachPressureYouLead.
  ///
  /// In en, this message translates to:
  /// **'You are in front right now. Leading means not being the first to quit.'**
  String get coachPressureYouLead;

  /// No description provided for @coachRaiseBarHarder.
  ///
  /// In en, this message translates to:
  /// **'You hit {percent}% of your days. Time to make the goal harder: one more day a week, or a higher daily target.'**
  String coachRaiseBarHarder(int percent);

  /// No description provided for @coachRaiseBarNoEffort.
  ///
  /// In en, this message translates to:
  /// **'You hit {percent}% of your days. Habits that cost no effort stop producing any. Raise a number.'**
  String coachRaiseBarNoEffort(int percent);

  /// No description provided for @coachRaiseBarSecondFront.
  ///
  /// In en, this message translates to:
  /// **'You hit {percent}% of your days. Take on a second front. You have the capacity.'**
  String coachRaiseBarSecondFront(int percent);

  /// No description provided for @coachRecoverRelapse.
  ///
  /// In en, this message translates to:
  /// **'Relapse on {habit}. That is part of the curve, not the end of it. {hint}'**
  String coachRecoverRelapse(String habit, String hint);

  /// No description provided for @coachRecoverStreakLost.
  ///
  /// In en, this message translates to:
  /// **'The streak is gone, the 100 days are not. The difference between a relapse and quitting is exactly what you do in the next 24 hours.'**
  String get coachRecoverStreakLost;

  /// No description provided for @coachSteadyMilestoneConsistency.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{One more day until day {milestone}.} other{{days} more days until day {milestone}.}} Consistency beats intensity. Always.'**
  String coachSteadyMilestoneConsistency(int days, int milestone);

  /// No description provided for @coachSteadyMilestoneNothingSpectacular.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{One more day until day {milestone}.} other{{days} more days until day {milestone}.}} Nothing spectacular required — just do not stop.'**
  String coachSteadyMilestoneNothingSpectacular(int days, int milestone);

  /// No description provided for @coachSteadyMilestonePlanWorks.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{One more day until day {milestone}.} other{{days} more days until day {milestone}.}} The plan works as long as you do it.'**
  String coachSteadyMilestonePlanWorks(int days, int milestone);

  /// No description provided for @coachSteadyRunning.
  ///
  /// In en, this message translates to:
  /// **'Running. Same as yesterday.'**
  String get coachSteadyRunning;

  /// No description provided for @coachUrgentLastChance.
  ///
  /// In en, this message translates to:
  /// **'{hours, plural, =1{One hour left.} other{{hours} hours left.}} {streak} days of work against a few minutes. Do the maths.'**
  String coachUrgentLastChance(int hours, int streak);

  /// No description provided for @coachUrgentSmallestVersion.
  ///
  /// In en, this message translates to:
  /// **'The day is nearly over and nothing is logged. Do the smallest version of it — it counts the same.'**
  String get coachUrgentSmallestVersion;

  /// No description provided for @coachWelcomeCheckOff.
  ///
  /// In en, this message translates to:
  /// **'The beginning is the easiest part and the most important one. One thing today: tick it off.'**
  String get coachWelcomeCheckOff;

  /// No description provided for @coachWelcomeNobodySees.
  ///
  /// In en, this message translates to:
  /// **'Nobody sees day {day}. Everyone sees day 100. One does not happen without the other.'**
  String coachWelcomeNobodySees(int day);

  /// No description provided for @coachWelcomeYourWords.
  ///
  /// In en, this message translates to:
  /// **'You told yourself: \"{statement}\". Today you turn that into the first piece of evidence.'**
  String coachWelcomeYourWords(String statement);

  /// No description provided for @ctaAdjustGoal.
  ///
  /// In en, this message translates to:
  /// **'Adjust the goal'**
  String get ctaAdjustGoal;

  /// No description provided for @ctaCheckInNow.
  ///
  /// In en, this message translates to:
  /// **'Check in now'**
  String get ctaCheckInNow;

  /// No description provided for @ctaKeepGoing.
  ///
  /// In en, this message translates to:
  /// **'Keep going'**
  String get ctaKeepGoing;

  /// No description provided for @ctaRescue.
  ///
  /// In en, this message translates to:
  /// **'Rescue it'**
  String get ctaRescue;

  /// No description provided for @ctaRestart.
  ///
  /// In en, this message translates to:
  /// **'Start over'**
  String get ctaRestart;

  /// No description provided for @ctaShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get ctaShare;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String errorGeneric(String message);

  /// No description provided for @exerciseAbWheel.
  ///
  /// In en, this message translates to:
  /// **'Ab wheel'**
  String get exerciseAbWheel;

  /// No description provided for @exerciseBackSquat.
  ///
  /// In en, this message translates to:
  /// **'Back squat (barbell)'**
  String get exerciseBackSquat;

  /// No description provided for @exerciseBandPulldown.
  ///
  /// In en, this message translates to:
  /// **'Band pulldown'**
  String get exerciseBandPulldown;

  /// No description provided for @exerciseBarbellRow.
  ///
  /// In en, this message translates to:
  /// **'Barbell row'**
  String get exerciseBarbellRow;

  /// No description provided for @exerciseBenchPress.
  ///
  /// In en, this message translates to:
  /// **'Bench press'**
  String get exerciseBenchPress;

  /// No description provided for @exerciseBicepsCurl.
  ///
  /// In en, this message translates to:
  /// **'Biceps curls'**
  String get exerciseBicepsCurl;

  /// No description provided for @exerciseBulgarianSplitSquat.
  ///
  /// In en, this message translates to:
  /// **'Bulgarian split squat'**
  String get exerciseBulgarianSplitSquat;

  /// No description provided for @exerciseBurpee.
  ///
  /// In en, this message translates to:
  /// **'Burpees'**
  String get exerciseBurpee;

  /// No description provided for @exerciseBwSquat.
  ///
  /// In en, this message translates to:
  /// **'Bodyweight squat'**
  String get exerciseBwSquat;

  /// No description provided for @exerciseCableRow.
  ///
  /// In en, this message translates to:
  /// **'Cable row'**
  String get exerciseCableRow;

  /// No description provided for @exerciseCalfRaise.
  ///
  /// In en, this message translates to:
  /// **'Calf raise'**
  String get exerciseCalfRaise;

  /// No description provided for @exerciseCueBackSquat.
  ///
  /// In en, this message translates to:
  /// **'Chest up, knees over toes, controlled on the way down.'**
  String get exerciseCueBackSquat;

  /// No description provided for @exerciseCueBenchPress.
  ///
  /// In en, this message translates to:
  /// **'Shoulder blades together, bar to the lower chest.'**
  String get exerciseCueBenchPress;

  /// No description provided for @exerciseCueBwSquat.
  ///
  /// In en, this message translates to:
  /// **'Slow on the way down, brief pause at the bottom.'**
  String get exerciseCueBwSquat;

  /// No description provided for @exerciseCueDeadlift.
  ///
  /// In en, this message translates to:
  /// **'Flat back, bar travels along the shin.'**
  String get exerciseCueDeadlift;

  /// No description provided for @exerciseCueGobletSquat.
  ///
  /// In en, this message translates to:
  /// **'Dumbbell at the chest, deep and upright.'**
  String get exerciseCueGobletSquat;

  /// No description provided for @exerciseCuePullup.
  ///
  /// In en, this message translates to:
  /// **'Shoulders down, chest to the bar.'**
  String get exerciseCuePullup;

  /// No description provided for @exerciseCuePushup.
  ///
  /// In en, this message translates to:
  /// **'Body stays a plank, elbows at 45 degrees.'**
  String get exerciseCuePushup;

  /// No description provided for @exerciseCueRdl.
  ///
  /// In en, this message translates to:
  /// **'Hips back, feel the stretch in the hamstrings.'**
  String get exerciseCueRdl;

  /// No description provided for @exerciseDbBench.
  ///
  /// In en, this message translates to:
  /// **'Dumbbell bench press'**
  String get exerciseDbBench;

  /// No description provided for @exerciseDbOhp.
  ///
  /// In en, this message translates to:
  /// **'Overhead press (dumbbell)'**
  String get exerciseDbOhp;

  /// No description provided for @exerciseDbRow.
  ///
  /// In en, this message translates to:
  /// **'Dumbbell row'**
  String get exerciseDbRow;

  /// No description provided for @exerciseDeadBug.
  ///
  /// In en, this message translates to:
  /// **'Dead bug'**
  String get exerciseDeadBug;

  /// No description provided for @exerciseDeadlift.
  ///
  /// In en, this message translates to:
  /// **'Deadlift'**
  String get exerciseDeadlift;

  /// No description provided for @exerciseDiamondPushup.
  ///
  /// In en, this message translates to:
  /// **'Diamond push-up'**
  String get exerciseDiamondPushup;

  /// No description provided for @exerciseDip.
  ///
  /// In en, this message translates to:
  /// **'Dips'**
  String get exerciseDip;

  /// No description provided for @exerciseFacePull.
  ///
  /// In en, this message translates to:
  /// **'Face pull'**
  String get exerciseFacePull;

  /// No description provided for @exerciseFarmersWalk.
  ///
  /// In en, this message translates to:
  /// **'Farmer\'s walk'**
  String get exerciseFarmersWalk;

  /// No description provided for @exerciseGluteBridge.
  ///
  /// In en, this message translates to:
  /// **'Glute bridge'**
  String get exerciseGluteBridge;

  /// No description provided for @exerciseGobletSquat.
  ///
  /// In en, this message translates to:
  /// **'Goblet squat'**
  String get exerciseGobletSquat;

  /// No description provided for @exerciseHammerCurl.
  ///
  /// In en, this message translates to:
  /// **'Hammer curls'**
  String get exerciseHammerCurl;

  /// No description provided for @exerciseHangingLegRaise.
  ///
  /// In en, this message translates to:
  /// **'Hanging leg raise'**
  String get exerciseHangingLegRaise;

  /// No description provided for @exerciseHipThrust.
  ///
  /// In en, this message translates to:
  /// **'Hip thrust'**
  String get exerciseHipThrust;

  /// No description provided for @exerciseInvertedRow.
  ///
  /// In en, this message translates to:
  /// **'Inverted row'**
  String get exerciseInvertedRow;

  /// No description provided for @exerciseJumpRope.
  ///
  /// In en, this message translates to:
  /// **'Jump rope'**
  String get exerciseJumpRope;

  /// No description provided for @exerciseKbSwing.
  ///
  /// In en, this message translates to:
  /// **'Kettlebell swing'**
  String get exerciseKbSwing;

  /// No description provided for @exerciseLatPulldown.
  ///
  /// In en, this message translates to:
  /// **'Lat pulldown'**
  String get exerciseLatPulldown;

  /// No description provided for @exerciseLateralRaise.
  ///
  /// In en, this message translates to:
  /// **'Lateral raise'**
  String get exerciseLateralRaise;

  /// No description provided for @exerciseLegCurl.
  ///
  /// In en, this message translates to:
  /// **'Leg curl'**
  String get exerciseLegCurl;

  /// No description provided for @exerciseLegPress.
  ///
  /// In en, this message translates to:
  /// **'Leg press'**
  String get exerciseLegPress;

  /// No description provided for @exerciseNordicCurl.
  ///
  /// In en, this message translates to:
  /// **'Nordic curl (assisted)'**
  String get exerciseNordicCurl;

  /// No description provided for @exerciseOhp.
  ///
  /// In en, this message translates to:
  /// **'Overhead press (barbell)'**
  String get exerciseOhp;

  /// No description provided for @exercisePikePushup.
  ///
  /// In en, this message translates to:
  /// **'Pike push-up'**
  String get exercisePikePushup;

  /// No description provided for @exercisePlank.
  ///
  /// In en, this message translates to:
  /// **'Plank'**
  String get exercisePlank;

  /// No description provided for @exercisePullup.
  ///
  /// In en, this message translates to:
  /// **'Pull-up'**
  String get exercisePullup;

  /// No description provided for @exercisePushup.
  ///
  /// In en, this message translates to:
  /// **'Push-up'**
  String get exercisePushup;

  /// No description provided for @exerciseRdl.
  ///
  /// In en, this message translates to:
  /// **'Romanian deadlift'**
  String get exerciseRdl;

  /// No description provided for @exerciseRowingErg.
  ///
  /// In en, this message translates to:
  /// **'Rowing machine'**
  String get exerciseRowingErg;

  /// No description provided for @exerciseStepUp.
  ///
  /// In en, this message translates to:
  /// **'Step-up'**
  String get exerciseStepUp;

  /// No description provided for @exerciseTricepsPushdown.
  ///
  /// In en, this message translates to:
  /// **'Triceps pushdown'**
  String get exerciseTricepsPushdown;

  /// No description provided for @exerciseWalkingLunge.
  ///
  /// In en, this message translates to:
  /// **'Walking lunges'**
  String get exerciseWalkingLunge;

  /// No description provided for @feedAscended.
  ///
  /// In en, this message translates to:
  /// **'{name} moved up a tier'**
  String feedAscended(String name);

  /// No description provided for @feedAscendedDetail.
  ///
  /// In en, this message translates to:
  /// **'New tier: {tier}'**
  String feedAscendedDetail(String tier);

  /// No description provided for @feedBackfilled.
  ///
  /// In en, this message translates to:
  /// **'backfilled for {date}'**
  String feedBackfilled(String date);

  /// No description provided for @feedBackfilledBadge.
  ///
  /// In en, this message translates to:
  /// **'backfilled'**
  String get feedBackfilledBadge;

  /// No description provided for @feedCheckIn.
  ///
  /// In en, this message translates to:
  /// **'{name}: {habit} done'**
  String feedCheckIn(String name, String habit);

  /// No description provided for @feedCheer.
  ///
  /// In en, this message translates to:
  /// **'Cheer'**
  String get feedCheer;

  /// No description provided for @feedCheerReceived.
  ///
  /// In en, this message translates to:
  /// **'{name} is cheering you on'**
  String feedCheerReceived(String name);

  /// No description provided for @feedCheerSent.
  ///
  /// In en, this message translates to:
  /// **'You cheered {name}'**
  String feedCheerSent(String name);

  /// No description provided for @feedCheered.
  ///
  /// In en, this message translates to:
  /// **'Cheered'**
  String get feedCheered;

  /// No description provided for @feedEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'As soon as you or your friends tick something off it shows up here — signed and checkable.'**
  String get feedEmptyBody;

  /// No description provided for @feedEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing in the feed yet'**
  String get feedEmptyTitle;

  /// No description provided for @feedNudgeReceived.
  ///
  /// In en, this message translates to:
  /// **'{name} is nudging you'**
  String feedNudgeReceived(String name);

  /// No description provided for @feedNudgeSent.
  ///
  /// In en, this message translates to:
  /// **'You nudged {name}'**
  String feedNudgeSent(String name);

  /// No description provided for @feedRelapse.
  ///
  /// In en, this message translates to:
  /// **'{name} had a relapse on {habit}'**
  String feedRelapse(String name, String habit);

  /// No description provided for @feedSomeone.
  ///
  /// In en, this message translates to:
  /// **'someone'**
  String get feedSomeone;

  /// No description provided for @feedStarted.
  ///
  /// In en, this message translates to:
  /// **'{name} started the challenge'**
  String feedStarted(String name);

  /// No description provided for @feedStreakDetail.
  ///
  /// In en, this message translates to:
  /// **'{streak, plural, =1{1 day streak} other{{streak} days streak}}'**
  String feedStreakDetail(int streak);

  /// No description provided for @feedVerified.
  ///
  /// In en, this message translates to:
  /// **'verified'**
  String get feedVerified;

  /// No description provided for @friendsConnected.
  ///
  /// In en, this message translates to:
  /// **'{name} connected.'**
  String friendsConnected(String name);

  /// No description provided for @friendsDayNumber.
  ///
  /// In en, this message translates to:
  /// **'Day {day}'**
  String friendsDayNumber(int day);

  /// No description provided for @friendsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'The app works alone — but it only bites once someone is watching. Show a friend your QR code.'**
  String get friendsEmptyBody;

  /// No description provided for @friendsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nobody connected yet'**
  String get friendsEmptyTitle;

  /// No description provided for @friendsFallbackName.
  ///
  /// In en, this message translates to:
  /// **'Friend'**
  String get friendsFallbackName;

  /// No description provided for @friendsInvite.
  ///
  /// In en, this message translates to:
  /// **'Invite'**
  String get friendsInvite;

  /// No description provided for @friendsInviteInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid invite: {message}'**
  String friendsInviteInvalid(String message);

  /// No description provided for @friendsNetworkNote.
  ///
  /// In en, this message translates to:
  /// **'Connections run directly between your devices — instantly on the same Wi-Fi, otherwise the next time you meet. No server in between that knows your streaks.'**
  String get friendsNetworkNote;

  /// No description provided for @friendsNoActivity.
  ///
  /// In en, this message translates to:
  /// **'No activity yet'**
  String get friendsNoActivity;

  /// No description provided for @friendsNudgeSection.
  ///
  /// In en, this message translates to:
  /// **'Nudge'**
  String get friendsNudgeSection;

  /// No description provided for @friendsNudgeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'These people have not been out today.'**
  String get friendsNudgeSubtitle;

  /// No description provided for @friendsScan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get friendsScan;

  /// No description provided for @friendsYourPeople.
  ///
  /// In en, this message translates to:
  /// **'Your people'**
  String get friendsYourPeople;

  /// No description provided for @goalBuildMuscle.
  ///
  /// In en, this message translates to:
  /// **'Build muscle'**
  String get goalBuildMuscle;

  /// No description provided for @goalBuildMusclePitch.
  ///
  /// In en, this message translates to:
  /// **'Get heavier, get stronger. Plan, protein, progression.'**
  String get goalBuildMusclePitch;

  /// No description provided for @goalClarity.
  ///
  /// In en, this message translates to:
  /// **'Clear your head'**
  String get goalClarity;

  /// No description provided for @goalClarityPitch.
  ///
  /// In en, this message translates to:
  /// **'Dopamine down, focus up. Less stimulus, more substance.'**
  String get goalClarityPitch;

  /// No description provided for @goalCustom.
  ///
  /// In en, this message translates to:
  /// **'Your own goal'**
  String get goalCustom;

  /// No description provided for @goalCustomPitch.
  ///
  /// In en, this message translates to:
  /// **'You know what is due. Build yourself the plan.'**
  String get goalCustomPitch;

  /// No description provided for @goalDiscipline.
  ///
  /// In en, this message translates to:
  /// **'Build discipline'**
  String get goalDiscipline;

  /// No description provided for @goalDisciplinePitch.
  ///
  /// In en, this message translates to:
  /// **'100 days, not up for negotiation. The streak is the goal.'**
  String get goalDisciplinePitch;

  /// No description provided for @goalGetFit.
  ///
  /// In en, this message translates to:
  /// **'Get fit'**
  String get goalGetFit;

  /// No description provided for @goalGetFitPitch.
  ///
  /// In en, this message translates to:
  /// **'Conditioning, strength, mobility. Back in shape.'**
  String get goalGetFitPitch;

  /// No description provided for @goalLoseFat.
  ///
  /// In en, this message translates to:
  /// **'Lose fat'**
  String get goalLoseFat;

  /// No description provided for @goalLoseFatPitch.
  ///
  /// In en, this message translates to:
  /// **'Hold the deficit, keep the muscle, week after week.'**
  String get goalLoseFatPitch;

  /// No description provided for @goalSober.
  ///
  /// In en, this message translates to:
  /// **'Stay clean'**
  String get goalSober;

  /// No description provided for @goalSoberPitch.
  ///
  /// In en, this message translates to:
  /// **'Alcohol, nicotine, sugar — every day counts on its own.'**
  String get goalSoberPitch;

  /// No description provided for @habitCardio.
  ///
  /// In en, this message translates to:
  /// **'Cardio'**
  String get habitCardio;

  /// No description provided for @habitCardioBlurb.
  ///
  /// In en, this message translates to:
  /// **'Easy aerobic work. Zone 2 — do not wreck yourself.'**
  String get habitCardioBlurb;

  /// No description provided for @habitColdShower.
  ///
  /// In en, this message translates to:
  /// **'Cold shower'**
  String get habitColdShower;

  /// No description provided for @habitColdShowerBlurb.
  ///
  /// In en, this message translates to:
  /// **'Two minutes cold. Win the first decision of the day.'**
  String get habitColdShowerBlurb;

  /// No description provided for @habitCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom habit'**
  String get habitCustom;

  /// No description provided for @habitCustomBlurb.
  ///
  /// In en, this message translates to:
  /// **'Your thing. You define what counts.'**
  String get habitCustomBlurb;

  /// No description provided for @habitDopamineDetox.
  ///
  /// In en, this message translates to:
  /// **'Dopamine detox'**
  String get habitDopamineDetox;

  /// No description provided for @habitDopamineDetoxBlurb.
  ///
  /// In en, this message translates to:
  /// **'No endless scrolling, no shorts, no binge-watching.'**
  String get habitDopamineDetoxBlurb;

  /// No description provided for @habitGym.
  ///
  /// In en, this message translates to:
  /// **'Training'**
  String get habitGym;

  /// No description provided for @habitGymBlurb.
  ///
  /// In en, this message translates to:
  /// **'Strength training to a plan. Progressive overload, not guesswork.'**
  String get habitGymBlurb;

  /// No description provided for @habitJournaling.
  ///
  /// In en, this message translates to:
  /// **'Journaling'**
  String get habitJournaling;

  /// No description provided for @habitJournalingBlurb.
  ///
  /// In en, this message translates to:
  /// **'Three sentences will do. Clear your head, see the pattern.'**
  String get habitJournalingBlurb;

  /// No description provided for @habitMeditation.
  ///
  /// In en, this message translates to:
  /// **'Meditation'**
  String get habitMeditation;

  /// No description provided for @habitMeditationBlurb.
  ///
  /// In en, this message translates to:
  /// **'Sit still, breathe, endure it.'**
  String get habitMeditationBlurb;

  /// No description provided for @habitNoAlcohol.
  ///
  /// In en, this message translates to:
  /// **'No alcohol'**
  String get habitNoAlcohol;

  /// No description provided for @habitNoAlcoholBlurb.
  ///
  /// In en, this message translates to:
  /// **'Zero alcohol. No \"just one beer\".'**
  String get habitNoAlcoholBlurb;

  /// No description provided for @habitNoFap.
  ///
  /// In en, this message translates to:
  /// **'NoFap'**
  String get habitNoFap;

  /// No description provided for @habitNoFapBlurb.
  ///
  /// In en, this message translates to:
  /// **'No porn, no relapse. The streak counts every day.'**
  String get habitNoFapBlurb;

  /// No description provided for @habitNoNicotine.
  ///
  /// In en, this message translates to:
  /// **'No nicotine'**
  String get habitNoNicotine;

  /// No description provided for @habitNoNicotineBlurb.
  ///
  /// In en, this message translates to:
  /// **'No cigarette, no vape, no snus.'**
  String get habitNoNicotineBlurb;

  /// No description provided for @habitNoSugar.
  ///
  /// In en, this message translates to:
  /// **'No sugar'**
  String get habitNoSugar;

  /// No description provided for @habitNoSugarBlurb.
  ///
  /// In en, this message translates to:
  /// **'No added sugar. Fruit is fine.'**
  String get habitNoSugarBlurb;

  /// No description provided for @habitNutrition.
  ///
  /// In en, this message translates to:
  /// **'Nutrition'**
  String get habitNutrition;

  /// No description provided for @habitNutritionBlurb.
  ///
  /// In en, this message translates to:
  /// **'Calorie and protein target hit.'**
  String get habitNutritionBlurb;

  /// No description provided for @habitReading.
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get habitReading;

  /// No description provided for @habitReadingBlurb.
  ///
  /// In en, this message translates to:
  /// **'Real pages, real book. The feed does not read itself.'**
  String get habitReadingBlurb;

  /// No description provided for @habitSleep.
  ///
  /// In en, this message translates to:
  /// **'Sleep'**
  String get habitSleep;

  /// No description provided for @habitSleepBlurb.
  ///
  /// In en, this message translates to:
  /// **'At least seven and a half hours. Everything else builds on it.'**
  String get habitSleepBlurb;

  /// No description provided for @habitSteps.
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get habitSteps;

  /// No description provided for @habitStepsBlurb.
  ///
  /// In en, this message translates to:
  /// **'Ten thousand a day. Your watch counts them — you only have to move.'**
  String get habitStepsBlurb;

  /// No description provided for @habitWater.
  ///
  /// In en, this message translates to:
  /// **'Water'**
  String get habitWater;

  /// No description provided for @habitWaterBlurb.
  ///
  /// In en, this message translates to:
  /// **'Eight glasses. The cheapest thing you can do for yourself.'**
  String get habitWaterBlurb;

  /// No description provided for @healthAccessSection.
  ///
  /// In en, this message translates to:
  /// **'Access'**
  String get healthAccessSection;

  /// No description provided for @healthAutoImport.
  ///
  /// In en, this message translates to:
  /// **'Import automatically'**
  String get healthAutoImport;

  /// No description provided for @healthAutoImportBody.
  ///
  /// In en, this message translates to:
  /// **'Runs when you open the app. Switched off, only the button below does anything.'**
  String get healthAutoImportBody;

  /// No description provided for @healthBadge.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get healthBadge;

  /// No description provided for @healthBadgeApple.
  ///
  /// In en, this message translates to:
  /// **'Apple Health'**
  String get healthBadgeApple;

  /// No description provided for @healthBadgeConnect.
  ///
  /// In en, this message translates to:
  /// **'Health Connect'**
  String get healthBadgeConnect;

  /// No description provided for @healthDenied.
  ///
  /// In en, this message translates to:
  /// **'Access refused'**
  String get healthDenied;

  /// No description provided for @healthDeniedBody.
  ///
  /// In en, this message translates to:
  /// **'Nothing can be read until you release the values in the system settings.'**
  String get healthDeniedBody;

  /// No description provided for @healthFromDevice.
  ///
  /// In en, this message translates to:
  /// **'from {device}'**
  String healthFromDevice(String device);

  /// No description provided for @healthGetHealthConnect.
  ///
  /// In en, this message translates to:
  /// **'Get Health Connect'**
  String get healthGetHealthConnect;

  /// No description provided for @healthGrant.
  ///
  /// In en, this message translates to:
  /// **'Allow access'**
  String get healthGrant;

  /// No description provided for @healthGranted.
  ///
  /// In en, this message translates to:
  /// **'Access granted'**
  String get healthGranted;

  /// No description provided for @healthHabitsEmpty.
  ///
  /// In en, this message translates to:
  /// **'None of the habits you picked can be read from a sensor. Training, cardio, steps, sleep, water and meditation can.'**
  String get healthHabitsEmpty;

  /// No description provided for @healthHabitsSection.
  ///
  /// In en, this message translates to:
  /// **'Which habits get filled in'**
  String get healthHabitsSection;

  /// No description provided for @healthHonestyBody.
  ///
  /// In en, this message translates to:
  /// **'Less than it looks like. The feed proves that an entry is yours, when it was written and that nobody altered it afterwards — it cannot prove a watch was involved, because nothing Apple or Google hands an app is signed in a way your friends\' phones could check. An imported entry is therefore labelled \"from Health\", never \"verified\".'**
  String get healthHonestyBody;

  /// No description provided for @healthHonestySection.
  ///
  /// In en, this message translates to:
  /// **'What this proves'**
  String get healthHonestySection;

  /// No description provided for @healthImportNow.
  ///
  /// In en, this message translates to:
  /// **'Import now'**
  String get healthImportNow;

  /// No description provided for @healthImportSection.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get healthImportSection;

  /// No description provided for @healthImported.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 check-in written} other{{count} check-ins written}}'**
  String healthImported(int count);

  /// No description provided for @healthImportedNothing.
  ///
  /// In en, this message translates to:
  /// **'Nothing new — everything is already logged.'**
  String get healthImportedNothing;

  /// No description provided for @healthImporting.
  ///
  /// In en, this message translates to:
  /// **'Reading…'**
  String get healthImporting;

  /// No description provided for @healthIntroApple.
  ///
  /// In en, this message translates to:
  /// **'Your iPhone and your Apple Watch write into Apple Health. The app reads from there — on the device, and only the values you release below.'**
  String get healthIntroApple;

  /// No description provided for @healthIntroConnect.
  ///
  /// In en, this message translates to:
  /// **'Fitbit, Pixel Watch, Samsung Health, Garmin and Strava all write into Health Connect. The app reads from there — on the device, and only the values you release below.'**
  String get healthIntroConnect;

  /// No description provided for @healthIntroNone.
  ///
  /// In en, this message translates to:
  /// **'This device has no health store to read from. Everything stays manual, which works perfectly well.'**
  String get healthIntroNone;

  /// No description provided for @healthLastImport.
  ///
  /// In en, this message translates to:
  /// **'Last import: {when}'**
  String healthLastImport(String when);

  /// No description provided for @healthMetricCardio.
  ///
  /// In en, this message translates to:
  /// **'cardio sessions'**
  String get healthMetricCardio;

  /// No description provided for @healthMetricMindful.
  ///
  /// In en, this message translates to:
  /// **'mindfulness sessions'**
  String get healthMetricMindful;

  /// No description provided for @healthMetricSleep.
  ///
  /// In en, this message translates to:
  /// **'sleep duration'**
  String get healthMetricSleep;

  /// No description provided for @healthMetricSteps.
  ///
  /// In en, this message translates to:
  /// **'step count'**
  String get healthMetricSteps;

  /// No description provided for @healthMetricStrength.
  ///
  /// In en, this message translates to:
  /// **'strength-training sessions'**
  String get healthMetricStrength;

  /// No description provided for @healthMetricWater.
  ///
  /// In en, this message translates to:
  /// **'water intake'**
  String get healthMetricWater;

  /// No description provided for @healthNever.
  ///
  /// In en, this message translates to:
  /// **'never'**
  String get healthNever;

  /// No description provided for @healthNoNetworkBadge.
  ///
  /// In en, this message translates to:
  /// **'Never leaves the device'**
  String get healthNoNetworkBadge;

  /// No description provided for @healthNotOnPlatform.
  ///
  /// In en, this message translates to:
  /// **'Not available on this platform'**
  String get healthNotOnPlatform;

  /// No description provided for @healthOpenSystem.
  ///
  /// In en, this message translates to:
  /// **'Open system settings'**
  String get healthOpenSystem;

  /// No description provided for @healthReads.
  ///
  /// In en, this message translates to:
  /// **'Reads: {metric}'**
  String healthReads(String metric);

  /// No description provided for @healthRuleAbstain.
  ///
  /// In en, this message translates to:
  /// **'It never touches an abstinence habit. No sensor can show that you did not drink.'**
  String get healthRuleAbstain;

  /// No description provided for @healthRuleBackfill.
  ///
  /// In en, this message translates to:
  /// **'It reaches at most {days} days back.'**
  String healthRuleBackfill(int days);

  /// No description provided for @healthRuleManual.
  ///
  /// In en, this message translates to:
  /// **'It never overwrites a number you entered yourself.'**
  String get healthRuleManual;

  /// No description provided for @healthRuleRelapse.
  ///
  /// In en, this message translates to:
  /// **'It never writes on a day you logged a relapse.'**
  String get healthRuleRelapse;

  /// No description provided for @healthRuleRest.
  ///
  /// In en, this message translates to:
  /// **'It leaves rest days empty, so a walk cannot earn XP on a day off.'**
  String get healthRuleRest;

  /// No description provided for @healthRuleUpwards.
  ///
  /// In en, this message translates to:
  /// **'It only ever raises a value, never lowers one.'**
  String get healthRuleUpwards;

  /// No description provided for @healthRulesSection.
  ///
  /// In en, this message translates to:
  /// **'What the import will not do'**
  String get healthRulesSection;

  /// No description provided for @healthTitle.
  ///
  /// In en, this message translates to:
  /// **'Watch & health data'**
  String get healthTitle;

  /// No description provided for @healthUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'Health Connect comes with Android 14 and newer; on older phones it is a free app from the Play Store. Without it there is nothing here to read.'**
  String get healthUnavailableBody;

  /// No description provided for @healthUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Health Connect is missing'**
  String get healthUnavailableTitle;

  /// No description provided for @healthUnknown.
  ///
  /// In en, this message translates to:
  /// **'Apple does not say'**
  String get healthUnknown;

  /// No description provided for @healthUnknownBody.
  ///
  /// In en, this message translates to:
  /// **'iOS deliberately never tells an app whether reading was allowed — a refusal would otherwise give something away by itself. If nothing arrives, check the release in the Health app.'**
  String get healthUnknownBody;

  /// No description provided for @heatLess.
  ///
  /// In en, this message translates to:
  /// **'less'**
  String get heatLess;

  /// No description provided for @heatMore.
  ///
  /// In en, this message translates to:
  /// **'more'**
  String get heatMore;

  /// No description provided for @homeAscendAction.
  ///
  /// In en, this message translates to:
  /// **'On to {tier}'**
  String homeAscendAction(String tier);

  /// No description provided for @homeAscendBody.
  ///
  /// In en, this message translates to:
  /// **'This is where most apps stop. Your next tier: {emoji} {tier}. Streak, XP and history all carry over.'**
  String homeAscendBody(String emoji, String tier);

  /// No description provided for @homeAscendTitle.
  ///
  /// In en, this message translates to:
  /// **'Cycle complete: {days} days.'**
  String homeAscendTitle(int days);

  /// No description provided for @homeCheckInToast.
  ///
  /// In en, this message translates to:
  /// **'{emoji} {habit} logged.'**
  String homeCheckInToast(String emoji, String habit);

  /// No description provided for @homeCheckOffToday.
  ///
  /// In en, this message translates to:
  /// **'Check off today'**
  String get homeCheckOffToday;

  /// No description provided for @homeDayCompleteToast.
  ///
  /// In en, this message translates to:
  /// **'🔥 Day complete — streak is at {streak}.'**
  String homeDayCompleteToast(int streak);

  /// No description provided for @homeDayOfTotal.
  ///
  /// In en, this message translates to:
  /// **'Day {day} / {total}'**
  String homeDayOfTotal(int day, int total);

  /// No description provided for @homeDoneOfTotal.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} done'**
  String homeDoneOfTotal(int done, int total);

  /// No description provided for @homeExercisesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} exercises'**
  String homeExercisesCount(int count);

  /// No description provided for @homeFreezeBody.
  ///
  /// In en, this message translates to:
  /// **'{count} left. Saves the streak but does not count as a completed day.'**
  String homeFreezeBody(int count);

  /// No description provided for @homeFreezeTitle.
  ///
  /// In en, this message translates to:
  /// **'Freeze the streak'**
  String get homeFreezeTitle;

  /// No description provided for @homeFreezeUse.
  ///
  /// In en, this message translates to:
  /// **'Use one'**
  String get homeFreezeUse;

  /// No description provided for @homeLevelAndTier.
  ///
  /// In en, this message translates to:
  /// **'{emoji} {tier} · Level {level}'**
  String homeLevelAndTier(String emoji, String tier, int level);

  /// No description provided for @homeMinutesApprox.
  ///
  /// In en, this message translates to:
  /// **'≈ {count} min'**
  String homeMinutesApprox(int count);

  /// No description provided for @homeOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get homeOptional;

  /// No description provided for @homeOptionalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Not scheduled today — still counts as XP.'**
  String get homeOptionalSubtitle;

  /// No description provided for @homeRelapseBody.
  ///
  /// In en, this message translates to:
  /// **'This resets the streak and is visible to your friends. Being honest is the whole point — but only if it is true.'**
  String get homeRelapseBody;

  /// No description provided for @homeRelapseConfirm.
  ///
  /// In en, this message translates to:
  /// **'Log it'**
  String get homeRelapseConfirm;

  /// No description provided for @homeRelapseTitle.
  ///
  /// In en, this message translates to:
  /// **'Relapse on {habit}?'**
  String homeRelapseTitle(String habit);

  /// No description provided for @homeRestDay.
  ///
  /// In en, this message translates to:
  /// **'Nothing scheduled today — rest day per the plan.'**
  String get homeRestDay;

  /// No description provided for @homeSetsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} sets'**
  String homeSetsCount(int count);

  /// No description provided for @homeStorageError.
  ///
  /// In en, this message translates to:
  /// **'The app could not open its storage.'**
  String get homeStorageError;

  /// No description provided for @homeStreakDays.
  ///
  /// In en, this message translates to:
  /// **'{streak, plural, =1{day streak} other{days streak}}'**
  String homeStreakDays(int streak);

  /// No description provided for @homeTodaysMacros.
  ///
  /// In en, this message translates to:
  /// **'Today\'s macros'**
  String get homeTodaysMacros;

  /// No description provided for @homeTodaysWorkout.
  ///
  /// In en, this message translates to:
  /// **'Today\'s training'**
  String get homeTodaysWorkout;

  /// No description provided for @homeXp.
  ///
  /// In en, this message translates to:
  /// **'{xp} XP'**
  String homeXp(int xp);

  /// No description provided for @inviteErrorMalformed.
  ///
  /// In en, this message translates to:
  /// **'This invite is not valid.'**
  String get inviteErrorMalformed;

  /// No description provided for @inviteErrorSelf.
  ///
  /// In en, this message translates to:
  /// **'That is you.'**
  String get inviteErrorSelf;

  /// No description provided for @inviteHowTitle.
  ///
  /// In en, this message translates to:
  /// **'How this works'**
  String get inviteHowTitle;

  /// No description provided for @inviteLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied.'**
  String get inviteLinkCopied;

  /// No description provided for @inviteReachableAt.
  ///
  /// In en, this message translates to:
  /// **'Reachable at'**
  String get inviteReachableAt;

  /// No description provided for @inviteShareSubject.
  ///
  /// In en, this message translates to:
  /// **'100 Days challenge'**
  String get inviteShareSubject;

  /// No description provided for @inviteShareText.
  ///
  /// In en, this message translates to:
  /// **'Do the 100 days with me: {link}'**
  String inviteShareText(String link);

  /// No description provided for @inviteStep1.
  ///
  /// In en, this message translates to:
  /// **'The other person scans the code or opens the link.'**
  String get inviteStep1;

  /// No description provided for @inviteStep2.
  ///
  /// In en, this message translates to:
  /// **'You follow each other directly — no account, no phone number, no provider granting permission.'**
  String get inviteStep2;

  /// No description provided for @inviteStep3.
  ///
  /// In en, this message translates to:
  /// **'From then on your devices sync whenever they see each other: same Wi-Fi, same home, same gym.'**
  String get inviteStep3;

  /// No description provided for @inviteTitle.
  ///
  /// In en, this message translates to:
  /// **'Invite friends'**
  String get inviteTitle;

  /// No description provided for @leagueActiveToday.
  ///
  /// In en, this message translates to:
  /// **'Active today'**
  String get leagueActiveToday;

  /// No description provided for @leagueBronze.
  ///
  /// In en, this message translates to:
  /// **'Bronze'**
  String get leagueBronze;

  /// No description provided for @leagueDiamond.
  ///
  /// In en, this message translates to:
  /// **'Diamond'**
  String get leagueDiamond;

  /// No description provided for @leagueFooter.
  ///
  /// In en, this message translates to:
  /// **'XP comes per check-in, scaled by difficulty and streak. On Sunday the top places move up and the bottom ones move down.'**
  String get leagueFooter;

  /// No description provided for @leagueGold.
  ///
  /// In en, this message translates to:
  /// **'Gold'**
  String get leagueGold;

  /// No description provided for @leagueNothingToday.
  ///
  /// In en, this message translates to:
  /// **'Nothing yet today'**
  String get leagueNothingToday;

  /// No description provided for @leagueObsidian.
  ///
  /// In en, this message translates to:
  /// **'Obsidian'**
  String get leagueObsidian;

  /// No description provided for @leaguePlatinum.
  ///
  /// In en, this message translates to:
  /// **'Platinum'**
  String get leaguePlatinum;

  /// No description provided for @leagueSilver.
  ///
  /// In en, this message translates to:
  /// **'Silver'**
  String get leagueSilver;

  /// No description provided for @leagueThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get leagueThisWeek;

  /// No description provided for @leagueTitle.
  ///
  /// In en, this message translates to:
  /// **'{league} league'**
  String leagueTitle(String league);

  /// No description provided for @leagueTooSmall.
  ///
  /// In en, this message translates to:
  /// **'A league with one person is just a list. Connect friends and the competition starts.'**
  String get leagueTooSmall;

  /// No description provided for @leagueWeekAndPeople.
  ///
  /// In en, this message translates to:
  /// **'Week {week} · {count} participants'**
  String leagueWeekAndPeople(String week, int count);

  /// No description provided for @leagueWood.
  ///
  /// In en, this message translates to:
  /// **'Wood'**
  String get leagueWood;

  /// No description provided for @leagueYouSuffix.
  ///
  /// In en, this message translates to:
  /// **'{name} (you)'**
  String leagueYouSuffix(String name);

  /// No description provided for @leagueYourRank.
  ///
  /// In en, this message translates to:
  /// **'your place'**
  String get leagueYourRank;

  /// No description provided for @mealBreakfast.
  ///
  /// In en, this message translates to:
  /// **'Breakfast'**
  String get mealBreakfast;

  /// No description provided for @mealDinner.
  ///
  /// In en, this message translates to:
  /// **'Dinner'**
  String get mealDinner;

  /// No description provided for @mealIdeaBreakfast1.
  ///
  /// In en, this message translates to:
  /// **'Skyr with berries, oats and flaxseed'**
  String get mealIdeaBreakfast1;

  /// No description provided for @mealIdeaBreakfast2.
  ///
  /// In en, this message translates to:
  /// **'Scrambled eggs (3) with wholegrain toast'**
  String get mealIdeaBreakfast2;

  /// No description provided for @mealIdeaBreakfast3.
  ///
  /// In en, this message translates to:
  /// **'Overnight oats with quark and banana'**
  String get mealIdeaBreakfast3;

  /// No description provided for @mealIdeaBreakfast4.
  ///
  /// In en, this message translates to:
  /// **'Protein porridge with peanut butter'**
  String get mealIdeaBreakfast4;

  /// No description provided for @mealIdeaDinner1.
  ///
  /// In en, this message translates to:
  /// **'Turkey pan with courgette and feta'**
  String get mealIdeaDinner1;

  /// No description provided for @mealIdeaDinner2.
  ///
  /// In en, this message translates to:
  /// **'Omelette with mushrooms and spinach'**
  String get mealIdeaDinner2;

  /// No description provided for @mealIdeaDinner3.
  ///
  /// In en, this message translates to:
  /// **'Chickpea curry with natural yoghurt'**
  String get mealIdeaDinner3;

  /// No description provided for @mealIdeaDinner4.
  ///
  /// In en, this message translates to:
  /// **'Tuna salad with beans and egg'**
  String get mealIdeaDinner4;

  /// No description provided for @mealIdeaLunch1.
  ///
  /// In en, this message translates to:
  /// **'Chicken breast, rice, broccoli'**
  String get mealIdeaLunch1;

  /// No description provided for @mealIdeaLunch2.
  ///
  /// In en, this message translates to:
  /// **'Lentil bolognese with wholegrain pasta'**
  String get mealIdeaLunch2;

  /// No description provided for @mealIdeaLunch3.
  ///
  /// In en, this message translates to:
  /// **'Salmon fillet with potatoes and salad'**
  String get mealIdeaLunch3;

  /// No description provided for @mealIdeaLunch4.
  ///
  /// In en, this message translates to:
  /// **'Beef strips with couscous and roast vegetables'**
  String get mealIdeaLunch4;

  /// No description provided for @mealIdeaSnack1.
  ///
  /// In en, this message translates to:
  /// **'Quark with honey and walnuts'**
  String get mealIdeaSnack1;

  /// No description provided for @mealIdeaSnack2.
  ///
  /// In en, this message translates to:
  /// **'Protein shake with banana'**
  String get mealIdeaSnack2;

  /// No description provided for @mealIdeaSnack3.
  ///
  /// In en, this message translates to:
  /// **'A handful of almonds and an apple'**
  String get mealIdeaSnack3;

  /// No description provided for @mealIdeaSnack4.
  ///
  /// In en, this message translates to:
  /// **'Cottage cheese on crispbread'**
  String get mealIdeaSnack4;

  /// No description provided for @mealLunch.
  ///
  /// In en, this message translates to:
  /// **'Lunch'**
  String get mealLunch;

  /// No description provided for @mealSnack.
  ///
  /// In en, this message translates to:
  /// **'Snack'**
  String get mealSnack;

  /// No description provided for @milestoneAlcohol14Body.
  ///
  /// In en, this message translates to:
  /// **'Liver fat measurably drops, inflammation markers fall.'**
  String get milestoneAlcohol14Body;

  /// No description provided for @milestoneAlcohol14Title.
  ///
  /// In en, this message translates to:
  /// **'Day 14 — the liver recovers'**
  String get milestoneAlcohol14Title;

  /// No description provided for @milestoneAlcohol1Body.
  ///
  /// In en, this message translates to:
  /// **'Blood sugar and sleep are still all over the place. Drink a lot, go to bed early.'**
  String get milestoneAlcohol1Body;

  /// No description provided for @milestoneAlcohol1Title.
  ///
  /// In en, this message translates to:
  /// **'Day 1 — the body starts clearing up'**
  String get milestoneAlcohol1Title;

  /// No description provided for @milestoneAlcohol30Body.
  ///
  /// In en, this message translates to:
  /// **'Markedly better liver values, a few kilos down on average, visibly calmer skin.'**
  String get milestoneAlcohol30Body;

  /// No description provided for @milestoneAlcohol30Title.
  ///
  /// In en, this message translates to:
  /// **'Day 30 — skin, sleep, weight'**
  String get milestoneAlcohol30Title;

  /// No description provided for @milestoneAlcohol3Body.
  ///
  /// In en, this message translates to:
  /// **'REM sleep comes back. You wake up less often at night.'**
  String get milestoneAlcohol3Body;

  /// No description provided for @milestoneAlcohol3Title.
  ///
  /// In en, this message translates to:
  /// **'Day 3 — sleep gets deeper'**
  String get milestoneAlcohol3Title;

  /// No description provided for @milestoneAlcohol7Body.
  ///
  /// In en, this message translates to:
  /// **'No residual alcohol. Concentration and mood stabilise.'**
  String get milestoneAlcohol7Body;

  /// No description provided for @milestoneAlcohol7Title.
  ///
  /// In en, this message translates to:
  /// **'Week 1 — a clear head in the morning'**
  String get milestoneAlcohol7Title;

  /// No description provided for @milestoneAlcohol90Body.
  ///
  /// In en, this message translates to:
  /// **'The craving is no longer a daily negotiation. Blood pressure and immune system benefit for good.'**
  String get milestoneAlcohol90Body;

  /// No description provided for @milestoneAlcohol90Title.
  ///
  /// In en, this message translates to:
  /// **'Day 90 — the new normal'**
  String get milestoneAlcohol90Title;

  /// No description provided for @milestoneDopamine1Body.
  ///
  /// In en, this message translates to:
  /// **'You will want to reach for your phone hundreds of times. That is the habit, not you.'**
  String get milestoneDopamine1Body;

  /// No description provided for @milestoneDopamine1Title.
  ///
  /// In en, this message translates to:
  /// **'Day 1 — reaching for the phone'**
  String get milestoneDopamine1Title;

  /// No description provided for @milestoneDopamine21Body.
  ///
  /// In en, this message translates to:
  /// **'The automatic hand movement in a queue disappears.'**
  String get milestoneDopamine21Body;

  /// No description provided for @milestoneDopamine21Title.
  ///
  /// In en, this message translates to:
  /// **'Day 21 — the reflex is gone'**
  String get milestoneDopamine21Title;

  /// No description provided for @milestoneDopamine3Body.
  ///
  /// In en, this message translates to:
  /// **'Boredom is not a bug. It is the state ideas come from.'**
  String get milestoneDopamine3Body;

  /// No description provided for @milestoneDopamine3Title.
  ///
  /// In en, this message translates to:
  /// **'Day 3 — boredom comes back'**
  String get milestoneDopamine3Title;

  /// No description provided for @milestoneDopamine60Body.
  ///
  /// In en, this message translates to:
  /// **'Two focused hours on one thing are normal again.'**
  String get milestoneDopamine60Body;

  /// No description provided for @milestoneDopamine60Title.
  ///
  /// In en, this message translates to:
  /// **'Day 60 — deep work'**
  String get milestoneDopamine60Title;

  /// No description provided for @milestoneDopamine7Body.
  ///
  /// In en, this message translates to:
  /// **'You can sit through longer texts and longer conversations without looking away.'**
  String get milestoneDopamine7Body;

  /// No description provided for @milestoneDopamine7Title.
  ///
  /// In en, this message translates to:
  /// **'Week 1 — attention span grows'**
  String get milestoneDopamine7Title;

  /// No description provided for @milestoneGeneric21Body.
  ///
  /// In en, this message translates to:
  /// **'The decision costs less than it did last week.'**
  String get milestoneGeneric21Body;

  /// No description provided for @milestoneGeneric21Title.
  ///
  /// In en, this message translates to:
  /// **'Day 21 — automation begins'**
  String get milestoneGeneric21Title;

  /// No description provided for @milestoneGeneric3Body.
  ///
  /// In en, this message translates to:
  /// **'The novelty bonus is gone. Now the habit decides.'**
  String get milestoneGeneric3Body;

  /// No description provided for @milestoneGeneric3Title.
  ///
  /// In en, this message translates to:
  /// **'Day 3 — the first real test'**
  String get milestoneGeneric3Title;

  /// No description provided for @milestoneGeneric66Body.
  ///
  /// In en, this message translates to:
  /// **'On average a behaviour takes 66 days to run automatically. You are there.'**
  String get milestoneGeneric66Body;

  /// No description provided for @milestoneGeneric66Title.
  ///
  /// In en, this message translates to:
  /// **'Day 66 — habit'**
  String get milestoneGeneric66Title;

  /// No description provided for @milestoneNicotine14Body.
  ///
  /// In en, this message translates to:
  /// **'Up to 30% better lung function; stairs get easier.'**
  String get milestoneNicotine14Body;

  /// No description provided for @milestoneNicotine14Title.
  ///
  /// In en, this message translates to:
  /// **'Day 14 — lungs work better'**
  String get milestoneNicotine14Title;

  /// No description provided for @milestoneNicotine1Body.
  ///
  /// In en, this message translates to:
  /// **'After 12 hours CO levels are normal and oxygen rises.'**
  String get milestoneNicotine1Body;

  /// No description provided for @milestoneNicotine1Title.
  ///
  /// In en, this message translates to:
  /// **'Day 1 — carbon monoxide gone'**
  String get milestoneNicotine1Title;

  /// No description provided for @milestoneNicotine3Body.
  ///
  /// In en, this message translates to:
  /// **'Physical withdrawal peaks. It gets easier from here.'**
  String get milestoneNicotine3Body;

  /// No description provided for @milestoneNicotine3Title.
  ///
  /// In en, this message translates to:
  /// **'Day 3 — nicotine is out'**
  String get milestoneNicotine3Title;

  /// No description provided for @milestoneNicotine90Body.
  ///
  /// In en, this message translates to:
  /// **'Coughing and shortness of breath drop markedly.'**
  String get milestoneNicotine90Body;

  /// No description provided for @milestoneNicotine90Title.
  ///
  /// In en, this message translates to:
  /// **'Day 90 — cilia recovered'**
  String get milestoneNicotine90Title;

  /// No description provided for @milestoneNoFap14Body.
  ///
  /// In en, this message translates to:
  /// **'If you feel flat and empty: that is a known phase and it passes.'**
  String get milestoneNoFap14Body;

  /// No description provided for @milestoneNoFap14Title.
  ///
  /// In en, this message translates to:
  /// **'Day 14 — flatline possible'**
  String get milestoneNoFap14Title;

  /// No description provided for @milestoneNoFap30Body.
  ///
  /// In en, this message translates to:
  /// **'Fewer intrusive thoughts, more presence in everyday life.'**
  String get milestoneNoFap30Body;

  /// No description provided for @milestoneNoFap30Title.
  ///
  /// In en, this message translates to:
  /// **'Day 30 — the head gets quieter'**
  String get milestoneNoFap30Title;

  /// No description provided for @milestoneNoFap3Body.
  ///
  /// In en, this message translates to:
  /// **'Restlessness and irritability are normal. Movement helps more than willpower.'**
  String get milestoneNoFap3Body;

  /// No description provided for @milestoneNoFap3Title.
  ///
  /// In en, this message translates to:
  /// **'Day 3 — the first wave'**
  String get milestoneNoFap3Title;

  /// No description provided for @milestoneNoFap7Body.
  ///
  /// In en, this message translates to:
  /// **'More drive, often better sleep too.'**
  String get milestoneNoFap7Body;

  /// No description provided for @milestoneNoFap7Title.
  ///
  /// In en, this message translates to:
  /// **'Week 1 — energy rises'**
  String get milestoneNoFap7Title;

  /// No description provided for @milestoneNoFap90Body.
  ///
  /// In en, this message translates to:
  /// **'The classic reboot mark. From here it is lifestyle, not a fight.'**
  String get milestoneNoFap90Body;

  /// No description provided for @milestoneNoFap90Title.
  ///
  /// In en, this message translates to:
  /// **'Day 90 — the reboot'**
  String get milestoneNoFap90Title;

  /// No description provided for @milestoneSugar14Body.
  ///
  /// In en, this message translates to:
  /// **'Fruit suddenly tastes sweet. That is the sensor coming back.'**
  String get milestoneSugar14Body;

  /// No description provided for @milestoneSugar14Title.
  ///
  /// In en, this message translates to:
  /// **'Day 14 — taste recalibrates'**
  String get milestoneSugar14Title;

  /// No description provided for @milestoneSugar2Body.
  ///
  /// In en, this message translates to:
  /// **'Headaches and cravings peak here. Protein and water.'**
  String get milestoneSugar2Body;

  /// No description provided for @milestoneSugar2Title.
  ///
  /// In en, this message translates to:
  /// **'Day 2 — sugar withdrawal'**
  String get milestoneSugar2Title;

  /// No description provided for @milestoneSugar30Body.
  ///
  /// In en, this message translates to:
  /// **'Face and belly look flatter, inflammation markers drop.'**
  String get milestoneSugar30Body;

  /// No description provided for @milestoneSugar30Title.
  ///
  /// In en, this message translates to:
  /// **'Day 30 — less water retention'**
  String get milestoneSugar30Title;

  /// No description provided for @milestoneSugar5Body.
  ///
  /// In en, this message translates to:
  /// **'No more afternoon slump, because the blood sugar rollercoaster is gone.'**
  String get milestoneSugar5Body;

  /// No description provided for @milestoneSugar5Title.
  ///
  /// In en, this message translates to:
  /// **'Day 5 — energy levels out'**
  String get milestoneSugar5Title;

  /// No description provided for @muscleBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get muscleBack;

  /// No description provided for @muscleBiceps.
  ///
  /// In en, this message translates to:
  /// **'Biceps'**
  String get muscleBiceps;

  /// No description provided for @muscleCalves.
  ///
  /// In en, this message translates to:
  /// **'Calves'**
  String get muscleCalves;

  /// No description provided for @muscleChest.
  ///
  /// In en, this message translates to:
  /// **'Chest'**
  String get muscleChest;

  /// No description provided for @muscleCore.
  ///
  /// In en, this message translates to:
  /// **'Core'**
  String get muscleCore;

  /// No description provided for @muscleFullBody.
  ///
  /// In en, this message translates to:
  /// **'Full body'**
  String get muscleFullBody;

  /// No description provided for @muscleGlutes.
  ///
  /// In en, this message translates to:
  /// **'Glutes'**
  String get muscleGlutes;

  /// No description provided for @muscleHamstrings.
  ///
  /// In en, this message translates to:
  /// **'Hamstrings'**
  String get muscleHamstrings;

  /// No description provided for @muscleQuads.
  ///
  /// In en, this message translates to:
  /// **'Quadriceps'**
  String get muscleQuads;

  /// No description provided for @muscleShoulders.
  ///
  /// In en, this message translates to:
  /// **'Shoulders'**
  String get muscleShoulders;

  /// No description provided for @muscleTriceps.
  ///
  /// In en, this message translates to:
  /// **'Triceps'**
  String get muscleTriceps;

  /// No description provided for @navFriends.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get navFriends;

  /// No description provided for @navMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get navMore;

  /// No description provided for @navPlan.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get navPlan;

  /// No description provided for @navSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettingsTitle;

  /// No description provided for @navStats.
  ///
  /// In en, this message translates to:
  /// **'Numbers'**
  String get navStats;

  /// No description provided for @navToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get navToday;

  /// No description provided for @notifChannelPressure.
  ///
  /// In en, this message translates to:
  /// **'Friends & streak warnings'**
  String get notifChannelPressure;

  /// No description provided for @notifChannelPressureDesc.
  ///
  /// In en, this message translates to:
  /// **'When friends have been active or your streak is on the line.'**
  String get notifChannelPressureDesc;

  /// No description provided for @notifChannelReminder.
  ///
  /// In en, this message translates to:
  /// **'Daily reminder'**
  String get notifChannelReminder;

  /// No description provided for @notifChannelReminderDesc.
  ///
  /// In en, this message translates to:
  /// **'Reminds you of your habits for today.'**
  String get notifChannelReminderDesc;

  /// No description provided for @notifDayDone.
  ///
  /// In en, this message translates to:
  /// **'Day {day} is in the bag. Again tomorrow.'**
  String notifDayDone(int day);

  /// No description provided for @notifDayOpenNoStreak.
  ///
  /// In en, this message translates to:
  /// **'Day {day} of {total}. Start again today.'**
  String notifDayOpenNoStreak(int day, int total);

  /// No description provided for @notifDayOpenWithStreak.
  ///
  /// In en, this message translates to:
  /// **'Day {day} of {total}. {streak} days of streak want defending.'**
  String notifDayOpenWithStreak(int day, int total, int streak);

  /// No description provided for @notifFriendActive.
  ///
  /// In en, this message translates to:
  /// **'{name} was already out today'**
  String notifFriendActive(String name);

  /// No description provided for @notifFriendsActive.
  ///
  /// In en, this message translates to:
  /// **'{count} of your people were already out today'**
  String notifFriendsActive(int count);

  /// No description provided for @notifFriendsActiveBody.
  ///
  /// In en, this message translates to:
  /// **'You are still on zero. The day is not over yet.'**
  String get notifFriendsActiveBody;

  /// No description provided for @notifStreakRiskBody.
  ///
  /// In en, this message translates to:
  /// **'{streak} days. One forgotten evening and they are gone.'**
  String notifStreakRiskBody(int streak);

  /// No description provided for @notifStreakRiskTitle.
  ///
  /// In en, this message translates to:
  /// **'Your streak is on the line'**
  String get notifStreakRiskTitle;

  /// No description provided for @nudgeCheerRespect.
  ///
  /// In en, this message translates to:
  /// **'Respect for {emoji}'**
  String nudgeCheerRespect(String emoji);

  /// No description provided for @nudgeDefaultPoke.
  ///
  /// In en, this message translates to:
  /// **'I already went today. And you?'**
  String get nudgeDefaultPoke;

  /// No description provided for @nudgeIWentDidYou.
  ///
  /// In en, this message translates to:
  /// **'I already went today. And you?'**
  String get nudgeIWentDidYou;

  /// No description provided for @nudgeNoPressure.
  ///
  /// In en, this message translates to:
  /// **'No pressure. But I can see your feed.'**
  String get nudgeNoPressure;

  /// No description provided for @nudgeReasonInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive for two days'**
  String get nudgeReasonInactive;

  /// No description provided for @nudgeReasonNothingToday.
  ///
  /// In en, this message translates to:
  /// **'Nothing done today'**
  String get nudgeReasonNothingToday;

  /// No description provided for @nudgeStreakWatching.
  ///
  /// In en, this message translates to:
  /// **'Day {day}. Your streak is looking at you.'**
  String nudgeStreakWatching(int day);

  /// No description provided for @nudgeStrongToday.
  ///
  /// In en, this message translates to:
  /// **'Strong today. Again tomorrow?'**
  String get nudgeStrongToday;

  /// No description provided for @nudgeYouWereInForDays.
  ///
  /// In en, this message translates to:
  /// **'{streak, plural, =1{You were in for 1 day. Today too?} other{You were in for {streak} days. Today too?}}'**
  String nudgeYouWereInForDays(int streak);

  /// No description provided for @obActivityAthlete.
  ///
  /// In en, this message translates to:
  /// **'Athlete'**
  String get obActivityAthlete;

  /// No description provided for @obActivityHigh.
  ///
  /// In en, this message translates to:
  /// **'Very active'**
  String get obActivityHigh;

  /// No description provided for @obActivityLight.
  ///
  /// In en, this message translates to:
  /// **'Lightly active'**
  String get obActivityLight;

  /// No description provided for @obActivityModerate.
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get obActivityModerate;

  /// No description provided for @obActivitySedentary.
  ///
  /// In en, this message translates to:
  /// **'Sedentary'**
  String get obActivitySedentary;

  /// No description provided for @obBodyActivity.
  ///
  /// In en, this message translates to:
  /// **'Daily life & movement'**
  String get obBodyActivity;

  /// No description provided for @obBodyAge.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get obBodyAge;

  /// No description provided for @obBodyAgeValue.
  ///
  /// In en, this message translates to:
  /// **'{years} years'**
  String obBodyAgeValue(int years);

  /// No description provided for @obBodyEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Nutrition'**
  String get obBodyEyebrow;

  /// No description provided for @obBodyHeight.
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get obBodyHeight;

  /// No description provided for @obBodyPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Your daily target'**
  String get obBodyPreviewTitle;

  /// No description provided for @obBodySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Only for the calorie and protein calculation. All of it stays on this device.'**
  String get obBodySubtitle;

  /// No description provided for @obBodyTitle.
  ///
  /// In en, this message translates to:
  /// **'A few numbers.'**
  String get obBodyTitle;

  /// No description provided for @obBodyWeight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get obBodyWeight;

  /// No description provided for @obCycleDays.
  ///
  /// In en, this message translates to:
  /// **'days'**
  String get obCycleDays;

  /// No description provided for @obCycleLengthTitle.
  ///
  /// In en, this message translates to:
  /// **'How long is one cycle?'**
  String get obCycleLengthTitle;

  /// No description provided for @obCycleNote.
  ///
  /// In en, this message translates to:
  /// **'The cycle ending is not the end: your streak carries on and you move up to the next tier.'**
  String get obCycleNote;

  /// No description provided for @obEquipmentBodyweight.
  ///
  /// In en, this message translates to:
  /// **'Bodyweight only'**
  String get obEquipmentBodyweight;

  /// No description provided for @obEquipmentBodyweightBody.
  ///
  /// In en, this message translates to:
  /// **'No equipment. Works anyway.'**
  String get obEquipmentBodyweightBody;

  /// No description provided for @obEquipmentFullGym.
  ///
  /// In en, this message translates to:
  /// **'Full gym'**
  String get obEquipmentFullGym;

  /// No description provided for @obEquipmentFullGymBody.
  ///
  /// In en, this message translates to:
  /// **'Barbell, machines, cables.'**
  String get obEquipmentFullGymBody;

  /// No description provided for @obEquipmentHome.
  ///
  /// In en, this message translates to:
  /// **'Home gym'**
  String get obEquipmentHome;

  /// No description provided for @obEquipmentHomeBody.
  ///
  /// In en, this message translates to:
  /// **'Dumbbells, bands, pull-up bar.'**
  String get obEquipmentHomeBody;

  /// No description provided for @obExample1Clarity.
  ///
  /// In en, this message translates to:
  /// **'Halve my screen time, get my head back'**
  String get obExample1Clarity;

  /// No description provided for @obExample1Custom.
  ///
  /// In en, this message translates to:
  /// **'My thing, my rules'**
  String get obExample1Custom;

  /// No description provided for @obExample1Discipline.
  ///
  /// In en, this message translates to:
  /// **'100 days, no excuses'**
  String get obExample1Discipline;

  /// No description provided for @obExample1Fat.
  ///
  /// In en, this message translates to:
  /// **'8 kg down by summer'**
  String get obExample1Fat;

  /// No description provided for @obExample1Fit.
  ///
  /// In en, this message translates to:
  /// **'5 km under 25 minutes'**
  String get obExample1Fit;

  /// No description provided for @obExample1Muscle.
  ///
  /// In en, this message translates to:
  /// **'5 kg of muscle in 100 days'**
  String get obExample1Muscle;

  /// No description provided for @obExample1Sober.
  ///
  /// In en, this message translates to:
  /// **'100 days completely dry'**
  String get obExample1Sober;

  /// No description provided for @obExample2Clarity.
  ///
  /// In en, this message translates to:
  /// **'100 days without doomscrolling'**
  String get obExample2Clarity;

  /// No description provided for @obExample2Discipline.
  ///
  /// In en, this message translates to:
  /// **'Up at 6 every morning, no debate'**
  String get obExample2Discipline;

  /// No description provided for @obExample2Fat.
  ///
  /// In en, this message translates to:
  /// **'Fit into my old jeans again'**
  String get obExample2Fat;

  /// No description provided for @obExample2Fit.
  ///
  /// In en, this message translates to:
  /// **'Up the stairs without stopping'**
  String get obExample2Fit;

  /// No description provided for @obExample2Muscle.
  ///
  /// In en, this message translates to:
  /// **'Finally 10 clean pull-ups'**
  String get obExample2Muscle;

  /// No description provided for @obExample2Sober.
  ///
  /// In en, this message translates to:
  /// **'No sugar, no alcohol, no exceptions'**
  String get obExample2Sober;

  /// No description provided for @obExperienceAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Experienced'**
  String get obExperienceAdvanced;

  /// No description provided for @obExperienceAdvancedBody.
  ///
  /// In en, this message translates to:
  /// **'More than three years. Volume is your lever.'**
  String get obExperienceAdvancedBody;

  /// No description provided for @obExperienceBeginner.
  ///
  /// In en, this message translates to:
  /// **'Beginner'**
  String get obExperienceBeginner;

  /// No description provided for @obExperienceBeginnerBody.
  ///
  /// In en, this message translates to:
  /// **'Under a year of consistency. Technique before weight.'**
  String get obExperienceBeginnerBody;

  /// No description provided for @obExperienceIntermediate.
  ///
  /// In en, this message translates to:
  /// **'Intermediate'**
  String get obExperienceIntermediate;

  /// No description provided for @obExperienceIntermediateBody.
  ///
  /// In en, this message translates to:
  /// **'One to three years. You know what RPE 8 feels like.'**
  String get obExperienceIntermediateBody;

  /// No description provided for @obGoalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'One goal. Everything else — training plan, nutrition plan, streak — is built from it.'**
  String get obGoalSubtitle;

  /// No description provided for @obGoalTitle.
  ///
  /// In en, this message translates to:
  /// **'What is this about?'**
  String get obGoalTitle;

  /// No description provided for @obHabitDailyTarget.
  ///
  /// In en, this message translates to:
  /// **'Daily target'**
  String get obHabitDailyTarget;

  /// No description provided for @obHabitRecommended.
  ///
  /// In en, this message translates to:
  /// **'recommended'**
  String get obHabitRecommended;

  /// No description provided for @obHabitsSubtitlePreselected.
  ///
  /// In en, this message translates to:
  /// **'What fits your goal is preselected. Change it however you like.'**
  String get obHabitsSubtitlePreselected;

  /// No description provided for @obHabitsSubtitleTooMany.
  ///
  /// In en, this message translates to:
  /// **'That is a lot. Experience says people stick with three or four — better fewer and actually done.'**
  String get obHabitsSubtitleTooMany;

  /// No description provided for @obHabitsTitle.
  ///
  /// In en, this message translates to:
  /// **'What counts every day?'**
  String get obHabitsTitle;

  /// No description provided for @obIdentityBoxBody.
  ///
  /// In en, this message translates to:
  /// **'An Ed25519 key pair on this device, as a did:key. Every check-in is signed with it — which is why nobody can fake your streak and you do not have to trust anyone. The recovery key is in settings. Back it up.'**
  String get obIdentityBoxBody;

  /// No description provided for @obIdentityBoxTitle.
  ///
  /// In en, this message translates to:
  /// **'Your identity'**
  String get obIdentityBoxTitle;

  /// No description provided for @obIdentityNameHint.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get obIdentityNameHint;

  /// No description provided for @obIdentitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'No account, no email, no password. Your key pair is already on this device.'**
  String get obIdentitySubtitle;

  /// No description provided for @obIdentityTitle.
  ///
  /// In en, this message translates to:
  /// **'How should your people see you?'**
  String get obIdentityTitle;

  /// No description provided for @obPointBeyondBody.
  ///
  /// In en, this message translates to:
  /// **'After that it carries on — next tier, harder targets, same streak.'**
  String get obPointBeyondBody;

  /// No description provided for @obPointBeyondTitle.
  ///
  /// In en, this message translates to:
  /// **'Day 100 is not the end'**
  String get obPointBeyondTitle;

  /// No description provided for @obPointGoalBody.
  ///
  /// In en, this message translates to:
  /// **'No goal, no plan. You say what this is about — the app builds training, nutrition or a streak around it.'**
  String get obPointGoalBody;

  /// No description provided for @obPointGoalTitle.
  ///
  /// In en, this message translates to:
  /// **'The goal comes first'**
  String get obPointGoalTitle;

  /// No description provided for @obPointPrivacyBody.
  ///
  /// In en, this message translates to:
  /// **'No account, no server, no cloud. Your data stays on your device and goes straight to your friends.'**
  String get obPointPrivacyBody;

  /// No description provided for @obPointPrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nobody else'**
  String get obPointPrivacyTitle;

  /// No description provided for @obPointSocialBody.
  ///
  /// In en, this message translates to:
  /// **'Not an anonymous counter. If Marcel was at the gym today and you were not, it says so. That is the point.'**
  String get obPointSocialBody;

  /// No description provided for @obPointSocialTitle.
  ///
  /// In en, this message translates to:
  /// **'Your people see everything'**
  String get obPointSocialTitle;

  /// No description provided for @obSetsAndMinutes.
  ///
  /// In en, this message translates to:
  /// **'{sets} sets · {minutes} min'**
  String obSetsAndMinutes(int sets, int minutes);

  /// No description provided for @obSexFemale.
  ///
  /// In en, this message translates to:
  /// **'female'**
  String get obSexFemale;

  /// No description provided for @obSexMale.
  ///
  /// In en, this message translates to:
  /// **'male'**
  String get obSexMale;

  /// No description provided for @obStartChallenge.
  ///
  /// In en, this message translates to:
  /// **'Start the challenge'**
  String get obStartChallenge;

  /// No description provided for @obStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not start: {message}'**
  String obStartFailed(String message);

  /// No description provided for @obStatementHint.
  ///
  /// In en, this message translates to:
  /// **'I want to …'**
  String get obStatementHint;

  /// No description provided for @obStatementSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You will see this sentence on every hard day. So write the real one, not the presentable one.'**
  String get obStatementSubtitle;

  /// No description provided for @obStatementTitle.
  ///
  /// In en, this message translates to:
  /// **'Say it in one sentence.'**
  String get obStatementTitle;

  /// No description provided for @obStep1.
  ///
  /// In en, this message translates to:
  /// **'Step 1'**
  String get obStep1;

  /// No description provided for @obStep2.
  ///
  /// In en, this message translates to:
  /// **'Step 2'**
  String get obStep2;

  /// No description provided for @obStep3.
  ///
  /// In en, this message translates to:
  /// **'Step 3'**
  String get obStep3;

  /// No description provided for @obStep4.
  ///
  /// In en, this message translates to:
  /// **'Step 4'**
  String get obStep4;

  /// No description provided for @obSummaryAlmostDone.
  ///
  /// In en, this message translates to:
  /// **'Almost there'**
  String get obSummaryAlmostDone;

  /// No description provided for @obSummaryDailySection.
  ///
  /// In en, this message translates to:
  /// **'This counts daily'**
  String get obSummaryDailySection;

  /// No description provided for @obSummaryDayOne.
  ///
  /// In en, this message translates to:
  /// **'{emoji} {goal} · Day 1 of {days}'**
  String obSummaryDayOne(String emoji, String goal, int days);

  /// No description provided for @obSummaryEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Your plan'**
  String get obSummaryEyebrow;

  /// No description provided for @obSummaryFriendsNote.
  ///
  /// In en, this message translates to:
  /// **'Next: connect friends. Almost nobody lasts 100 days alone — with an audience they do.'**
  String get obSummaryFriendsNote;

  /// No description provided for @obSummaryMissing.
  ///
  /// In en, this message translates to:
  /// **'A few details are still missing.'**
  String get obSummaryMissing;

  /// No description provided for @obSummaryNutritionSection.
  ///
  /// In en, this message translates to:
  /// **'Nutrition plan'**
  String get obSummaryNutritionSection;

  /// No description provided for @obSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'{days} days, starting today.'**
  String obSummaryTitle(int days);

  /// No description provided for @obSummaryTrainingSection.
  ///
  /// In en, this message translates to:
  /// **'Training plan'**
  String get obSummaryTrainingSection;

  /// No description provided for @obTrainingDaysPerWeek.
  ///
  /// In en, this message translates to:
  /// **'Training days per week'**
  String get obTrainingDaysPerWeek;

  /// No description provided for @obTrainingEquipment.
  ///
  /// In en, this message translates to:
  /// **'Equipment'**
  String get obTrainingEquipment;

  /// No description provided for @obTrainingExperience.
  ///
  /// In en, this message translates to:
  /// **'Experience'**
  String get obTrainingExperience;

  /// No description provided for @obTrainingEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Training'**
  String get obTrainingEyebrow;

  /// No description provided for @obTrainingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The app builds your split from this — including deload weeks, so you are not running on empty after six weeks.'**
  String get obTrainingSubtitle;

  /// No description provided for @obTrainingTitle.
  ///
  /// In en, this message translates to:
  /// **'How often and with what?'**
  String get obTrainingTitle;

  /// No description provided for @obWelcomeEyebrow.
  ///
  /// In en, this message translates to:
  /// **'100 days and far beyond'**
  String get obWelcomeEyebrow;

  /// No description provided for @obWelcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Set a goal. Get a plan. After that only one thing counts: whether you showed up today — and whether your people can see it.'**
  String get obWelcomeSubtitle;

  /// No description provided for @obWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'You do not need a new you.\nYou need 100 days.'**
  String get obWelcomeTitle;

  /// No description provided for @peerActivityAscended.
  ///
  /// In en, this message translates to:
  /// **'Reached the next tier'**
  String get peerActivityAscended;

  /// No description provided for @peerActivityCheckIn.
  ///
  /// In en, this message translates to:
  /// **'{emoji} {habit} done'**
  String peerActivityCheckIn(String emoji, String habit);

  /// No description provided for @peerActivityFreeze.
  ///
  /// In en, this message translates to:
  /// **'Streak frozen'**
  String get peerActivityFreeze;

  /// No description provided for @peerActivityMissed.
  ///
  /// In en, this message translates to:
  /// **'Missed a day'**
  String get peerActivityMissed;

  /// No description provided for @peerActivityNone.
  ///
  /// In en, this message translates to:
  /// **'Nothing yet'**
  String get peerActivityNone;

  /// No description provided for @peerActivityRelapse.
  ///
  /// In en, this message translates to:
  /// **'Relapse logged'**
  String get peerActivityRelapse;

  /// No description provided for @peerActivityStarted.
  ///
  /// In en, this message translates to:
  /// **'Challenge started'**
  String get peerActivityStarted;

  /// No description provided for @planAdjustmentsNote.
  ///
  /// In en, this message translates to:
  /// **'Worked out on this device, from your last few weeks. None of it leaves your phone.'**
  String get planAdjustmentsNote;

  /// No description provided for @planBmr.
  ///
  /// In en, this message translates to:
  /// **'Basal metabolic rate (BMR)'**
  String get planBmr;

  /// No description provided for @planCarbs.
  ///
  /// In en, this message translates to:
  /// **'Carbs'**
  String get planCarbs;

  /// No description provided for @planCarbsShort.
  ///
  /// In en, this message translates to:
  /// **'Carbs'**
  String get planCarbsShort;

  /// No description provided for @planCleanDays.
  ///
  /// In en, this message translates to:
  /// **'{days} days clean'**
  String planCleanDays(int days);

  /// No description provided for @planContext.
  ///
  /// In en, this message translates to:
  /// **'Context'**
  String get planContext;

  /// No description provided for @planCurrentBadge.
  ///
  /// In en, this message translates to:
  /// **'current'**
  String get planCurrentBadge;

  /// No description provided for @planDeloadBadge.
  ///
  /// In en, this message translates to:
  /// **'deload'**
  String get planDeloadBadge;

  /// No description provided for @planExpectedChange.
  ///
  /// In en, this message translates to:
  /// **'Expected change'**
  String get planExpectedChange;

  /// No description provided for @planFat.
  ///
  /// In en, this message translates to:
  /// **'Fat'**
  String get planFat;

  /// No description provided for @planFiber.
  ///
  /// In en, this message translates to:
  /// **'Fibre'**
  String get planFiber;

  /// No description provided for @planKcal.
  ///
  /// In en, this message translates to:
  /// **'kcal'**
  String get planKcal;

  /// No description provided for @planKcalPerDay.
  ///
  /// In en, this message translates to:
  /// **'{kcal} kcal per day'**
  String planKcalPerDay(int kcal);

  /// No description provided for @planKcalPerDayShort.
  ///
  /// In en, this message translates to:
  /// **'kcal / day'**
  String get planKcalPerDayShort;

  /// No description provided for @planMealMacros.
  ///
  /// In en, this message translates to:
  /// **'{kcal} kcal · {protein}g P'**
  String planMealMacros(int kcal, int protein);

  /// No description provided for @planMeals.
  ///
  /// In en, this message translates to:
  /// **'Meals'**
  String get planMeals;

  /// No description provided for @planNutritionDeficit.
  ///
  /// In en, this message translates to:
  /// **'A {percent}% deficit below your {tdee} kcal expenditure. That is roughly 0.5 kg of fat a week — fast enough to see, slow enough to keep the muscle.'**
  String planNutritionDeficit(int percent, int tdee);

  /// No description provided for @planNutritionMaintain.
  ///
  /// In en, this message translates to:
  /// **'Maintenance at {tdee} kcal. Habit and performance first, body composition second.'**
  String planNutritionMaintain(int tdee);

  /// No description provided for @planNutritionSideGoal.
  ///
  /// In en, this message translates to:
  /// **'Maintenance at {tdee} kcal. Your goal is elsewhere — nutrition just should not slow you down.'**
  String planNutritionSideGoal(int tdee);

  /// No description provided for @planNutritionSurplus.
  ///
  /// In en, this message translates to:
  /// **'A {percent}% surplus over your {tdee} kcal expenditure. Lean bulk: enough to build, little enough that it is not just fat.'**
  String planNutritionSurplus(int percent, int tdee);

  /// No description provided for @planPerWeek.
  ///
  /// In en, this message translates to:
  /// **'{value} kg/week'**
  String planPerWeek(String value);

  /// No description provided for @planProtein.
  ///
  /// In en, this message translates to:
  /// **'Protein'**
  String get planProtein;

  /// No description provided for @planTabAbstinence.
  ///
  /// In en, this message translates to:
  /// **'Staying clean'**
  String get planTabAbstinence;

  /// No description provided for @planTabAdjustments.
  ///
  /// In en, this message translates to:
  /// **'Adjustments'**
  String get planTabAdjustments;

  /// No description provided for @planTabNutrition.
  ///
  /// In en, this message translates to:
  /// **'Nutrition'**
  String get planTabNutrition;

  /// No description provided for @planTabTraining.
  ///
  /// In en, this message translates to:
  /// **'Training'**
  String get planTabTraining;

  /// No description provided for @planTdee.
  ///
  /// In en, this message translates to:
  /// **'Total expenditure (TDEE)'**
  String get planTdee;

  /// No description provided for @planWater.
  ///
  /// In en, this message translates to:
  /// **'Water'**
  String get planWater;

  /// No description provided for @planWeekNumber.
  ///
  /// In en, this message translates to:
  /// **'Week {week}'**
  String planWeekNumber(int week);

  /// No description provided for @planWorkoutSummary.
  ///
  /// In en, this message translates to:
  /// **'{sets} sets · ≈ {minutes} min'**
  String planWorkoutSummary(int sets, int minutes);

  /// No description provided for @pressureBodyBehind.
  ///
  /// In en, this message translates to:
  /// **'{activity} · {streak, plural, =1{1 day streak} other{{streak} days streak}}. You are still on zero today.'**
  String pressureBodyBehind(String activity, int streak);

  /// No description provided for @pressureBodyDone.
  ///
  /// In en, this message translates to:
  /// **'You too. Keep it up.'**
  String get pressureBodyDone;

  /// No description provided for @pressureManyActive.
  ///
  /// In en, this message translates to:
  /// **'{count} of your people were already out today'**
  String pressureManyActive(int count);

  /// No description provided for @pressureOneActive.
  ///
  /// In en, this message translates to:
  /// **'{name} was already out today'**
  String pressureOneActive(String name);

  /// No description provided for @profileCheer.
  ///
  /// In en, this message translates to:
  /// **'Cheer'**
  String get profileCheer;

  /// No description provided for @profileCheerSent.
  ///
  /// In en, this message translates to:
  /// **'Cheered.'**
  String get profileCheerSent;

  /// No description provided for @profileDaysCount.
  ///
  /// In en, this message translates to:
  /// **'{days} days'**
  String profileDaysCount(int days);

  /// No description provided for @profileDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get profileDisconnect;

  /// No description provided for @profileHabits.
  ///
  /// In en, this message translates to:
  /// **'Habits'**
  String get profileHabits;

  /// No description provided for @profileHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get profileHistory;

  /// No description provided for @profileNudge.
  ///
  /// In en, this message translates to:
  /// **'Nudge'**
  String get profileNudge;

  /// No description provided for @profileNudgeSent.
  ///
  /// In en, this message translates to:
  /// **'Nudge sent.'**
  String get profileNudgeSent;

  /// No description provided for @profileRemoveBody.
  ///
  /// In en, this message translates to:
  /// **'This deletes their entire history from your device. The only way back is to connect again.'**
  String get profileRemoveBody;

  /// No description provided for @profileRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}?'**
  String profileRemoveTitle(String name);

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profileUnknownBody.
  ///
  /// In en, this message translates to:
  /// **'Nothing about this identity is on your device.'**
  String get profileUnknownBody;

  /// No description provided for @profileUnknownTitle.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get profileUnknownTitle;

  /// No description provided for @promptAdjustHabitLine.
  ///
  /// In en, this message translates to:
  /// **'- {habit}: target {target}, {days}x per week, streak {streak}'**
  String promptAdjustHabitLine(
      String habit, String target, int days, int streak);

  /// No description provided for @promptAdjustments.
  ///
  /// In en, this message translates to:
  /// **'You are a training and habit coach. Write in English, second person.\nThe user is on day {day} of {total}.\nHit rate: {percent}%.\nGoal: \"{statement}\"\n\n{habits}\n\nGive at most 4 concrete adjustments, one per line, at most 15 words each. No preamble, no numbering, no emoji.'**
  String promptAdjustments(
      int day, int total, int percent, String statement, String habits);

  /// No description provided for @promptBriefing.
  ///
  /// In en, this message translates to:
  /// **'You are the coach in a 100-day challenge app. Write in English, second person.\n{persona}\nTwo sentences at most. No emoji at the start of a line. No quotation marks.\n\nThe goal: \"{statement}\"\nDay {day} of {total} (tier: {tier})\nCurrent streak: {streak} days, longest: {longest}\nDone today: {doneToday}\nTime of day: {hour}:00\n\nHabits:\n{habits}\n\nFriends:\n{peers}\n\nAnswer in exactly this format:\nTITLE: <at most 6 words>\nTEXT: <1-2 sentences>'**
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
      String peers);

  /// No description provided for @promptHabitLine.
  ///
  /// In en, this message translates to:
  /// **'- {emoji} {habit}: {streak} {unit}'**
  String promptHabitLine(String emoji, String habit, int streak, String unit);

  /// No description provided for @promptNo.
  ///
  /// In en, this message translates to:
  /// **'no'**
  String get promptNo;

  /// No description provided for @promptNoFriends.
  ///
  /// In en, this message translates to:
  /// **'- no friends connected'**
  String get promptNoFriends;

  /// No description provided for @promptNudge.
  ///
  /// In en, this message translates to:
  /// **'Write a single short taunt in English aimed at {name}, who has done nothing for their own challenge today. The sender is on day {day} with a {streak} day streak. At most 12 words, cheeky but friendly, no bullying, no quotation marks. Output only the message.'**
  String promptNudge(String name, int day, int streak);

  /// No description provided for @promptPeerActive.
  ///
  /// In en, this message translates to:
  /// **'ALREADY active today'**
  String get promptPeerActive;

  /// No description provided for @promptPeerInactive.
  ///
  /// In en, this message translates to:
  /// **'nothing yet today'**
  String get promptPeerInactive;

  /// No description provided for @promptPeerLine.
  ///
  /// In en, this message translates to:
  /// **'- {name}: {streak} day streak, {status}'**
  String promptPeerLine(String name, int streak, String status);

  /// No description provided for @promptPersonaCalm.
  ///
  /// In en, this message translates to:
  /// **'You are calm and matter-of-fact.'**
  String get promptPersonaCalm;

  /// No description provided for @promptPersonaCelebrate.
  ///
  /// In en, this message translates to:
  /// **'You are brief and proud, without schmaltz.'**
  String get promptPersonaCelebrate;

  /// No description provided for @promptPersonaDemanding.
  ///
  /// In en, this message translates to:
  /// **'You are demanding and concrete.'**
  String get promptPersonaDemanding;

  /// No description provided for @promptPersonaDirect.
  ///
  /// In en, this message translates to:
  /// **'You are direct and mildly provocative, never insulting.'**
  String get promptPersonaDirect;

  /// No description provided for @promptPersonaRecover.
  ///
  /// In en, this message translates to:
  /// **'You are sober and respectful. No pity, no blame.'**
  String get promptPersonaRecover;

  /// No description provided for @promptUnitClean.
  ///
  /// In en, this message translates to:
  /// **'days clean'**
  String get promptUnitClean;

  /// No description provided for @promptUnitStreak.
  ///
  /// In en, this message translates to:
  /// **'days streak'**
  String get promptUnitStreak;

  /// No description provided for @promptYes.
  ///
  /// In en, this message translates to:
  /// **'yes'**
  String get promptYes;

  /// No description provided for @recoveryCopied.
  ///
  /// In en, this message translates to:
  /// **'Key copied.'**
  String get recoveryCopied;

  /// No description provided for @recoveryLookAround.
  ///
  /// In en, this message translates to:
  /// **'Have a look around you first.'**
  String get recoveryLookAround;

  /// No description provided for @recoveryShow.
  ///
  /// In en, this message translates to:
  /// **'Show the key'**
  String get recoveryShow;

  /// No description provided for @recoveryTip1.
  ///
  /// In en, this message translates to:
  /// **'A password manager — the best place for it.'**
  String get recoveryTip1;

  /// No description provided for @recoveryTip2.
  ///
  /// In en, this message translates to:
  /// **'Write it down and put it in the drawer where your ID lives.'**
  String get recoveryTip2;

  /// No description provided for @recoveryTip3.
  ///
  /// In en, this message translates to:
  /// **'Not into a chat, not into a cloud-synced notes app, not as a screenshot in your gallery.'**
  String get recoveryTip3;

  /// No description provided for @recoveryTitle.
  ///
  /// In en, this message translates to:
  /// **'Recovery key'**
  String get recoveryTitle;

  /// No description provided for @recoveryWarning.
  ///
  /// In en, this message translates to:
  /// **'Whoever has this key is you. They can sign check-ins in your name, and you cannot revoke it — there is no provider who could.'**
  String get recoveryWarning;

  /// No description provided for @recoveryWhereTitle.
  ///
  /// In en, this message translates to:
  /// **'Where to keep it'**
  String get recoveryWhereTitle;

  /// No description provided for @relativeDays.
  ///
  /// In en, this message translates to:
  /// **'{count} days ago'**
  String relativeDays(int count);

  /// No description provided for @relativeHours.
  ///
  /// In en, this message translates to:
  /// **'{count} h ago'**
  String relativeHours(int count);

  /// No description provided for @relativeJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get relativeJustNow;

  /// No description provided for @relativeMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count} min ago'**
  String relativeMinutes(int count);

  /// No description provided for @relativeYesterday.
  ///
  /// In en, this message translates to:
  /// **'yesterday'**
  String get relativeYesterday;

  /// No description provided for @ringDayOfTotal.
  ///
  /// In en, this message translates to:
  /// **'Day {day} / {total}'**
  String ringDayOfTotal(int day, int total);

  /// No description provided for @ringDayStreak.
  ///
  /// In en, this message translates to:
  /// **'{streak, plural, =1{day streak} other{days streak}}'**
  String ringDayStreak(int streak);

  /// No description provided for @scanCameraUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'It works without the camera too: have the invite link sent to you and paste it below.\n\n{code}'**
  String scanCameraUnavailableBody(String code);

  /// No description provided for @scanCameraUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Camera unavailable'**
  String get scanCameraUnavailableTitle;

  /// No description provided for @scanHint.
  ///
  /// In en, this message translates to:
  /// **'Point the camera at your friend’s QR code.'**
  String get scanHint;

  /// No description provided for @scanPasteInstead.
  ///
  /// In en, this message translates to:
  /// **'Paste a link instead'**
  String get scanPasteInstead;

  /// No description provided for @scanPasteTitle.
  ///
  /// In en, this message translates to:
  /// **'Invite link'**
  String get scanPasteTitle;

  /// No description provided for @scanTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan a code'**
  String get scanTitle;

  /// No description provided for @setAboutBody.
  ///
  /// In en, this message translates to:
  /// **'No account, no server, no ads, no tracking. Your data lives on this device and only goes to the friends you connected yourself. The source is open — check it instead of believing it.'**
  String get setAboutBody;

  /// No description provided for @setAboutSection.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get setAboutSection;

  /// No description provided for @setAboutTitle.
  ///
  /// In en, this message translates to:
  /// **'100 days and far beyond'**
  String get setAboutTitle;

  /// No description provided for @setCoachSection.
  ///
  /// In en, this message translates to:
  /// **'Coach'**
  String get setCoachSection;

  /// No description provided for @setDidCopied.
  ///
  /// In en, this message translates to:
  /// **'DID copied.'**
  String get setDidCopied;

  /// No description provided for @setHealthConnected.
  ///
  /// In en, this message translates to:
  /// **'Filling in {count, plural, =1{1 habit} other{{count} habits}}'**
  String setHealthConnected(int count);

  /// No description provided for @setHealthOff.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get setHealthOff;

  /// No description provided for @setHealthSection.
  ///
  /// In en, this message translates to:
  /// **'Watch & health data'**
  String get setHealthSection;

  /// No description provided for @setHealthTitle.
  ///
  /// In en, this message translates to:
  /// **'Apple Health and Health Connect'**
  String get setHealthTitle;

  /// No description provided for @setIdentitySection.
  ///
  /// In en, this message translates to:
  /// **'Identity & data'**
  String get setIdentitySection;

  /// No description provided for @setLan.
  ///
  /// In en, this message translates to:
  /// **'Local network'**
  String get setLan;

  /// No description provided for @setLanOff.
  ///
  /// In en, this message translates to:
  /// **'Not active.'**
  String get setLanOff;

  /// No description provided for @setLanOn.
  ///
  /// In en, this message translates to:
  /// **'Active — finds friends on the same Wi-Fi automatically.'**
  String get setLanOn;

  /// No description provided for @setLanguage.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get setLanguage;

  /// No description provided for @setLanguageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get setLanguageEnglish;

  /// No description provided for @setLanguageGerman.
  ///
  /// In en, this message translates to:
  /// **'Deutsch'**
  String get setLanguageGerman;

  /// No description provided for @setLanguageSection.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get setLanguageSection;

  /// No description provided for @setLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'System language'**
  String get setLanguageSystem;

  /// No description provided for @setLanguageSystemSub.
  ///
  /// In en, this message translates to:
  /// **'Follows your phone. Currently: {language}'**
  String setLanguageSystemSub(String language);

  /// No description provided for @setNetworkSection.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get setNetworkSection;

  /// No description provided for @setOnDeviceAi.
  ///
  /// In en, this message translates to:
  /// **'On-device AI'**
  String get setOnDeviceAi;

  /// No description provided for @setOnThisDevice.
  ///
  /// In en, this message translates to:
  /// **'On this device'**
  String get setOnThisDevice;

  /// No description provided for @setOnThisDeviceSub.
  ///
  /// In en, this message translates to:
  /// **'{events} own entries · {friends} connected feeds'**
  String setOnThisDeviceSub(int events, int friends);

  /// No description provided for @setRecoveryKey.
  ///
  /// In en, this message translates to:
  /// **'Recovery key'**
  String get setRecoveryKey;

  /// No description provided for @setRecoveryKeySub.
  ///
  /// In en, this message translates to:
  /// **'The only way back into your account.'**
  String get setRecoveryKeySub;

  /// No description provided for @setSyncFailed.
  ///
  /// In en, this message translates to:
  /// **'Last attempt failed: {message}'**
  String setSyncFailed(String message);

  /// No description provided for @setSyncLast.
  ///
  /// In en, this message translates to:
  /// **'Last with {peer}: {received} received, {sent} sent.'**
  String setSyncLast(String peer, int received, int sent);

  /// No description provided for @setSyncNever.
  ///
  /// In en, this message translates to:
  /// **'No round has run yet.'**
  String get setSyncNever;

  /// No description provided for @setSyncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get setSyncNow;

  /// No description provided for @setSyncPeerFallback.
  ///
  /// In en, this message translates to:
  /// **'a peer'**
  String get setSyncPeerFallback;

  /// No description provided for @setSyncStarted.
  ///
  /// In en, this message translates to:
  /// **'Sync round started.'**
  String get setSyncStarted;

  /// No description provided for @setViewSource.
  ///
  /// In en, this message translates to:
  /// **'View the source'**
  String get setViewSource;

  /// No description provided for @setWipe.
  ///
  /// In en, this message translates to:
  /// **'Delete everything'**
  String get setWipe;

  /// No description provided for @setWipeBody.
  ///
  /// In en, this message translates to:
  /// **'Without your recovery key nothing can be restored afterwards — there is no server holding a copy. That is the price of nobody else holding one either.'**
  String get setWipeBody;

  /// No description provided for @setWipeSub.
  ///
  /// In en, this message translates to:
  /// **'Remove identity, challenge and all friends.'**
  String get setWipeSub;

  /// No description provided for @setWipeTitle.
  ///
  /// In en, this message translates to:
  /// **'Really delete everything?'**
  String get setWipeTitle;

  /// No description provided for @socialTabFeed.
  ///
  /// In en, this message translates to:
  /// **'Feed'**
  String get socialTabFeed;

  /// No description provided for @socialTabFriends.
  ///
  /// In en, this message translates to:
  /// **'Friends ({count})'**
  String socialTabFriends(int count);

  /// No description provided for @socialTabLeague.
  ///
  /// In en, this message translates to:
  /// **'League'**
  String get socialTabLeague;

  /// No description provided for @splitFullBodyThrice.
  ///
  /// In en, this message translates to:
  /// **'Full body 3x'**
  String get splitFullBodyThrice;

  /// No description provided for @splitFullBodyTwice.
  ///
  /// In en, this message translates to:
  /// **'Full body 2x'**
  String get splitFullBodyTwice;

  /// No description provided for @splitPplPlusUpperLower.
  ///
  /// In en, this message translates to:
  /// **'Push / Pull / Legs + Upper / Lower'**
  String get splitPplPlusUpperLower;

  /// No description provided for @splitPplTwice.
  ///
  /// In en, this message translates to:
  /// **'Push / Pull / Legs 2x'**
  String get splitPplTwice;

  /// No description provided for @splitPreview2.
  ///
  /// In en, this message translates to:
  /// **'Full body 2x — every session hits everything.'**
  String get splitPreview2;

  /// No description provided for @splitPreview3.
  ///
  /// In en, this message translates to:
  /// **'Full body 3x — the best trade-off for most people.'**
  String get splitPreview3;

  /// No description provided for @splitPreview4.
  ///
  /// In en, this message translates to:
  /// **'Upper / Lower — upper body twice, legs twice.'**
  String get splitPreview4;

  /// No description provided for @splitPreview5.
  ///
  /// In en, this message translates to:
  /// **'Push / Pull / Legs plus Upper / Lower.'**
  String get splitPreview5;

  /// No description provided for @splitPreview6.
  ///
  /// In en, this message translates to:
  /// **'Push / Pull / Legs, twice a week.'**
  String get splitPreview6;

  /// No description provided for @splitUpperLower.
  ///
  /// In en, this message translates to:
  /// **'Upper / Lower'**
  String get splitUpperLower;

  /// No description provided for @statDay.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get statDay;

  /// No description provided for @statRecord.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get statRecord;

  /// No description provided for @statStreak.
  ///
  /// In en, this message translates to:
  /// **'Streak'**
  String get statStreak;

  /// No description provided for @statXp.
  ///
  /// In en, this message translates to:
  /// **'XP'**
  String get statXp;

  /// No description provided for @statsCurrentStreak.
  ///
  /// In en, this message translates to:
  /// **'Current streak'**
  String get statsCurrentStreak;

  /// No description provided for @statsFullDays.
  ///
  /// In en, this message translates to:
  /// **'Full days'**
  String get statsFullDays;

  /// No description provided for @statsHabitProgress.
  ///
  /// In en, this message translates to:
  /// **'{done} of {planned} planned days ({percent} %)'**
  String statsHabitProgress(int done, int planned, int percent);

  /// No description provided for @statsHistorySince.
  ///
  /// In en, this message translates to:
  /// **'Since {date}'**
  String statsHistorySince(String date);

  /// No description provided for @statsHitRate.
  ///
  /// In en, this message translates to:
  /// **'Hit rate'**
  String get statsHitRate;

  /// No description provided for @statsLevel.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get statsLevel;

  /// No description provided for @statsLevelNumber.
  ///
  /// In en, this message translates to:
  /// **'Level {level}'**
  String statsLevelNumber(int level);

  /// No description provided for @statsLongestStreak.
  ///
  /// In en, this message translates to:
  /// **'Longest streak'**
  String get statsLongestStreak;

  /// No description provided for @statsNoXpYet.
  ///
  /// In en, this message translates to:
  /// **'No XP yet. It arrives with the first tick.'**
  String get statsNoXpYet;

  /// No description provided for @statsPerHabit.
  ///
  /// In en, this message translates to:
  /// **'Per habit'**
  String get statsPerHabit;

  /// No description provided for @statsPercent.
  ///
  /// In en, this message translates to:
  /// **'{value} %'**
  String statsPercent(String value);

  /// No description provided for @statsWeeklyXp.
  ///
  /// In en, this message translates to:
  /// **'XP over recent weeks'**
  String get statsWeeklyXp;

  /// No description provided for @statsXpToNextLevel.
  ///
  /// In en, this message translates to:
  /// **'{remaining} XP to level {level} ({current} / {total})'**
  String statsXpToNextLevel(int remaining, int level, int current, int total);

  /// No description provided for @targetClean.
  ///
  /// In en, this message translates to:
  /// **'clean'**
  String get targetClean;

  /// No description provided for @targetCount.
  ///
  /// In en, this message translates to:
  /// **'{count}x'**
  String targetCount(int count);

  /// No description provided for @targetDone.
  ///
  /// In en, this message translates to:
  /// **'done'**
  String get targetDone;

  /// No description provided for @targetGrams.
  ///
  /// In en, this message translates to:
  /// **'{count} g'**
  String targetGrams(int count);

  /// No description provided for @targetKcal.
  ///
  /// In en, this message translates to:
  /// **'{count} kcal'**
  String targetKcal(int count);

  /// No description provided for @targetMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count} min'**
  String targetMinutes(int count);

  /// No description provided for @targetPages.
  ///
  /// In en, this message translates to:
  /// **'{count} pages'**
  String targetPages(int count);

  /// No description provided for @targetSteps.
  ///
  /// In en, this message translates to:
  /// **'{count} steps'**
  String targetSteps(int count);

  /// No description provided for @tier0.
  ///
  /// In en, this message translates to:
  /// **'The first 100'**
  String get tier0;

  /// No description provided for @tier1.
  ///
  /// In en, this message translates to:
  /// **'Beyond the 100'**
  String get tier1;

  /// No description provided for @tier2.
  ///
  /// In en, this message translates to:
  /// **'Three hundred'**
  String get tier2;

  /// No description provided for @tier3.
  ///
  /// In en, this message translates to:
  /// **'The year'**
  String get tier3;

  /// No description provided for @tier4.
  ///
  /// In en, this message translates to:
  /// **'Unbending'**
  String get tier4;

  /// No description provided for @tier5.
  ///
  /// In en, this message translates to:
  /// **'Legend'**
  String get tier5;

  /// No description provided for @tierNumbered.
  ///
  /// In en, this message translates to:
  /// **'Legend {rank}'**
  String tierNumbered(int rank);

  /// No description provided for @tileCheckOff.
  ///
  /// In en, this message translates to:
  /// **'Check off'**
  String get tileCheckOff;

  /// No description provided for @tileCleanToday.
  ///
  /// In en, this message translates to:
  /// **'Clean today'**
  String get tileCleanToday;

  /// No description provided for @tileDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get tileDone;

  /// No description provided for @tileDoneWith.
  ///
  /// In en, this message translates to:
  /// **'Done · {target}'**
  String tileDoneWith(String target);

  /// No description provided for @tileLogAmount.
  ///
  /// In en, this message translates to:
  /// **'Log'**
  String get tileLogAmount;

  /// No description provided for @tileRelapse.
  ///
  /// In en, this message translates to:
  /// **'Relapse'**
  String get tileRelapse;

  /// No description provided for @tileRelapseLogged.
  ///
  /// In en, this message translates to:
  /// **'Relapse logged — start again tomorrow.'**
  String get tileRelapseLogged;

  /// No description provided for @tileRestToday.
  ///
  /// In en, this message translates to:
  /// **'Rest day today per the plan'**
  String get tileRestToday;

  /// No description provided for @tileStreakBadge.
  ///
  /// In en, this message translates to:
  /// **'{streak} 🔥'**
  String tileStreakBadge(int streak);

  /// No description provided for @tileTarget.
  ///
  /// In en, this message translates to:
  /// **'Target: {target}'**
  String tileTarget(String target);

  /// No description provided for @tileUpdateAmount.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get tileUpdateAmount;

  /// No description provided for @trainingPhaseBuild.
  ///
  /// In en, this message translates to:
  /// **'Build {week}/3 · Block {block}'**
  String trainingPhaseBuild(int week, int block);

  /// No description provided for @trainingPhaseDeload.
  ///
  /// In en, this message translates to:
  /// **'Deload'**
  String get trainingPhaseDeload;

  /// No description provided for @trainingRationale.
  ///
  /// In en, this message translates to:
  /// **'{days} training days a week as \"{split}\". Three weeks of building, then a deload week — so you last 100 days without burning out.'**
  String trainingRationale(int days, String split);

  /// No description provided for @weekdayFri.
  ///
  /// In en, this message translates to:
  /// **'FRI'**
  String get weekdayFri;

  /// No description provided for @weekdayMon.
  ///
  /// In en, this message translates to:
  /// **'MON'**
  String get weekdayMon;

  /// No description provided for @weekdaySat.
  ///
  /// In en, this message translates to:
  /// **'SAT'**
  String get weekdaySat;

  /// No description provided for @weekdayShortFri.
  ///
  /// In en, this message translates to:
  /// **'Fr'**
  String get weekdayShortFri;

  /// No description provided for @weekdayShortMon.
  ///
  /// In en, this message translates to:
  /// **'Mo'**
  String get weekdayShortMon;

  /// No description provided for @weekdayShortSun.
  ///
  /// In en, this message translates to:
  /// **'Su'**
  String get weekdayShortSun;

  /// No description provided for @weekdayShortWed.
  ///
  /// In en, this message translates to:
  /// **'We'**
  String get weekdayShortWed;

  /// No description provided for @weekdaySun.
  ///
  /// In en, this message translates to:
  /// **'SUN'**
  String get weekdaySun;

  /// No description provided for @weekdayThu.
  ///
  /// In en, this message translates to:
  /// **'THU'**
  String get weekdayThu;

  /// No description provided for @weekdayTue.
  ///
  /// In en, this message translates to:
  /// **'TUE'**
  String get weekdayTue;

  /// No description provided for @weekdayWed.
  ///
  /// In en, this message translates to:
  /// **'WED'**
  String get weekdayWed;

  /// No description provided for @workoutExercises.
  ///
  /// In en, this message translates to:
  /// **'Exercises'**
  String get workoutExercises;

  /// No description provided for @workoutFullBodyA.
  ///
  /// In en, this message translates to:
  /// **'Full body A'**
  String get workoutFullBodyA;

  /// No description provided for @workoutFullBodyAFocus.
  ///
  /// In en, this message translates to:
  /// **'Knee, push, pull'**
  String get workoutFullBodyAFocus;

  /// No description provided for @workoutFullBodyB.
  ///
  /// In en, this message translates to:
  /// **'Full body B'**
  String get workoutFullBodyB;

  /// No description provided for @workoutFullBodyBFocus.
  ///
  /// In en, this message translates to:
  /// **'Hip, overhead, pull-up'**
  String get workoutFullBodyBFocus;

  /// No description provided for @workoutFullBodyC.
  ///
  /// In en, this message translates to:
  /// **'Full body C'**
  String get workoutFullBodyC;

  /// No description provided for @workoutFullBodyCFocus.
  ///
  /// In en, this message translates to:
  /// **'Single leg, push, pull'**
  String get workoutFullBodyCFocus;

  /// No description provided for @workoutIntensity.
  ///
  /// In en, this message translates to:
  /// **'Intensity'**
  String get workoutIntensity;

  /// No description provided for @workoutLegs.
  ///
  /// In en, this message translates to:
  /// **'Legs'**
  String get workoutLegs;

  /// No description provided for @workoutLegsFocus.
  ///
  /// In en, this message translates to:
  /// **'Quads, hamstrings, glutes'**
  String get workoutLegsFocus;

  /// No description provided for @workoutLower.
  ///
  /// In en, this message translates to:
  /// **'Lower body'**
  String get workoutLower;

  /// No description provided for @workoutLowerFocus.
  ///
  /// In en, this message translates to:
  /// **'Legs and core'**
  String get workoutLowerFocus;

  /// No description provided for @workoutMinutes.
  ///
  /// In en, this message translates to:
  /// **'Minutes'**
  String get workoutMinutes;

  /// No description provided for @workoutPull.
  ///
  /// In en, this message translates to:
  /// **'Pull'**
  String get workoutPull;

  /// No description provided for @workoutPullFocus.
  ///
  /// In en, this message translates to:
  /// **'Back, biceps, rear delts'**
  String get workoutPullFocus;

  /// No description provided for @workoutPush.
  ///
  /// In en, this message translates to:
  /// **'Push'**
  String get workoutPush;

  /// No description provided for @workoutPushFocus.
  ///
  /// In en, this message translates to:
  /// **'Chest, shoulders, triceps'**
  String get workoutPushFocus;

  /// No description provided for @workoutReps.
  ///
  /// In en, this message translates to:
  /// **'Reps'**
  String get workoutReps;

  /// No description provided for @workoutRest.
  ///
  /// In en, this message translates to:
  /// **'Rest'**
  String get workoutRest;

  /// No description provided for @workoutRestSeconds.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s'**
  String workoutRestSeconds(int seconds);

  /// No description provided for @workoutRpe.
  ///
  /// In en, this message translates to:
  /// **'RPE {value}'**
  String workoutRpe(String value);

  /// No description provided for @workoutRpeBody.
  ///
  /// In en, this message translates to:
  /// **'RPE 8 means: after the set you could have done two more clean reps. Pick the weight that makes that true — not the one that was in the plan last week.'**
  String get workoutRpeBody;

  /// No description provided for @workoutRpeTitle.
  ///
  /// In en, this message translates to:
  /// **'Understanding RPE'**
  String get workoutRpeTitle;

  /// No description provided for @workoutSets.
  ///
  /// In en, this message translates to:
  /// **'Sets'**
  String get workoutSets;

  /// No description provided for @workoutUpper.
  ///
  /// In en, this message translates to:
  /// **'Upper body'**
  String get workoutUpper;

  /// No description provided for @workoutUpperFocus.
  ///
  /// In en, this message translates to:
  /// **'Push and pull'**
  String get workoutUpperFocus;

  /// No description provided for @workoutWorkingSets.
  ///
  /// In en, this message translates to:
  /// **'Working sets'**
  String get workoutWorkingSets;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
