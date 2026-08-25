import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';

import 'app.dart';
import 'data/app_repository.dart';
import 'data/key_store.dart';
import 'data/lan_transport.dart';
import 'data/notifications.dart';
import 'data/sqlite_feed_store.dart';
import 'data/sync_service.dart';
import 'state/providers.dart';

/// The name peers see during a handshake.
///
/// Held in a mutable box because the transports start before the profile is
/// projected, and the user can rename themselves at any time afterwards.
class _LocalName {
  String value = 'Jemand';
}

final _LocalName _localName = _LocalName();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final SqliteFeedStore store = await SqliteFeedStore.open();
  final AppRepository repository = await AppRepository.open(
    keyStore: SecureKeyStore(),
    store: store,
  );

  final NotificationService notifications = NotificationService();
  await notifications.initialize();

  final SyncService sync = SyncService(
    store: store,
    replicator: repository.replicator,
    localDid: repository.did,
    localDisplayName: () => _localName.value,
    followedDids: () => repository.follows,
  );

  // Discovery and replication are best-effort: a locked-down network must
  // degrade the app to "works alone", never to "does not start".
  LanTransport? lan;
  try {
    lan = LanTransport(
      localDid: repository.did,
      localName: () => _localName.value,
    );
    await sync.addTransport(lan);
  } on Object catch (error) {
    debugPrint('LAN transport unavailable: $error');
    lan = null;
  }

  runApp(ProviderScope(
    overrides: <Override>[
      repositoryProvider.overrideWithValue(repository),
      notificationsProvider.overrideWithValue(notifications),
      syncServiceProvider.overrideWithValue(sync),
      lanTransportProvider.overrideWithValue(lan),
    ],
    child: const _Bootstrap(child: HundredDaysApp()),
  ));
}

/// Side effects that need the provider container: reminder scheduling and
/// notifications for peer activity that arrives while the app is open.
class _Bootstrap extends ConsumerStatefulWidget {
  const _Bootstrap({required this.child});

  final Widget child;

  @override
  ConsumerState<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends ConsumerState<_Bootstrap>
    with WidgetsBindingObserver {
  ProviderSubscription<AsyncValue<AppSnapshot>>? _subscription;
  StreamSubscription<SyncEvent>? _syncSubscription;
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
        _localName.value = snapshot.me.profile.displayName;
        if (snapshot.hasChallenge) {
          unawaited(_scheduleReminders(snapshot));
        }
      },
      fireImmediately: true,
    );

    _syncSubscription =
        ref.read(syncServiceProvider)?.events.listen(_onSyncEvent);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Coming back into the app is the cheapest moment to look for peers:
      // the user is holding the phone, on a network, right now.
      unawaited(ref.read(appStateProvider.notifier).syncNow());
    }
  }

  Future<void> _onSyncEvent(SyncEvent event) async {
    if (!event.broughtSomething) return;
    await ref.read(appStateProvider.notifier).refresh();

    final AppSnapshot? snapshot = ref.read(appStateProvider).valueOrNull;
    if (snapshot == null || snapshot.me.streak.doneToday) return;

    final List<PeerState> active = snapshot.peerStates
        .where((PeerState p) => p.activeToday)
        .toList();
    if (active.isEmpty) return;

    await ref.read(notificationsProvider).showNow(
          id: snapshot.today.toString().hashCode,
          title: active.length == 1
              ? '${active.first.profile.displayName} war heute schon dran'
              : '${active.length} deiner Leute waren heute schon dran',
          body: 'Du stehst noch auf null. Noch ist der Tag nicht rum.',
        );
  }

  /// Rewrites the next two weeks of reminders on every state change.
  ///
  /// Cheap enough to do eagerly, and it keeps the text honest: a reminder
  /// written today knows today's streak, so it can say "Tag 41" instead of
  /// something generic.
  Future<void> _scheduleReminders(AppSnapshot snapshot) async {
    final String signature = '${snapshot.today}-${snapshot.me.streak.current}-'
        '${snapshot.me.streak.doneToday}';
    if (_lastScheduledFor == signature) return;
    _lastScheduledFor = signature;

    final NotificationService notifications = ref.read(notificationsProvider);
    final Challenge challenge = snapshot.challenge!;
    final int streak = snapshot.me.streak.current;

    await notifications.scheduleDailyReminders(
      hour: 18,
      minute: 30,
      messageBuilder: (int offset) {
        final int day = challenge.dayNumber(snapshot.today.addDays(offset));
        if (offset == 0 && snapshot.me.streak.doneToday) {
          return 'Tag $day steht. Morgen wieder.';
        }
        return 'Tag $day von ${challenge.lengthDays}. '
            '${streak > 0 ? '$streak Tage Streak wollen verteidigt werden.' : 'Heute wieder anfangen.'}';
      },
    );

    if (streak >= 3) {
      await notifications.scheduleStreakRisk(
        hour: 21,
        minute: 30,
        body: '$streak Tage. Ein vergessener Abend, und sie sind weg.',
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.close();
    unawaited(_syncSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
