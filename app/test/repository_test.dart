import 'package:flutter_test/flutter_test.dart';
import 'package:hundred_core/hundred_core.dart';
import 'package:hundred_days/data/app_repository.dart';
import 'package:hundred_days/data/feed_sync.dart';
import 'package:hundred_days/data/social_backend.dart';

import 'helpers.dart';

/// The phone's cache across accounts, restarts and new phones.
void main() {
  test('a cache that belongs to another account is emptied on open',
      () async {
    final MemoryFeedStore store = MemoryFeedStore();
    final AppRepository alice = AppRepository(userId: 'alice', store: store);
    await alice.open();
    await alice.startChallenge(testChallenge());
    await alice.close().catchError((Object _) {});

    final MemoryFeedStore reopened = MemoryFeedStore();
    await reopened.putAll(await store.eventsOf('alice'));
    await reopened.setMeta('owner', 'alice');
    final AppRepository bob = AppRepository(userId: 'bob', store: reopened);
    await bob.open();
    expect(await reopened.authors(), isEmpty);
    expect(await reopened.meta('owner'), 'bob');
  });

  test('the friend list survives a restart without a network', () async {
    final MemoryFeedStore store = MemoryFeedStore();
    final AppRepository first = await testRepository();
    final AppRepository me = AppRepository(
      userId: 'me',
      store: store,
      social: first.social,
    );
    await me.open();
    (me.social as MemorySocialBackend).link(const FriendLink(
      userId: 'friend-lena',
      displayName: 'Lena',
      emoji: '🦊',
      status: FriendStatus.friends,
    ));
    await me.refreshFriends();

    final AppRepository later = AppRepository(
      userId: 'me',
      store: store,
      social: _OfflineSocial(),
    );
    await later.open();
    expect(later.follows, <String>{'friend-lena'});
  });

  test('a new phone waits for the first pull before it offers onboarding',
      () async {
    final MemoryFeedStore store = MemoryFeedStore();
    final AppRepository me = AppRepository(
      userId: 'me',
      store: store,
      requiresFirstPull: true,
    );
    await me.open();
    expect((await me.snapshot()).accountLoaded, isFalse);
    await store.setMeta(kPulledOnceMeta, '1');
    expect((await me.snapshot()).accountLoaded, isTrue);
  });

  test('an undo takes today\'s tick back', () async {
    final AppRepository me = await testRepository();
    final Challenge challenge = testChallenge();
    await me.startChallenge(challenge);
    final Habit habit = challenge.habits.first;
    await me.checkIn(habit: habit, day: DayKey.today());
    expect((await me.snapshot()).me.logsByDay[DayKey.today().toString()],
        isNotNull);
    await me.undoCheckIn(habit: habit, day: DayKey.today());
    expect((await me.snapshot()).me.logsByDay[DayKey.today().toString()],
        isNull);
  });
}

/// A server that cannot be reached.
class _OfflineSocial extends MemorySocialBackend {
  _OfflineSocial() : super(userId: 'me');

  @override
  Future<List<FriendLink>> friendships() async => throw StateError('offline');
}
