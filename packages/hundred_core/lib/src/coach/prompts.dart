import '../domain/habit.dart';
import '../domain/peer.dart';
import 'coach.dart';

/// Builds the prompts sent to the on-device model.
///
/// A port rather than a constant, because the prompt has to be written in the
/// language the user reads: asking a model for German output from an English
/// prompt works badly, and hardcoding either one here would put display
/// language back into a package that must not have it. The app supplies a
/// localized builder; [EnglishCoachPrompts] keeps the package usable — and
/// testable — on its own.
abstract class CoachPromptBuilder {
  String briefing(CoachContext context, CoachTone tone);

  String nudge(CoachContext context, PeerState peer);

  String adjustments(CoachContext context);
}

class EnglishCoachPrompts implements CoachPromptBuilder {
  const EnglishCoachPrompts();

  @override
  String briefing(CoachContext c, CoachTone tone) {
    final habits = c.challenge.habits
        .map((Habit h) => '- ${h.category.name}: '
            '${c.habitStreaks[h.id] ?? 0} day streak')
        .join('\n');
    final peers = c.peers.isEmpty
        ? '- no friends connected'
        : c.peers
            .take(5)
            .map((PeerState p) => '- ${p.profile.displayName}: '
                '${p.currentStreak} day streak, '
                '${p.activeToday ? 'ALREADY active today' : 'nothing yet today'}')
            .join('\n');

    return '''
You are the coach in a 100-day challenge app. Write in English, second person.
${_persona(tone)}
Two sentences at most. No emoji at the start of a line. No quotation marks.

The user's goal: "${c.challenge.goal.statement}"
Day ${c.dayNumber} of ${c.challenge.lengthDays}
Current streak: ${c.streak.current} days, longest: ${c.streak.longest}
Done today: ${c.streak.doneToday ? 'yes' : 'no'}
Time of day: ${c.now.hour}:00

Habits:
$habits

Friends:
$peers

Answer in exactly this format:
TITLE: <at most 6 words>
TEXT: <1-2 sentences>
''';
  }

  @override
  String nudge(CoachContext c, PeerState peer) => '''
Write a single short taunt in English aimed at ${peer.profile.displayName},
who has done nothing for their own challenge today. The sender is on day
${c.dayNumber} with a ${c.streak.current} day streak. At most 12 words,
cheeky but friendly, no bullying, no quotation marks. Output only the message.
''';

  @override
  String adjustments(CoachContext c) {
    final habits = c.challenge.habits
        .map((Habit h) => '- ${h.category.name}: target ${h.target}, '
            '${h.daysPerWeek}x per week, streak ${c.habitStreaks[h.id] ?? 0}')
        .join('\n');
    return '''
You are a training and habit coach. Write in English, second person.
The user is on day ${c.dayNumber} of ${c.challenge.lengthDays}.
Hit rate: ${c.completionPercent}%.
Goal: "${c.challenge.goal.statement}"

$habits

Give at most 4 concrete adjustments, one per line, at most 15 words each.
No preamble, no numbering, no emoji.
''';
  }

  String _persona(CoachTone tone) {
    switch (tone) {
      case CoachTone.recover:
        return 'You are sober and respectful. No pity, no blame.';
      case CoachTone.celebrate:
        return 'You are brief and proud, without schmaltz.';
      case CoachTone.urgent:
      case CoachTone.socialPressure:
        return 'You are direct and mildly provocative, never insulting.';
      case CoachTone.raiseTheBar:
        return 'You are demanding and concrete.';
      case CoachTone.welcome:
      case CoachTone.steady:
        return 'You are calm and matter-of-fact.';
    }
  }
}
