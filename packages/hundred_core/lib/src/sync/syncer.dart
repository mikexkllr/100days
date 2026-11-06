import 'dart:async';
import 'dart:convert';
import 'dart:math';

import '../feed/event.dart';
import '../identity/identity.dart';
import '../feed/feed_store.dart';
import '../feed/feed_writer.dart';
import 'protocol.dart';
import 'transport.dart';

/// How a round ended, beyond "it worked".
enum SyncOutcome {
  /// Both sides were friends and replicated.
  synced,

  /// The peer proved who they are, but we do not follow them: nothing was
  /// sent. The app turns this into a friend request.
  refusedStranger,

  /// The peer does not follow us (yet): they sent nothing.
  notFriendsYet,

  /// The peer's handshake signature did not verify.
  authFailed,

  /// Anything else: a dropped connection, a timeout, a version mismatch.
  failed,
}

class SyncResult {
  const SyncResult({
    required this.peerDid,
    required this.received,
    required this.sent,
    required this.rejections,
    this.error,
    this.outcome,
    this.peerName,
    this.peerEmoji,
  });

  /// Only trustworthy when [isAuthenticated].
  final String? peerDid;
  final int received;
  final int sent;
  final List<EventRejection> rejections;
  final Object? error;
  final String? peerName;
  final String? peerEmoji;

  final SyncOutcome? outcome;

  SyncOutcome get status =>
      outcome ?? (error == null ? SyncOutcome.synced : SyncOutcome.failed);

  /// The peer proved it holds the key of [peerDid].
  bool get isAuthenticated =>
      status == SyncOutcome.synced ||
      status == SyncOutcome.refusedStranger ||
      status == SyncOutcome.notFriendsYet;

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
///
/// Friends only: before anything is sent, each side signs the other's nonce
/// to prove it holds the key of the DID it claims, and a side only serves
/// feeds to a peer it follows. A stranger on the same Wi-Fi learns that this
/// phone runs the app and what name it uses — nothing else.
class Syncer {
  Syncer({
    required this.identity,
    required this.store,
    required this.replicator,
    required this.localDisplayName,
    this.localAvatarEmoji,
    this.followedDids,
    this.timeout = const Duration(seconds: 20),
  });

  final Identity identity;
  final FeedStore store;
  final FeedReplicator replicator;
  final String localDisplayName;
  final String? localAvatarEmoji;

  String get localDid => identity.did;

  /// When set, only these peers are served, and only these feeds are offered
  /// and accepted. Keeps strangers out, and a friend's friend-of-a-friend
  /// graph from silently landing on your device. Null serves every peer that
  /// authenticates — only tests do that.
  final Set<String>? followedDids;

  /// Idle timeout: how long we wait for the peer's *next* frame. Applied per
  /// frame rather than to the round as a whole, so a first-time sync of a
  /// year-long history is not cut off halfway.
  final Duration timeout;

  Future<SyncResult> run(PeerSession session) async {
    final state = _RoundState(nonce: _freshNonce());

    try {
      await session.send(
        HelloMessage(
          did: localDid,
          displayName: localDisplayName,
          avatarEmoji: localAvatarEmoji,
          nonce: state.nonce,
        ).toJson(),
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
      peerName: state.peerName,
      peerEmoji: state.peerEmoji,
      received: state.received,
      sent: state.sent,
      rejections: state.rejections,
      error: state.error,
      outcome: state.outcome,
    );
  }

  static String _freshNonce() {
    final random = Random.secure();
    return base64Encode(
        List<int>.generate(24, (int _) => random.nextInt(256)));
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
        if (state.peerDid != null) return false;
        state.peerDid = message.did;
        state.peerName = message.displayName;
        state.peerEmoji = message.avatarEmoji;
        if (message.protocolVersion != kProtocolVersion) {
          await session
              .send(const ErrorMessage('protocol version mismatch').toJson());
          state.error = StateError(
            'Peer speaks protocol v${message.protocolVersion}, '
            'we speak v$kProtocolVersion',
          );
          return true;
        }
        if (message.nonce.length < 16 || message.did == localDid) {
          await session.send(const ErrorMessage(kAuthFailedError).toJson());
          state.error = StateError('Peer sent an unusable handshake');
          state.outcome = SyncOutcome.authFailed;
          return true;
        }
        final signature = await identity.sign(authChallenge(
          nonce: message.nonce,
          signerDid: localDid,
          verifierDid: message.did,
        ));
        await session.send(AuthMessage(signature).toJson());
        return false;

      case AuthMessage():
        final peerDid = state.peerDid;
        if (peerDid == null || state.authenticated) return false;
        final valid = await Identity.verify(
          peerDid,
          authChallenge(
            nonce: state.nonce,
            signerDid: peerDid,
            verifierDid: localDid,
          ),
          message.signature,
        );
        if (!valid) {
          await session.send(const ErrorMessage(kAuthFailedError).toJson());
          state.error = StateError('Peer could not prove it is $peerDid');
          state.outcome = SyncOutcome.authFailed;
          return true;
        }
        state.authenticated = true;
        if (!_isFriend(peerDid)) {
          await session.send(const ErrorMessage(kNotFriendsError).toJson());
          state.outcome = SyncOutcome.refusedStranger;
          return true;
        }
        await session.send(HaveMessage(await _offeredHeads()).toJson());
        return false;

      // Nothing below runs for a peer that has not proved who it is.
      case HaveMessage() when !state.authenticated:
      case WantMessage() when !state.authenticated:
      case EventsMessage() when !state.authenticated:
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
        if (message.message == kNotFriendsError && state.authenticated) {
          // They do not follow us yet. Not a failure: once they accept,
          // the next round goes through.
          state.outcome ??= SyncOutcome.notFriendsYet;
          return true;
        }
        state.error = StateError('Peer error: ${message.message}');
        if (message.message == kAuthFailedError) {
          state.outcome ??= SyncOutcome.authFailed;
        }
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

  bool _isFriend(String did) {
    final allowed = followedDids;
    return allowed == null || allowed.contains(did);
  }

  Future<List<FeedHead>> _offeredHeads() async {
    final all = await store.heads();
    return all.where((FeedHead h) => _accepts(h.did)).toList();
  }
}

class _RoundState {
  _RoundState({required this.nonce});

  final String nonce;
  bool authenticated = false;
  SyncOutcome? outcome;
  String? peerDid;
  String? peerName;
  String? peerEmoji;
  int received = 0;
  int sent = 0;
  bool localDone = false;
  bool remoteDone = false;
  Object? error;
  final List<EventRejection> rejections = <EventRejection>[];

  bool get isFinished => localDone && remoteDone;
}
