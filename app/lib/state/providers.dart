import 'dart:async';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../ai/allowance.dart';
import '../ai/dartantic_llm_client.dart';
import '../ai/gateway.dart';
import '../ai/own_key.dart';
import '../ai/subscription_service.dart';
import '../config/backend_config.dart';
import '../data/app_prefs.dart';
import '../data/app_repository.dart';
import '../data/auth_service.dart';
import '../data/feed_sync.dart';
import '../data/locale_store.dart';
import '../data/notifications.dart';
import '../data/social_backend.dart';
import '../data/sqlite_feed_store.dart';
import '../data/streak_widget.dart';
import '../l10n/l10n.dart';
import '../l10n/prompt_l10n.dart';

/// The backend this install talks to. Overridden in `main()`.
final Provider<BackendConfig> backendConfigProvider =
    Provider<BackendConfig>((Ref ref) => BackendConfig.defaults);

/// The Supabase client, once `Supabase.initialize` ran in `main()`.
final Provider<SupabaseClient> supabaseClientProvider =
    Provider<SupabaseClient>((Ref ref) => Supabase.instance.client);

final Provider<AuthService> authServiceProvider = Provider<AuthService>(
  (Ref ref) => AuthService(
    ref.watch(supabaseClientProvider),
    ref.watch(backendConfigProvider),
  ),
);

/// The signed-in account's e-mail address, for the settings screen. Null
/// when Apple hides it, or off the platform (tests).
final Provider<String?> accountEmailProvider = Provider<String?>((Ref ref) {
  ref.watch(signedInUserProvider);
  try {
    return ref.watch(supabaseClientProvider).auth.currentUser?.email;
  } on Object {
    return null;
  }
});

/// The first name the identity provider reported, to prefill the profile.
final Provider<String?> accountGivenNameProvider = Provider<String?>((Ref ref) {
  ref.watch(signedInUserProvider);
  try {
    final Map<String, dynamic>? meta =
        ref.watch(supabaseClientProvider).auth.currentUser?.userMetadata;
    final String? name = (meta?['given_name'] ??
        (meta?['full_name'] as String?)?.split(' ').first ??
        (meta?['name'] as String?)?.split(' ').first) as String?;
    return name == null || name.isEmpty ? null : name;
  } on Object {
    return null;
  }
});

/// The signed-in account's id, or null while signed out.
final StreamProvider<String?> signedInUserProvider =
    StreamProvider<String?>((Ref ref) async* {
  final SupabaseClient client = ref.watch(supabaseClientProvider);
  String? last = client.auth.currentUser?.id;
  yield last;
  // The first auth event repeats the session we already reported; yielding
  // it again would build the account's repository a second time.
  await for (final AuthState state in client.auth.onAuthStateChange) {
    final String? id = state.session?.user.id;
    if (id == last) continue;
    last = id;
    yield id;
  }
});

/// The previous account's repository while it shuts down. The next one
/// waits for it: both open the same database file.
Future<void>? _closingRepository;

/// The signed-in account's data: its local store, its friends, its sync.
/// Null while signed out. Rebuilt — and the previous one closed — when the
/// account changes.
final FutureProvider<AppRepository?> sessionRepositoryProvider =
    FutureProvider<AppRepository?>((Ref ref) async {
  final String? userId = await ref.watch(signedInUserProvider.future);
  final Future<void>? closing = _closingRepository;
  if (closing != null) await closing.catchError((Object _) {});
  if (userId == null) return null;
  final SupabaseClient client = ref.watch(supabaseClientProvider);
  final SqliteFeedStore store = await SqliteFeedStore.open();
  final SupabaseFeedSync sync =
      SupabaseFeedSync(client: client, store: store, userId: userId);
  final AppRepository repository = AppRepository(
    userId: userId,
    store: store,
    social: SupabaseSocialBackend(client, userId: userId),
    sync: sync,
    requiresFirstPull: true,
  );
  // A store left over from another account on this phone is not ours.
  await repository.open();
  ref.onDispose(() {
    _closingRepository = repository.close();
  });
  sync.start();
  unawaited(repository.syncNow());
  return repository;
});

/// The repository the screens use. Only read below the sign-in gate, where
/// [sessionRepositoryProvider] has produced one; tests override it.
final Provider<AppRepository> repositoryProvider = Provider<AppRepository>(
  (Ref ref) {
    final AppRepository? repository =
        ref.watch(sessionRepositoryProvider).valueOrNull;
    if (repository == null) throw StateError('Nobody is signed in');
    return repository;
  },
);

final Provider<NotificationService> notificationsProvider =
    Provider<NotificationService>(
  (Ref ref) => throw UnimplementedError('notificationsProvider not initialised'),
);

/// The streak on the home screen. Talks to a platform plugin, so widget tests
/// leave it alone: off Android and iOS it does nothing.
final Provider<StreakWidgetSync> streakWidgetProvider =
    Provider<StreakWidgetSync>((Ref ref) => StreakWidgetSync());

/// Whether to offer putting the widget on the home screen: Android, a
/// launcher that supports it, and no widget there yet.
final FutureProvider<bool> canPinStreakWidgetProvider =
    FutureProvider<bool>((Ref ref) => ref.watch(streakWidgetProvider).canPin());

/// Where this phone's preferences live. Overridden in `main()`; memory
/// otherwise (tests, the demo).
final Provider<AppPrefsStore> appPrefsStoreProvider =
    Provider<AppPrefsStore>((Ref ref) => MemoryPrefsStore());

class AppPrefsController extends Notifier<AppPrefs> {
  @override
  AppPrefs build() => ref.watch(appPrefsStoreProvider).read();

  Future<void> update(AppPrefs Function(AppPrefs prefs) change) async {
    state = change(state);
    await ref.read(appPrefsStoreProvider).write(state);
  }
}

final NotifierProvider<AppPrefsController, AppPrefs> appPrefsProvider =
    NotifierProvider<AppPrefsController, AppPrefs>(AppPrefsController.new);

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

final Provider<OwnKeyStore> ownKeyStoreProvider =
    Provider<OwnKeyStore>((Ref ref) => OwnKeyStore());

/// The user's own API key, if they set one up.
class OwnKeyController extends AsyncNotifier<OwnKey?> {
  @override
  Future<OwnKey?> build() async {
    try {
      return await ref.watch(ownKeyStoreProvider).read();
    } on Object {
      // No keychain (tests, desktop): no own key.
      return null;
    }
  }

  Future<void> save(OwnKey key) async {
    await ref.read(ownKeyStoreProvider).write(key);
    state = AsyncValue<OwnKey?>.data(key);
  }

  Future<void> clear() async {
    await ref.read(ownKeyStoreProvider).clear();
    state = const AsyncValue<OwnKey?>.data(null);
  }
}

final AsyncNotifierProvider<OwnKeyController, OwnKey?> ownKeyProvider =
    AsyncNotifierProvider<OwnKeyController, OwnKey?>(OwnKeyController.new);

/// The last thing that stopped the model from answering — the screens show
/// the paywall when it is [AiFailure.quotaExceeded].
final StateProvider<AiFailure?> aiFailureProvider =
    StateProvider<AiFailure?>((Ref ref) => null);

/// This month's AI allowance as the server enforces it. Refreshed after a
/// purchase and when an AI screen opens.
final FutureProvider<AiAllowance> aiAllowanceProvider =
    FutureProvider<AiAllowance>((Ref ref) async {
  if (await ref.watch(signedInUserProvider.future) == null) {
    return AiAllowance.unknown;
  }
  try {
    return await AiAllowance.fetch(ref.watch(supabaseClientProvider));
  } on Object {
    return AiAllowance.unknown;
  }
});

/// The language model behind the coach, the diary's estimates and the meal
/// planner: the user's own key if they set one, otherwise the project's
/// gateway with the signed-in account's allowance.
final Provider<LlmClient> llmClientProvider = Provider<LlmClient>((Ref ref) {
  void report(AiFailure failure) {
    ref.read(aiFailureProvider.notifier).state = failure;
    if (failure == AiFailure.quotaExceeded) ref.invalidate(aiAllowanceProvider);
  }

  final OwnKey? own = ref.watch(ownKeyProvider).valueOrNull;
  if (own != null) {
    return DartanticLlmClient(
      provider: (LlmPurpose _) => own.toProvider(),
      modelName: own.model.isEmpty ? own.provider.name : own.model,
      chatModelName: own.model.isEmpty ? null : own.model,
      isGoogle: own.provider == OwnKeyProvider.google,
      onFailure: report,
    );
  }

  final String? userId = ref.watch(signedInUserProvider).valueOrNull;
  if (userId == null) return const UnavailableLlmClient();
  final SupabaseClient client = ref.watch(supabaseClientProvider);
  final BackendConfig backend = ref.watch(backendConfigProvider);
  return DartanticLlmClient(
    provider: (LlmPurpose purpose) => GatewayProvider(
      baseUrl: GatewayProvider.baseUrlFor(backend.supabaseUrl),
      client: GatewayHttpClient(
        accessToken: () async {
          Session? session = client.auth.currentSession;
          if (session == null) return null;
          if (session.isExpired) {
            session = (await client.auth.refreshSession()).session;
          }
          return session?.accessToken;
        },
        publishableKey: backend.supabaseKey,
        purpose: purpose,
      ),
    ),
    modelName: kAiModel,
    chatModelName: kAiModel,
    onFailure: report,
  );
});

/// Premium purchases. Listens from the first read for the rest of the
/// session, so a purchase finishing in the background is not lost.
final Provider<SubscriptionService> subscriptionServiceProvider =
    Provider<SubscriptionService>((Ref ref) {
  final SubscriptionService service =
      SubscriptionService(ref.watch(supabaseClientProvider))..start();
  final StreamSubscription<PurchaseOutcome> refresh =
      service.outcomes.listen((PurchaseOutcome outcome) {
    if (outcome == PurchaseOutcome.premium) ref.invalidate(aiAllowanceProvider);
  });
  ref.onDispose(() {
    unawaited(refresh.cancel());
    unawaited(service.dispose());
  });
  return service;
});

/// Whether the coach may use the model: with an own key, or with premium —
/// on a free account the allowance goes to what the user asks for.
final FutureProvider<bool> modelCoachAllowedProvider =
    FutureProvider<bool>((Ref ref) async {
  if (ref.watch(ownKeyProvider).valueOrNull != null) return true;
  return (await ref.watch(aiAllowanceProvider.future)).premium;
});

/// The coach the app is currently using.
///
/// Falls back to the rule-based engine whenever no model is reachable, so
/// the app is never in a state where it cannot say something useful.
final FutureProvider<CoachEngine> coachEngineProvider =
    FutureProvider<CoachEngine>((Ref ref) async {
  final LlmClient llm = ref.watch(llmClientProvider);
  if (!llm.isReady) return const HeuristicCoach();
  if (!await ref.watch(modelCoachAllowedProvider.future)) {
    return const HeuristicCoach();
  }
  // The prompt is written in the user's language, so the coach has to be
  // rebuilt when that changes.
  final locale = ref.watch(effectiveLocaleProvider);
  final l10n = await AppLocalizations.delegate.load(locale);
  return LlmCoach(llm: llm, prompts: LocalizedCoachPrompts(l10n));
});

/// Meal estimates, suggestions and target proposals — or null without a
/// model, in which case the diary works from the food table alone.
final FutureProvider<NutritionAssistant?> nutritionAssistantProvider =
    FutureProvider<NutritionAssistant?>((Ref ref) async {
  final LlmClient llm = ref.watch(llmClientProvider);
  if (!llm.isReady) return null;
  final locale = ref.watch(effectiveLocaleProvider);
  final l10n = await AppLocalizations.delegate.load(locale);
  return NutritionAssistant(
    llm: llm,
    prompts: LocalizedNutritionPrompts(l10n),
  );
});

/// The app's single source of truth for the UI.
/// A day the user just completed, waiting to be celebrated. Set by
/// [AppController] whichever screen completed the day — the check-in on
/// Today, the workout logger or the food diary — and shown once by the app
/// shell.
class DayCelebration {
  const DayCelebration({
    required this.reward,
    required this.challenge,
    required this.lifetimeXp,
  });

  final DayReward reward;
  final Challenge challenge;
  final int lifetimeXp;
}

final StateProvider<DayCelebration?> celebrationProvider =
    StateProvider<DayCelebration?>((Ref ref) => null);

class AppController extends AsyncNotifier<AppSnapshot> {
  Timer? _debounce;
  Timer? _midnight;

  @override
  Future<AppSnapshot> build() async {
    final repository = ref.watch(repositoryProvider);

    // Today ends at midnight even with the app open: the streak, the ring,
    // the clock and where a check-in lands all move to the new day.
    _midnight?.cancel();
    final DateTime now = DateTime.now();
    _midnight = Timer(
      DateTime(now.year, now.month, now.day + 1, 0, 0, 1).difference(now),
      ref.invalidateSelf,
    );

    // The feed changes both from local actions and from peer sync. Debounced
    // because a sync round can land two hundred events in a burst, and
    // reprojecting once per event would jank the whole screen.
    final subscription = repository.changes.listen((FeedEvent _) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 120), () {
        ref.invalidateSelf();
      });
    });
    // A friend request or an accepted invite arrives through the server.
    final social = repository.social.changes.listen((void _) {
      unawaited(repository
          .syncNow()
          .then((SyncReport _) => ref.invalidateSelf(), onError: (Object _) {}));
    });
    ref.onDispose(() {
      _debounce?.cancel();
      _midnight?.cancel();
      // Pushes still held back for the undo window are dropped with the
      // session; the events themselves are already in the feed.
      for (final Timer notice in _pendingNotices.values) {
        notice.cancel();
      }
      _pendingNotices.clear();
      subscription.cancel();
      social.cancel();
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

  /// Logs [habit]. Without [day] it lands on the real today — not on the
  /// day the snapshot was taken, which after midnight is yesterday.
  ///
  /// Friends hear about it after [notifyDelay], so an undo right after a
  /// slip of the thumb does not send them a push first.
  Future<void> checkIn(
    Habit habit, {
    num? value,
    String? note,
    bool tracked = false,
    DayKey? day,
    Duration notifyDelay = Duration.zero,
  }) async {
    final snapshot = state.valueOrNull;
    final DayKey target = day ?? DayKey.today();
    // Logged again — a corrected amount, a diary day counted on target
    // after all: friends already heard about this habit today.
    final bool already =
        snapshot?.me.logsByDay[target.toString()]?.entryFor(habit.id) != null;
    final FeedEvent event = await _repository.checkIn(
      habit: habit,
      day: target,
      value: value,
      note: note,
      streak: snapshot?.me.habitStreaks[habit.id],
      tracked: tracked,
      challenge: snapshot?.challenge,
    );
    if (!already) _notifyLater(event, habit, target, notifyDelay);
    await refresh();
    _celebrateIfCompleted(snapshot);
  }

  final Map<String, Timer> _pendingNotices = <String, Timer>{};

  void _notifyLater(FeedEvent event, Habit habit, DayKey day, Duration delay) {
    final String key = '${habit.id}|$day';
    _pendingNotices.remove(key)?.cancel();
    if (delay == Duration.zero) {
      unawaited(_repository.notifyFriends(event));
      return;
    }
    _pendingNotices[key] = Timer(delay, () {
      _pendingNotices.remove(key);
      unawaited(_repository.notifyFriends(event));
    });
  }

  /// A check-in on a day that has passed — yesterday, forgotten. It counts,
  /// and friends see that it was logged late.
  Future<void> checkInOn(Habit habit, DayKey day, {num? value}) async {
    final snapshot = state.valueOrNull;
    await _repository.checkIn(
      habit: habit,
      day: day,
      value: value,
      challenge: snapshot?.challenge,
    );
    await refresh();
    _celebrateIfCompleted(snapshot);
  }

  /// Takes back today's (or [day]'s) entry for [habit].
  Future<void> undoCheckIn(Habit habit, {DayKey? day}) async {
    final DayKey target = day ?? DayKey.today();
    // A push still waiting to go out for this tick goes nowhere.
    _pendingNotices.remove('${habit.id}|$target')?.cancel();
    await _repository.undoCheckIn(
      habit: habit,
      day: target,
      challenge: state.valueOrNull?.challenge,
    );
    await refresh();
  }

  /// Hands the day just completed to the celebration, if [before] was taken
  /// on the same day and today was not done then.
  void _celebrateIfCompleted(AppSnapshot? before) {
    final AppSnapshot? after = state.valueOrNull;
    if (before == null || after == null || after.challenge == null) return;
    if (before.today != after.today) return;
    if (before.me.streak.doneToday || !after.me.streak.doneToday) return;
    ref.read(celebrationProvider.notifier).state = DayCelebration(
      reward: rewardForDay(
        challenge: after.challenge!,
        today: after.today,
        before: before.me.streak,
        after: after.me.streak,
        xpBefore: before.me.lifetimeXp,
        xpAfter: after.me.lifetimeXp,
        xpToday: after.me.xpByDay[after.today.toString()] ??
            after.me.lifetimeXp - before.me.lifetimeXp,
      ),
      challenge: after.challenge!,
      lifetimeXp: after.me.lifetimeXp,
    );
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
    _celebrateIfCompleted(snapshot);
  }

  Future<void> logFood(FoodEntry entry) async {
    await _repository.logFood(entry);
    await refresh();
  }

  Future<void> removeFood(String entryId) async {
    await _repository.removeFood(entryId);
    await refresh();
  }

  Future<void> respondToRequest(FriendLink request, {required bool accept}) async {
    await _repository.respondToRequest(request.userId, accept: accept);
    await refresh();
  }

  /// Freezes [day] — today, or a missed yesterday when offered right after.
  Future<void> useStreakFreeze({DayKey? day}) async {
    await _repository.useStreakFreeze(day ?? DayKey.today());
    await refresh();
  }

  Future<void> ascend() async {
    final challenge = state.valueOrNull?.challenge;
    if (challenge == null) return;
    await _repository.ascend(challenge, today: DayKey.today());
    await refresh();
  }

  /// Begins the challenge again from day one, with [challenge]'s habits.
  Future<void> restartChallenge(Challenge challenge) async {
    await _repository.restartChallenge(
      challenge.copyWith(startDay: DayKey.today(), cycle: 0),
    );
    await refresh();
  }

  Future<void> nudge(String targetId, String text) async {
    final FeedEvent event = await _repository.nudge(targetId, text);
    unawaited(_repository.notifyFriends(event));
    await refresh();
  }

  Future<void> cheer(
    String targetId,
    String text, {
    String? eventId,
  }) async {
    final FeedEvent event =
        await _repository.cheer(targetId, text, eventId: eventId);
    unawaited(_repository.notifyFriends(event));
    await refresh();
  }

  /// Redeems a friend's invite. Throws [InviteRejection].
  Future<void> redeemInvite(String code) async {
    await _repository.redeemInvite(code);
    await refresh();
  }

  Future<void> sendFriendRequest(String userId) async {
    await _repository.sendFriendRequest(userId);
    await refresh();
  }

  Future<void> removeFriend(String userId) async {
    await _repository.removeFriend(userId);
    await refresh();
  }

  Future<SyncReport> syncNow() async {
    final SyncReport report = await _repository.syncNow();
    await refresh();
    return report;
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

/// The last line the model wrote, and the moment it was written for.
class _BriefingCache {
  String? key;
  Future<CoachDirective?>? line;
}

final Provider<_BriefingCache> _briefingCacheProvider =
    Provider<_BriefingCache>((Ref ref) => _BriefingCache());

/// The same moment phrased by the language model, when one is reachable.
/// Takes a moment; the card swaps it in once it arrives.
///
/// The snapshot changes with every check-in and every sync; the model is
/// only asked again when the *moment* changes — another day, another tone,
/// another streak, today done — not every two minutes the app is open.
final FutureProvider<CoachDirective?> modelBriefingProvider =
    FutureProvider<CoachDirective?>((Ref ref) async {
  final snapshot = await ref.watch(appStateProvider.future);
  if (!snapshot.hasChallenge) return null;
  final coach = await ref.watch(coachEngineProvider.future);
  if (coach.modelName == null) return null;
  final CoachContext context = snapshot.toCoachContext();
  final String key = '${snapshot.today}|${selectTone(context).name}|'
      '${snapshot.me.streak.current}|${snapshot.me.streak.doneToday}|'
      '${coach.modelName}|${ref.watch(effectiveLocaleProvider).languageCode}';
  final _BriefingCache cache = ref.read(_briefingCacheProvider);
  if (cache.key != key || cache.line == null) {
    cache.key = key;
    cache.line = coach.dailyBriefing(context).then(
          (CoachDirective directive) =>
              directive.source == CoachSource.llm ? directive : null,
          onError: (Object _) => null,
        );
  }
  return cache.line;
});

/// Ready-made jabs for friends who have not moved today.
///
/// Templates, not the model: a list of friends must not sit empty while a
/// model writes a sentence for each of them.
final FutureProvider<List<NudgeSuggestion>> nudgeSuggestionsProvider =
    FutureProvider<List<NudgeSuggestion>>((Ref ref) async {
  final snapshot = await ref.watch(appStateProvider.future);
  if (!snapshot.hasChallenge) return const <NudgeSuggestion>[];
  return const HeuristicCoach().nudgeSuggestions(snapshot.toCoachContext());
});

/// What the last sync did, for the settings screen.
final StreamProvider<SyncReport> syncReportsProvider =
    StreamProvider<SyncReport>((Ref ref) {
  final AppRepository repository = ref.watch(repositoryProvider);
  return repository.sync.reports;
});
