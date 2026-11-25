import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import 'app.dart';
import 'config/backend_config.dart';
import 'data/app_prefs.dart';
import 'data/app_repository.dart';
import 'data/crash_reporting.dart';
import 'data/feed_sync.dart';
import 'data/locale_store.dart';
import 'data/notifications.dart';
import 'data/push_service.dart';
import 'data/social_backend.dart';
import 'l10n/l10n.dart';
import 'state/household_providers.dart';
import 'state/providers.dart';
import 'ai/dartantic_llm_client.dart';
import 'ui/auth/login_screen.dart';
import 'ui/mealplan/household_screen.dart';
import 'ui/motion/sounds.dart';
import 'ui/settings/ai_screen.dart';
import 'ui/social/invite_flow.dart';

/// Crash reports go to Sentry only in the official builds: the release
/// workflows pass the DSN. A build without one — a self-hosted build, a
/// local run, the tests — reports nothing.
const String _sentryDsn = String.fromEnvironment('SENTRY_DSN');
const String _sentryEnvironment =
    String.fromEnvironment('SENTRY_ENVIRONMENT', defaultValue: 'production');

Future<void> main() async {
  if (_sentryDsn.isEmpty) return _run();
  await SentryFlutter.init(
    (SentryFlutterOptions options) {
      options
        ..dsn = _sentryDsn
        ..environment = _sentryEnvironment
        // Errors and crashes only: no tracing, no screenshots (nor the
        // view hierarchy, off by default), and nothing that names the
        // user — no user id, no e-mail, no IP address (also scrubbed in
        // the Sentry project).
        ..tracesSampleRate = null
        ..sendDefaultPii = false
        ..attachScreenshot = false
        // Log lines can carry names and goals; the breadcrumbs of
        // navigation and app state are enough to follow a crash.
        ..enablePrintBreadcrumbs = false;
    },
    appRunner: _run,
  );
}

Future<void> _run() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(
      <String>['Unbounded', 'Manrope'],
      await rootBundle.loadString('assets/fonts/OFL.txt'),
    );
  });

  final BackendConfig backend = await BackendConfig.load();
  await Supabase.initialize(
    url: backend.supabaseUrl,
    publishableKey: backend.supabaseKey,
  );

  final NotificationService notifications = NotificationService();
  await notifications.initialize();

  final LocaleStore localeStore = await LocaleStore.open();
  final SharedPrefsStore prefs = await SharedPrefsStore.open();

  // The app is laid out for a phone held upright.
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);

  AppSounds.enabled = prefs.read().soundOn;
  unawaited(AppSounds.start());

  runApp(ProviderScope(
    observers: const <ProviderObserver>[CrashReportingObserver()],
    overrides: <Override>[
      backendConfigProvider.overrideWithValue(backend),
      notificationsProvider.overrideWithValue(notifications),
      localeStoreProvider.overrideWithValue(localeStore),
      appPrefsStoreProvider.overrideWithValue(prefs),
    ],
    child: const _Bootstrap(child: HundredDaysApp()),
  ));
}

/// Side effects that need the provider container: reminder scheduling, the
/// home screen widget, syncing on resume, and notifications for friends'
/// activity that arrives while the app is open.
class _Bootstrap extends ConsumerStatefulWidget {
  const _Bootstrap({required this.child});

  final Widget child;

  @override
  ConsumerState<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends ConsumerState<_Bootstrap>
    with WidgetsBindingObserver {
  ProviderSubscription<AsyncValue<AppSnapshot>>? _subscription;
  ProviderSubscription<AsyncValue<SyncReport>>? _syncSubscription;
  ProviderSubscription<AiFailure?>? _aiFailures;
  ProviderSubscription<AsyncValue<AppRepository?>>? _session;
  ProviderSubscription<Locale>? _locale;
  ProviderSubscription<AppPrefs>? _prefs;
  ProviderSubscription<void>? _sharedTargets;
  StreamSubscription<Uri>? _links;
  StreamSubscription<void>? _recoveries;
  Timer? _periodicSync;

  /// An invite link that arrived before there was anyone to redeem it for:
  /// signed out, or still in onboarding.
  String? _pendingInvite;
  String? _lastScheduledFor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _subscription = ref.listenManual<AsyncValue<AppSnapshot>>(
      appStateProvider,
      (AsyncValue<AppSnapshot>? _, AsyncValue<AppSnapshot> next) {
        final AppSnapshot? snapshot = next.valueOrNull;
        if (snapshot == null) return;
        if (snapshot.hasChallenge) {
          // The calorie target a household plans with follows the user's
          // plan from the start — not only once a plan or diary screen was
          // opened. Only for someone with a nutrition plan.
          if (snapshot.plan?.nutrition != null) {
            _sharedTargets ??= ref.listenManual<void>(
              sharedTargetsSyncProvider,
              (void _, void __) {},
            );
          }
          _redeemPendingInvite();
          unawaited(ref.read(repositoryProvider).reportLeagueXp(snapshot));
          unawaited(_scheduleReminders(snapshot));
          unawaited(_publishWidget(snapshot));
        }
      },
      fireImmediately: true,
    );

    // Once signed in: register for pushes, and tell the server which
    // language the user reads, for the texts it sends.
    _session = ref.listenManual<AsyncValue<AppRepository?>>(
      sessionRepositoryProvider,
      (AsyncValue<AppRepository?>? _, AsyncValue<AppRepository?> next) {
        final AppRepository? repository = next.valueOrNull;
        if (repository == null) return;
        unawaited(PushService.start(repository.social));
        unawaited(_saveLanguage(repository));
        // Listening from the start of every session is what picks up
        // renewals and purchases that finished while the app was closed.
        unawaited(ref.read(subscriptionServiceProvider).refreshRenewals());
      },
      fireImmediately: true,
    );

    // Pushes are written by the server in the language the user reads;
    // a language switch in the app has to reach it too.
    _locale = ref.listenManual<Locale>(
      effectiveLocaleProvider,
      (Locale? previous, Locale next) {
        if (previous?.languageCode == next.languageCode) return;
        final AppRepository? repository =
            ref.read(sessionRepositoryProvider).valueOrNull;
        if (repository != null) unawaited(_saveLanguage(repository));
        _lastScheduledFor = null;
        _rescheduleFromState();
      },
    );

    // A new reminder time or a switch turned off takes effect at once.
    _prefs = ref.listenManual<AppPrefs>(
      appPrefsProvider,
      (AppPrefs? previous, AppPrefs next) {
        AppSounds.enabled = next.soundOn;
        _lastScheduledFor = null;
        _rescheduleFromState();
      },
    );

    _syncSubscription = ref.listenManual<AsyncValue<SyncReport>>(
      syncReportsProvider,
      (AsyncValue<SyncReport>? _, AsyncValue<SyncReport> next) {
        final SyncReport? report = next.valueOrNull;
        if (report != null) unawaited(_onSyncReport(report));
      },
    );

    // The month's allowance ran out mid-task: say so, once, with the way
    // out, rather than letting the feature quietly fall back.
    _aiFailures = ref.listenManual<AiFailure?>(
      aiFailureProvider,
      (AiFailure? _, AiFailure? failure) {
        if (failure != AiFailure.quotaExceeded) return;
        ref.read(aiFailureProvider.notifier).state = null;
        final BuildContext? context = appNavigatorKey.currentContext;
        if (context != null) unawaited(showPaywall(context));
      },
    );

    // A password-reset link signed the user in: ask for the new password.
    _recoveries = ref
        .read(authServiceProvider)
        .passwordRecoveries
        .listen((void _) {
      final BuildContext? context = appNavigatorKey.currentContext;
      if (context == null || !context.mounted) return;
      unawaited(showDialog<void>(
        context: context,
        builder: (BuildContext context) => const NewPasswordDialog(),
      ));
    }, onError: (Object _) {});

    final AppLinks links = AppLinks();
    unawaited(links.getInitialLink().then(_onLink, onError: (Object _) {}));
    _links = links.uriLinkStream.listen(_onLink, onError: (Object _) {});

    // Realtime delivers while the app is open; this catches what a dropped
    // connection missed.
    _periodicSync = Timer.periodic(const Duration(minutes: 2), (_) => _sync());
  }

  Future<void> _saveLanguage(AppRepository repository) async {
    try {
      final SocialSettings settings = await repository.social.settings();
      final String language = ref.read(effectiveLocaleProvider).languageCode;
      if (settings.language != language) {
        await repository.social.saveSettings(settings.copyWith(language: language));
      }
    } on Object {
      // Offline: the next start tries again.
    }
  }

  void _onLink(Uri? uri) {
    if (uri == null || uri.scheme != kInviteScheme) return;
    if (uri.host != 'invite' && uri.host != 'household') return;
    _pendingInvite = uri.toString();
    _redeemPendingInvite();
  }

  void _redeemPendingInvite() {
    final String? invite = _pendingInvite;
    final BuildContext? context = appNavigatorKey.currentContext;
    final AppSnapshot? snapshot = ref.read(appStateProvider).valueOrNull;
    if (invite == null || context == null || snapshot == null) return;
    if (!snapshot.hasChallenge) return;
    _pendingInvite = null;
    unawaited(Uri.parse(invite).host == 'household'
        ? joinHouseholdFlow(context, ref, invite)
        : redeemInviteFlow(context, ref, invite));
  }

  void _sync() {
    if (ref.read(sessionRepositoryProvider).valueOrNull == null) return;
    unawaited(ref.read(appStateProvider.notifier).syncNow().then(
        (SyncReport _) {}, onError: (Object _) {}));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Coming back into the app — maybe the next morning. Today first,
      // from the phone's own store, so nothing waits on the network; then
      // the user is holding the phone, probably online, and wants to see
      // what friends did meanwhile.
      if (ref.read(sessionRepositoryProvider).valueOrNull != null) {
        unawaited(ref
            .read(appStateProvider.notifier)
            .refresh()
            .then((void _) {}, onError: (Object _) {}));
      }
      _sync();
    }
  }

  /// Notification text is resolved outside the widget tree, so it follows the
  /// same language setting the screens do.
  Future<AppLocalizations> _strings() =>
      AppLocalizations.delegate.load(ref.read(effectiveLocaleProvider));

  NotificationCopy _copy(AppLocalizations l10n) => NotificationCopy(
        appTitle: l10n.appTitle,
        reminderChannelName: l10n.notifChannelReminder,
        reminderChannelDescription: l10n.notifChannelReminderDesc,
        pressureChannelName: l10n.notifChannelPressure,
        pressureChannelDescription: l10n.notifChannelPressureDesc,
        streakRiskTitle: l10n.notifStreakRiskTitle,
      );

  void _rescheduleFromState() {
    final AppSnapshot? snapshot = ref.read(appStateProvider).valueOrNull;
    if (snapshot != null && snapshot.hasChallenge) {
      unawaited(_scheduleReminders(snapshot));
    }
  }

  /// Friends already announced today, so each one is announced once — not
  /// again with every sync while the user has not checked in.
  final Set<String> _announced = <String>{};
  String? _announcedOn;

  Future<void> _onSyncReport(SyncReport report) async {
    if (!report.broughtSomething) return;
    await ref.read(appStateProvider.notifier).refresh();

    final AppSnapshot? snapshot = ref.read(appStateProvider).valueOrNull;
    if (snapshot == null || snapshot.me.streak.doneToday) return;
    if (!ref.read(appPrefsProvider).remindersOn) return;

    if (_announcedOn != snapshot.today.toString()) {
      _announcedOn = snapshot.today.toString();
      _announced.clear();
    }
    final List<PeerState> active = snapshot.peerStates
        .where((PeerState p) => p.activeToday)
        .toList();
    final bool anyNew =
        active.any((PeerState p) => !_announced.contains(p.userId));
    if (!anyNew) return;
    _announced.addAll(active.map((PeerState p) => p.userId));

    final AppLocalizations l10n = await _strings();
    await ref.read(notificationsProvider).showNow(
          copy: _copy(l10n),
          id: snapshot.today.toString().hashCode,
          title: active.length == 1
              ? l10n.notifFriendActive(active.first.profile.displayName)
              : l10n.notifFriendsActive(active.length),
          body: l10n.notifFriendsActiveBody,
        );
  }

  /// Hands the home screen widget today's state and the next two weeks.
  Future<void> _publishWidget(AppSnapshot snapshot) async {
    await ref.read(streakWidgetProvider).publish(snapshot, await _strings());
  }

  /// Rewrites the next two weeks of reminders on every state change.
  ///
  /// Cheap enough to do eagerly, and it keeps the text honest: a reminder
  /// written today knows today's streak, so it can say "Tag 41" instead of
  /// something generic.
  ///
  /// Each day's text comes from the outlook — the streak as it stands on
  /// that day if nothing more is logged — which is exactly the case in which
  /// a reminder fires: someone who opens the app reschedules them all.
  Future<void> _scheduleReminders(AppSnapshot snapshot) async {
    final AppPrefs prefs = ref.read(appPrefsProvider);
    final String signature = '${snapshot.today}-${snapshot.me.streak.current}-'
        '${snapshot.me.streak.doneToday}-${snapshot.me.frozenDays.length}-'
        '${ref.read(effectiveLocaleProvider).languageCode}-'
        '${prefs.remindersOn}-${prefs.streakWarningOn}-'
        '${prefs.reminderTime.hour}:${prefs.reminderTime.minute}';
    if (_lastScheduledFor == signature) return;
    _lastScheduledFor = signature;

    final NotificationService notifications = ref.read(notificationsProvider);
    final Challenge challenge = snapshot.challenge!;
    final AppLocalizations l10n = await _strings();
    final NotificationCopy copy = _copy(l10n);
    final List<StreakOutlook> outlook = projectOutlook(
      challenge: challenge,
      streak: snapshot.me.streak,
      today: snapshot.today,
      logsByDay: snapshot.me.logsByDay,
      frozenDays: snapshot.me.frozenDays,
    );

    if (prefs.remindersOn) {
      await notifications.scheduleDailyReminders(
        copy: copy,
        hour: prefs.reminderTime.hour,
        minute: prefs.reminderTime.minute,
        messageBuilder: (int offset) {
          if (offset >= outlook.length) return null;
          final StreakOutlook day = outlook[offset];
          final int number = challenge.dayNumber(day.day);
          return switch (day.state) {
            // Done already: no reminder — a "well done" at 18:30 is noise.
            OutlookState.done || OutlookState.rest || OutlookState.frozen =>
              null,
            OutlookState.open => day.streak > 0
                ? l10n.notifDayOpenWithStreak(
                    number, challenge.lengthDays, day.streak)
                : l10n.notifDayOpenNoStreak(number, challenge.lengthDays),
            OutlookState.cold =>
              l10n.notifDayOpenNoStreak(number, challenge.lengthDays),
          };
        },
      );
    } else {
      await notifications.cancelDailyReminders();
    }

    if (prefs.streakWarningOn) {
      // Late enough to be a warning, and after the reminder.
      final int reminderMinute =
          prefs.reminderTime.hour * 60 + prefs.reminderTime.minute;
      final int warnMinute =
          reminderMinute >= 21 * 60 + 30 ? 22 * 60 + 45 : 21 * 60 + 30;
      await notifications.scheduleStreakRisk(
        copy: copy,
        hour: warnMinute ~/ 60,
        minute: warnMinute % 60,
        bodyBuilder: (int offset) {
          if (offset >= outlook.length) return null;
          final StreakOutlook day = outlook[offset];
          // Only an open day with a streak worth losing; never a day that is
          // done, resting or held by a freeze.
          if (day.state != OutlookState.open || day.streak < 3) return null;
          return l10n.notifStreakRiskBody(day.streak);
        },
      );
    } else {
      await notifications.cancelStreakRisk();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.close();
    _syncSubscription?.close();
    _aiFailures?.close();
    _session?.close();
    _locale?.close();
    _prefs?.close();
    _sharedTargets?.close();
    unawaited(_links?.cancel());
    unawaited(_recoveries?.cancel());
    _periodicSync?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
