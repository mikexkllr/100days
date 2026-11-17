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
  yield client.auth.currentUser?.id;
  yield* client.auth.onAuthStateChange
      .map((AuthState state) => state.session?.user.id)
      .distinct();
});

/// The signed-in account's data: its local store, its friends, its sync.
/// Null while signed out. Rebuilt — and the previous one closed — when the
/// account changes.
final FutureProvider<AppRepository?> sessionRepositoryProvider =
    FutureProvider<AppRepository?>((Ref ref) async {
  final String? userId = await ref.watch(signedInUserProvider.future);
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
  );
  // A store left over from another account on this phone is not ours.
  final Set<String> authors = await store.authors();
  if (authors.isNotEmpty && !authors.contains(userId)) {
    await store.clear();
  }
  ref.onDispose(() => unawaited(repository.close()));
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
    // A friend request or an accepted invite arrives through the server.
    final social = repository.social.changes.listen((void _) {
      unawaited(repository
          .syncNow()
          .then((SyncReport _) => ref.invalidateSelf(), onError: (Object _) {}));
    });
    ref.onDispose(() {
      _debounce?.cancel();
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

  Future<void> respondToRequest(FriendLink request, {required bool accept}) async {
    await _repository.respondToRequest(request.userId, accept: accept);
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

  Future<void> nudge(String targetId, String text) async {
    await _repository.nudge(targetId, text);
    await refresh();
  }

  Future<void> cheer(
    String targetId,
    String text, {
    String? eventId,
  }) async {
    await _repository.cheer(targetId, text, eventId: eventId);
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

/// The same moment phrased by the language model, when one is reachable.
/// Takes a moment; the card swaps it in once it arrives.
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
