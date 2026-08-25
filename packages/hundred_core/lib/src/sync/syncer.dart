import 'dart:async';

import '../feed/event.dart';
import '../feed/feed_store.dart';
import '../feed/feed_writer.dart';
import 'protocol.dart';
import 'transport.dart';

class SyncResult {
  const SyncResult({
    required this.peerDid,
    required this.received,
    required this.sent,
    required this.rejections,
    this.error,
  });

  final String? peerDid;
  final int received;
  final int sent;
  final List<EventRejection> rejections;
  final Object? error;

  bool get isSuccess => error == null;

  @override
  String toString() => error != null
      ? 'SyncResult(error: $error)'
      : 'SyncResult(peer: $peerDid, in: $received, out: $sent)';
}

/// Runs one replication round over an open [PeerSession].
///
/// Both sides run the identical routine — there is no client and no server,
/// which is what makes the mesh work when two phones meet with no internet
/// between them.
class Syncer {
  Syncer({
    required this.store,
    required this.replicator,
    required this.localDid,
    required this.localDisplayName,
    this.followedDids,
    this.timeout = const Duration(seconds: 20),
  });

  final FeedStore store;
  final FeedReplicator replicator;
  final String localDid;
  final String localDisplayName;

  /// When set, only these feeds are offered and accepted. Keeps a friend's
  /// friend-of-a-friend graph from silently landing on your device.
  final Set<String>? followedDids;

  /// Idle timeout: how long we wait for the peer's *next* frame. Applied per
  /// frame rather than to the round as a whole, so a first-time sync of a
  /// year-long history is not cut off halfway.
  final Duration timeout;

  Future<SyncResult> run(PeerSession session) async {
    final state = _RoundState();

    try {
      await session.send(
        HelloMessage(did: localDid, displayName: localDisplayName).toJson(),
      );

      // Sequential by construction: each frame is fully applied before the
      // next is read. Handling frames concurrently would let a `done` land
      // while a batch of events is still being written, and the round would
      // report success over a half-replicated feed.
      await for (final Map<String, dynamic> raw
          in session.messages.timeout(timeout)) {
        final finished = await _handle(session, raw, state);
        if (finished) break;
      }
    } on Object catch (error) {
      state.error ??= error;
    } finally {
      await session.close();
    }

    return SyncResult(
      peerDid: state.peerDid,
      received: state.received,
      sent: state.sent,
      rejections: state.rejections,
      error: state.error,
    );
  }

  /// Returns true when the round is over.
  Future<bool> _handle(
    PeerSession session,
    Map<String, dynamic> raw,
    _RoundState state,
  ) async {
    final message = SyncMessage.decode(raw);
    if (message == null) return false;

    switch (message) {
      case HelloMessage():
        state.peerDid = message.did;
        state.peerName = message.displayName;
        if (message.protocolVersion != kProtocolVersion) {
          await session
              .send(const ErrorMessage('protocol version mismatch').toJson());
          state.error = StateError(
            'Peer speaks protocol v${message.protocolVersion}, '
            'we speak v$kProtocolVersion',
          );
          return true;
        }
        await session.send(HaveMessage(await _offeredHeads()).toJson());
        return false;

      case HaveMessage():
        final ranges = <WantRange>[];
        for (final head in message.heads) {
          if (!_accepts(head.did)) continue;
          final local = await store.head(head.did);
          if (local == null) {
            ranges.add(WantRange(did: head.did, fromSeq: 0));
          } else if (head.seq > local.seq) {
            ranges.add(WantRange(did: head.did, fromSeq: local.seq));
          }
        }
        await session.send(WantMessage(ranges).toJson());
        return false;

      case WantMessage():
        for (final range in message.ranges) {
          if (!_accepts(range.did)) continue;
          var cursor = range.fromSeq;
          while (true) {
            final batch = await store.eventsAfter(
              range.did,
              cursor,
              limit: kMaxEventsPerFrame,
            );
            if (batch.isEmpty) break;
            await session.send(EventsMessage(
              batch,
              hasMore: batch.length == kMaxEventsPerFrame,
            ).toJson());
            state.sent += batch.length;
            cursor = batch.last.seq;
            if (batch.length < kMaxEventsPerFrame) break;
          }
        }
        await session.send(const DoneMessage().toJson());
        state.localDone = true;
        return state.isFinished;

      case EventsMessage():
        final accepted =
            message.events.where((FeedEvent e) => _accepts(e.author)).toList();
        final report = await replicator.apply(accepted);
        state.received += report.applied;
        state.rejections.addAll(report.rejections);
        return false;

      case DoneMessage():
        state.remoteDone = true;
        return state.isFinished;

      case ErrorMessage():
        state.error = StateError('Peer error: ${message.message}');
        return true;

      default:
        return false;
    }
  }

  bool _accepts(String did) {
    if (did == localDid) return true;
    final allowed = followedDids;
    return allowed == null || allowed.contains(did);
  }

  Future<List<FeedHead>> _offeredHeads() async {
    final all = await store.heads();
    return all.where((FeedHead h) => _accepts(h.did)).toList();
  }
}

class _RoundState {
  String? peerDid;
  String? peerName;
  int received = 0;
  int sent = 0;
  bool localDone = false;
  bool remoteDone = false;
  Object? error;
  final List<EventRejection> rejections = <EventRejection>[];

  bool get isFinished => localDone && remoteDone;
}
