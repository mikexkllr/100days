/// Local-first, peer-to-peer core of the 100 Days challenge app.
///
/// Nothing in this package touches Flutter, the network stack or the file
/// system: it is the part of the product that must be correct — signed feeds,
/// streak arithmetic, plan generation and the sync protocol — kept testable in
/// isolation from the platform.
library hundred_core;

export 'src/coach/coach.dart';
export 'src/coach/heuristic_coach.dart';
export 'src/coach/llm_coach.dart';
export 'src/coach/local_llm.dart';
export 'src/coach/prompts.dart';
export 'src/domain/challenge.dart';
export 'src/domain/check_in.dart';
export 'src/domain/goal.dart';
export 'src/domain/habit.dart';
export 'src/domain/peer.dart';
export 'src/domain/progression.dart';
export 'src/domain/schedule.dart';
export 'src/domain/streak.dart';
export 'src/feed/event.dart';
export 'src/feed/feed_store.dart';
export 'src/feed/feed_writer.dart';
export 'src/identity/identity.dart';
export 'src/plan/abstinence.dart';
export 'src/plan/exercises.dart';
export 'src/plan/nutrition.dart';
export 'src/plan/plan.dart';
export 'src/plan/training.dart';
export 'src/social/activity.dart';
export 'src/social/invite.dart';
export 'src/social/projection.dart';
export 'src/sync/loopback_transport.dart';
export 'src/sync/protocol.dart';
export 'src/sync/syncer.dart';
export 'src/sync/transport.dart';
export 'src/util/codec.dart';
export 'src/util/dates.dart';
