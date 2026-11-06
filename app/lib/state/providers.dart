import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';

import 'dart:ui';

import '../data/app_repository.dart';
import '../data/device_profile.dart';
import '../data/lan_transport.dart';
import '../data/llama_runtime.dart';
import '../data/locale_store.dart';
import '../data/llm_runtime.dart';
import '../data/model_download.dart';
import '../data/notifications.dart';
import '../data/streak_widget.dart';
import '../data/sync_service.dart';
import '../l10n/l10n.dart';
import '../l10n/prompt_l10n.dart';

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

/// The streak on the home screen. Talks to a platform plugin, so widget tests
/// leave it alone: off Android and iOS it does nothing.
final Provider<StreakWidgetSync> streakWidgetProvider =
    Provider<StreakWidgetSync>((Ref ref) => StreakWidgetSync());

/// Whether to offer putting the widget on the home screen: Android, a
/// launcher that supports it, and no widget there yet.
final FutureProvider<bool> canPinStreakWidgetProvider =
    FutureProvider<bool>((Ref ref) => ref.watch(streakWidgetProvider).canPin());

final Provider<LocalModelManager> modelManagerProvider =
    Provider<LocalModelManager>((Ref ref) => LocalModelManager());

final Provider<LocaleStore> localeStoreProvider = Provider<LocaleStore>(
  (Ref ref) => throw UnimplementedError('localeStoreProvider not initialised'),
);

/// The language override, or null to follow the system.
class LocaleController extends Notifier<Locale?> {
  @override
  Locale? build() => ref.watch(localeStoreProvider).read();

  Future<void> set(Locale? locale) async {
    await ref.read(localeStoreProvider).write(locale);
    state = locale;
  }
}

final NotifierProvider<LocaleController, Locale?> localeProvider =
    NotifierProvider<LocaleController, Locale?>(LocaleController.new);

/// The locale actually in effect: the explicit choice, or the first system
/// language the app ships, or German.
final Provider<Locale> effectiveLocaleProvider = Provider<Locale>((Ref ref) {
  final Locale? chosen = ref.watch(localeProvider);
  if (chosen != null) return chosen;
  for (final Locale system in PlatformDispatcher.instance.locales) {
    final match = kSupportedLocales
        .where((Locale l) => l.languageCode == system.languageCode)
        .firstOrNull;
    if (match != null) return match;
  }
  return kSupportedLocales.first;
});

/// The phone the app runs on. Falls back to [DeviceProfile.unknown] where
/// the platform will not say (tests, desktop).
final FutureProvider<DeviceProfile> deviceProfileProvider =
    FutureProvider<DeviceProfile>((Ref ref) => DeviceProfile.detect());

/// The model file on disk, if any. Invalidated after a download or removal.
final FutureProvider<LocalModelSpec?> installedModelProvider =
    FutureProvider<LocalModelSpec?>((Ref ref) async {
  try {
    return await ref.watch(modelManagerProvider).installedModel();
  } on Object {
    // No file system to look at (widget tests): no model.
    return null;
  }
});

/// The loaded on-device model, shared by the coach and the nutrition
/// assistant — loading it twice would cost twice the memory. Null when no
/// model is installed or it fails to load.
final FutureProvider<LocalLlmRuntime?> llmRuntimeProvider =
    FutureProvider<LocalLlmRuntime?>((Ref ref) async {
  final spec = await ref.watch(installedModelProvider.future);
  if (spec == null) return null;
  final file = await ref.read(modelManagerProvider).fileFor(spec);
  if (file == null) return null;
  final runtime = LlamaCppRuntime(spec: spec, file: file);
  ref.onDispose(runtime.dispose);
  try {
    await runtime.load();
  } on Object catch (error) {
    // A model that will not load must never take the app down with it.
    debugPrint('Local model failed to load: $error');
    return null;
  }
  return runtime;
});

/// The coach the app is currently using.
///
/// Falls back to the rule-based engine unless a model is installed and
/// loads, so the app is never in a state where it cannot say something
/// useful.
final FutureProvider<CoachEngine> coachEngineProvider =
    FutureProvider<CoachEngine>((Ref ref) async {
  final runtime = await ref.watch(llmRuntimeProvider.future);
  if (runtime == null) return const HeuristicCoach();
  // Small models help with the diary, where every answer is checked; the
  // coach's line is shown as it comes, so only models that stay on topic
  // write it.
  final spec = await ref.watch(installedModelProvider.future);
  if (spec == null || !spec.writesCoach) return const HeuristicCoach();

  // The prompt is written in the user's language, so the coach has to be
  // rebuilt when that changes.
  final locale = ref.watch(effectiveLocaleProvider);
  final l10n = await AppLocalizations.delegate.load(locale);
  return LocalLlmCoach(
    runtime: runtime,
    prompts: LocalizedCoachPrompts(l10n),
    // A phone CPU writes ten to twenty tokens a second.
    timeout: const Duration(seconds: 40),
  );
});

/// Meal estimates, suggestions and target proposals — or null without a
/// model, in which case the diary works from the food table alone.
final FutureProvider<NutritionAssistant?> nutritionAssistantProvider =
    FutureProvider<NutritionAssistant?>((Ref ref) async {
  final runtime = await ref.watch(llmRuntimeProvider.future);
  if (runtime == null) return null;
  final locale = ref.watch(effectiveLocaleProvider);
  final l10n = await AppLocalizations.delegate.load(locale);
  return NutritionAssistant(
    runtime: runtime,
    prompts: LocalizedNutritionPrompts(l10n),
  );
});

enum DownloadPhase { idle, downloading, verifying, done, failed, cancelled }

class ModelDownloadState {
  const ModelDownloadState({
    this.phase = DownloadPhase.idle,
    this.spec,
    this.received = 0,
    this.total = 0,
    this.error,
  });

  final DownloadPhase phase;
  final LocalModelSpec? spec;
  final int received;
  final int total;
  final Object? error;

  bool get isActive =>
      phase == DownloadPhase.downloading || phase == DownloadPhase.verifying;

  double? get fraction => total <= 0 ? null : (received / total).clamp(0, 1);
}

/// One model download at a time, started from onboarding or settings and
/// running while the user does other things.
class ModelDownloadController extends Notifier<ModelDownloadState> {
  ModelDownloader? _active;

  @override
  ModelDownloadState build() => const ModelDownloadState();

  Future<void> start(LocalModelSpec spec) async {
    if (state.isActive) return;
    final downloader = _active = ModelDownloader();
    state = ModelDownloadState(
      phase: DownloadPhase.downloading,
      spec: spec,
      total: spec.sizeBytes,
    );
    try {
      final manager = ref.read(modelManagerProvider);
      await downloader.download(
        spec,
        await manager.targetFile(spec),
        onProgress: (int received, int total) {
          // Repainting per network chunk would be thousands of frames.
          final step = total ~/ 400;
          if (received - state.received < step && received < total) return;
          state = ModelDownloadState(
            phase: DownloadPhase.downloading,
            spec: spec,
            received: received,
            total: total,
          );
        },
        onVerifying: () => state = ModelDownloadState(
          phase: DownloadPhase.verifying,
          spec: spec,
          received: spec.sizeBytes,
          total: spec.sizeBytes,
        ),
      );
      // One model at a time: the new one replaces whatever was there.
      await manager.keepOnly(spec);
      state = ModelDownloadState(
        phase: DownloadPhase.done,
        spec: spec,
        received: spec.sizeBytes,
        total: spec.sizeBytes,
      );
      ref.invalidate(installedModelProvider);
    } on ModelDownloadCancelled {
      state = ModelDownloadState(phase: DownloadPhase.cancelled, spec: spec);
    } on Object catch (error) {
      state = ModelDownloadState(
        phase: DownloadPhase.failed,
        spec: spec,
        error: error,
      );
    } finally {
      _active = null;
    }
  }

  void cancel() => _active?.cancel();
}

final NotifierProvider<ModelDownloadController, ModelDownloadState>
    modelDownloadProvider =
    NotifierProvider<ModelDownloadController, ModelDownloadState>(
        ModelDownloadController.new);

/// Strangers who connected and want in.
final StreamProvider<List<FriendRequest>> friendRequestsProvider =
    StreamProvider<List<FriendRequest>>((Ref ref) async* {
  final sync = ref.watch(syncServiceProvider);
  if (sync == null) {
    yield const <FriendRequest>[];
    return;
  }
  yield sync.friendRequests;
  yield* sync.friendRequestChanges;
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

  /// Saves an edited challenge: a new split, own nutrition targets, a
  /// sharing change.
  Future<void> updateChallenge(Challenge challenge) async {
    await _repository.updateChallenge(challenge);
    await refresh();
  }

  Future<void> checkIn(
    Habit habit, {
    num? value,
    String? note,
    bool tracked = false,
    DayKey? day,
  }) async {
    final snapshot = state.valueOrNull;
    await _repository.checkIn(
      habit: habit,
      day: day ?? snapshot?.today ?? DayKey.today(),
      value: value,
      note: note,
      streak: snapshot?.me.habitStreaks[habit.id],
      tracked: tracked,
      challenge: snapshot?.challenge,
    );
    await refresh();
  }

  Future<void> checkInOn(Habit habit, DayKey day, {num? value}) async {
    await _repository.checkIn(
      habit: habit,
      day: day,
      value: value,
      challenge: state.valueOrNull?.challenge,
    );
    await refresh();
  }

  Future<void> logRelapse(Habit habit, {String? note}) async {
    final snapshot = state.valueOrNull;
    await _repository.logRelapse(
      habit: habit,
      day: snapshot?.today ?? DayKey.today(),
      note: note,
      challenge: snapshot?.challenge,
    );
    await refresh();
  }

  Future<void> logWorkout(WorkoutLog log, Habit habit) async {
    final snapshot = state.valueOrNull;
    final challenge = snapshot?.challenge;
    if (challenge == null) return;
    await _repository.logWorkout(
      log: log,
      habit: habit,
      challenge: challenge,
      streak: snapshot?.me.habitStreaks[habit.id],
    );
    await refresh();
  }

  Future<void> logFood(FoodEntry entry) async {
    await _repository.logFood(entry);
    await refresh();
  }

  Future<void> removeFood(String entryId) async {
    await _repository.removeFood(entryId);
    await refresh();
  }

  Future<void> acceptFriendRequest(FriendRequest request) async {
    ref.read(syncServiceProvider)?.resolveRequest(request.did, accepted: true);
    await _repository.addFriend(Invite(
      did: request.did,
      displayName: request.displayName,
      avatarEmoji: request.avatarEmoji,
    ));
    await refresh();
    unawaited(syncNow());
  }

  void declineFriendRequest(FriendRequest request) =>
      ref.read(syncServiceProvider)?.resolveRequest(request.did, accepted: false);

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

/// The rule-based coach's directive for right now — instant, so the home
/// screen never waits on a model. The wording is applied by the widget that
/// shows it, in whatever language the app is running in.
final FutureProvider<CoachDirective?> briefingProvider =
    FutureProvider<CoachDirective?>((Ref ref) async {
  final snapshot = await ref.watch(appStateProvider.future);
  if (!snapshot.hasChallenge) return null;
  return const HeuristicCoach().dailyBriefing(snapshot.toCoachContext());
});

/// The same moment phrased by the on-device model, when there is one. Takes
/// seconds on a phone; the card swaps it in once it arrives.
final FutureProvider<CoachDirective?> modelBriefingProvider =
    FutureProvider<CoachDirective?>((Ref ref) async {
  final snapshot = await ref.watch(appStateProvider.future);
  if (!snapshot.hasChallenge) return null;
  final coach = await ref.watch(coachEngineProvider.future);
  if (coach.modelName == null) return null;
  final directive = await coach.dailyBriefing(snapshot.toCoachContext());
  return directive.source == CoachSource.llm ? directive : null;
});

/// Ready-made jabs for friends who have not moved today.
///
/// Templates, not the model: a phone writes a sentence in seconds, and a
/// list of friends must not sit empty while it does — once per friend.
final FutureProvider<List<NudgeSuggestion>> nudgeSuggestionsProvider =
    FutureProvider<List<NudgeSuggestion>>((Ref ref) async {
  final snapshot = await ref.watch(appStateProvider.future);
  if (!snapshot.hasChallenge) return const <NudgeSuggestion>[];
  return const HeuristicCoach().nudgeSuggestions(snapshot.toCoachContext());
});

/// Live sync activity for the status strip.
final StreamProvider<SyncEvent> syncEventsProvider =
    StreamProvider<SyncEvent>((Ref ref) {
  final sync = ref.watch(syncServiceProvider);
  return sync?.events ?? const Stream<SyncEvent>.empty();
});
