import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../l10n/l10n.dart';
import '../../theme/theme.dart';
import '../mascot/flame_painter.dart';
import '../motion/motion.dart';
import '../motion/particles.dart';

/// How a friend's flame feels about their day, from their events alone: fed
/// once the day is done, asleep on a rest day or a frozen one, hungry while
/// it is open. Every phone draws a friend the same way.
MascotMood friendMood(UserProjection person, DayKey today) {
  final Challenge? challenge = person.challenge;
  if (challenge == null) return MascotMood.sleepy;
  if (person.streak.doneToday) return MascotMood.happy;
  if (isRestDay(challenge, today) ||
      person.frozenDays.contains(today.toString())) {
    return MascotMood.sleepy;
  }
  return MascotMood.hungry;
}

/// Nudges sent this session, per friend: each one puffs at their flame.
/// Bumped by whoever sends a nudge; the flames listen.
final StateProvider<Map<String, int>> nudgePuffsProvider =
    StateProvider<Map<String, int>>((Ref ref) => const <String, int>{});

/// Puffs at [friendId]'s flame wherever it is on screen.
void puffAt(WidgetRef ref, String friendId) {
  final StateController<Map<String, int>> puffs =
      ref.read(nudgePuffsProvider.notifier);
  puffs.state = <String, int>{
    ...puffs.state,
    friendId: (puffs.state[friendId] ?? 0) + 1,
  };
}

/// A person as their flame: the form their streak has reached, the mood of
/// their day, and their emoji as a small badge. A nudge sent to them blows
/// a burst of sparks off it — unless the system asks for less motion.
class FriendFlame extends ConsumerWidget {
  const FriendFlame({
    super.key,
    required this.person,
    required this.today,
    this.size = 46,
    this.alive = true,
  });

  final UserProjection person;
  final DayKey today;
  final double size;

  /// Flickers and blinks while ambient motion is on. Off for long lists,
  /// where a ticker per row would cost more than it shows; the nudge burst
  /// plays either way.
  final bool alive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool motion = ambientMotionOf(context);
    final int? puffs = ref.watch(nudgePuffsProvider
        .select((Map<String, int> m) => m[person.userId]));
    final FlameStage stage = flameStageFor(person.streak.current);
    final MascotMood mood = friendMood(person, today);

    Widget paint(double seconds) => CustomPaint(
          size: Size.square(size),
          painter: FlamePainter(
            stage: stage,
            mood: mood,
            seconds: seconds,
            blink: motion && alive,
          ),
        );

    return Semantics(
      label: context.l10n.friendFlameLabel(
          person.profile.displayName, person.streak.current),
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned.fill(
              child: ParticleBurst(
                trigger: motion ? puffs : null,
                origin: const Alignment(0, -0.1),
                count: 14,
                kinds: const <ParticleKind>[
                  ParticleKind.spark,
                  ParticleKind.ember,
                ],
                power: 0.35,
                gravity: 260,
                sizeScale: 0.7,
                child: alive
                    ? AmbientClock(
                        builder:
                            (BuildContext context, double seconds, Widget? _) =>
                                paint(seconds),
                      )
                    : paint(1.2),
              ),
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: ExcludeSemantics(
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: AppColors.ink,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    person.profile.avatarEmoji,
                    style: TextStyle(fontSize: size * 0.26, height: 1.1),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Everyone around one fire: the user and their friends as flames in a row,
/// each one a way into their profile.
class Campfire extends StatelessWidget {
  const Campfire({
    super.key,
    required this.people,
    required this.today,
    required this.onOpen,
  });

  /// The user first, then the friends.
  final List<UserProjection> people;
  final DayKey today;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return SizedBox(
      key: const Key('campfire'),
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: people.length,
        separatorBuilder: (BuildContext context, int _) =>
            const SizedBox(width: AppSpacing.sm),
        itemBuilder: (BuildContext context, int index) {
          final UserProjection person = people[index];
          return InkWell(
            key: Key('campfire-${person.userId}'),
            borderRadius: BorderRadius.circular(16),
            onTap: () => onOpen(person.userId),
            child: SizedBox(
              width: 68,
              child: Column(
                children: <Widget>[
                  const SizedBox(height: AppSpacing.xs),
                  FriendFlame(person: person, today: today, size: 54),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    person.profile.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelSmall
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
