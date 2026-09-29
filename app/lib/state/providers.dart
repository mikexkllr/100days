import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';

import 'dart:ui';

import '../data/app_repository.dart';
import '../data/health_gateway.dart';
import '../data/health_import_service.dart';
import '../data/health_preferences.dart';
import '../data/lan_transport.dart';
import '../data/locale_store.dart';
import '../data/llm_runtime.dart';
import '../data/notifications.dart';
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

final Provider<LocalModelManager> modelManagerProvider =
    Provider<LocalModelManager>((Ref ref) => LocalModelManager());

/// The phone's fitness store. Overridden in `main()`; the default is the
/// "no provider here" stand-in so widget tests and desktop builds work.
final Provider<HealthDataSource> healthSourceProvider =
    Provider<HealthDataSource>((Ref ref) => PlatformHealthSource());

final Provider<HealthPreferences> healthPreferencesProvider =
    Provider<HealthPreferences>(
  (Ref ref) =>
      throw UnimplementedError('healthPreferencesProvider not initialised'),
);

final Provider<HealthImportService> healthImportProvider =
    Provider<HealthImportService>(
  (Ref ref) => HealthImportService(
    source: ref.watch(healthSourceProvider),
    preferences: ref.watch(healthPreferencesProvider),
    repository: ref.watch(repositoryProvider),
  ),
);

/// Which habits the user released to the watch. Held in a notifier so the
/// settings screen and the check-in tiles agree without either of them
/// re-reading preferences on every build.
class HealthCategoriesController extends Notifier<Set<HabitCategory>> {
  @override
  Set<HabitCategory> build() =>
      ref.watch(healthPreferencesProvider).enabledCategories();

  Future<void> toggle(HabitCategory category, {required bool on}) async {
    final Set<HabitCategory> next = <HabitCategory>{...state};
    if (on) {
      next.add(category);
    } else {
      next.remove(category);
    }
    await ref.read(healthPreferencesProvider).setEnabledCategories(next);
    state = next;
  }
}

final NotifierProvider<HealthCategoriesController, Set<HabitCategory>>
    healthCategoriesProvider =
    NotifierProvider<HealthCategoriesController, Set<HabitCategory>>(
  HealthCategoriesController.new,
);

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

  // The prompt is written in the user's language, so the coach has to be
  // rebuilt when that changes.
  final locale = ref.watch(effectiveLocaleProvider);
  final l10n = await AppLocalizations.delegate.load(locale);
  return LocalLlmCoach(
    runtime: runtime,
    prompts: LocalizedCoachPrompts(l10n),
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

  /// Reads the watch and folds whatever it finds into the feed.
  ///
  /// Never throws: a missing provider, a revoked permission or a phone with no
  /// health store at all are all ordinary states, and none of them is a reason
  /// for the screen the user is looking at to fall over.
  Future<HealthImportResult> importHealth({bool onlyIfEnabled = false}) async {
    final HealthImportService service = ref.read(healthImportProvider);
    HealthImportResult result = HealthImportResult.none;
    try {
      result = onlyIfEnabled
          ? await service.importIfEnabled()
          : await service.importNow();
    } on Object catch (error) {
      debugPrint('Health import failed: $error');
      return HealthImportResult.none;
    }
    if (result.changedSomething) await refresh();
    return result;
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

/// The coach's directive for right now. The wording is applied by the widget
/// that shows it, in whatever language the app is running in.
final FutureProvider<CoachDirective?> briefingProvider =
    FutureProvider<CoachDirective?>((Ref ref) async {
  final snapshot = await ref.watch(appStateProvider.future);
  if (!snapshot.hasChallenge) return null;
  final coach = await ref.watch(coachEngineProvider.future);
  return coach.dailyBriefing(snapshot.toCoachContext());
});

/// Concrete plan tweaks, shown on the plan screen.
final FutureProvider<List<PlanAdvice>> planAdjustmentsProvider =
    FutureProvider<List<PlanAdvice>>((Ref ref) async {
  final snapshot = await ref.watch(appStateProvider.future);
  if (!snapshot.hasChallenge) return const <PlanAdvice>[];
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
