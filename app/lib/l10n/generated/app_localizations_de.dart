// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get actionCancel => 'Abbrechen';

  @override
  String get actionConnect => 'Verbinden';

  @override
  String get actionCopy => 'Kopieren';

  @override
  String get actionCopyLink => 'Link kopieren';

  @override
  String get actionDelete => 'Löschen';

  @override
  String get actionNext => 'Weiter';

  @override
  String get actionOk => 'OK';

  @override
  String get actionRemove => 'Entfernen';

  @override
  String get actionRetry => 'Nochmal versuchen';

  @override
  String get actionSave => 'Speichern';

  @override
  String get actionSend => 'Senden';

  @override
  String get actionSent => 'Gesendet';

  @override
  String get actionShare => 'Link teilen';

  @override
  String get addMealKcal => 'kcal pro Portion (optional)';

  @override
  String get addMealTitle => 'Was gibt\'s?';

  @override
  String adviceCutScope(int percent) {
    return 'Du triffst nur $percent % deiner Tage. Nimm eine Gewohnheit raus statt weiter zu scheitern — drei sichere Tage schlagen fünf geplante.';
  }

  @override
  String adviceHalveTarget(String emoji, String habit) {
    return '$emoji $habit läuft nicht. Halbier das Ziel, bis es wieder greift.';
  }

  @override
  String get adviceInviteSomeone =>
      'Du hast noch niemanden verbunden. Allein durchzuhalten ist messbar schwerer — lade jemanden ein.';

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
      other: '$days Tage',
      one: '1 Tag',
    );
    return '$emoji $habit: noch $_temp0 bis \"$milestone\".';
  }

  @override
  String adviceRaiseTarget(String emoji, String habit, int days) {
    return '$emoji $habit läuft seit $days Tagen. Erhöh das Tagesziel um 20 %.';
  }

  @override
  String get aiFreeExplainer =>
      'Ein Foto kostet etwa 1–2k Tokens, ein Wochenplan etwa 10–20k. Das Kontingent beginnt am 1. neu.';

  @override
  String get aiOwnKeyActive =>
      'Anfragen gehen direkt von deinem Handy zum Anbieter. Das Kontingent deines Kontos gilt dann nicht; der Anbieter rechnet mit dir ab.';

  @override
  String get aiOwnKeyInvalid =>
      'Mit diesem Anbieter und Modell hat der Key nicht funktioniert.';

  @override
  String get aiOwnKeyKey => 'API-Key';

  @override
  String get aiOwnKeyModel => 'Modell';

  @override
  String get aiOwnKeyModelDefault => 'Leer: Standard des Anbieters';

  @override
  String get aiOwnKeyProvider => 'Anbieter';

  @override
  String get aiOwnKeyRemove => 'Key entfernen';

  @override
  String get aiOwnKeySave => 'Prüfen und speichern';

  @override
  String get aiOwnKeySaved =>
      'Der Key funktioniert und liegt im Schlüsselbund dieses Handys.';

  @override
  String get aiOwnKeySub =>
      'Nutz dein eigenes Konto bei Google, Anthropic oder OpenAI statt des Kontingents der App.';

  @override
  String get aiOwnKeyTitle => 'Eigener API-Key';

  @override
  String get aiPaywallAction => 'Optionen ansehen';

  @override
  String get aiPaywallBody =>
      'Dein kostenloses Kontingent beginnt am 1. neu. Mit Premium oder deinem eigenen API-Key geht es sofort weiter. Alles andere in der App funktioniert wie gewohnt.';

  @override
  String get aiPaywallLater => 'Später';

  @override
  String get aiPaywallTitle => 'Die KI für diesen Monat ist aufgebraucht';

  @override
  String get aiPremiumActive => 'Premium ist aktiv. Danke!';

  @override
  String aiPremiumBuy(String price) {
    return 'Premium holen · $price';
  }

  @override
  String aiPremiumMonthly(String price) {
    return 'Monatlich · $price';
  }

  @override
  String get aiPremiumPoint1 => 'Fotos und Schätzungen, ohne zu zählen';

  @override
  String get aiPremiumPoint2 =>
      'Wochenpläne, Einkaufslisten und der Planungs-Chat für deinen Haushalt';

  @override
  String get aiPremiumPoint3 => 'Ein Coach, der deine Tageszeile schreibt';

  @override
  String get aiPremiumRenewal =>
      'Premium verlängert sich automatisch zum angezeigten Preis, bis du kündigst. Kündige spätestens 24 Stunden vor Ende eines Zeitraums in deinem App-Store- oder Google-Play-Konto.';

  @override
  String get aiPremiumRestore => 'Kauf wiederherstellen';

  @override
  String get aiPremiumSub => 'Für die KI im Alltag.';

  @override
  String get aiPremiumTitle => 'Premium';

  @override
  String get aiPremiumUnavailable =>
      'Premium ist in diesem Store noch nicht verfügbar.';

  @override
  String aiPremiumUntil(String date) {
    return 'Premium läuft bis $date.';
  }

  @override
  String aiPremiumYearly(String price) {
    return 'Jährlich · $price';
  }

  @override
  String aiProviderName(String provider) {
    String _temp0 = intl.Intl.selectLogic(provider, {
      'google': 'Google Gemini',
      'anthropic': 'Anthropic Claude',
      'openai': 'OpenAI',
      'other': '$provider',
    });
    return '$_temp0';
  }

  @override
  String get aiPurchaseDone => 'Premium ist aktiv.';

  @override
  String get aiPurchaseFailed => 'Der Kauf hat nicht geklappt.';

  @override
  String get aiPurchaseNotVerified =>
      'Der Store hat den Kauf nicht bestätigt. Es wurde nichts doppelt berechnet; versuch später „Kauf wiederherstellen“.';

  @override
  String get aiStatusFree => 'Free';

  @override
  String aiStatusOwnKey(String provider) {
    return 'Eigener Key · $provider';
  }

  @override
  String get aiStatusPremium => 'Premium';

  @override
  String get aiTitle => 'KI & Abo';

  @override
  String aiUsage(int used, int limit) {
    return '${used}k von ${limit}k Tokens diesen Monat';
  }

  @override
  String get aiUsageUnknown => 'Diesen Monat noch keine KI genutzt.';

  @override
  String get aiWhatItSeesBody =>
      'Nur, was eine Funktion braucht, in dem Moment, in dem du sie nutzt: die Mahlzeit, die du beschreibst oder fotografierst, deine Ziele und Vorlieben für einen Ernährungsplan, dein Streak und die Vornamen deiner Freunde für eine Coach-Zeile. Es geht über das Gateway der App zu Googles Gemini (oder direkt zu deinem eigenen Anbieter). Der Server der App behält nur die Zahl der Tokens im Monat.';

  @override
  String get aiWhatItSeesTitle => 'Was die KI sieht';

  @override
  String get appTitle => '100 Tage';

  @override
  String boardMilestone(int day, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days Tagen',
      one: '1 Tag',
    );
    return 'Meilenstein Tag $day in $_temp0';
  }

  @override
  String boardSummary(int done, int left) {
    return '$done geschafft · $left vor dir';
  }

  @override
  String boardTitle(int days) {
    return 'Deine $days Tage';
  }

  @override
  String cadenceEveryNDays(int days) {
    return 'Alle $days Tage';
  }

  @override
  String get cadenceManual => 'Nach Bedarf';

  @override
  String cadenceWeekly(String weekday) {
    return 'Jeden $weekday';
  }

  @override
  String get celebrateBonusCycle => 'ZYKLUS';

  @override
  String get celebrateBonusEvolution => 'EVOLUTION';

  @override
  String get celebrateBonusLevel => 'LEVEL UP';

  @override
  String get celebrateBonusMilestone => 'MEILENSTEIN';

  @override
  String get celebrateBonusPerfect => 'PERFEKT';

  @override
  String get celebrateBonusRecord => 'REKORD';

  @override
  String get celebrateContinue => 'Weiter brennen';

  @override
  String celebrateHighlightCycle(int days) {
    return 'Zyklus geschafft: $days Tage';
  }

  @override
  String celebrateHighlightEvolution(String stage) {
    return 'Neue Form: $stage';
  }

  @override
  String celebrateHighlightLevel(int level) {
    return 'Level $level erreicht';
  }

  @override
  String celebrateHighlightMilestone(int day) {
    return 'Meilenstein: Tag $day';
  }

  @override
  String celebrateHighlightPerfect(int xp) {
    return 'Perfekter Tag: +$xp XP Bonus';
  }

  @override
  String celebrateHighlightRecord(int streak) {
    String _temp0 = intl.Intl.pluralLogic(
      streak,
      locale: localeName,
      other: '$streak Tage',
      one: '1 Tag',
    );
    return 'Neuer Rekord: $_temp0';
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
      other: '$days Tagen',
      one: '1 Tag',
    );
    return 'Tag $day in $_temp0';
  }

  @override
  String get celebrateNextUp => 'Als Nächstes';

  @override
  String get celebrateReelBonus => 'BONUS';

  @override
  String get celebrateReelStreak => 'STREAK';

  @override
  String get celebrateReelXp => 'XP HEUTE';

  @override
  String get celebrateShare => 'Angeben';

  @override
  String celebrateShareText(int streak, int day) {
    String _temp0 = intl.Intl.pluralLogic(
      streak,
      locale: localeName,
      other: '🔥 $streak Tage Streak',
      one: '🔥 1 Tag Streak',
    );
    return '$_temp0, Tag $day meiner Challenge. Hol mich doch ein.';
  }

  @override
  String get celebrateSkip => 'Tippen zum Überspringen';

  @override
  String get celebrateTitle => 'TAG GESCHAFFT!';

  @override
  String cheerRespectStreak(int streak) {
    String _temp0 = intl.Intl.pluralLogic(
      streak,
      locale: localeName,
      other: 'Respekt, $streak Tage!',
      one: 'Respekt, 1 Tag!',
    );
    return '$_temp0';
  }

  @override
  String get coachBadgeLlm => 'on-device KI';

  @override
  String get coachBadgeRule => 'Coach';

  @override
  String coachCelebrateGeneric(int day) {
    return '$day Tage am Stück. Das ist der Beweis, nicht das Gefühl.';
  }

  @override
  String get coachCelebrateHabitFormed =>
      '66 Tage — der Durchschnitt, bis ein Verhalten automatisch läuft. Du bist durch.';

  @override
  String coachCelebrateHundred(String tier) {
    return 'Hundert Tage. Und jetzt kommt der Teil, für den die App gebaut ist: es hört hier nicht auf. Willkommen in \"$tier\".';
  }

  @override
  String get coachCelebrateMonth =>
      '30 Tage. Ab jetzt musst du dich weniger überreden.';

  @override
  String get coachCelebrateWeek =>
      'Eine Woche. Die meisten hören genau hier auf.';

  @override
  String get coachCelebrateYear =>
      'Ein Jahr. Das ist keine Challenge mehr, das bist du.';

  @override
  String coachEngineModel(String model) {
    return 'KI-Coach · $model';
  }

  @override
  String get coachEngineRuleBased => 'Regelbasiert';

  @override
  String coachHeadAtStake(int streak) {
    String _temp0 = intl.Intl.pluralLogic(
      streak,
      locale: localeName,
      other: '$streak Tage stehen auf dem Spiel',
      one: '1 Tag steht auf dem Spiel',
    );
    return '$_temp0';
  }

  @override
  String coachHeadCelebrate(int day) {
    return 'Tag $day 🎉';
  }

  @override
  String coachHeadDayOf(int day, int total) {
    return 'Tag $day von $total';
  }

  @override
  String get coachHeadDayStillOpen => 'Heute steht noch offen';

  @override
  String coachHeadFriendActive(String name) {
    return '$name war heute schon dran';
  }

  @override
  String coachHeadFriendsActive(int count) {
    return '$count deiner Leute waren heute schon dran';
  }

  @override
  String get coachHeadLastChance => 'Letzte Chance';

  @override
  String coachHeadLeaderAhead(String name) {
    return '$name liegt vor dir';
  }

  @override
  String get coachHeadNewDayOne => 'Neuer Tag 1';

  @override
  String coachHeadStreak(int streak) {
    String _temp0 = intl.Intl.pluralLogic(
      streak,
      locale: localeName,
      other: '$streak Tage Streak',
      one: '1 Tag Streak',
    );
    return '$_temp0';
  }

  @override
  String coachHeadTooSmooth(int streak) {
    String _temp0 = intl.Intl.pluralLogic(
      streak,
      locale: localeName,
      other: '$streak Tage — das läuft zu glatt',
      one: '1 Tag — zu glatt',
    );
    return '$_temp0';
  }

  @override
  String get coachHintAlcoholPattern =>
      'Schreib auf, wo du warst und mit wem. Das Muster ist wichtiger als der eine Abend.';

  @override
  String get coachHintDigitalTrigger =>
      'Handy heute Abend aus dem Schlafzimmer. Das ist der Trigger, nicht die Willenskraft.';

  @override
  String get coachHintSmallestVersion =>
      'Morgen die kleinste mögliche Version. Nur nicht null.';

  @override
  String get coachHintSugarBreakfast =>
      'Mehr Protein zum Frühstück. Heißhunger ist meistens ein Frühstücksproblem.';

  @override
  String coachNamesMore(String names, int count) {
    return '$names und $count weitere';
  }

  @override
  String coachNamesTwo(String first, String second) {
    return '$first und $second';
  }

  @override
  String coachPressureHoursLeft(String names) {
    return '$names waren heute schon dran. Du stehst noch auf 0. In zwei Stunden ist der Tag durch.';
  }

  @override
  String coachPressureLeaderBody(
    String emoji,
    String name,
    int peerStreak,
    int streak,
  ) {
    return '$emoji $name: $peerStreak Tage. Du: $streak. Das ist noch aufholbar — heute.';
  }

  @override
  String coachPressureLeaveIt(String names) {
    return '$names waren heute schon dran. Du stehst noch auf 0. Willst du das so stehen lassen?';
  }

  @override
  String coachPressureTheySee(String names) {
    return '$names waren heute schon dran. Du stehst noch auf 0. Die sehen deinen Feed auch.';
  }

  @override
  String get coachPressureYouLead =>
      'Du führst gerade. Führen heißt, nicht der Erste zu sein, der aufhört.';

  @override
  String coachRaiseBarHarder(int percent) {
    return 'Du triffst $percent % deiner Tage. Zeit, das Ziel härter zu machen: ein Tag mehr pro Woche oder ein höheres Tagesziel.';
  }

  @override
  String coachRaiseBarNoEffort(int percent) {
    return 'Du triffst $percent % deiner Tage. Gewohnheiten, die keine Kraft mehr kosten, bringen auch keine mehr. Erhöh eine Zahl.';
  }

  @override
  String coachRaiseBarSecondFront(int percent) {
    return 'Du triffst $percent % deiner Tage. Nimm dir eine zweite Baustelle dazu. Du hast Kapazität.';
  }

  @override
  String coachRecoverRelapse(String habit, String hint) {
    return 'Rückfall bei $habit. Das ist Teil der Kurve, nicht ihr Ende. $hint';
  }

  @override
  String get coachRecoverStreakLost =>
      'Streak ist weg, die 100 Tage sind es nicht. Der Unterschied zwischen einem Rückfall und einem Abbruch ist genau das, was du in den nächsten 24 Stunden machst.';

  @override
  String coachSteadyMilestoneConsistency(int days, int milestone) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Noch $days Tage bis Tag $milestone.',
      one: 'Noch 1 Tag bis Tag $milestone.',
    );
    return '$_temp0 Konstanz schlägt Intensität. Immer.';
  }

  @override
  String coachSteadyMilestoneNothingSpectacular(int days, int milestone) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Noch $days Tage bis Tag $milestone.',
      one: 'Noch 1 Tag bis Tag $milestone.',
    );
    return '$_temp0 Nichts Spektakuläres nötig — nur nicht aufhören.';
  }

  @override
  String coachSteadyMilestonePlanWorks(int days, int milestone) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Noch $days Tage bis Tag $milestone.',
      one: 'Noch 1 Tag bis Tag $milestone.',
    );
    return '$_temp0 Der Plan funktioniert, solange du ihn machst.';
  }

  @override
  String get coachSteadyRunning => 'Läuft. Weiter wie gestern.';

  @override
  String coachUrgentLastChance(int hours, int streak) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: 'Noch $hours Stunden.',
      one: 'Noch 1 Stunde.',
    );
    return '$_temp0 $streak Tage Arbeit gegen ein paar Minuten. Rechne selbst.';
  }

  @override
  String get coachUrgentSmallestVersion =>
      'Der Tag ist fast rum und heute fehlt noch alles. Mach die kleinste Version davon — sie zählt genauso.';

  @override
  String get coachWelcomeCheckOff =>
      'Der Anfang ist der einfachste Teil und der wichtigste. Heute nur eine Sache: abhaken.';

  @override
  String coachWelcomeNobodySees(int day) {
    return 'Niemand sieht Tag $day. Alle sehen Tag 100. Der eine geht nicht ohne den anderen.';
  }

  @override
  String coachWelcomeYourWords(String statement) {
    return 'Du hast dir vorgenommen: \"$statement\". Heute machst du den ersten Beweis daraus.';
  }

  @override
  String get ctaAdjustGoal => 'Ziel anpassen';

  @override
  String get ctaCheckInNow => 'Jetzt abhaken';

  @override
  String get ctaKeepGoing => 'Weitermachen';

  @override
  String get ctaRescue => 'Retten';

  @override
  String get ctaRestart => 'Neu starten';

  @override
  String get ctaShare => 'Teilen';

  @override
  String get dayDone => 'Tag geschafft';

  @override
  String get dayFrozen => 'Eingefroren';

  @override
  String get dayMissed => 'Verpasst';

  @override
  String get dayNotLogged => 'Nicht eingetragen';

  @override
  String get dayOpen => 'Noch offen';

  @override
  String get dayRest => 'Pausentag';

  @override
  String get dayUpcoming => 'Kommt noch';

  @override
  String get diaryClose => 'Tag abschließen';

  @override
  String get diaryCloseOnTarget => 'Tag abschließen — im Ziel';

  @override
  String get diaryClosedPlain => 'Tag abgehakt.';

  @override
  String get diaryClosedTracked =>
      'Tag im Ziel abgeschlossen — getrackt, mit Plan-Bonus.';

  @override
  String diaryEatenOfTarget(int eaten, int target) {
    return '$eaten von $target kcal gegessen';
  }

  @override
  String diaryEntryKcal(int kcal) {
    return '$kcal kcal';
  }

  @override
  String get diaryKcalLeft => 'kcal übrig';

  @override
  String get diaryKcalOver => 'kcal drüber';

  @override
  String diaryMealKcal(int eaten, int target) {
    return '$eaten / $target kcal';
  }

  @override
  String diaryOffTargetBody(int delta) {
    return 'Du liegst $delta kcal neben deinem Ziel. Du kannst den Tag trotzdem abhaken — nur ohne Plan-Bonus.';
  }

  @override
  String get diaryOffTargetConfirm => 'Trotzdem abhaken';

  @override
  String get diaryOffTargetTitle => 'Nicht ganz im Ziel';

  @override
  String get diarySuggestions => 'IDEEN, DIE PASSEN';

  @override
  String get diaryTitle => 'Ernährungstagebuch';

  @override
  String get diaryToday => 'Heute';

  @override
  String get dietOmnivore => 'Alles';

  @override
  String get dietVegan => 'Vegan';

  @override
  String get dietVegetarian => 'Vegetarisch';

  @override
  String get editorAddExercise => 'Übung hinzufügen';

  @override
  String get editorDaysNote =>
      'Gilt ab heute — vergangene Tage bleiben, wie sie waren.';

  @override
  String get editorMoveDown => 'Nach unten';

  @override
  String get editorMoveUp => 'Nach oben';

  @override
  String get editorRepsHigh => 'Wiederholungen, oben';

  @override
  String get editorRepsLow => 'Wiederholungen, unten';

  @override
  String get editorReset => 'Vorschlag wiederherstellen';

  @override
  String get editorRest => 'Pause';

  @override
  String get editorRir => 'Reserve (RIR)';

  @override
  String get editorRirHelp =>
      'RIR 2 heißt: zwei saubere Wiederholungen vor dem Muskelversagen aufhören. Weniger ist härter.';

  @override
  String get editorSaved => 'Trainingsplan gespeichert';

  @override
  String get editorSessionEmpty => 'Noch keine Übung — füge eine hinzu.';

  @override
  String get editorSessionsSubtitle =>
      'Tippe auf eine Übung, um Sätze, Wiederholungen und Reserve zu ändern oder sie zu tauschen.';

  @override
  String get editorSessionsTitle => 'Übungen je Einheit';

  @override
  String get editorSets => 'Sätze';

  @override
  String editorSetsReps(int sets, String reps, int rir) {
    return '$sets × $reps · RIR $rir';
  }

  @override
  String get editorSplitTitle => 'Split';

  @override
  String get editorSwap => 'Tauschen gegen';

  @override
  String get editorTitle => 'Trainingsplan bearbeiten';

  @override
  String errorGeneric(String message) {
    return 'Fehler: $message';
  }

  @override
  String get evolutionCurrent => 'Du bist hier';

  @override
  String get evolutionLocked => 'Gesperrt';

  @override
  String get evolutionOpen => 'Alle Formen ansehen';

  @override
  String get evolutionSubtitle =>
      'Dein Streak bestimmt die Form. Ein Abbruch nimmt sie dir wieder.';

  @override
  String get evolutionTitle => 'Flammen-Evolution';

  @override
  String get evolutionUnlocked => 'Freigeschaltet';

  @override
  String get exerciseAbWheel => 'Bauchroller';

  @override
  String get exerciseArnoldPress => 'Arnold Press';

  @override
  String get exerciseAssistedPullup => 'Klimmzug mit Unterstützung';

  @override
  String get exerciseBackExtension => 'Rückenstrecker (Hyperextension)';

  @override
  String get exerciseBackSquat => 'Kniebeuge (Langhantel)';

  @override
  String get exerciseBandPulldown => 'Latzug mit Band';

  @override
  String get exerciseBarbellRow => 'Langhantelrudern';

  @override
  String get exerciseBenchPress => 'Bankdrücken';

  @override
  String get exerciseBicepsCurl => 'Bizepscurls';

  @override
  String get exerciseBulgarianSplitSquat => 'Bulgarian Split Squat';

  @override
  String get exerciseBurpee => 'Burpees';

  @override
  String get exerciseBwSquat => 'Körpergewicht-Kniebeuge';

  @override
  String get exerciseCableCrunch => 'Kabel-Crunch';

  @override
  String get exerciseCableCurl => 'Bizepscurls am Kabel';

  @override
  String get exerciseCableFly => 'Kabelzug-Fliegende';

  @override
  String get exerciseCableLateralRaise => 'Seitheben am Kabel';

  @override
  String get exerciseCableRow => 'Rudern am Kabelzug';

  @override
  String get exerciseCalfRaise => 'Wadenheben';

  @override
  String get exerciseChestPressMachine => 'Brustpresse';

  @override
  String get exerciseChestSupportedRow => 'Rudern mit Brustauflage';

  @override
  String get exerciseChinUp => 'Klimmzug im Untergriff';

  @override
  String get exerciseCueBackSquat =>
      'Brust hoch, Knie über die Fußspitzen, kontrolliert runter.';

  @override
  String get exerciseCueBenchPress =>
      'Schulterblätter zusammen, Stange zur unteren Brust.';

  @override
  String get exerciseCueBwSquat => 'Langsam runter, unten kurz halten.';

  @override
  String get exerciseCueDeadlift =>
      'Rücken gerade, Hantel am Schienbein entlang.';

  @override
  String get exerciseCueGobletSquat =>
      'Kurzhantel vor der Brust, tief und aufrecht.';

  @override
  String get exerciseCuePullup => 'Schultern runter, Brust zur Stange.';

  @override
  String get exerciseCuePushup => 'Körper bleibt ein Brett, Ellbogen 45 Grad.';

  @override
  String get exerciseCueRdl =>
      'Hüfte nach hinten, Dehnung in den Beinbeugern spüren.';

  @override
  String get exerciseDbBench => 'Kurzhantel-Bankdrücken';

  @override
  String get exerciseDbFly => 'Fliegende (Kurzhantel)';

  @override
  String get exerciseDbOhp => 'Schulterdrücken (Kurzhantel)';

  @override
  String get exerciseDbRow => 'Kurzhantelrudern';

  @override
  String get exerciseDeadBug => 'Dead Bug';

  @override
  String get exerciseDeadlift => 'Kreuzheben';

  @override
  String get exerciseDiamondPushup => 'Diamond Push-up';

  @override
  String get exerciseDip => 'Dips';

  @override
  String get exerciseFacePull => 'Face Pull';

  @override
  String get exerciseFarmersWalk => 'Farmer\'s Walk';

  @override
  String get exerciseFrontSquat => 'Frontkniebeuge';

  @override
  String get exerciseGluteBridge => 'Glute Bridge';

  @override
  String get exerciseGobletSquat => 'Goblet Squat';

  @override
  String get exerciseHackSquat => 'Hackenschmidt-Kniebeuge';

  @override
  String get exerciseHammerCurl => 'Hammercurls';

  @override
  String get exerciseHangingLegRaise => 'Hängendes Beinheben';

  @override
  String get exerciseHipAbduction => 'Abduktorenmaschine';

  @override
  String get exerciseHipThrust => 'Hip Thrust';

  @override
  String get exerciseInclineBench => 'Schrägbankdrücken';

  @override
  String get exerciseInclineDbPress => 'Schrägbankdrücken (Kurzhantel)';

  @override
  String get exerciseInvertedRow => 'Australian Pull-up';

  @override
  String get exerciseJumpRope => 'Seilspringen';

  @override
  String get exerciseKbSwing => 'Kettlebell Swing';

  @override
  String get exerciseLatPulldown => 'Latzug';

  @override
  String get exerciseLateralRaise => 'Seitheben';

  @override
  String get exerciseLegCurl => 'Beinbeuger';

  @override
  String get exerciseLegExtension => 'Beinstrecker';

  @override
  String get exerciseLegPress => 'Beinpresse';

  @override
  String get exerciseMachineShoulderPress => 'Schulterpresse';

  @override
  String get exerciseNordicCurl => 'Nordic Curl (assistiert)';

  @override
  String get exerciseOhp => 'Schulterdrücken (Langhantel)';

  @override
  String get exerciseOverheadTricepsExtension => 'Trizepsstrecken über Kopf';

  @override
  String get exercisePecDeck => 'Butterfly-Maschine';

  @override
  String get exercisePikePushup => 'Pike Push-up';

  @override
  String get exercisePlank => 'Unterarmstütz';

  @override
  String get exercisePreacherCurl => 'Scottcurls';

  @override
  String get exercisePullup => 'Klimmzug';

  @override
  String get exercisePushup => 'Liegestütz';

  @override
  String get exerciseRdl => 'Rumänisches Kreuzheben';

  @override
  String get exerciseRearDeltFly => 'Reverse Flys';

  @override
  String get exerciseRowingErg => 'Rudergerät';

  @override
  String get exerciseSeatedCalfRaise => 'Wadenheben sitzend';

  @override
  String get exerciseSkullCrusher => 'French Press (SZ-Stange)';

  @override
  String get exerciseStepUp => 'Step-up';

  @override
  String get exerciseTBarRow => 'T-Bar-Rudern';

  @override
  String get exerciseTricepsPushdown => 'Trizepsdrücken am Kabel';

  @override
  String get exerciseWalkingLunge => 'Ausfallschritte';

  @override
  String feedAscended(String name) {
    return '$name ist auf die nächste Stufe';
  }

  @override
  String feedAscendedDetail(String tier) {
    return 'Neue Stufe: $tier';
  }

  @override
  String feedBackfilled(String date) {
    return 'nachgetragen für $date';
  }

  @override
  String get feedBackfilledBadge => 'nachgetragen';

  @override
  String feedCheckIn(String name, String habit) {
    return '$name: $habit erledigt';
  }

  @override
  String get feedCheer => 'Feiern';

  @override
  String feedCheerReceived(String name) {
    return '$name feiert dich';
  }

  @override
  String feedCheerSent(String name) {
    return 'Du hast $name gefeiert';
  }

  @override
  String get feedCheered => 'Gefeiert';

  @override
  String get feedEmptyBody =>
      'Sobald du oder deine Freunde etwas abhaken, steht es hier.';

  @override
  String get feedEmptyTitle => 'Noch nichts im Feed';

  @override
  String feedNudgeReceived(String name) {
    return '$name stupst dich an';
  }

  @override
  String feedNudgeSent(String name) {
    return 'Du hast $name angestupst';
  }

  @override
  String feedRelapse(String name, String habit) {
    return '$name hatte einen Rückfall bei $habit';
  }

  @override
  String get feedSomeone => 'jemanden';

  @override
  String feedStarted(String name) {
    return '$name hat die Challenge gestartet';
  }

  @override
  String feedStreakDetail(int streak) {
    String _temp0 = intl.Intl.pluralLogic(
      streak,
      locale: localeName,
      other: '$streak Tage Streak',
      one: '1 Tag Streak',
    );
    return '$_temp0';
  }

  @override
  String get feedVerified => 'verifiziert';

  @override
  String feedWorkout(String name, String workout) {
    return '$name: $workout erledigt';
  }

  @override
  String feedWorkoutDetail(int sets, String tonnes) {
    return '$sets Sätze · $tonnes t bewegt';
  }

  @override
  String get findAdd => 'Hinzufügen';

  @override
  String get findAlreadyFriends => 'Befreundet';

  @override
  String get findAlsoFindMe => 'Meine Kontakte dürfen mich auch finden';

  @override
  String get findAlsoFindMeSub =>
      'Über deine bestätigte E-Mail-Adresse. Abschalten geht in den Einstellungen.';

  @override
  String get findContactsAction => 'Kontakte durchsuchen';

  @override
  String get findContactsDenied =>
      'Ohne Zugriff auf die Kontakte geht das nicht. Such per Name oder schick einen Link.';

  @override
  String get findContactsNone =>
      'Noch keiner deiner Kontakte ist auffindbar. Schick ihnen einen Link!';

  @override
  String get findContactsSub =>
      'Telefonnummern und E-Mail-Adressen werden auf dem Server als verschlüsselte Hashes verglichen und nicht gespeichert. Es erscheint nur, wer auffindbar sein will.';

  @override
  String get findContactsTitle => 'Aus deinen Kontakten';

  @override
  String get findInviteTitle => 'Oder einladen';

  @override
  String get findNoResults =>
      'Niemand gefunden. Per Name findbar ist, wer sich einen Benutzernamen gegeben hat.';

  @override
  String get findRequested => 'Angefragt';

  @override
  String get findSearchHint => 'Name oder @benutzername';

  @override
  String get findTitle => 'Freunde finden';

  @override
  String foodAddAll(int count, int kcal) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Einträge hinzufügen · $kcal kcal',
      one: '1 Eintrag hinzufügen · $kcal kcal',
    );
    return '$_temp0';
  }

  @override
  String foodAddTo(String meal) {
    return 'Zu $meal hinzufügen';
  }

  @override
  String foodAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Einträge eingetragen',
      one: 'Im Tagebuch eingetragen',
    );
    return '$_temp0';
  }

  @override
  String get foodAiFailed =>
      'Damit konnte das Modell nichts anfangen. Versuch es einfacher oder trag es manuell ein.';

  @override
  String get foodAiNotInstalled =>
      'Erkennt Lebensmittel aus der Tabelle. Mit der KI (Einstellungen → KI) schätzt es auch Gerichte, die es nicht kennt.';

  @override
  String get foodAmountLabel => 'Menge';

  @override
  String foodAmountPiece(int grams) {
    return '1 Stück ($grams g)';
  }

  @override
  String foodAmountPortion(int grams) {
    return 'Portion ($grams g)';
  }

  @override
  String foodAmountResult(int kcal, int protein, int carbs, int fat) {
    return '$kcal kcal · $protein g Eiweiß · $carbs g KH · $fat g Fett';
  }

  @override
  String get foodAskAi => 'Mit KI schätzen';

  @override
  String get foodBarcodeLabel => 'Oder Barcode-Nummer (EAN) eintippen';

  @override
  String get foodBarcodeNoNutrition =>
      'Produkt gefunden, aber ohne Nährwerte. Trag es manuell ein.';

  @override
  String get foodBarcodeNotFound =>
      'Dieses Produkt ist noch nicht in Open Food Facts. Trag es manuell ein — die Werte stehen auf der Packung.';

  @override
  String get foodBarcodeOffline =>
      'Keine Verbindung zu Open Food Facts. Versuch es später nochmal oder trag es manuell ein.';

  @override
  String get foodBarcodePrivacy =>
      'Die Abfrage schickt nur die Barcode-Nummer an Open Food Facts, die offene Produktdatenbank — kein Konto, kein Tagebuch, nichts über dich.';

  @override
  String get foodDescribeHint =>
      'Was hast du gegessen? z. B. „2 Eier, eine Scheibe Vollkornbrot und ein Cappuccino“';

  @override
  String get foodManualAdd => 'Hinzufügen';

  @override
  String get foodManualCarbs => 'Kohlenhydrate in g (optional)';

  @override
  String get foodManualFat => 'Fett in g (optional)';

  @override
  String get foodManualGrams => 'Menge in g (optional)';

  @override
  String get foodManualKcal => 'Kalorien (kcal)';

  @override
  String get foodManualName => 'Name';

  @override
  String get foodManualProtein => 'Eiweiß in g (optional)';

  @override
  String foodNotRecognised(String items) {
    return 'Nicht erkannt: $items. Lass sie von der KI schätzen, such sie oder trag sie manuell ein.';
  }

  @override
  String foodPer100(int kcal, int protein, int carbs, int fat) {
    return '$kcal kcal · $protein g E · $carbs g K · $fat g F pro 100 g';
  }

  @override
  String get foodPhotoCamera => 'Kamera';

  @override
  String get foodPhotoCheck =>
      'Schätzung vom Foto. Prüf die Mengen, bevor du sie einträgst.';

  @override
  String get foodPhotoFailed =>
      'Auf dem Foto wurde nichts erkannt. Versuch es mit dem ganzen Teller im Bild oder beschreib es.';

  @override
  String get foodPhotoGallery => 'Galerie';

  @override
  String get foodPhotoHint => 'Noch etwas dazu? z. B. nur die Hälfte';

  @override
  String get foodPhotoIntro =>
      'Fotografier deine Mahlzeit. Die KI schätzt Lebensmittel und Mengen; du prüfst sie, bevor etwas im Tagebuch landet. Das Foto wird verkleinert, ohne Standort- und Kameradaten verschickt und nicht gespeichert.';

  @override
  String get foodPhotoNeedsAi =>
      'Die KI schätzt, was drauf ist. Dafür anmelden oder unter Einstellungen → KI einen eigenen Key hinterlegen.';

  @override
  String get foodPhotoTitle => 'Ein Foto von deinem Teller';

  @override
  String get foodPhotoWorking => 'Schaue mir deinen Teller an …';

  @override
  String get foodRecent => 'Zuletzt eingetragen';

  @override
  String get foodRecognise => 'Erkennen';

  @override
  String get foodScanButton => 'Barcode scannen';

  @override
  String get foodScanCameraUnavailable =>
      'Die Kamera ist nicht verfügbar. Tipp die Barcode-Nummer stattdessen ein.';

  @override
  String get foodScanHint => 'Halte den Barcode in den Rahmen.';

  @override
  String get foodScanTitle => 'Produkt scannen';

  @override
  String get foodSearchHint =>
      'Lebensmittel, z. B. Haferflocken, Banane, Pizza';

  @override
  String get foodSearchNothing =>
      'Nichts in der Lebensmitteltabelle. Beschreib es lieber, scanne den Barcode oder trag die Werte selbst ein.';

  @override
  String get foodSourceAi => 'KI-Schätzung';

  @override
  String get foodSourceBarcode => 'Packungsangabe';

  @override
  String get foodSourceDatabase => 'Lebensmitteltabelle';

  @override
  String get foodSourceManual => 'eingetragen';

  @override
  String get foodSourceParsed => 'erkannt';

  @override
  String get foodSourcePhoto => 'Foto-Schätzung';

  @override
  String get foodSourcePlan => 'wie geplant';

  @override
  String get foodTabBarcode => 'Barcode';

  @override
  String get foodTabDescribe => 'Beschreiben';

  @override
  String get foodTabManual => 'Manuell';

  @override
  String get foodTabPhoto => 'Foto';

  @override
  String get foodTabSearch => 'Suchen';

  @override
  String friendsConnected(String name) {
    return 'Du und $name seid jetzt befreundet.';
  }

  @override
  String friendsDayNumber(int day) {
    return 'Tag $day';
  }

  @override
  String get friendsEmptyBody =>
      'Die App funktioniert allein, aber sie wirkt erst, wenn jemand zuschaut. Schick einem Freund deine Einladung.';

  @override
  String get friendsEmptyTitle => 'Noch niemand verbunden';

  @override
  String get friendsFallbackName => 'Freund';

  @override
  String get friendsInvite => 'Einladen';

  @override
  String get friendsLeagueSection => 'Unter Freunden';

  @override
  String get friendsNetworkNote =>
      'Freunde sehen, was du teilst: deinen Streak, geteilte Gewohnheiten und auf Wunsch deine Trainings. Körperdaten, Ziele und das Ernährungstagebuch bleiben privat; der Server gibt sie nur dir.';

  @override
  String get friendsNoActivity => 'Noch keine Aktivität';

  @override
  String get friendsNudgeSection => 'Anstupsen';

  @override
  String get friendsNudgeSubtitle => 'Die hier waren heute noch nicht dran.';

  @override
  String get friendsRequestAccept => 'Annehmen';

  @override
  String get friendsRequestDecline => 'Ablehnen';

  @override
  String friendsRequestFrom(String name) {
    return '$name';
  }

  @override
  String get friendsRequestsSub => 'Geteilt wird erst, wenn du annimmst.';

  @override
  String get friendsRequestsTitle => 'Freundschaftsanfragen';

  @override
  String get friendsScan => 'Scannen';

  @override
  String get friendsYourPeople => 'Deine Leute';

  @override
  String get globalLeagueEmpty =>
      'Deine Liga-Gruppe beginnt mit deinem ersten Check-in diese Woche: bis zu 30 Leute deiner Division, die Besten steigen am Montag auf.';

  @override
  String get globalLeagueHonesty =>
      'Die XP von Fremden meldet deren Handy, pro Tag gedeckelt. Unter Freunden rechnet jedes Handy die XP aus den geteilten Check-ins nach.';

  @override
  String get globalLeagueSection => 'Liga dieser Woche';

  @override
  String globalLeagueSub(int size, int up, int down) {
    return '$size Leute · Top $up steigen auf, letzte $down ab';
  }

  @override
  String globalLeagueXp(int xp) {
    return '$xp XP';
  }

  @override
  String get goalBuildMuscle => 'Muskeln aufbauen';

  @override
  String get goalBuildMusclePitch =>
      'Schwerer werden, stärker werden. Plan, Protein, Progression.';

  @override
  String get goalClarity => 'Kopf frei kriegen';

  @override
  String get goalClarityPitch =>
      'Dopamin runter, Fokus rauf. Weniger Reiz, mehr Substanz.';

  @override
  String get goalCustom => 'Eigenes Ziel';

  @override
  String get goalCustomPitch =>
      'Du weißt selbst, was ansteht. Bau dir den Plan.';

  @override
  String get goalDiscipline => 'Disziplin aufbauen';

  @override
  String get goalDisciplinePitch =>
      '100 Tage nicht verhandeln. Der Streak ist das Ziel.';

  @override
  String get goalGetFit => 'Fit werden';

  @override
  String get goalGetFitPitch =>
      'Kondition, Kraft, Beweglichkeit. Zurück in Form.';

  @override
  String get goalLoseFat => 'Fett verlieren';

  @override
  String get goalLoseFatPitch =>
      'Defizit halten, Muskeln behalten, Woche für Woche.';

  @override
  String get goalSober => 'Clean bleiben';

  @override
  String get goalSoberPitch =>
      'Alkohol, Nikotin, Zucker — jeder Tag zählt einzeln.';

  @override
  String get goalsAiApply => 'Übernehmen';

  @override
  String get goalsAiAsk => 'Vorschlag holen';

  @override
  String get goalsAiFailed =>
      'Kein brauchbarer Vorschlag. Formulier es anders — oder stell die Zahlen oben selbst ein.';

  @override
  String get goalsAiHint =>
      'z. B. „weniger Kohlenhydrate, ich trainiere abends“';

  @override
  String goalsAiProposal(int kcal, int protein, int carbs, int fat) {
    return '$kcal kcal · $protein % Eiweiß · $carbs % KH · $fat % Fett';
  }

  @override
  String get goalsAiSub =>
      'Beschreib, was du willst; die KI schlägt neue Ziele vor. Nichts ändert sich, bis du es übernimmst.';

  @override
  String get goalsAiTitle => 'Mit KI anpassen';

  @override
  String get goalsAiUnavailable => 'Braucht die KI, siehe Einstellungen → KI.';

  @override
  String get goalsBodySub =>
      'Nur für den Zielvorschlag. Sie sind privat und werden nie geteilt.';

  @override
  String get goalsBodyTitle => 'Körperdaten';

  @override
  String goalsFatRest(int percent) {
    return 'Fett: $percent % (der Rest)';
  }

  @override
  String get goalsMacroTitle => 'Makro-Verteilung';

  @override
  String get goalsOwnTarget => 'Eigenes Ziel festlegen';

  @override
  String get goalsOwnTargetSub =>
      'Deine Zahl gilt. Die Empfehlung bleibt daneben sichtbar.';

  @override
  String get goalsSaved => 'Ziele gespeichert';

  @override
  String goalsSuggested(int kcal) {
    return 'Empfohlen: $kcal kcal pro Tag';
  }

  @override
  String get goalsTargetTitle => 'Tagesziel';

  @override
  String get goalsTitle => 'Ernährungsziele';

  @override
  String get goalsTooLow =>
      'Das liegt mehr als 25 % unter deinem Verbrauch. So steile Defizite kosten Muskeln und Schlaf — kaum jemand hält damit 100 Tage durch.';

  @override
  String get habitCardio => 'Cardio';

  @override
  String get habitCardioBlurb =>
      'Ausdauer im lockeren Bereich. Zone 2, nicht kaputt machen.';

  @override
  String get habitColdShower => 'Kalt duschen';

  @override
  String get habitColdShowerBlurb =>
      'Zwei Minuten kalt. Jeden Morgen die erste Entscheidung gewinnen.';

  @override
  String get habitCustom => 'Eigene Gewohnheit';

  @override
  String get habitCustomBlurb => 'Dein Ding. Du definierst, was zählt.';

  @override
  String get habitDopamineDetox => 'Dopamin-Detox';

  @override
  String get habitDopamineDetoxBlurb =>
      'Kein Endlos-Scrollen, keine Shorts, kein Binge-Watching.';

  @override
  String get habitGym => 'Training';

  @override
  String get habitGymBlurb =>
      'Krafttraining nach Plan. Progressive Überlastung, kein Zufall.';

  @override
  String get habitJournaling => 'Journaling';

  @override
  String get habitJournalingBlurb =>
      'Drei Sätze reichen. Kopf leeren, Muster sehen.';

  @override
  String get habitMeditation => 'Meditation';

  @override
  String get habitMeditationBlurb => 'Still sitzen, atmen, aushalten.';

  @override
  String get habitNoAlcohol => 'Kein Alkohol';

  @override
  String get habitNoAlcoholBlurb => 'Null Alkohol. Kein \"nur ein Bier\".';

  @override
  String get habitNoFap => 'NoFap';

  @override
  String get habitNoFapBlurb =>
      'Kein Porno, kein Rückfall. Streak zählt jeden Tag.';

  @override
  String get habitNoNicotine => 'Kein Nikotin';

  @override
  String get habitNoNicotineBlurb => 'Keine Zigarette, kein Vape, kein Snus.';

  @override
  String get habitNoSugar => 'Kein Zucker';

  @override
  String get habitNoSugarBlurb => 'Kein zugesetzter Zucker. Obst ist erlaubt.';

  @override
  String get habitNutrition => 'Ernährung';

  @override
  String get habitNutritionBlurb => 'Kalorien- und Proteinziel getroffen.';

  @override
  String get habitReading => 'Lesen';

  @override
  String get habitReadingBlurb =>
      'Echte Seiten, echtes Buch. Feed liest sich nicht selbst.';

  @override
  String get habitSleep => 'Schlaf';

  @override
  String get habitSleepBlurb =>
      'Mindestens 7,5 Stunden. Der Rest baut darauf auf.';

  @override
  String get habitWater => 'Wasser';

  @override
  String get habitWaterBlurb =>
      'Acht Gläser. Das Billigste, was du für dich tun kannst.';

  @override
  String get heatLess => 'weniger';

  @override
  String get heatMore => 'mehr';

  @override
  String heroBest(int days) {
    return 'Rekord: $days';
  }

  @override
  String heroCountdownFirst(String time) {
    return 'Noch $time für den ersten Funken';
  }

  @override
  String heroCountdownSave(String time) {
    return 'Noch $time, um deinen Streak zu retten';
  }

  @override
  String get heroFedToday => 'Heute gefüttert. Bis morgen.';

  @override
  String get heroFrozen => 'Heute eingefroren. Der Streak hält.';

  @override
  String get heroRelapse =>
      'Rückfall eingetragen. Morgen gibt es einen neuen Funken.';

  @override
  String get heroRestDay => 'Pausentag. Der Streak wartet.';

  @override
  String get heroThisWeek => 'Diese Woche';

  @override
  String homeAscendAction(String tier) {
    return 'Weiter zu $tier';
  }

  @override
  String homeAscendBody(String emoji, String tier) {
    return 'Hier hören die meisten Apps auf. Deine nächste Stufe: $emoji $tier. Streak, XP und Historie bleiben.';
  }

  @override
  String homeAscendTitle(int days) {
    return 'Zyklus geschafft: $days Tage.';
  }

  @override
  String homeCheckInToast(String emoji, String habit) {
    return '$emoji $habit eingetragen.';
  }

  @override
  String get homeCheckOffToday => 'Heute abhaken';

  @override
  String homeDayCompleteToast(int streak) {
    return '🔥 Tag komplett — Streak steht bei $streak.';
  }

  @override
  String homeDayOfTotal(int day, int total) {
    return 'Tag $day / $total';
  }

  @override
  String homeDoneOfTotal(int done, int total) {
    return '$done von $total erledigt';
  }

  @override
  String homeExercisesCount(int count) {
    return '$count Übungen';
  }

  @override
  String homeFreezeBody(int count) {
    return 'Noch $count übrig. Rettet den Streak, zählt aber nicht als erledigter Tag.';
  }

  @override
  String get homeFreezeTitle => 'Streak einfrieren';

  @override
  String get homeFreezeUse => 'Nutzen';

  @override
  String homeLevelAndTier(String emoji, String tier, int level) {
    return '$emoji $tier · Level $level';
  }

  @override
  String homeMinutesApprox(int count) {
    return '≈ $count Min';
  }

  @override
  String get homeOpenDiary => 'Ernährungstagebuch öffnen';

  @override
  String get homeOptional => 'Freiwillig';

  @override
  String get homeOptionalSubtitle =>
      'Heute nicht eingeplant — zählt trotzdem als XP.';

  @override
  String get homeQuestsTitle => 'Quests für heute';

  @override
  String get homeRelapseBody =>
      'Das setzt den Streak zurück und ist für deine Freunde sichtbar. Ehrlich bleiben ist der ganze Sinn — aber nur, wenn es stimmt.';

  @override
  String get homeRelapseConfirm => 'Eintragen';

  @override
  String homeRelapseTitle(String habit) {
    return 'Rückfall bei $habit?';
  }

  @override
  String get homeRestDay => 'Heute steht nichts an — Pausentag laut Plan.';

  @override
  String homeSetsCount(int count) {
    return '$count Sätze';
  }

  @override
  String homeStartWorkout(int percent) {
    return 'Training starten · +$percent % XP';
  }

  @override
  String get homeStorageError => 'Die App konnte ihren Speicher nicht öffnen.';

  @override
  String homeStreakDays(int streak) {
    String _temp0 = intl.Intl.pluralLogic(
      streak,
      locale: localeName,
      other: 'Tage Streak',
      one: 'Tag Streak',
    );
    return '$_temp0';
  }

  @override
  String get homeTodaysMacros => 'Heutige Makros';

  @override
  String get homeTodaysWorkout => 'Heutiges Training';

  @override
  String get homeWorkoutLogged => 'Heute geloggt';

  @override
  String homeXp(int xp) {
    return '$xp XP';
  }

  @override
  String get householdAllergies => 'Allergien & Unverträglichkeiten';

  @override
  String get householdDiet => 'Ernährungsweise';

  @override
  String get householdDietHint => 'z. B. vegetarisch';

  @override
  String get householdDislikes => 'Mag nicht';

  @override
  String get householdInviteShort => 'Einladen';

  @override
  String get householdInviteTitle => 'In den Haushalt einladen';

  @override
  String get householdJoin => 'Einem Haushalt beitreten';

  @override
  String get householdJoinAction => 'Beitreten';

  @override
  String get householdJoinBody =>
      'Ihr teilt Essensplan und Einkaufsliste. Dein Tagebuch bleibt privat, deine Ziele auch, außer du teilst sie.';

  @override
  String householdJoinTitle(String name) {
    return '$name beitreten?';
  }

  @override
  String get householdJoined => 'Du bist drin. Der Plan ist jetzt geteilt.';

  @override
  String get householdJustYou =>
      'Nur du. Lade jemanden zum gemeinsamen Planen ein';

  @override
  String get householdListHint => 'mit Komma getrennt';

  @override
  String get householdMeSub =>
      'Damit, wer plant, deine Portionen passend macht und weglässt, was du nicht isst.';

  @override
  String get householdMeTitle => 'Du im Haushalt';

  @override
  String householdMembers(int count) {
    return '$count Personen';
  }

  @override
  String get householdMembersTitle => 'Wer zusammen kocht und einkauft';

  @override
  String get householdNoTarget => 'Ziele privat, je eine Portion';

  @override
  String get householdPantry => 'Meistens zuhause';

  @override
  String get householdPantryHint =>
      'Salz, Öl, Pfeffer: kommt nicht auf erzeugte Listen';

  @override
  String get householdSaved => 'Für den Haushalt gespeichert.';

  @override
  String get householdShareTargets => 'Meine Ziele mit dem Haushalt teilen';

  @override
  String get householdShareTargetsNoPlan =>
      'Schalte zuerst den Ernährungsplan ein, damit es Ziele zum Teilen gibt.';

  @override
  String householdShareTargetsSub(int kcal, int protein) {
    return '$kcal kcal und $protein g Eiweiß am Tag. Nur diese zwei Zahlen.';
  }

  @override
  String householdShareText(String link, String code) {
    return 'Plan unser Essen mit mir in 100 Days: $link (oder gib den Haushalts-Code $code ein)';
  }

  @override
  String householdSharesTarget(int kcal) {
    return 'Teilt Ziele · $kcal kcal am Tag';
  }

  @override
  String get householdShoppingTitle => 'Wann ihr einkauft';

  @override
  String get householdTitle => 'Haushalt';

  @override
  String householdYou(String name) {
    return '$name (du)';
  }

  @override
  String inviteAlreadyFriends(String name) {
    return 'Du und $name seid schon befreundet.';
  }

  @override
  String get inviteCodeHint => 'z. B. K7QM4 TX29P';

  @override
  String get inviteConfirmAction => 'Befreunden';

  @override
  String get inviteConfirmBody =>
      'Ihr seht gegenseitig Streak, geteilte Gewohnheiten und Trainings. Körperdaten und Ernährungstagebücher bleiben privat.';

  @override
  String inviteConfirmTitle(String name) {
    return 'Mit $name befreunden?';
  }

  @override
  String get inviteEnterCode => 'Code eingeben';

  @override
  String get inviteErrorMalformed => 'Diese Einladung ist ungültig.';

  @override
  String get inviteErrorOffline =>
      'Keine Verbindung zum Server. Versuch es gleich noch einmal.';

  @override
  String get inviteErrorSelf => 'Das bist du selbst.';

  @override
  String get inviteHowTitle => 'Wie das funktioniert';

  @override
  String get inviteLinkCopied => 'Link kopiert.';

  @override
  String get inviteRevoke => 'Neuer Code (der alte gilt dann nicht mehr)';

  @override
  String get inviteRevoked =>
      'Neuer Code ist da. Der alte funktioniert nicht mehr.';

  @override
  String get inviteShareSubject => '100 Tage Challenge';

  @override
  String inviteShareText(String link, String code) {
    return 'Mach die 100 Tage mit mir: $link (oder gib in der App den Code $code ein)';
  }

  @override
  String get inviteStep1 =>
      'Dein Gegenüber scannt den Code, öffnet den Link oder tippt den Code ein.';

  @override
  String get inviteStep2 =>
      'Ihr seid sofort befreundet, denn das Teilen des Codes ist dein Ja. Er gilt 14 Tage.';

  @override
  String get inviteStep3 =>
      'Ab dann seht ihr euren Tag gegenseitig live, egal wo ihr seid.';

  @override
  String get inviteTitle => 'Freunde einladen';

  @override
  String get leagueActiveToday => 'Heute schon aktiv';

  @override
  String get leagueBronze => 'Bronze';

  @override
  String get leagueDiamond => 'Diamant';

  @override
  String get leagueFooter =>
      'Hier treten nur Freunde an, die du selbst verbunden hast — keine Fremden. XP gibt es pro Check-in, skaliert mit Schwierigkeit und Streak; getrackte Trainings und Tagebuch-Tage zählen extra. Am Sonntag steigen die oberen Plätze auf, die unteren ab.';

  @override
  String get leagueGold => 'Gold';

  @override
  String get leagueNothingToday => 'Heute noch nichts';

  @override
  String get leagueObsidian => 'Obsidian';

  @override
  String get leaguePlatinum => 'Platin';

  @override
  String get leagueSilver => 'Silber';

  @override
  String get leagueThisWeek => 'Diese Woche';

  @override
  String leagueTitle(String league) {
    return '$league-Liga';
  }

  @override
  String get leagueTooSmall =>
      'Eine Liga mit einer Person ist nur eine Liste. Verbinde Freunde, dann fängt der Wettkampf an.';

  @override
  String leagueWeekAndPeople(String week, int count) {
    return 'Woche $week · $count Teilnehmer';
  }

  @override
  String get leagueWood => 'Holz';

  @override
  String leagueYouSuffix(String name) {
    return '$name (du)';
  }

  @override
  String get leagueYourRank => 'dein Platz';

  @override
  String get legalPrivacy => 'Datenschutz';

  @override
  String get legalTerms => 'Nutzungsbedingungen';

  @override
  String get loggerAddSet => 'Satz hinzufügen';

  @override
  String get loggerAdviceAddReps => 'Gleiches Gewicht, eine Wdh. mehr pro Satz';

  @override
  String loggerAdviceAddWeight(String weight) {
    return 'Oberes Ende erreicht — jetzt $weight kg';
  }

  @override
  String loggerAdviceFirst(int rir) {
    return 'Erstes Mal: Gewicht so wählen, dass $rir Wdh. in Reserve bleiben';
  }

  @override
  String get loggerAdviceHold =>
      'Gewicht halten — jeden Satz in den Bereich bringen';

  @override
  String loggerAdviceReduce(String weight) {
    return 'Zweimal verfehlt — zurück auf $weight kg und neu aufbauen';
  }

  @override
  String get loggerDiscard => 'Verwerfen';

  @override
  String get loggerDiscardBody => 'Die eingetragenen Sätze gehen verloren.';

  @override
  String get loggerDiscardTitle => 'Training verwerfen?';

  @override
  String get loggerFinish => 'Training abschließen';

  @override
  String get loggerFinishNoSets => 'Hake zuerst mindestens einen Satz ab.';

  @override
  String get loggerIntro =>
      'Trag jeden Satz ein. Beim nächsten Mal sagt dir die App, was du schlagen musst: mehr Wiederholungen beim gleichen Gewicht, dann mehr Gewicht.';

  @override
  String get loggerKg => 'kg';

  @override
  String loggerLastTime(String sets) {
    return 'Letztes Mal: $sets';
  }

  @override
  String get loggerReps => 'Wdh.';

  @override
  String get loggerSaved => 'Training gespeichert — getrackt, mit Plan-Bonus.';

  @override
  String loggerSet(int number) {
    return 'Satz $number';
  }

  @override
  String loggerTarget(String reps, int rir) {
    return 'Ziel: $reps Wdh. · RIR $rir';
  }

  @override
  String get loginApple => 'Mit Apple anmelden';

  @override
  String get loginFailed =>
      'Die Anmeldung hat nicht geklappt. Prüf deine Verbindung und versuch es noch einmal.';

  @override
  String get loginGoogle => 'Mit Google anmelden';

  @override
  String get loginNotConfigured =>
      'Die Anmeldung ist für diesen Server noch nicht eingerichtet.';

  @override
  String get loginOwnServer => 'Eigener Server';

  @override
  String loginOwnServerActive(String host) {
    return 'Eigener Server: $host';
  }

  @override
  String get loginOwnServerBody =>
      'Betreib 100 Days auf deiner eigenen Supabase-Instanz, gehostet oder selbst betrieben. Projekt-URL und Publishable Key reichen; die Einrichtung steht in docs/self-hosting.md.';

  @override
  String get loginOwnServerGoogle => 'Google Web-Client-ID (optional)';

  @override
  String get loginOwnServerKey => 'Publishable Key';

  @override
  String get loginOwnServerReset => 'Standard-Server nutzen';

  @override
  String get loginOwnServerRestart =>
      'Gespeichert. Schließ die App und öffne sie neu, um dich mit dem neuen Server zu verbinden.';

  @override
  String get loginPrivacy =>
      'Dein Konto speichert nur, was die App braucht. Freunde sehen, was du teilst; Körperdaten, Ziele und das Ernährungstagebuch bleiben privat. Die App ist Open Source, und du kannst deinen eigenen Server betreiben.';

  @override
  String get loginSubtitle =>
      'Anmelden, Ziel setzen, Plan bekommen. Deine Freunde sehen, ob du heute dran warst.';

  @override
  String get macroPresetAuto => 'Automatisch';

  @override
  String get macroPresetAutoBlurb =>
      'Eiweiß und Fett pro Kilo Körpergewicht, der Rest Kohlenhydrate. Der beste Standard für Trainingsziele.';

  @override
  String get macroPresetBalanced => 'Ausgewogen';

  @override
  String get macroPresetBalancedBlurb =>
      '50 % Kohlenhydrate, 20 % Eiweiß, 30 % Fett — die klassische Verteilung.';

  @override
  String get macroPresetCustom => 'Eigene';

  @override
  String get macroPresetCustomBlurb =>
      'Eiweiß und Kohlenhydrate selbst einstellen; Fett bekommt den Rest.';

  @override
  String get macroPresetHighProtein => 'Proteinreich';

  @override
  String get macroPresetHighProteinBlurb =>
      '35 % Eiweiß, 40 % Kohlenhydrate, 25 % Fett. Macht im Defizit satt.';

  @override
  String get macroPresetLowCarb => 'Low Carb';

  @override
  String get macroPresetLowCarbBlurb =>
      '30 % Eiweiß, 20 % Kohlenhydrate, 50 % Fett.';

  @override
  String get mascotHappy1 => 'Gefüttert. Ich brenne für dich.';

  @override
  String get mascotHappy2 => 'Erledigt. So entstehen Legenden.';

  @override
  String get mascotHappy3 => 'Wieder ein Tag im Sack. Bis morgen.';

  @override
  String mascotHappy4(int streak) {
    String _temp0 = intl.Intl.pluralLogic(
      streak,
      locale: localeName,
      other: '$streak Tage',
      one: 'Ein Tag',
    );
    return '$_temp0. Mir wird richtig heiß.';
  }

  @override
  String get mascotHappy5 => 'Geschafft. Schon wieder. Ich feier das.';

  @override
  String get mascotHappy6 => 'Jetzt Pause. Morgen hab ich wieder Hunger.';

  @override
  String get mascotHopeful1 => 'Jedes Feuer beginnt mit einem Funken. Heute?';

  @override
  String get mascotHopeful2 => 'Ich bin nur Glut. Mach eine Flamme aus mir.';

  @override
  String get mascotHopeful3 => 'Null ist nur eine Startnummer.';

  @override
  String get mascotHopeful4 => 'Ein Tag. Dann reden wir weiter.';

  @override
  String get mascotHungry1 => 'Ich hab Hunger. Füttere mich mit einem Tag.';

  @override
  String get mascotHungry2 => 'Heute zählt. Nur heute.';

  @override
  String get mascotHungry3 => 'Ein Tap und ich wachse. Du bist dran.';

  @override
  String get mascotHungry4 => 'Dein zukünftiges Ich schaut zu. Ich auch.';

  @override
  String get mascotHungry5 => 'Auftauchen. Das ist der ganze Trick.';

  @override
  String mascotHungry6(int day) {
    return 'Tag $day. Lass ihn zählen.';
  }

  @override
  String get mascotHyped1 => 'JAAA! Du bist on fire. Wortwörtlich.';

  @override
  String get mascotHyped2 => 'Schau, wie ich brenne!';

  @override
  String get mascotHyped3 => 'Genau DAS meine ich!';

  @override
  String get mascotHyped4 => 'Nicht zu stoppen. Morgen genauso.';

  @override
  String get mascotName => 'Funki';

  @override
  String get mascotPoke1 => 'Hey! Das kitzelt.';

  @override
  String get mascotPoke2 => 'Vorsicht, heiß!';

  @override
  String get mascotPoke3 => 'Nochmal! 🔥';

  @override
  String get mascotPoke4 => 'Weniger stupsen, mehr abhaken.';

  @override
  String get mascotPoke5 => 'Ich beiß nicht. Ich brenn.';

  @override
  String get mascotPoke6 => 'Boop.';

  @override
  String get mascotPokeCombo => 'Okay, okay, ich brenn ja schon!';

  @override
  String get mascotSad1 => 'Passiert. Ehrlich schlägt perfekt.';

  @override
  String get mascotSad2 => 'Am Boden, nicht raus. Morgen geht\'s wieder los.';

  @override
  String get mascotSad3 => 'Heute bin ich klein. Ich komm zurück.';

  @override
  String get mascotSemantics => 'Funki, deine Flamme. Tippen zum Anstupsen.';

  @override
  String get mascotSleepy1 => 'Pausentag. Ich glühe nur leise vor mich hin.';

  @override
  String get mascotSleepy2 => 'Heute nichts geplant. Ich lade auf. Zzz.';

  @override
  String get mascotSleepy3 => 'Pause gehört zum Plan. Der Streak wartet.';

  @override
  String mascotWorried1(int hours) {
    return 'Psst. Noch $hours Std. Mir wird kalt.';
  }

  @override
  String mascotWorried2(int streak) {
    String _temp0 = intl.Intl.pluralLogic(
      streak,
      locale: localeName,
      other: '$streak Tage',
      one: 'Ein Tag',
    );
    return '$_temp0. Lass mich heute Nacht nicht ausgehen.';
  }

  @override
  String get mascotWorried3 => 'Lass mich nicht ausgehen. Bitte?';

  @override
  String get mascotWorried4 => 'Mitternacht verhandelt nicht. Du schon noch.';

  @override
  String get mascotWorried5 => 'Ich flackere. Das ist kein gutes Zeichen.';

  @override
  String get mealBreakfast => 'Frühstück';

  @override
  String get mealDinner => 'Abendessen';

  @override
  String get mealIdeaBreakfast1 =>
      'Skyr mit Beeren, Haferflocken und Leinsamen';

  @override
  String get mealIdeaBreakfast2 => 'Rührei aus 3 Eiern mit Vollkorntoast';

  @override
  String get mealIdeaBreakfast3 => 'Overnight Oats mit Magerquark und Banane';

  @override
  String get mealIdeaBreakfast4 => 'Proteinporridge mit Erdnussmus';

  @override
  String get mealIdeaBreakfast5 => 'Tofu-Rührei mit Vollkornbrot';

  @override
  String get mealIdeaDinner1 => 'Putenpfanne mit Zucchini und Feta';

  @override
  String get mealIdeaDinner2 => 'Omelette mit Champignons und Spinat';

  @override
  String get mealIdeaDinner3 => 'Kichererbsencurry mit Naturjoghurt';

  @override
  String get mealIdeaDinner4 => 'Thunfischsalat mit Bohnen und Ei';

  @override
  String get mealIdeaDinner5 => 'Bohnen-Gemüse-Chili';

  @override
  String get mealIdeaDinner6 => 'Vollkorn-Wrap mit Hähnchen und Salat';

  @override
  String get mealIdeaLunch1 => 'Hähnchenbrust, Reis, Brokkoli';

  @override
  String get mealIdeaLunch2 => 'Linsenbolognese mit Vollkornnudeln';

  @override
  String get mealIdeaLunch3 => 'Lachsfilet mit Kartoffeln und Salat';

  @override
  String get mealIdeaLunch4 =>
      'Rindergeschnetzeltes mit Couscous und Ofengemüse';

  @override
  String get mealIdeaLunch5 => 'Tofu-Gemüse-Pfanne mit Reis';

  @override
  String get mealIdeaSnack1 => 'Magerquark mit Honig und Walnüssen';

  @override
  String get mealIdeaSnack2 => 'Proteinshake mit Banane';

  @override
  String get mealIdeaSnack3 => 'Handvoll Mandeln und ein Apfel';

  @override
  String get mealIdeaSnack4 => 'Hüttenkäse auf Knäckebrot';

  @override
  String get mealIdeaSnack5 => 'Hummus mit Gemüsesticks';

  @override
  String get mealIdeaSnack6 => 'Reiswaffeln mit Erdnussbutter';

  @override
  String get mealLunch => 'Mittagessen';

  @override
  String get mealSnack => 'Snack';

  @override
  String get milestoneAlcohol14Body =>
      'Leberfett geht messbar zurück, Entzündungswerte sinken.';

  @override
  String get milestoneAlcohol14Title => 'Tag 14 — Leber erholt sich';

  @override
  String get milestoneAlcohol1Body =>
      'Blutzucker und Schlaf sind noch durcheinander. Viel trinken, früh ins Bett.';

  @override
  String get milestoneAlcohol1Title => 'Tag 1 — Der Körper räumt auf';

  @override
  String get milestoneAlcohol30Body =>
      'Leberwerte deutlich besser, im Schnitt ein paar Kilo weniger, Haut sichtbar ruhiger.';

  @override
  String get milestoneAlcohol30Title => 'Tag 30 — Haut, Schlaf, Gewicht';

  @override
  String get milestoneAlcohol3Body =>
      'Der REM-Schlaf kommt zurück. Du wachst seltener nachts auf.';

  @override
  String get milestoneAlcohol3Title => 'Tag 3 — Schlaf wird tiefer';

  @override
  String get milestoneAlcohol7Body =>
      'Kein Restalkohol mehr. Konzentration und Stimmung stabilisieren sich.';

  @override
  String get milestoneAlcohol7Title => 'Woche 1 — Klarer Kopf am Morgen';

  @override
  String get milestoneAlcohol90Body =>
      'Das Verlangen ist keine tägliche Verhandlung mehr. Blutdruck und Immunsystem profitieren dauerhaft.';

  @override
  String get milestoneAlcohol90Title => 'Tag 90 — Neue Normalität';

  @override
  String get milestoneDopamine1Body =>
      'Du wirst hunderte Male zum Handy greifen wollen. Das ist die Gewohnheit, nicht du.';

  @override
  String get milestoneDopamine1Title => 'Tag 1 — Der Griff zum Handy';

  @override
  String get milestoneDopamine21Body =>
      'Die automatische Handbewegung in der Warteschlange verschwindet.';

  @override
  String get milestoneDopamine21Title => 'Tag 21 — Der Reflex ist weg';

  @override
  String get milestoneDopamine3Body =>
      'Langeweile ist kein Fehler. Sie ist der Zustand, aus dem Ideen kommen.';

  @override
  String get milestoneDopamine3Title => 'Tag 3 — Langeweile kommt zurück';

  @override
  String get milestoneDopamine60Body =>
      'Zwei Stunden konzentriert an einer Sache sind wieder normal.';

  @override
  String get milestoneDopamine60Title => 'Tag 60 — Tiefe Arbeit';

  @override
  String get milestoneDopamine7Body =>
      'Du hältst längere Texte und längere Gespräche aus, ohne wegzuschauen.';

  @override
  String get milestoneDopamine7Title =>
      'Woche 1 — Aufmerksamkeitsspanne wächst';

  @override
  String get milestoneGeneric21Body =>
      'Die Entscheidung kostet weniger Kraft als noch letzte Woche.';

  @override
  String get milestoneGeneric21Title => 'Tag 21 — Automatisierung beginnt';

  @override
  String get milestoneGeneric3Body =>
      'Der Neuheitsbonus ist weg. Jetzt entscheidet die Gewohnheit.';

  @override
  String get milestoneGeneric3Title => 'Tag 3 — Der erste echte Test';

  @override
  String get milestoneGeneric66Body =>
      'Im Schnitt braucht ein Verhalten 66 Tage, bis es automatisch läuft. Du bist da.';

  @override
  String get milestoneGeneric66Title => 'Tag 66 — Gewohnheit';

  @override
  String get milestoneNicotine14Body =>
      'Bis zu 30 % bessere Lungenfunktion, Treppen fallen leichter.';

  @override
  String get milestoneNicotine14Title => 'Tag 14 — Lunge arbeitet besser';

  @override
  String get milestoneNicotine1Body =>
      'Nach 12 Stunden ist der CO-Spiegel normal, Sauerstoff steigt.';

  @override
  String get milestoneNicotine1Title => 'Tag 1 — Kohlenmonoxid weg';

  @override
  String get milestoneNicotine3Body =>
      'Der körperliche Entzug hat seinen Höhepunkt. Ab hier wird es leichter.';

  @override
  String get milestoneNicotine3Title => 'Tag 3 — Nikotin ist raus';

  @override
  String get milestoneNicotine90Body =>
      'Husten und Kurzatmigkeit gehen deutlich zurück.';

  @override
  String get milestoneNicotine90Title => 'Tag 90 — Flimmerhärchen erholt';

  @override
  String get milestoneNoFap14Body =>
      'Wenn du dich flach und leer fühlst: das ist eine bekannte Phase und sie geht vorbei.';

  @override
  String get milestoneNoFap14Title => 'Tag 14 — Flatline möglich';

  @override
  String get milestoneNoFap30Body =>
      'Weniger Zwangsgedanken, mehr Präsenz im Alltag.';

  @override
  String get milestoneNoFap30Title => 'Tag 30 — Kopf wird ruhiger';

  @override
  String get milestoneNoFap3Body =>
      'Unruhe und Reizbarkeit sind normal. Bewegung hilft mehr als Willenskraft.';

  @override
  String get milestoneNoFap3Title => 'Tag 3 — Erste Welle';

  @override
  String get milestoneNoFap7Body => 'Mehr Antrieb, oft auch besserer Schlaf.';

  @override
  String get milestoneNoFap7Title => 'Woche 1 — Energie steigt';

  @override
  String get milestoneNoFap90Body =>
      'Die klassische Reboot-Marke. Ab hier ist es Lebensstil, nicht Kampf.';

  @override
  String get milestoneNoFap90Title => 'Tag 90 — Der Reboot';

  @override
  String get milestoneSugar14Body =>
      'Obst schmeckt plötzlich süß. Das ist der Sensor, der zurückkommt.';

  @override
  String get milestoneSugar14Title => 'Tag 14 — Geschmack kalibriert sich';

  @override
  String get milestoneSugar2Body =>
      'Kopfschmerzen und Heißhunger sind der Peak. Protein und Wasser.';

  @override
  String get milestoneSugar2Title => 'Tag 2 — Zuckerentzug';

  @override
  String get milestoneSugar30Body =>
      'Gesicht und Bauch wirken flacher, Entzündungsmarker sinken.';

  @override
  String get milestoneSugar30Title => 'Tag 30 — Weniger Wassereinlagerungen';

  @override
  String get milestoneSugar5Body =>
      'Kein Nachmittagstief mehr, weil die Blutzuckerachterbahn fehlt.';

  @override
  String get milestoneSugar5Title => 'Tag 5 — Energie wird gleichmäßig';

  @override
  String get muscleBack => 'Rücken';

  @override
  String get muscleBiceps => 'Bizeps';

  @override
  String get muscleCalves => 'Waden';

  @override
  String get muscleChest => 'Brust';

  @override
  String get muscleCore => 'Rumpf';

  @override
  String get muscleFullBody => 'Ganzkörper';

  @override
  String get muscleGlutes => 'Gesäß';

  @override
  String get muscleHamstrings => 'Beinbeuger';

  @override
  String get muscleQuads => 'Quadrizeps';

  @override
  String get muscleShoulders => 'Schultern';

  @override
  String get muscleTriceps => 'Trizeps';

  @override
  String get navFriends => 'Freunde';

  @override
  String get navMore => 'Mehr';

  @override
  String get navPlan => 'Plan';

  @override
  String get navSettingsTitle => 'Einstellungen';

  @override
  String get navStats => 'Zahlen';

  @override
  String get navToday => 'Heute';

  @override
  String get notifChannelPressure => 'Freunde & Streak-Warnungen';

  @override
  String get notifChannelPressureDesc =>
      'Wenn Freunde aktiv waren oder dein Streak auf der Kippe steht.';

  @override
  String get notifChannelReminder => 'Tägliche Erinnerung';

  @override
  String get notifChannelReminderDesc =>
      'Erinnert dich an deine Gewohnheiten für heute.';

  @override
  String notifDayDone(int day) {
    return 'Tag $day steht. Morgen wieder.';
  }

  @override
  String notifDayOpenNoStreak(int day, int total) {
    return 'Tag $day von $total. Heute wieder anfangen.';
  }

  @override
  String notifDayOpenWithStreak(int day, int total, int streak) {
    return 'Tag $day von $total. $streak Tage Streak wollen verteidigt werden.';
  }

  @override
  String notifFriendActive(String name) {
    return '$name war heute schon dran';
  }

  @override
  String notifFriendsActive(int count) {
    return '$count deiner Leute waren heute schon dran';
  }

  @override
  String get notifFriendsActiveBody =>
      'Du stehst noch auf null. Noch ist der Tag nicht rum.';

  @override
  String notifStreakRiskBody(int streak) {
    return '$streak Tage. Ein vergessener Abend, und sie sind weg.';
  }

  @override
  String get notifStreakRiskTitle => 'Dein Streak steht auf dem Spiel';

  @override
  String nudgeCheerRespect(String emoji) {
    return 'Respekt für $emoji';
  }

  @override
  String get nudgeDefaultPoke => 'Ich war heute schon. Und du?';

  @override
  String get nudgeIWentDidYou => 'Ich war heute schon. Und du?';

  @override
  String get nudgeNoPressure => 'Kein Druck. Aber ich sehe deinen Feed.';

  @override
  String get nudgeReasonInactive => 'Seit zwei Tagen inaktiv';

  @override
  String get nudgeReasonNothingToday => 'Heute noch nichts gemacht';

  @override
  String nudgeStreakWatching(int day) {
    return 'Tag $day. Dein Streak schaut dich an.';
  }

  @override
  String get nudgeStrongToday => 'Stark heute. Morgen wieder?';

  @override
  String nudgeYouWereInForDays(int streak) {
    String _temp0 = intl.Intl.pluralLogic(
      streak,
      locale: localeName,
      other: '$streak Tage warst du dabei. Heute auch?',
      one: '1 Tag warst du dabei. Heute auch?',
    );
    return '$_temp0';
  }

  @override
  String get obActivityAthlete => 'Sportler';

  @override
  String get obActivityHigh => 'Sehr aktiv';

  @override
  String get obActivityLight => 'Leicht aktiv';

  @override
  String get obActivityModerate => 'Moderat';

  @override
  String get obActivitySedentary => 'Sitzend';

  @override
  String get obAiEyebrow => 'KI';

  @override
  String get obAiFreeBody =>
      'Ein Monatskontingent, genug für ab und zu ein Foto und einen Ernährungsplan.';

  @override
  String get obAiFreeTitle => 'Kostenlos zum Start';

  @override
  String get obAiLater =>
      'Jetzt musst du nichts entscheiden. Streak, Pläne und Tagebuch funktionieren auch ohne KI.';

  @override
  String get obAiOwnKeyBody =>
      'Du hast einen API-Key von Google, Anthropic oder OpenAI? Hinterleg ihn in den Einstellungen und nutz den.';

  @override
  String get obAiOwnKeyTitle => 'Oder dein eigener Key';

  @override
  String get obAiPremiumBody =>
      'Fotos ohne zu zählen, Wochenpläne, der Planungs-Chat und ein Coach, der schreibt.';

  @override
  String get obAiPremiumTitle => 'Premium für jeden Tag';

  @override
  String get obAiSubtitle =>
      'Mahlzeit fotografieren und schätzen lassen, eine Woche Essen und die Einkaufsliste planen lassen, für dich oder deinen ganzen Haushalt.';

  @override
  String get obAiTitle => 'KI, die mitdenkt.';

  @override
  String get obBodyActivity => 'Alltag & Bewegung';

  @override
  String get obBodyAge => 'Alter';

  @override
  String obBodyAgeValue(int years) {
    return '$years Jahre';
  }

  @override
  String get obBodyEyebrow => 'Ernährung';

  @override
  String get obBodyHeight => 'Größe';

  @override
  String get obBodyPreviewTitle => 'Dein Tagesziel';

  @override
  String get obBodySubtitle =>
      'Nur für die Kalorien- und Proteinberechnung. Alles bleibt privat.';

  @override
  String get obBodyTitle => 'Ein paar Zahlen.';

  @override
  String get obBodyWeight => 'Gewicht';

  @override
  String get obCycleDays => 'Tage';

  @override
  String get obCycleLengthTitle => 'Wie lang ist ein Zyklus?';

  @override
  String get obCycleNote =>
      'Am Ende des Zyklus ist nicht Schluss: dein Streak läuft weiter und du steigst in die nächste Stufe auf.';

  @override
  String get obEquipmentBodyweight => 'Nur Körpergewicht';

  @override
  String get obEquipmentBodyweightBody => 'Kein Equipment. Geht trotzdem.';

  @override
  String get obEquipmentFullGym => 'Volles Studio';

  @override
  String get obEquipmentFullGymBody => 'Langhantel, Maschinen, Kabelzug.';

  @override
  String get obEquipmentHome => 'Home-Gym';

  @override
  String get obEquipmentHomeBody => 'Kurzhanteln, Bänder, Klimmzugstange.';

  @override
  String get obExample1Clarity => 'Handyzeit halbieren, Kopf zurückholen';

  @override
  String get obExample1Custom => 'Mein Ding, meine Regeln';

  @override
  String get obExample1Discipline => '100 Tage keine Ausrede';

  @override
  String get obExample1Fat => '8 kg runter bis zum Sommer';

  @override
  String get obExample1Fit => '5 km unter 25 Minuten laufen';

  @override
  String get obExample1Muscle => 'In 100 Tagen 5 kg Muskeln drauf';

  @override
  String get obExample1Sober => '100 Tage komplett trocken';

  @override
  String get obExample2Clarity => '100 Tage ohne Doomscrolling';

  @override
  String get obExample2Discipline => 'Jeden Morgen um 6 auf, ohne Diskussion';

  @override
  String get obExample2Fat => 'Wieder in meine alte Hose passen';

  @override
  String get obExample2Fit => 'Ohne Pause die Treppen hoch';

  @override
  String get obExample2Muscle => 'Endlich 10 saubere Klimmzüge';

  @override
  String get obExample2Sober => 'Kein Zucker, kein Alkohol, keine Ausnahme';

  @override
  String get obExperienceAdvanced => 'Erfahren';

  @override
  String get obExperienceAdvancedBody =>
      'Mehr als drei Jahre. Volumen ist dein Hebel.';

  @override
  String get obExperienceBeginner => 'Anfänger';

  @override
  String get obExperienceBeginnerBody =>
      'Unter einem Jahr regelmäßig. Technik vor Gewicht.';

  @override
  String get obExperienceIntermediate => 'Fortgeschritten';

  @override
  String get obExperienceIntermediateBody =>
      'Ein bis drei Jahre. Du weißt, wie sich RPE 8 anfühlt.';

  @override
  String get obGoalSubtitle =>
      'Ein Ziel. Alles andere — Trainingsplan, Ernährungsplan, Streak — wird daraus gebaut.';

  @override
  String get obGoalTitle => 'Worum geht es?';

  @override
  String get obHabitDailyTarget => 'Tagesziel';

  @override
  String get obHabitRecommended => 'empfohlen';

  @override
  String get obHabitsSubtitlePreselected =>
      'Vorausgewählt ist, was zu deinem Ziel passt. Ändere es, wie du willst.';

  @override
  String get obHabitsSubtitleTooMany =>
      'Das sind viele. Erfahrungsgemäß hält man drei bis vier durch — lieber weniger und dafür wirklich.';

  @override
  String get obHabitsTitle => 'Was zählt jeden Tag?';

  @override
  String get obIdentityNameHint => 'Dein Name';

  @override
  String get obIdentitySubtitle =>
      'So sehen dich deine Freunde: im Feed, in Anfragen und in der Liga.';

  @override
  String get obIdentityTitle => 'Wie sollen dich deine Leute sehen?';

  @override
  String get obKcalEyebrow => 'Ernährung';

  @override
  String get obKcalSubtitle =>
      'Aus deinen Zahlen berechnet — oder setz dein eigenes. Beides kannst du jederzeit ändern.';

  @override
  String get obKcalTitle => 'Dein Tagesziel.';

  @override
  String obPlanBonus(int percent) {
    return '+$percent % XP';
  }

  @override
  String get obPlanNutrition => 'Mit Ernährungsplan';

  @override
  String get obPlanNutritionBody =>
      'Kalorienziel und Ernährungstagebuch mit Essensideen. Optional — ohne hakst du den Tag nur ab.';

  @override
  String get obPlanTraining => 'Mit Trainingsplan';

  @override
  String get obPlanTrainingBody =>
      'Eigener Split und eigene Übungen, jeder Satz geloggt mit Progressions-Tipps. Optional — ohne hakst du das Training nur ab.';

  @override
  String get obPointBeyondBody =>
      'Danach geht es weiter — nächste Stufe, härtere Ziele, gleicher Streak.';

  @override
  String get obPointBeyondTitle => 'Tag 100 ist nicht das Ende';

  @override
  String get obPointGoalBody =>
      'Ohne Ziel kein Plan. Du sagst, worum es geht — die App baut Training, Ernährung oder Streak drumherum.';

  @override
  String get obPointGoalTitle => 'Erst das Ziel';

  @override
  String get obPointPrivacyBody =>
      'Freunde sehen, was du teilst, sonst niemand. Open Source, und wenn du willst, auf deinem eigenen Server.';

  @override
  String get obPointPrivacyTitle => 'Deins';

  @override
  String get obPointSocialBody =>
      'Kein anonymer Zähler. Wenn Marcel heute im Gym war und du nicht, steht das da. Genau das ist der Punkt.';

  @override
  String get obPointSocialTitle => 'Deine Leute sehen alles';

  @override
  String get obPrivacyEyebrow => 'Privatsphäre';

  @override
  String get obPrivacySubtitle =>
      'Nur Freunde, die du selbst verbindest, sehen überhaupt etwas — keine Fremden, kein öffentliches Profil. Und davon nur, was du hier freigibst.';

  @override
  String get obPrivacyTitle => 'Wer sieht was.';

  @override
  String obSetsAndMinutes(int sets, int minutes) {
    return '$sets Sätze · $minutes Min';
  }

  @override
  String get obSexFemale => 'weiblich';

  @override
  String get obSexMale => 'männlich';

  @override
  String get obSplitEyebrow => 'Trainingsplan';

  @override
  String get obSplitSubtitle =>
      'Wähle, wie deine Woche aufgeteilt ist. Wir schlagen Übungen vor — ändere, was du willst.';

  @override
  String get obSplitTitle => 'Dein Split.';

  @override
  String get obStartChallenge => 'Challenge starten';

  @override
  String obStartFailed(String message) {
    return 'Start fehlgeschlagen: $message';
  }

  @override
  String get obStatementHint => 'Ich will …';

  @override
  String get obStatementSubtitle =>
      'Diesen Satz bekommst du an jedem schweren Tag zu sehen. Also schreib den echten, nicht den vorzeigbaren.';

  @override
  String get obStatementTitle => 'Sag es in einem Satz.';

  @override
  String get obStep1 => 'Schritt 1';

  @override
  String get obStep2 => 'Schritt 2';

  @override
  String get obStep3 => 'Schritt 3';

  @override
  String get obStep4 => 'Schritt 4';

  @override
  String get obSummaryAlmostDone => 'Fast fertig';

  @override
  String obSummaryBonusNutrition(int percent) {
    return 'Ernährungsplan an: +$percent % XP für jeden Tag im Ziel';
  }

  @override
  String get obSummaryBonusSection => 'Bonus';

  @override
  String obSummaryBonusTraining(int percent) {
    return 'Trainingsplan an: +$percent % XP für jedes geloggte Training';
  }

  @override
  String get obSummaryDailySection => 'Das zählt täglich';

  @override
  String obSummaryDayOne(String emoji, String goal, int days) {
    return '$emoji $goal · Tag 1 von $days';
  }

  @override
  String get obSummaryEyebrow => 'Dein Plan';

  @override
  String get obSummaryFriendsNote =>
      'Danach: Freunde verbinden. Allein hält es kaum jemand 100 Tage durch — mit Publikum schon.';

  @override
  String get obSummaryMissing => 'Ein paar Angaben fehlen noch.';

  @override
  String get obSummaryNutritionSection => 'Ernährungsplan';

  @override
  String get obSummaryPrivacyAllShared =>
      'Alle Gewohnheiten und dein Streak. Körperdaten und Ernährungstagebuch bleiben privat.';

  @override
  String get obSummaryPrivacySection => 'Mit Freunden geteilt';

  @override
  String obSummaryPrivacySome(String habits) {
    return 'Dein Streak und deine Gewohnheiten, außer $habits, das bleibt privat. Körperdaten und Ernährungstagebuch bleiben auch privat.';
  }

  @override
  String obSummaryTitle(int days) {
    return '$days Tage, ab heute.';
  }

  @override
  String get obSummaryTrainingSection => 'Trainingsplan';

  @override
  String get obTrainingDaysPerWeek => 'Trainingstage pro Woche';

  @override
  String get obTrainingEquipment => 'Ausrüstung';

  @override
  String get obTrainingExperience => 'Erfahrung';

  @override
  String get obTrainingEyebrow => 'Training';

  @override
  String get obTrainingNoPlanHint =>
      'Ohne Plan zählt die App nur, ob du trainiert hast.';

  @override
  String obTrainingSplitHint(String split) {
    return 'Vorschlag dafür: $split. Auswählen kannst du auf der nächsten Seite.';
  }

  @override
  String get obTrainingSubtitle =>
      'Trainingstage zählen für den Streak. Mit Trainingsplan wählst du auf der nächsten Seite auch Split und Übungen.';

  @override
  String get obTrainingTitle => 'Wie oft und womit?';

  @override
  String get obWelcomeEyebrow => '100 Tage und weit darüber hinaus';

  @override
  String get obWelcomeMascot =>
      'Hi, ich bin Funki, deine Flamme. Füttere mich jeden Tag, dann wachse ich.';

  @override
  String get obWelcomeSubtitle =>
      'Setz ein Ziel. Bekomm einen Plan. Und danach zählt nur noch eins: ob du heute dran warst — und ob deine Leute es sehen.';

  @override
  String get obWelcomeTitle =>
      'Du brauchst kein neues Ich.\nDu brauchst 100 Tage.';

  @override
  String get peerActivityAscended => 'Nächste Stufe erreicht';

  @override
  String peerActivityCheckIn(String emoji, String habit) {
    return '$emoji $habit erledigt';
  }

  @override
  String get peerActivityFreeze => 'Streak eingefroren';

  @override
  String get peerActivityMissed => 'Tag verpasst';

  @override
  String get peerActivityNone => 'Noch nichts los';

  @override
  String get peerActivityRelapse => 'Rückfall eingetragen';

  @override
  String get peerActivityStarted => 'Challenge gestartet';

  @override
  String planAccepted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Mahlzeiten geplant.',
      one: 'Eine Mahlzeit geplant.',
    );
    return '$_temp0';
  }

  @override
  String get planAddMeal => 'Mahlzeit eintragen';

  @override
  String get planBmr => 'Grundumsatz (BMR)';

  @override
  String get planCarbs => 'Kohlenhydrate';

  @override
  String get planCarbsShort => 'Carbs';

  @override
  String get planChat => 'Planungs-Chat';

  @override
  String planCleanDays(int days) {
    return '$days Tage clean';
  }

  @override
  String get planContext => 'Kontext';

  @override
  String get planCurrentBadge => 'aktuell';

  @override
  String get planDeloadBadge => 'deload';

  @override
  String get planEditTraining => 'Split und Übungen bearbeiten';

  @override
  String get planEmptySlot => 'Noch nichts geplant';

  @override
  String get planEnableNutrition => 'Ernährungsplan einschalten';

  @override
  String planEnableNutritionBody(int percent) {
    return 'Setz ein Kalorienziel und führ ein Ernährungstagebuch — jeder Tag im Ziel bringt +$percent % XP.';
  }

  @override
  String get planEnableTraining => 'Trainingsplan einschalten';

  @override
  String planEnableTrainingBody(int percent) {
    return 'Wähle einen Split, pass die Übungen an und logge jeden Satz — jedes geloggte Training bringt +$percent % XP.';
  }

  @override
  String get planExpectedChange => 'Erwartete Änderung';

  @override
  String get planFat => 'Fett';

  @override
  String get planFiber => 'Ballaststoffe';

  @override
  String get planKcal => 'kcal';

  @override
  String planKcalPerDay(int kcal) {
    return '$kcal kcal pro Tag';
  }

  @override
  String get planKcalPerDayShort => 'kcal / Tag';

  @override
  String get planLoadFailed =>
      'Konnte nicht laden. Zum Neuladen nach unten ziehen.';

  @override
  String planMealMacros(int kcal, int protein) {
    return '$kcal kcal · ${protein}g P';
  }

  @override
  String get planMeals => 'Mahlzeiten';

  @override
  String planMinutes(int minutes) {
    return '$minutes Min.';
  }

  @override
  String get planNeedsAi =>
      'Planen mit der KI braucht dein Kontingent oder einen eigenen Key (Einstellungen → KI). Von Hand eintragen geht immer.';

  @override
  String planNutritionDeficit(int percent, int tdee) {
    return '$percent % Defizit unter deinem Verbrauch von $tdee kcal. Das sind rund 0,5 kg Fett pro Woche — schnell genug, dass du es siehst, langsam genug, dass die Muskeln bleiben.';
  }

  @override
  String planNutritionMaintain(int tdee) {
    return 'Erhaltung bei $tdee kcal. Erst Gewohnheit und Leistung, dann Körperkomposition.';
  }

  @override
  String planNutritionSideGoal(int tdee) {
    return 'Erhaltung bei $tdee kcal. Dein Ziel liegt woanders — Ernährung soll dich hier nur nicht ausbremsen.';
  }

  @override
  String planNutritionSurplus(int percent, int tdee) {
    return '$percent % Überschuss über deinem Verbrauch von $tdee kcal. Lean Bulk: genug für Aufbau, wenig genug, dass du nicht nur Fett zunimmst.';
  }

  @override
  String planPerWeek(String value) {
    return '$value kg/Woche';
  }

  @override
  String get planProtein => 'Protein';

  @override
  String get planTabAbstinence => 'Clean bleiben';

  @override
  String get planTabMeals => 'Essen';

  @override
  String get planTabNutrition => 'Ernährung';

  @override
  String get planTabShopping => 'Einkauf';

  @override
  String get planTabTraining => 'Training';

  @override
  String get planTdee => 'Gesamtumsatz (TDEE)';

  @override
  String get planToday => 'HEUTE';

  @override
  String get planWater => 'Wasser';

  @override
  String planWeekAccept(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Diese $count Mahlzeiten übernehmen',
      one: 'Diese Mahlzeit übernehmen',
    );
    return '$_temp0';
  }

  @override
  String get planWeekAgain => 'Neuer Vorschlag';

  @override
  String get planWeekAi => 'Woche planen';

  @override
  String get planWeekAnyTime => 'Egal';

  @override
  String get planWeekDays => 'Tage';

  @override
  String get planWeekFailed =>
      'Diesmal kein brauchbarer Plan. Versuch es noch einmal oder mit weniger Tagen.';

  @override
  String planWeekNumber(int week) {
    return 'Woche $week';
  }

  @override
  String get planWeekPropose => 'Vorschlag machen';

  @override
  String get planWeekSlots => 'Mahlzeiten';

  @override
  String get planWeekTime => 'Kochzeit';

  @override
  String get planWeekWishHint =>
      'Wünsche? z. B. kein Fisch, Mittwoch was Schnelles, viel Gemüse';

  @override
  String get planWeekWorking => 'Plane eure Woche … das dauert einen Moment.';

  @override
  String planWorkoutSummary(int sets, int minutes) {
    return '$sets Sätze · ≈ $minutes Min';
  }

  @override
  String plannerAdded(String name) {
    return 'Auf der Liste: $name';
  }

  @override
  String get plannerDone => 'Erledigt.';

  @override
  String get plannerFailed =>
      'Das hat nicht geklappt. Versuch es gleich noch einmal.';

  @override
  String get plannerHint => 'Was soll sich ändern?';

  @override
  String get plannerIntro =>
      'Sag mir, was ihr braucht: „diese Woche kein Fisch“, „Mittwoch was Schnelles“, „Reis haben wir noch“. Ich ändere Plan und Liste direkt, und jede Änderung lässt sich rückgängig machen.';

  @override
  String get plannerListMade => 'Neue Einkaufsliste aus dem Plan';

  @override
  String plannerRemoved(String name) {
    return 'Von der Liste: $name';
  }

  @override
  String plannerRemovedMeal(String day, String slot) {
    return '$day, $slot: entfernt';
  }

  @override
  String plannerSetMeal(String day, String slot, String title) {
    return '$day, $slot: $title';
  }

  @override
  String get plannerUndo => 'Rückgängig';

  @override
  String portionsCount(String n) {
    return '$n Portionen';
  }

  @override
  String pressureBodyBehind(String activity, int streak) {
    String _temp0 = intl.Intl.pluralLogic(
      streak,
      locale: localeName,
      other: '$streak Tage Streak',
      one: '1 Tag Streak',
    );
    return '$activity · $_temp0. Du stehst heute noch auf null.';
  }

  @override
  String get pressureBodyDone => 'Du auch. Weiter so.';

  @override
  String pressureManyActive(int count) {
    return '$count deiner Leute waren heute schon dran';
  }

  @override
  String pressureOneActive(String name) {
    return '$name war heute schon dran';
  }

  @override
  String get privacyAlwaysPrivate =>
      'Immer privat, ohne Schalter: Körperdaten, Kalorienziele und das Ernährungstagebuch. Der Server gibt sie nur dir.';

  @override
  String get privacyFromNowOn =>
      'Änderungen gelten ab jetzt. Was Freunde schon bekommen haben, bleibt bei ihnen — eine Gewohnheit, die du privat stellst, verschwindet für neue Einträge, nicht für alte.';

  @override
  String get privacyHabitsSub =>
      'Eine private Gewohnheit ist für Freunde unsichtbar — samt Check-ins und Rückfällen. Dein Streak zählt für sie nur die geteilten.';

  @override
  String get privacyHabitsTitle => 'Gewohnheiten';

  @override
  String get privacyMoreTitle => 'Weiteres';

  @override
  String get privacyPrivate => 'Nur du';

  @override
  String get privacySaved => 'Privatsphäre gespeichert';

  @override
  String get privacyShared => 'Freunde sehen sie';

  @override
  String get privacyStatement => 'Zielsatz';

  @override
  String get privacyStatementSub =>
      'Dein Ziel in deinen Worten, auf deinem Profil.';

  @override
  String get privacyTitle => 'Privatsphäre';

  @override
  String get privacyWorkouts => 'Trainingsdetails';

  @override
  String get privacyWorkoutsSub =>
      'Einheit, Sätze und Gewichte. Aus: Freunde sehen nur, dass du trainiert hast.';

  @override
  String get profileCheer => 'Feiern';

  @override
  String get profileCheerSent => 'Gefeiert.';

  @override
  String profileDaysCount(int days) {
    return '$days Tage';
  }

  @override
  String get profileDisconnect => 'Verbindung trennen';

  @override
  String get profileHabits => 'Gewohnheiten';

  @override
  String get profileHistory => 'Verlauf';

  @override
  String get profileNudge => 'Anstupsen';

  @override
  String get profileNudgeSent => 'Anstupser gesendet.';

  @override
  String get profileRemoveBody =>
      'Die komplette Historie dieser Person wird von deinem Gerät gelöscht. Rückgängig geht das nur durch erneutes Verbinden.';

  @override
  String profileRemoveTitle(String name) {
    return '$name entfernen?';
  }

  @override
  String get profileTitle => 'Profil';

  @override
  String get profileUnknownBody =>
      'Zu dieser Identität liegt nichts auf deinem Gerät.';

  @override
  String get profileUnknownTitle => 'Unbekannt';

  @override
  String promptAdjustHabitLine(
    String habit,
    String target,
    int days,
    int streak,
  ) {
    return '- $habit: Ziel $target, ${days}x/Woche, Streak $streak';
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
    return 'Du bist Ernährungscoach. Aktuelles Tagesziel: $kcal kcal, $protein g Eiweiß, $carbs g Kohlenhydrate, $fat g Fett. Energieverbrauch: $tdee kcal.\nDer Nutzer möchte: „$wish“\n\nSchlag neue Ziele vor. Bleib zwischen $min und $max kcal und nie mehr als 25 % unter dem Verbrauch.\nAntworte nur mit JSON, genau in dieser Form, die Begründung auf Deutsch:\n$format';
  }

  @override
  String promptAdjustments(
    int day,
    int total,
    int percent,
    String statement,
    String habits,
  ) {
    return 'Du bist Trainings- und Gewohnheitscoach. Sprache: Deutsch, Du-Form.\nDer Nutzer ist bei Tag $day von $total.\nTrefferquote: $percent %.\nZiel: \"$statement\"\n\n$habits\n\nGib maximal 4 konkrete Anpassungen, je eine Zeile, je maximal 15 Wörter. Keine Einleitung, keine Nummerierung, keine Emojis.';
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
    return 'Du bist der Coach in einer 100-Tage-Challenge-App. Sprache: Deutsch, Du-Form.\n$persona\nMaximal 2 Sätze. Keine Emojis am Zeilenanfang. Keine Anführungszeichen.\n\nZiel des Nutzers: \"$statement\"\nTag $day von $total (Stufe: $tier)\nAktueller Streak: $streak Tage, längster: $longest\nHeute erledigt: $doneToday\nUhrzeit: $hour:00\n\nGewohnheiten:\n$habits\n\nFreunde:\n$peers\n\nAntworte in genau diesem Format:\nTITEL: <maximal 6 Wörter>\nTEXT: <1-2 Sätze>';
  }

  @override
  String promptFoodEstimate(String text, String format) {
    return 'Du bist Ernährungsassistent. Schätze, was diese Person gegessen hat:\n\"$text\"\n\nSchätze für jedes Lebensmittel das Gesamtgewicht in Gramm (2 Eier sind etwa 110 g, nicht 2) und die Kalorien und Makros dieser ganzen Menge.\nAntworte nur mit JSON, in dieser Form, Namen auf Deutsch:\n$format';
  }

  @override
  String promptFoodPhoto(String hint, String format) {
    return 'Du bist Ernährungsassistent. Das Foto zeigt, was diese Person gleich isst. Ihre Notiz: \"$hint\"\n\nNenne jedes Lebensmittel, das du siehst. Schätze für jedes das Gewicht in Gramm anhand von Teller, Besteck und Verpackung daneben, und die Kalorien und Makros dieser ganzen Menge. Lass weg, was du nicht siehst. Zeigt das Foto kein Essen, antworte mit einer leeren foods-Liste.\nAntworte nur mit JSON, in dieser Form, Namen auf Deutsch:\n$format';
  }

  @override
  String promptHabitLine(String emoji, String habit, int streak, String unit) {
    return '- $emoji $habit: $streak $unit';
  }

  @override
  String promptMealIdeas(String meal, int kcal, int protein, String wish) {
    return 'Schlag 3 einfache Ideen für $meal vor, je etwa $kcal kcal und mindestens $protein g Eiweiß. Wunsch: $wish\nEine Idee pro Zeile, höchstens 12 Wörter, mit den geschätzten kcal am Ende. Auf Deutsch. Keine Nummerierung, keine Einleitung.';
  }

  @override
  String promptMealPlan(
    String days,
    String people,
    String extra,
    String format,
  ) {
    return 'Du planst Hausmannskost für einen Haushalt. Plane diese Mahlzeiten (Tag: Slots, die Namen in Klammern sind nur für dich):\n$days\n\nWer isst:\n$people\n$extra\n\nEinfache, abwechslungsreiche Gerichte aus einem normalen Supermarkt. Verwende Zutaten über die Woche mehrfach, damit wenig übrig bleibt. Ein Rezept pro Mahlzeit mit Portionen für den ganzen Haushalt, Kalorien und Makros EINER Portion, Zutaten für alle Portionen in g, ml oder Stück (unit \"g\", \"ml\", \"piece\", \"tbsp\" oder \"tsp\") mit Kategorie (produce, bakery, dairy, meat, fish, pantry, frozen, drinks, other) und kurzen Schritten. Slot-Namen: breakfast, lunch, snack, dinner. Titel, Zutaten und Schritte auf Deutsch.\nAntworte nur mit JSON, in dieser Form:\n$format';
  }

  @override
  String get promptNo => 'nein';

  @override
  String get promptNoFriends => '- keine Freunde verbunden';

  @override
  String promptNudge(String name, int day, int streak) {
    return 'Schreibe eine einzelne, kurze Stichel-Nachricht auf Deutsch an $name, der oder die heute noch nichts für die eigene Challenge getan hat. Der Absender ist bei Tag $day mit $streak Tagen Streak. Maximal 12 Wörter, frech aber freundlich, kein Mobbing, keine Anführungszeichen. Nur die Nachricht, sonst nichts.';
  }

  @override
  String get promptPeerActive => 'HEUTE schon aktiv';

  @override
  String get promptPeerInactive => 'heute noch nichts';

  @override
  String promptPeerLine(String name, int streak, String status) {
    return '- $name: $streak Tage Streak, $status';
  }

  @override
  String get promptPersonaCalm => 'Du bist ruhig und sachlich.';

  @override
  String get promptPersonaCelebrate => 'Du bist kurz und stolz, ohne Kitsch.';

  @override
  String get promptPersonaDemanding => 'Du bist fordernd und konkret.';

  @override
  String get promptPersonaDirect =>
      'Du bist direkt und leicht provokant, aber nie beleidigend.';

  @override
  String get promptPersonaRecover =>
      'Du bist nüchtern und respektvoll. Kein Mitleid, keine Vorwürfe.';

  @override
  String promptPlanAllergies(String list) {
    return 'allergisch gegen $list';
  }

  @override
  String promptPlanAvoid(String titles) {
    return 'Kürzlich gegessen, bitte nicht wieder: $titles.';
  }

  @override
  String promptPlanDislikes(String list) {
    return 'mag kein(e) $list';
  }

  @override
  String promptPlanKcal(int kcal) {
    return '$kcal kcal am Tag';
  }

  @override
  String promptPlanMinutes(int minutes) {
    return 'Höchstens $minutes Minuten Kochzeit pro Mahlzeit.';
  }

  @override
  String promptPlanProtein(int grams) {
    return '$grams g Eiweiß am Tag';
  }

  @override
  String promptPlanWish(String wish) {
    return 'Ihr Wunsch: „$wish“';
  }

  @override
  String promptPlannerChat(
    String today,
    String weekday,
    String start,
    String end,
  ) {
    return 'Du hilfst einem Haushalt in der App 100 Days beim Planen von Essen und Einkauf. Heute ist $today ($weekday); geplant wird die Woche vom $start bis $end. Lies den Plan mit get_plan, bevor du ihn änderst. Ändere ihn mit den Tools, beschreib Änderungen nie nur. Rezepte: einfach, aus einem normalen Supermarkt, Portionen für den ganzen Haushalt, Kalorien und Makros pro Portion. Antworte in ein bis zwei kurzen Sätzen, auf Deutsch, per du.';
  }

  @override
  String get promptUnitClean => 'Tage clean';

  @override
  String get promptUnitStreak => 'Tage Streak';

  @override
  String get promptYes => 'ja';

  @override
  String get pushCheer => 'Anfeuern von Freunden';

  @override
  String get pushFriendActivity => 'Ein Freund war schon dran, du noch nicht';

  @override
  String get pushFriendRequest => 'Freundschaftsanfragen';

  @override
  String get pushNudge => 'Anstupser von Freunden';

  @override
  String qtyPieces(String n) {
    return '$n Stk.';
  }

  @override
  String qtyTbsp(String n) {
    return '$n EL';
  }

  @override
  String qtyTsp(String n) {
    return '$n TL';
  }

  @override
  String get questDone => 'Quest geschafft, zusammen.';

  @override
  String questProgress(int mine, int theirs, String name) {
    return 'Du $mine · $name $theirs';
  }

  @override
  String questTitle(int target) {
    return 'Quest diese Woche: $target Check-ins zusammen';
  }

  @override
  String get recipeEatenAsPlanned => 'Gegessen wie geplant';

  @override
  String recipeIngredients(int servings) {
    return 'Zutaten für $servings';
  }

  @override
  String get recipeLogged => 'Steht im Tagebuch.';

  @override
  String recipePerServing(int kcal, int protein, int carbs, int fat) {
    return 'Eine Portion: $kcal kcal · $protein g Eiweiß · $carbs g Kohlenhydrate · $fat g Fett';
  }

  @override
  String get recipeRemove => 'Aus dem Plan nehmen';

  @override
  String get recipeSteps => 'So geht\'s';

  @override
  String recipeYourShare(String portions, int kcal, int protein) {
    return 'Dein Teil: $portions · $kcal kcal · $protein g Eiweiß';
  }

  @override
  String relativeDays(int count) {
    return 'vor $count Tagen';
  }

  @override
  String relativeHours(int count) {
    return 'vor $count Std';
  }

  @override
  String get relativeJustNow => 'gerade eben';

  @override
  String relativeMinutes(int count) {
    return 'vor $count Min';
  }

  @override
  String get relativeYesterday => 'gestern';

  @override
  String ringDayOfTotal(int day, int total) {
    return 'Tag $day / $total';
  }

  @override
  String ringDayStreak(int streak) {
    String _temp0 = intl.Intl.pluralLogic(
      streak,
      locale: localeName,
      other: 'Tage Streak',
      one: 'Tag Streak',
    );
    return '$_temp0';
  }

  @override
  String scanCameraUnavailableBody(String code) {
    return 'Ohne Kamerazugriff geht es auch: lass dir den Einladungslink schicken und füge ihn unten ein.\n\n$code';
  }

  @override
  String get scanCameraUnavailableTitle => 'Kamera nicht verfügbar';

  @override
  String get scanHint => 'Halte die Kamera auf den QR-Code deines Freundes.';

  @override
  String get scanPasteInstead => 'Stattdessen Link einfügen';

  @override
  String get scanPasteTitle => 'Einladungslink';

  @override
  String get scanTitle => 'Code scannen';

  @override
  String get setAboutBody =>
      'Keine Werbung, kein Tracking, kein Datenverkauf. Dein Konto enthält, was die App braucht, Freunde sehen, was du teilst. Der Quellcode ist offen: Prüf es nach, statt es zu glauben, oder betreib deinen eigenen Server.';

  @override
  String get setAboutSection => 'Über';

  @override
  String get setAboutTitle => '100 Tage und weit darüber hinaus';

  @override
  String get setAccountSection => 'Konto';

  @override
  String get setAi => 'KI';

  @override
  String get setAiSubFree =>
      'Fotos, Schätzungen, Ernährungspläne – kostenlos mit Monatskontingent';

  @override
  String get setCoachSection => 'Coach';

  @override
  String get setDeleteAccount => 'Konto löschen';

  @override
  String get setDeleteAccountBody =>
      'Dein Streak, deine Pläne, dein Tagebuch und deine Freundschaften werden auf dem Server gelöscht, endgültig. Das lässt sich nicht rückgängig machen.';

  @override
  String get setDeleteAccountFailed =>
      'Das Konto konnte nicht gelöscht werden. Prüf deine Verbindung und versuch es noch einmal.';

  @override
  String get setDeleteAccountSub => 'Löscht dein Konto und alles darin.';

  @override
  String get setDeleteAccountTitle => 'Konto wirklich löschen?';

  @override
  String get setLanguage => 'App-Sprache';

  @override
  String get setLanguageEnglish => 'English';

  @override
  String get setLanguageGerman => 'Deutsch';

  @override
  String get setLanguageSection => 'Sprache';

  @override
  String get setLanguageSystem => 'Systemsprache';

  @override
  String setLanguageSystemSub(String language) {
    return 'Richtet sich nach deinem Handy. Aktuell: $language';
  }

  @override
  String get setPrivacy => 'Privatsphäre';

  @override
  String get setPrivacySub => 'Was deine Freunde sehen';

  @override
  String get setServer => 'Server';

  @override
  String setServerCustom(String host) {
    return 'Eigener Server: $host';
  }

  @override
  String get setServerDefault => 'Der 100-Days-Server';

  @override
  String get setSignOut => 'Abmelden';

  @override
  String get setSignOutBody =>
      'Alles ist in deinem Konto gespeichert und wieder da, sobald du dich neu anmeldest. Dieses Handy vergisst es bis dahin.';

  @override
  String get setSignOutSub => 'Deine Daten bleiben in deinem Konto.';

  @override
  String setSyncDone(int sent, int received) {
    return 'Aktuell · $sent gesendet, $received empfangen';
  }

  @override
  String get setSyncNever => 'Noch nicht synchronisiert.';

  @override
  String get setSyncNow => 'Jetzt synchronisieren';

  @override
  String get setSyncOffline =>
      'Offline. Alles bleibt gespeichert und geht später raus.';

  @override
  String get setViewSource => 'Quellcode ansehen';

  @override
  String get shopAddHint => 'Etwas hinzufügen …';

  @override
  String get shopBakery => 'Brot & Backwaren';

  @override
  String shopCadenceLine(String cadence) {
    return 'Einkauf: $cadence';
  }

  @override
  String shopCheckedBy(String name) {
    return 'im Korb · $name';
  }

  @override
  String get shopDairy => 'Milch & Eier';

  @override
  String get shopDrinks => 'Getränke';

  @override
  String get shopEmptyBody =>
      'Mach eine aus dem Plan: alles für die Tage bis zum nächsten Einkauf, zusammengerechnet und nach Gängen sortiert. Oder fang eine leere an.';

  @override
  String get shopEmptyTitle => 'Noch keine Liste';

  @override
  String get shopExtraList => 'Extra-Liste';

  @override
  String get shopFinish => 'Einkauf erledigt';

  @override
  String shopFinishMoving(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Erledigt, $count aufs nächste Mal',
      one: 'Erledigt, den Rest aufs nächste Mal',
    );
    return '$_temp0';
  }

  @override
  String get shopFish => 'Fisch';

  @override
  String get shopFromPlan => 'Liste aus Plan';

  @override
  String get shopFrozen => 'Tiefkühl';

  @override
  String get shopHousehold => 'Haushalt';

  @override
  String get shopMeat => 'Fleisch & Wurst';

  @override
  String get shopOther => 'Sonstiges';

  @override
  String get shopPantry => 'Vorrat';

  @override
  String get shopProduce => 'Obst & Gemüse';

  @override
  String shopProgress(int done, int total) {
    return '$done von $total';
  }

  @override
  String skyStars(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count Sterne stehen an deinem Himmel — einer für jeden geschafften Tag.',
      one: '1 Stern steht an deinem Himmel — einer für jeden geschafften Tag.',
      zero:
          'Noch kein Stern an deinem Himmel. Der erste kommt mit dem ersten geschafften Tag.',
    );
    return '$_temp0';
  }

  @override
  String get socialFindable => 'Über Kontakte auffindbar';

  @override
  String get socialFindableSub =>
      'Wer deine E-Mail-Adresse (oder bestätigte Nummer) in den Kontakten hat, kann dich finden.';

  @override
  String get socialFoundTitle => 'Gefunden werden';

  @override
  String get socialLeague => 'Öffentliche Wochenliga';

  @override
  String get socialLeagueSub =>
      'Tritt gegen Leute außerhalb deiner Freunde an. Sie sehen Name, Emoji und Wochen-XP, sonst nichts.';

  @override
  String get socialPushNotConfigured =>
      'Diese Version hat keinen Push-Dienst eingerichtet; Erinnerungen kommen weiterhin vom Handy selbst.';

  @override
  String get socialPushTitle => 'Push-Benachrichtigungen';

  @override
  String get socialSettingsSub => 'Benutzername, Auffindbarkeit, Liga, Pushes';

  @override
  String get socialSettingsTitle => 'Freunde & Benachrichtigungen';

  @override
  String get socialTabFeed => 'Feed';

  @override
  String socialTabFriends(int count) {
    return 'Freunde ($count)';
  }

  @override
  String get socialTabLeague => 'Liga';

  @override
  String get splitBlurbBroSplit =>
      'Brust, Rücken, Beine, Schultern, Arme — eine Muskelgruppe pro Tag. Ab fünf Tagen.';

  @override
  String get splitBlurbFullBody =>
      'Jede Einheit trainiert alles. Der beste Kompromiss bei zwei oder drei Tagen.';

  @override
  String get splitBlurbPplUpperLower =>
      'Fünf Einheiten: PPL plus ein Ober- und ein Unterkörpertag. Gemacht für fünf Tage.';

  @override
  String get splitBlurbPushPullLegs =>
      'Drücken, Ziehen, Beine — im Wechsel. Stark bei drei oder sechs Tagen.';

  @override
  String get splitBlurbUpperLower =>
      'Oberkörper und Beine im Wechsel. Ideal bei vier Tagen.';

  @override
  String get splitBroSplit => 'Muskelgruppen-Split';

  @override
  String get splitFullBody => 'Ganzkörper';

  @override
  String get splitPplUpperLower => 'Push / Pull / Beine + Ober- / Unterkörper';

  @override
  String get splitPushPullLegs => 'Push / Pull / Beine';

  @override
  String get splitRecommended => 'empfohlen';

  @override
  String get splitUpperLower => 'Oberkörper / Unterkörper';

  @override
  String get stageBlaze => 'Lagerfeuer';

  @override
  String get stageBlue => 'Blaue Flamme';

  @override
  String get stageEmber => 'Glut';

  @override
  String get stageFinal => 'Endform. Jetzt heißt es nur noch: weiterbrennen.';

  @override
  String get stageFlame => 'Flamme';

  @override
  String get stageFlicker => 'Flämmchen';

  @override
  String stageFrom(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Ab $days Tagen',
      one: 'Ab 1 Tag',
      zero: 'Ohne Streak',
    );
    return '$_temp0';
  }

  @override
  String get stageGalaxy => 'Galaxie';

  @override
  String get stageInferno => 'Inferno';

  @override
  String stageNext(String stage, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days Tagen',
      one: '1 Tag',
    );
    return '$stage in $_temp0';
  }

  @override
  String get stageNova => 'Supernova';

  @override
  String get stagePlasma => 'Plasma';

  @override
  String get stageSpark => 'Funke';

  @override
  String get statDay => 'Tag';

  @override
  String get statRecord => 'Rekord';

  @override
  String get statStreak => 'Streak';

  @override
  String get statXp => 'XP';

  @override
  String get statsCurrentStreak => 'Aktueller Streak';

  @override
  String get statsFlameTitle => 'Deine Flamme';

  @override
  String get statsFullDays => 'Volle Tage';

  @override
  String statsHabitProgress(int done, int planned, int percent) {
    return '$done von $planned geplanten Tagen ($percent %)';
  }

  @override
  String statsHistorySince(String date) {
    return 'Seit $date';
  }

  @override
  String get statsHitRate => 'Trefferquote';

  @override
  String get statsLevel => 'Level';

  @override
  String statsLevelNumber(int level) {
    return 'Level $level';
  }

  @override
  String get statsLongestStreak => 'Längster Streak';

  @override
  String get statsNoXpYet => 'Noch keine XP. Die kommen mit dem ersten Haken.';

  @override
  String get statsPerHabit => 'Pro Gewohnheit';

  @override
  String statsPercent(String value) {
    return '$value %';
  }

  @override
  String get statsWeeklyXp => 'XP der letzten Wochen';

  @override
  String statsXpToNextLevel(int remaining, int level, int current, int total) {
    return 'Noch $remaining XP bis Level $level ($current / $total)';
  }

  @override
  String get targetClean => 'clean';

  @override
  String targetCount(int count) {
    return '${count}x';
  }

  @override
  String get targetDone => 'erledigt';

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
    return '$count Min';
  }

  @override
  String targetPages(int count) {
    return '$count Seiten';
  }

  @override
  String targetSteps(int count) {
    return '$count Schritte';
  }

  @override
  String get tier0 => 'Die ersten 100';

  @override
  String get tier1 => 'Jenseits der 100';

  @override
  String get tier2 => 'Dreihundert';

  @override
  String get tier3 => 'Das Jahr';

  @override
  String get tier4 => 'Unbeugsam';

  @override
  String get tier5 => 'Legende';

  @override
  String tierNumbered(int rank) {
    return 'Legende $rank';
  }

  @override
  String get tileCheckOff => 'Abhaken';

  @override
  String get tileCleanToday => 'Heute clean';

  @override
  String get tileDone => 'Erledigt';

  @override
  String tileDoneWith(String target) {
    return 'Erledigt · $target';
  }

  @override
  String get tileHoldExplain => 'Gedrückt halten zum Eintragen.';

  @override
  String get tileHoldHint => 'Halten';

  @override
  String get tileLogAmount => 'Eintragen';

  @override
  String get tileRelapse => 'Rückfall';

  @override
  String get tileRelapseLogged => 'Rückfall eingetragen — morgen neu.';

  @override
  String get tileRestToday => 'Heute Pause laut Plan';

  @override
  String tileStreakBadge(int streak) {
    return '$streak 🔥';
  }

  @override
  String tileTarget(String target) {
    return 'Ziel: $target';
  }

  @override
  String get tileUpdateAmount => 'Update';

  @override
  String togetherNoStreak(String name) {
    return 'Starte einen Streak mit $name: Beide heute dran sein.';
  }

  @override
  String togetherStreak(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days Tage am Stück zusammen',
      one: '1 Tag am Stück zusammen',
    );
    return '$_temp0';
  }

  @override
  String trainingPhaseBuild(int week, int block) {
    return 'Aufbau $week/3 · Block $block';
  }

  @override
  String get trainingPhaseDeload => 'Deload';

  @override
  String trainingRationale(int days, String split) {
    return '$days Trainingstage pro Woche als \"$split\". Drei Wochen Aufbau, dann eine Deload-Woche — so hältst du 100 Tage durch, ohne auszubrennen.';
  }

  @override
  String get usernameNone => 'Keiner, du bist nur per Einladung findbar';

  @override
  String get usernameRules => '3–20 Zeichen: a–z, Ziffern oder _';

  @override
  String get usernameTaken => 'Dieser Benutzername ist vergeben.';

  @override
  String get usernameTitle => 'Benutzername';

  @override
  String get weekdayFri => 'FR';

  @override
  String get weekdayMon => 'MO';

  @override
  String get weekdaySat => 'SA';

  @override
  String get weekdayShortFri => 'Fr';

  @override
  String get weekdayShortMon => 'Mo';

  @override
  String get weekdayShortSat => 'Sa';

  @override
  String get weekdayShortSun => 'So';

  @override
  String get weekdayShortThu => 'Do';

  @override
  String get weekdayShortTue => 'Di';

  @override
  String get weekdayShortWed => 'Mi';

  @override
  String get weekdaySun => 'SO';

  @override
  String get weekdayThu => 'DO';

  @override
  String get weekdayTue => 'DI';

  @override
  String get weekdayWed => 'MI';

  @override
  String get widgetCold => 'Zünde heute den ersten Funken.';

  @override
  String get widgetDone => 'Heute gefüttert ✓';

  @override
  String get widgetFrozen => 'Eingefroren. Der Streak ist sicher.';

  @override
  String get widgetGoesOutIn => 'Geht aus in';

  @override
  String get widgetOpen => 'Füttere mich heute noch!';

  @override
  String get widgetPromoAction => 'Widget hinzufügen';

  @override
  String get widgetPromoBody =>
      'Sieh Funki bei jedem Entsperren. Satt, hungrig oder kurz vorm Ausgehen.';

  @override
  String get widgetPromoManual =>
      'Halte den Homescreen gedrückt, tippe auf Widgets und wähle 100 Tage.';

  @override
  String get widgetPromoTitle => 'Dein Streak auf dem Homescreen';

  @override
  String get widgetRest => 'Pausentag. Ich spare Energie.';

  @override
  String get workoutArms => 'Arme';

  @override
  String get workoutArmsFocus => 'Bizeps und Trizeps';

  @override
  String get workoutBack => 'Rücken';

  @override
  String get workoutBackFocus => 'Latissimus, oberer Rücken und Bizeps';

  @override
  String get workoutChest => 'Brust';

  @override
  String get workoutChestFocus => 'Brust und Trizeps';

  @override
  String get workoutExercises => 'Übungen';

  @override
  String get workoutFullBodyA => 'Ganzkörper A';

  @override
  String get workoutFullBodyAFocus => 'Knie, Druck, Zug';

  @override
  String get workoutFullBodyB => 'Ganzkörper B';

  @override
  String get workoutFullBodyBFocus => 'Hüfte, Überkopf, Klimmzug';

  @override
  String get workoutFullBodyC => 'Ganzkörper C';

  @override
  String get workoutFullBodyCFocus => 'Einbeinig, Druck, Zug';

  @override
  String get workoutIntensity => 'Intensität';

  @override
  String get workoutLegs => 'Legs';

  @override
  String get workoutLegsFocus => 'Quads, Hamstrings, Glutes';

  @override
  String get workoutLower => 'Unterkörper';

  @override
  String get workoutLowerFocus => 'Beine und Rumpf';

  @override
  String get workoutMinutes => 'Minuten';

  @override
  String get workoutPull => 'Pull';

  @override
  String get workoutPullFocus => 'Rücken, Bizeps, hintere Schulter';

  @override
  String get workoutPush => 'Push';

  @override
  String get workoutPushFocus => 'Brust, Schultern, Trizeps';

  @override
  String get workoutReps => 'Wdh.';

  @override
  String get workoutRest => 'Pause';

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
      'RIR 2 heißt: nach dem Satz hättest du noch zwei saubere Wiederholungen geschafft. Wähle das Gewicht so, dass das stimmt — der Logger sagt dir dann jedes Mal, ob mehr Wiederholungen oder mehr Gewicht dran sind.';

  @override
  String get workoutRpeTitle => 'RIR verstehen';

  @override
  String get workoutSets => 'Sätze';

  @override
  String get workoutShoulders => 'Schultern';

  @override
  String get workoutShouldersFocus => 'Alle drei Schulterköpfe, dazu Rumpf';

  @override
  String get workoutStart => 'Training starten';

  @override
  String get workoutUpper => 'Oberkörper';

  @override
  String get workoutUpperFocus => 'Druck und Zug';

  @override
  String get workoutWorkingSets => 'Arbeitssätze';
}
