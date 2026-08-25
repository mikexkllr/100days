import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';

import '../data/app_repository.dart';
import '../data/lan_transport.dart';
import '../data/llm_runtime.dart';
import '../data/notifications.dart';
import '../data/sync_service.dart';

/// Overridden in `main()` once the database and keystore are open.
final Provider<AppRepository> repositoryProvider = Provider<AppRepository>(
  (Ref ref) => throw UnimplementedError('repositoryProvider not initialised'),
);

final Provider<NotificationService> notificationsProvider =
    Provider<NotificationService>(
  (Ref ref) => throw UnimplementedError('notificationsProvider not initialised'),
);

final Provider<SyncService?> syncServiceProvider =
    Provider<SyncService?>((Ref ref) => null);

/// The LAN transport, when one is running. Null on platforms or networks
/// where it could not start.
final Provider<LanTransport?> lanTransportProvider =
    Provider<LanTransport?>((Ref ref) => null);

final Provider<LocalModelManager> modelManagerProvider =
    Provider<LocalModelManager>((Ref ref) => LocalModelManager());

/// The coach the app is currently using.
///
/// Falls back to the rule-based engine unless a model *and* an inference
/// backend are both present, so the app is never in a state where it cannot
/// say something useful.
final FutureProvider<CoachEngine> coachEngineProvider =
    FutureProvider<CoachEngine>((Ref ref) async {
  if (!GgufLlmRuntime.hasBackend) return const HeuristicCoach();
  final manager = ref.watch(modelManagerProvider);
  final spec = await manager.installedModel();
  if (spec == null) return const HeuristicCoach();
  final file = await manager.fileFor(spec);
  if (file == null) return const HeuristicCoach();
  final runtime = GgufLlmRuntime(spec: spec, file: file);
  await runtime.load();
  ref.onDispose(runtime.dispose);
  return LocalLlmCoach(runtime: runtime);
});

/// The app's single source of truth for the UI.
class AppController extends AsyncNotifier<AppSnapshot> {
  Timer? _debounce;

  @override
  Future<AppSnapshot> build() async {
    final repository = ref.watch(repositoryProvider);

    // The feed changes both from local actions and from peer sync. Debounced
    // because a sync round can land two hundred events in a burst, and
    // reprojecting once per event would jank the whole screen.
    final subscription = repository.changes.listen((FeedEvent _) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 120), () {
        ref.invalidateSelf();
      });
    });
    ref.onDispose(() {
      _debounce?.cancel();
      subscription.cancel();
    });

    return repository.snapshot();
  }

  AppRepository get _repository => ref.read(repositoryProvider);

  Future<void> refresh() async {
    state = AsyncValue<AppSnapshot>.data(await _repository.snapshot());
  }

  Future<void> saveProfile({
    required String displayName,
    required String avatarEmoji,
    String? goalStatement,
  }) async {
    await _repository.saveProfile(
      displayName: displayName,
      avatarEmoji: avatarEmoji,
      goalStatement: goalStatement,
    );
    await refresh();
  }

  Future<void> startChallenge(Challenge challenge) async {
    await _repository.startChallenge(challenge);
    await refresh();
  }

  Future<void> checkIn(Habit habit, {num? value, String? note}) async {
    final snapshot = state.valueOrNull;
    final day = snapshot?.today ?? DayKey.today();
    await _repository.checkIn(
      habit: habit,
      day: day,
      value: value,
      note: note,
      streak: snapshot?.me.habitStreaks[habit.id],
    );
    await refresh();
  }

  Future<void> checkInOn(Habit habit, DayKey day, {num? value}) async {
    await _repository.checkIn(habit: habit, day: day, value: value);
    await refresh();
  }

  Future<void> logRelapse(Habit habit, {String? note}) async {
    final day = state.valueOrNull?.today ?? DayKey.today();
    await _repository.logRelapse(habit: habit, day: day, note: note);
    await refresh();
  }

  Future<void> useStreakFreeze() async {
    final day = state.valueOrNull?.today ?? DayKey.today();
    await _repository.useStreakFreeze(day);
    await refresh();
  }

  Future<void> ascend() async {
    final challenge = state.valueOrNull?.challenge;
    if (challenge == null) return;
    await _repository.ascend(challenge);
    await refresh();
  }

  Future<void> nudge(String targetDid, String text) async {
    await _repository.nudge(targetDid, text);
    await refresh();
  }

  Future<void> cheer(
    String targetDid,
    String text, {
    String? eventHash,
  }) async {
    await _repository.cheer(targetDid, text, eventHash: eventHash);
    await refresh();
  }

  Future<void> addFriend(Invite invite) async {
    await _repository.addFriend(invite);
    await refresh();
    unawaited(_syncWith(invite));
  }

  Future<void> removeFriend(String did) async {
    await _repository.removeFriend(did);
    await refresh();
  }

  Future<void> syncNow() async {
    await ref.read(syncServiceProvider)?.syncNow();
    await refresh();
  }

  Future<void> _syncWith(Invite invite) async {
    final sync = ref.read(syncServiceProvider);
    if (sync == null) return;
    for (final address in invite.addresses) {
      try {
        await sync.syncWithAddress('lan', address);
      } on Object {
        // The address in the invite goes stale as soon as the peer's DHCP
        // lease changes; discovery will find them on the next round.
      }
    }
    await refresh();
  }
}

final AsyncNotifierProvider<AppController, AppSnapshot> appStateProvider =
    AsyncNotifierProvider<AppController, AppSnapshot>(AppController.new);

/// The coach's message for right now.
final FutureProvider<CoachMessage?> briefingProvider =
    FutureProvider<CoachMessage?>((Ref ref) async {
  final snapshot = await ref.watch(appStateProvider.future);
  if (!snapshot.hasChallenge) return null;
  final coach = await ref.watch(coachEngineProvider.future);
  return coach.dailyBriefing(snapshot.toCoachContext());
});

/// Concrete plan tweaks, shown on the plan screen.
final FutureProvider<List<String>> planAdjustmentsProvider =
    FutureProvider<List<String>>((Ref ref) async {
  final snapshot = await ref.watch(appStateProvider.future);
  if (!snapshot.hasChallenge) return const <String>[];
  final coach = await ref.watch(coachEngineProvider.future);
  return coach.planAdjustments(snapshot.toCoachContext());
});

/// Ready-made jabs for friends who have not moved today.
final FutureProvider<List<NudgeSuggestion>> nudgeSuggestionsProvider =
    FutureProvider<List<NudgeSuggestion>>((Ref ref) async {
  final snapshot = await ref.watch(appStateProvider.future);
  if (!snapshot.hasChallenge) return const <NudgeSuggestion>[];
  final coach = await ref.watch(coachEngineProvider.future);
  return coach.nudgeSuggestions(snapshot.toCoachContext());
});

/// Live sync activity for the status strip.
final StreamProvider<SyncEvent> syncEventsProvider =
    StreamProvider<SyncEvent>((Ref ref) {
  final sync = ref.watch(syncServiceProvider);
  return sync?.events ?? const Stream<SyncEvent>.empty();
});
