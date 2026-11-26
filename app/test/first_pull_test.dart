import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hundred_core/hundred_core.dart';
import 'package:hundred_days/data/app_repository.dart';
import 'package:hundred_days/data/feed_sync.dart';
import 'package:hundred_days/data/social_backend.dart';
import 'package:hundred_days/state/providers.dart';

import 'helpers.dart';

/// A brand-new account: the server has nothing for it, so the first pull
/// brings no events — it only marks the account as seen on this phone.
class _EmptyServerSync implements FeedSync {
  _EmptyServerSync(this.store);

  final FeedStore store;
  final StreamController<SyncReport> _reports =
      StreamController<SyncReport>.broadcast();

  @override
  Future<SyncReport> syncNow() async {
    await store.setMeta(kPulledOnceMeta, '1');
    final SyncReport report = SyncReport(at: DateTime.now());
    _reports.add(report);
    return report;
  }

  @override
  void schedulePush() {}

  @override
  Future<void> setAuthors(Set<String> authors) async {}

  @override
  Stream<SyncReport> get reports => _reports.stream;

  @override
  Future<void> dispose() => _reports.close();
}

void main() {
  // The first sign-in with a new account used to stay on "loading your
  // account", then said there was no connection, until some later sync
  // happened to read the snapshot again: the empty pull changed no events.
  test('a new account goes on to onboarding once its empty first pull is in',
      () async {
    final MemoryFeedStore store = MemoryFeedStore();
    final _EmptyServerSync sync = _EmptyServerSync(store);
    final AppRepository repository = AppRepository(
      userId: 'me',
      store: store,
      social: MemorySocialBackend(userId: 'me'),
      sync: sync,
      requiresFirstPull: true,
    );
    await repository.open();
    final ProviderContainer container = ProviderContainer(overrides: <Override>[
      repositoryProvider.overrideWithValue(repository),
      ...platformFreeOverrides(),
    ]);
    addTearDown(container.dispose);
    container.listen(appStateProvider, (Object? _, Object? __) {});

    final AppSnapshot before = await container.read(appStateProvider.future);
    expect(before.accountLoaded, isFalse);
    expect(before.hasChallenge, isFalse);

    // What the session does right after sign-in, in the background.
    await repository.syncNow();
    await pumpEventQueue();

    final AppSnapshot after = await container.read(appStateProvider.future);
    expect(after.accountLoaded, isTrue);
  });
}
