import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import 'app.dart';
import 'config/backend_config.dart';
import 'data/app_repository.dart';
import 'data/feed_sync.dart';
import 'data/locale_store.dart';
import 'data/notifications.dart';
import 'l10n/l10n.dart';
import 'state/providers.dart';
import 'ai/dartantic_llm_client.dart';
import 'ui/mealplan/household_screen.dart';
import 'ui/settings/ai_screen.dart';
import 'ui/social/invite_flow.dart';

Future<void> main() async {
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

  runApp(ProviderScope(
    overrides: <Override>[
      backendConfigProvider.overrideWithValue(backend),
      notificationsProvider.overrideWithValue(notifications),
      localeStoreProvider.overrideWithValue(localeStore),
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
  StreamSubscription<Uri>? _links;
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
          _redeemPendingInvite();
          unawaited(_scheduleReminders(snapshot));
          unawaited(_publishWidget(snapshot));
        }
      },
      fireImmediately: true,
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

    final AppLinks links = AppLinks();
    unawaited(links.getInitialLink().then(_onLink, onError: (Object _) {}));
    _links = links.uriLinkStream.listen(_onLink, onError: (Object _) {});

    // Realtime delivers while the app is open; this catches what a dropped
    // connection missed.
    _periodicSync = Timer.periodic(const Duration(minutes: 2), (_) => _sync());
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
      // Coming back into the app: the user is holding the phone, probably
      // online, and wants to see what friends did meanwhile.
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

  Future<void> _onSyncReport(SyncReport report) async {
    if (!report.broughtSomething) return;
    await ref.read(appStateProvider.notifier).refresh();

    final AppSnapshot? snapshot = ref.read(appStateProvider).valueOrNull;
    if (snapshot == null || snapshot.me.streak.doneToday) return;

    final List<PeerState> active = snapshot.peerStates
        .where((PeerState p) => p.activeToday)
        .toList();
    if (active.isEmpty) return;

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
  Future<void> _scheduleReminders(AppSnapshot snapshot) async {
    final String signature = '${snapshot.today}-${snapshot.me.streak.current}-'
        '${snapshot.me.streak.doneToday}-'
        '${ref.read(effectiveLocaleProvider).languageCode}';
    if (_lastScheduledFor == signature) return;
    _lastScheduledFor = signature;

    final NotificationService notifications = ref.read(notificationsProvider);
    final Challenge challenge = snapshot.challenge!;
    final int streak = snapshot.me.streak.current;
    final AppLocalizations l10n = await _strings();
    final NotificationCopy copy = _copy(l10n);

    await notifications.scheduleDailyReminders(
      copy: copy,
      hour: 18,
      minute: 30,
      messageBuilder: (int offset) {
        final int day = challenge.dayNumber(snapshot.today.addDays(offset));
        if (offset == 0 && snapshot.me.streak.doneToday) {
          return l10n.notifDayDone(day);
        }
        return streak > 0
            ? l10n.notifDayOpenWithStreak(day, challenge.lengthDays, streak)
            : l10n.notifDayOpenNoStreak(day, challenge.lengthDays);
      },
    );

    if (streak >= 3) {
      await notifications.scheduleStreakRisk(
        copy: copy,
        hour: 21,
        minute: 30,
        body: l10n.notifStreakRiskBody(streak),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.close();
    _syncSubscription?.close();
    _aiFailures?.close();
    unawaited(_links?.cancel());
    _periodicSync?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
