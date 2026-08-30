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
      String emoji, String habit, int days, String milestone) {
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
  String get aiBackendMissing =>
      'Aktuell läuft der regelbasierte Coach. Er braucht kein Modell, funktioniert offline und antwortet sofort — die Sprache ist nur weniger variabel.';

  @override
  String get aiBackendPresent =>
      'Eine Inferenz-Engine ist eingebunden. Mit installiertem Modell formuliert sie deine Tagesansage.';

  @override
  String aiGigabytes(String size) {
    return '$size GB';
  }

  @override
  String get aiInstallBody =>
      'Lade die GGUF-Datei am Rechner herunter und leg sie in diesen Ordner:';

  @override
  String get aiInstallTitle => 'Modell installieren';

  @override
  String get aiInstalled => 'installiert';

  @override
  String get aiLoading => 'Wird geladen …';

  @override
  String get aiModelGemmaDesc =>
      'Etwas stärker im Deutschen, braucht mehr RAM.';

  @override
  String get aiModelQwenDesc =>
      'Guter Kompromiss aus Qualität und Größe. Läuft auf Mittelklasse-Geräten.';

  @override
  String get aiModelSmolDesc => 'Winzig und schnell, für ältere Geräte.';

  @override
  String get aiNoAutoDownload =>
      'Die App lädt nichts von selbst herunter — ein Gigabyte über Mobilfunk ist nichts, was ohne Nachfrage passieren sollte.';

  @override
  String get aiNoNetworkBadge => 'kein Netzwerkzugriff';

  @override
  String get aiSource => 'Quelle';

  @override
  String get aiSupportedModels => 'Unterstützte Modelle';

  @override
  String get aiTitle => 'KI auf dem Gerät';

  @override
  String get aiWhatItSeesBody =>
      'Streak, Tagesnummer, deine Gewohnheiten und ob deine Freunde heute aktiv waren — als Text, direkt an das Modell auf diesem Gerät. Kein Netzwerkaufruf, keine Telemetrie, kein Zwischenspeicher in einer Cloud.';

  @override
  String get aiWhatItSeesTitle => 'Was das Modell sieht';

  @override
  String get appTitle => '100 Tage';

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
    return '$model (on-device)';
  }

  @override
  String get coachEngineRuleBased => 'Regelbasiert (on-device)';

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
      String emoji, String name, int peerStreak, int streak) {
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
  String errorGeneric(String message) {
    return 'Fehler: $message';
  }

  @override
  String get exerciseAbWheel => 'Bauchroller';

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
  String get exerciseCableRow => 'Rudern am Kabelzug';

  @override
  String get exerciseCalfRaise => 'Wadenheben';

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
  String get exerciseGluteBridge => 'Glute Bridge';

  @override
  String get exerciseGobletSquat => 'Goblet Squat';

  @override
  String get exerciseHammerCurl => 'Hammercurls';

  @override
  String get exerciseHangingLegRaise => 'Hängendes Beinheben';

  @override
  String get exerciseHipThrust => 'Hip Thrust';

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
  String get exerciseLegPress => 'Beinpresse';

  @override
  String get exerciseNordicCurl => 'Nordic Curl (assistiert)';

  @override
  String get exerciseOhp => 'Schulterdrücken (Langhantel)';

  @override
  String get exercisePikePushup => 'Pike Push-up';

  @override
  String get exercisePlank => 'Unterarmstütz';

  @override
  String get exercisePullup => 'Klimmzug';

  @override
  String get exercisePushup => 'Liegestütz';

  @override
  String get exerciseRdl => 'Rumänisches Kreuzheben';

  @override
  String get exerciseRowingErg => 'Rudergerät';

  @override
  String get exerciseStepUp => 'Step-up';

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
      'Sobald du oder deine Freunde etwas abhaken, steht es hier — signiert und nachprüfbar.';

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
  String friendsConnected(String name) {
    return '$name verbunden.';
  }

  @override
  String friendsDayNumber(int day) {
    return 'Tag $day';
  }

  @override
  String get friendsEmptyBody =>
      'Die App funktioniert allein — aber sie wirkt erst, wenn jemand zuschaut. Zeig einem Freund deinen QR-Code.';

  @override
  String get friendsEmptyTitle => 'Noch niemand verbunden';

  @override
  String get friendsFallbackName => 'Freund';

  @override
  String get friendsInvite => 'Einladen';

  @override
  String friendsInviteInvalid(String message) {
    return 'Einladung ungültig: $message';
  }

  @override
  String get friendsNetworkNote =>
      'Verbindungen laufen direkt zwischen euren Geräten — im gleichen WLAN sofort, sonst beim nächsten Treffen. Kein Server dazwischen, der eure Streaks kennt.';

  @override
  String get friendsNoActivity => 'Noch keine Aktivität';

  @override
  String get friendsNudgeSection => 'Anstupsen';

  @override
  String get friendsNudgeSubtitle => 'Die hier waren heute noch nicht dran.';

  @override
  String get friendsScan => 'Scannen';

  @override
  String get friendsYourPeople => 'Deine Leute';

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
  String get habitSteps => 'Schritte';

  @override
  String get habitStepsBlurb =>
      'Zehntausend am Tag. Deine Uhr zählt sie — du musst dich nur bewegen.';

  @override
  String get habitWater => 'Wasser';

  @override
  String get habitWaterBlurb =>
      'Acht Gläser. Das Billigste, was du für dich tun kannst.';

  @override
  String get healthAccessSection => 'Zugriff';

  @override
  String get healthAutoImport => 'Automatisch importieren';

  @override
  String get healthAutoImportBody =>
      'Läuft, wenn du die App öffnest. Ausgeschaltet passiert nur noch etwas über den Knopf unten.';

  @override
  String get healthBadge => 'Health';

  @override
  String get healthBadgeApple => 'Apple Health';

  @override
  String get healthBadgeConnect => 'Health Connect';

  @override
  String get healthDenied => 'Zugriff verweigert';

  @override
  String get healthDeniedBody =>
      'Solange du die Werte in den Systemeinstellungen nicht freigibst, kann nichts gelesen werden.';

  @override
  String healthFromDevice(String device) {
    return 'von $device';
  }

  @override
  String get healthGetHealthConnect => 'Health Connect holen';

  @override
  String get healthGrant => 'Zugriff erlauben';

  @override
  String get healthGranted => 'Zugriff erteilt';

  @override
  String get healthHabitsEmpty =>
      'Keine deiner gewählten Gewohnheiten lässt sich aus einem Sensor lesen. Training, Cardio, Schritte, Schlaf, Wasser und Meditation gehen.';

  @override
  String get healthHabitsSection => 'Welche Gewohnheiten ausgefüllt werden';

  @override
  String get healthHonestyBody =>
      'Weniger, als es aussieht. Der Feed beweist, dass ein Eintrag von dir ist, wann er geschrieben wurde und dass ihn danach niemand verändert hat — er kann nicht beweisen, dass eine Uhr im Spiel war, denn nichts, was Apple oder Google einer App geben, ist so signiert, dass die Handys deiner Freunde es prüfen könnten. Ein importierter Eintrag ist deshalb mit „aus Health“ beschriftet, nie mit „verifiziert“.';

  @override
  String get healthHonestySection => 'Was das beweist';

  @override
  String get healthImportNow => 'Jetzt importieren';

  @override
  String get healthImportSection => 'Import';

  @override
  String healthImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Einträge geschrieben',
      one: '1 Eintrag geschrieben',
    );
    return '$_temp0';
  }

  @override
  String get healthImportedNothing => 'Nichts Neues — alles schon eingetragen.';

  @override
  String get healthImporting => 'Lese …';

  @override
  String get healthIntroApple =>
      'Dein iPhone und deine Apple Watch schreiben nach Apple Health. Die App liest von dort — auf dem Gerät, und nur die Werte, die du unten freigibst.';

  @override
  String get healthIntroConnect =>
      'Fitbit, Pixel Watch, Samsung Health, Garmin und Strava schreiben alle nach Health Connect. Die App liest von dort — auf dem Gerät, und nur die Werte, die du unten freigibst.';

  @override
  String get healthIntroNone =>
      'Dieses Gerät hat keinen Gesundheitsspeicher, aus dem gelesen werden könnte. Alles bleibt manuell, und das funktioniert einwandfrei.';

  @override
  String healthLastImport(String when) {
    return 'Letzter Import: $when';
  }

  @override
  String get healthMetricCardio => 'Cardio-Einheiten';

  @override
  String get healthMetricMindful => 'Achtsamkeits-Einheiten';

  @override
  String get healthMetricSleep => 'Schlafdauer';

  @override
  String get healthMetricSteps => 'Schrittzahl';

  @override
  String get healthMetricStrength => 'Krafttrainings-Einheiten';

  @override
  String get healthMetricWater => 'Wasseraufnahme';

  @override
  String get healthNever => 'nie';

  @override
  String get healthNoNetworkBadge => 'Verlässt das Gerät nie';

  @override
  String get healthNotOnPlatform => 'Auf dieser Plattform nicht verfügbar';

  @override
  String get healthOpenSystem => 'Systemeinstellungen öffnen';

  @override
  String healthReads(String metric) {
    return 'Liest: $metric';
  }

  @override
  String get healthRuleAbstain =>
      'Er fasst keine Verzichts-Gewohnheit an. Kein Sensor kann zeigen, dass du nicht getrunken hast.';

  @override
  String healthRuleBackfill(int days) {
    return 'Er greift höchstens $days Tage zurück.';
  }

  @override
  String get healthRuleManual =>
      'Er überschreibt nie eine Zahl, die du selbst eingetragen hast.';

  @override
  String get healthRuleRelapse =>
      'Er schreibt nie an einem Tag, an dem du einen Rückfall eingetragen hast.';

  @override
  String get healthRuleRest =>
      'Er lässt Ruhetage leer, damit ein Spaziergang an einem freien Tag kein XP bringt.';

  @override
  String get healthRuleUpwards => 'Er hebt einen Wert nur an, nie ab.';

  @override
  String get healthRulesSection => 'Was der Import nicht tut';

  @override
  String get healthTitle => 'Uhr & Gesundheitsdaten';

  @override
  String get healthUnavailableBody =>
      'Health Connect ist ab Android 14 dabei; auf älteren Handys ist es eine kostenlose App aus dem Play Store. Ohne sie gibt es hier nichts zu lesen.';

  @override
  String get healthUnavailableTitle => 'Health Connect fehlt';

  @override
  String get healthUnknown => 'Apple sagt es nicht';

  @override
  String get healthUnknownBody =>
      'iOS verrät einer App bewusst nie, ob Lesen erlaubt wurde — eine Ablehnung würde sonst selbst etwas verraten. Wenn nichts ankommt, prüf die Freigabe in der Health-App.';

  @override
  String get heatLess => 'weniger';

  @override
  String get heatMore => 'mehr';

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
  String get homeOptional => 'Freiwillig';

  @override
  String get homeOptionalSubtitle =>
      'Heute nicht eingeplant — zählt trotzdem als XP.';

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
  String homeXp(int xp) {
    return '$xp XP';
  }

  @override
  String get inviteErrorMalformed => 'Diese Einladung ist ungültig.';

  @override
  String get inviteErrorSelf => 'Das bist du selbst.';

  @override
  String get inviteHowTitle => 'Wie das funktioniert';

  @override
  String get inviteLinkCopied => 'Link kopiert.';

  @override
  String get inviteReachableAt => 'Erreichbar unter';

  @override
  String get inviteShareSubject => '100 Tage Challenge';

  @override
  String inviteShareText(String link) {
    return 'Mach die 100 Tage mit mir: $link';
  }

  @override
  String get inviteStep1 =>
      'Dein Gegenüber scannt den Code oder öffnet den Link.';

  @override
  String get inviteStep2 =>
      'Ihr folgt einander direkt — kein Konto, keine Telefonnummer, keine Freigabe durch einen Anbieter.';

  @override
  String get inviteStep3 =>
      'Ab dann synchronisieren eure Geräte, sobald sie sich sehen: gleiches WLAN, gleiches Zuhause, gleiches Gym.';

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
      'XP gibt es pro Check-in, skaliert mit Schwierigkeit und Streak. Am Sonntag steigen die oberen Plätze auf, die unteren ab.';

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
  String get mealIdeaDinner1 => 'Putenpfanne mit Zucchini und Feta';

  @override
  String get mealIdeaDinner2 => 'Omelette mit Champignons und Spinat';

  @override
  String get mealIdeaDinner3 => 'Kichererbsencurry mit Naturjoghurt';

  @override
  String get mealIdeaDinner4 => 'Thunfischsalat mit Bohnen und Ei';

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
  String get mealIdeaSnack1 => 'Magerquark mit Honig und Walnüssen';

  @override
  String get mealIdeaSnack2 => 'Proteinshake mit Banane';

  @override
  String get mealIdeaSnack3 => 'Handvoll Mandeln und ein Apfel';

  @override
  String get mealIdeaSnack4 => 'Hüttenkäse auf Knäckebrot';

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
      'Nur für die Kalorien- und Proteinberechnung. Alles bleibt auf diesem Gerät.';

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
  String get obIdentityBoxBody =>
      'Ein Ed25519-Schlüsselpaar auf diesem Gerät, als did:key. Jeder Check-in wird damit signiert — deshalb kann niemand deinen Streak fälschen, und du brauchst niemandem zu vertrauen. Den Wiederherstellungs-Key findest du in den Einstellungen. Sichere ihn.';

  @override
  String get obIdentityBoxTitle => 'Deine Identität';

  @override
  String get obIdentityNameHint => 'Dein Name';

  @override
  String get obIdentitySubtitle =>
      'Kein Konto, keine E-Mail, kein Passwort. Dein Schlüsselpaar liegt schon auf diesem Gerät.';

  @override
  String get obIdentityTitle => 'Wie sollen dich deine Leute sehen?';

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
      'Kein Konto, kein Server, keine Cloud. Deine Daten liegen auf deinem Gerät und gehen direkt zu deinen Freunden.';

  @override
  String get obPointPrivacyTitle => 'Niemand sonst';

  @override
  String get obPointSocialBody =>
      'Kein anonymer Zähler. Wenn Marcel heute im Gym war und du nicht, steht das da. Genau das ist der Punkt.';

  @override
  String get obPointSocialTitle => 'Deine Leute sehen alles';

  @override
  String obSetsAndMinutes(int sets, int minutes) {
    return '$sets Sätze · $minutes Min';
  }

  @override
  String get obSexFemale => 'weiblich';

  @override
  String get obSexMale => 'männlich';

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
  String get obTrainingSubtitle =>
      'Daraus baut die App deinen Split — inklusive Deload-Wochen, damit du nach sechs Wochen nicht auf dem Zahnfleisch gehst.';

  @override
  String get obTrainingTitle => 'Wie oft und womit?';

  @override
  String get obWelcomeEyebrow => '100 Tage und weit darüber hinaus';

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
  String get planAdjustmentsNote =>
      'Ausgewertet auf diesem Gerät, aus deinen letzten Wochen. Nichts davon verlässt dein Handy.';

  @override
  String get planBmr => 'Grundumsatz (BMR)';

  @override
  String get planCarbs => 'Kohlenhydrate';

  @override
  String get planCarbsShort => 'Carbs';

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
  String planMealMacros(int kcal, int protein) {
    return '$kcal kcal · ${protein}g P';
  }

  @override
  String get planMeals => 'Mahlzeiten';

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
  String get planTabAdjustments => 'Anpassungen';

  @override
  String get planTabNutrition => 'Ernährung';

  @override
  String get planTabTraining => 'Training';

  @override
  String get planTdee => 'Gesamtumsatz (TDEE)';

  @override
  String get planWater => 'Wasser';

  @override
  String planWeekNumber(int week) {
    return 'Woche $week';
  }

  @override
  String planWorkoutSummary(int sets, int minutes) {
    return '$sets Sätze · ≈ $minutes Min';
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
      String habit, String target, int days, int streak) {
    return '- $habit: Ziel $target, ${days}x/Woche, Streak $streak';
  }

  @override
  String promptAdjustments(
      int day, int total, int percent, String statement, String habits) {
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
      String peers) {
    return 'Du bist der Coach in einer 100-Tage-Challenge-App. Sprache: Deutsch, Du-Form.\n$persona\nMaximal 2 Sätze. Keine Emojis am Zeilenanfang. Keine Anführungszeichen.\n\nZiel des Nutzers: \"$statement\"\nTag $day von $total (Stufe: $tier)\nAktueller Streak: $streak Tage, längster: $longest\nHeute erledigt: $doneToday\nUhrzeit: $hour:00\n\nGewohnheiten:\n$habits\n\nFreunde:\n$peers\n\nAntworte in genau diesem Format:\nTITEL: <maximal 6 Wörter>\nTEXT: <1-2 Sätze>';
  }

  @override
  String promptHabitLine(String emoji, String habit, int streak, String unit) {
    return '- $emoji $habit: $streak $unit';
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
  String get promptUnitClean => 'Tage clean';

  @override
  String get promptUnitStreak => 'Tage Streak';

  @override
  String get promptYes => 'ja';

  @override
  String get recoveryCopied => 'Key kopiert.';

  @override
  String get recoveryLookAround => 'Schau dich einmal um.';

  @override
  String get recoveryShow => 'Key anzeigen';

  @override
  String get recoveryTip1 => 'Passwortmanager — der beste Ort dafür.';

  @override
  String get recoveryTip2 =>
      'Aufschreiben und in die Schublade legen, in der auch dein Ausweis liegt.';

  @override
  String get recoveryTip3 =>
      'Nicht in einen Chat, nicht in eine Notiz-App mit Cloud-Sync, nicht als Screenshot in der Galerie.';

  @override
  String get recoveryTitle => 'Wiederherstellungs-Key';

  @override
  String get recoveryWarning =>
      'Wer diesen Key hat, ist du. Er kann in deinem Namen Check-ins signieren, und du kannst ihn nicht sperren — es gibt keinen Anbieter, der das könnte.';

  @override
  String get recoveryWhereTitle => 'Wohin damit';

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
      'Kein Konto, kein Server, keine Werbung, kein Tracking. Deine Daten liegen auf diesem Gerät und gehen nur an die Freunde, die du selbst verbunden hast. Der Quellcode ist offen — prüf es nach, statt es zu glauben.';

  @override
  String get setAboutSection => 'Über';

  @override
  String get setAboutTitle => '100 Tage und weit darüber hinaus';

  @override
  String get setCoachSection => 'Coach';

  @override
  String get setDidCopied => 'DID kopiert.';

  @override
  String setHealthConnected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Gewohnheiten',
      one: '1 Gewohnheit',
    );
    return 'Füllt $_temp0 aus';
  }

  @override
  String get setHealthOff => 'Nicht verbunden';

  @override
  String get setHealthSection => 'Uhr & Gesundheitsdaten';

  @override
  String get setHealthTitle => 'Apple Health und Health Connect';

  @override
  String get setIdentitySection => 'Identität & Daten';

  @override
  String get setLan => 'Lokales Netzwerk';

  @override
  String get setLanOff => 'Nicht aktiv.';

  @override
  String get setLanOn => 'Aktiv — findet Freunde im gleichen WLAN automatisch.';

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
  String get setNetworkSection => 'Netzwerk';

  @override
  String get setOnDeviceAi => 'KI auf dem Gerät';

  @override
  String get setOnThisDevice => 'Auf diesem Gerät';

  @override
  String setOnThisDeviceSub(int events, int friends) {
    return '$events eigene Einträge · $friends verbundene Feeds';
  }

  @override
  String get setRecoveryKey => 'Wiederherstellungs-Key';

  @override
  String get setRecoveryKeySub => 'Der einzige Weg zurück zu deinem Account.';

  @override
  String setSyncFailed(String message) {
    return 'Letzter Versuch fehlgeschlagen: $message';
  }

  @override
  String setSyncLast(String peer, int received, int sent) {
    return 'Zuletzt mit $peer: $received empfangen, $sent gesendet.';
  }

  @override
  String get setSyncNever => 'Noch keine Runde gelaufen.';

  @override
  String get setSyncNow => 'Jetzt synchronisieren';

  @override
  String get setSyncPeerFallback => 'einem Peer';

  @override
  String get setSyncStarted => 'Sync-Runde gestartet.';

  @override
  String get setViewSource => 'Quellcode ansehen';

  @override
  String get setWipe => 'Alles löschen';

  @override
  String get setWipeBody =>
      'Ohne deinen Wiederherstellungs-Key ist danach nichts mehr zu retten — es gibt keinen Server, der eine Kopie hat. Das ist der Preis dafür, dass auch sonst niemand eine hat.';

  @override
  String get setWipeSub => 'Identität, Challenge und alle Freunde entfernen.';

  @override
  String get setWipeTitle => 'Wirklich alles löschen?';

  @override
  String get socialTabFeed => 'Feed';

  @override
  String socialTabFriends(int count) {
    return 'Freunde ($count)';
  }

  @override
  String get socialTabLeague => 'Liga';

  @override
  String get splitFullBodyThrice => 'Ganzkörper 3x';

  @override
  String get splitFullBodyTwice => 'Ganzkörper 2x';

  @override
  String get splitPplPlusUpperLower => 'Push / Pull / Legs + Upper / Lower';

  @override
  String get splitPplTwice => 'Push / Pull / Legs 2x';

  @override
  String get splitPreview2 => 'Ganzkörper 2x — jede Einheit trifft alles.';

  @override
  String get splitPreview3 =>
      'Ganzkörper 3x — bester Kompromiss für die meisten.';

  @override
  String get splitPreview4 =>
      'Upper / Lower — zweimal Oberkörper, zweimal Beine.';

  @override
  String get splitPreview5 => 'Push / Pull / Legs plus Upper / Lower.';

  @override
  String get splitPreview6 => 'Push / Pull / Legs, zweimal die Woche.';

  @override
  String get splitUpperLower => 'Upper / Lower';

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
  String get weekdayShortSun => 'So';

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
  String workoutRpe(String value) {
    return 'RPE $value';
  }

  @override
  String get workoutRpeBody =>
      'RPE 8 heißt: nach dem Satz hättest du noch zwei saubere Wiederholungen geschafft. Wähle das Gewicht so, dass das stimmt — nicht das, was letzte Woche im Plan stand.';

  @override
  String get workoutRpeTitle => 'RPE verstehen';

  @override
  String get workoutSets => 'Sätze';

  @override
  String get workoutUpper => 'Oberkörper';

  @override
  String get workoutUpperFocus => 'Druck und Zug';

  @override
  String get workoutWorkingSets => 'Arbeitssätze';
}
