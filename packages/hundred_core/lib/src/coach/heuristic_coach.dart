import 'dart:math' as math;

import '../domain/habit.dart';
import '../domain/peer.dart';
import '../plan/abstinence.dart';
import 'coach.dart';

/// The always-available coach: pure rules, zero model, zero network.
///
/// This is the floor of the product. If the on-device model is missing, still
/// downloading, or too slow, the user must never get a blank screen where the
/// motivation is supposed to be — so every path here terminates in a real
/// sentence.
class HeuristicCoach implements CoachEngine {
  const HeuristicCoach();

  @override
  bool get isReady => true;

  @override
  String get name => 'Regelbasiert (on-device)';

  @override
  Future<CoachMessage> dailyBriefing(CoachContext c) async {
    final tone = selectTone(c);
    // Seeded by the day so the message is stable within a day: re-opening the
    // app should not reroll the pep talk.
    final random = math.Random(c.today.toString().hashCode ^ tone.index);

    switch (tone) {
      case CoachTone.welcome:
        return CoachMessage(
          tone: tone,
          headline: 'Tag ${c.dayNumber} von ${c.challenge.lengthDays}',
          body: _pick(random, <String>[
            'Der Anfang ist der einfachste Teil und der wichtigste. '
                'Heute nur eine Sache: abhaken.',
            'Du hast dir vorgenommen: "${c.challenge.goal.statement}". '
                'Heute machst du den ersten Beweis daraus.',
            'Niemand sieht Tag ${c.dayNumber}. Alle sehen Tag 100. '
                'Der eine geht nicht ohne den anderen.',
          ]),
          ctaLabel: 'Heute abhaken',
        );

      case CoachTone.steady:
        final next = c.challenge.nextMilestone(c.dayNumber);
        return CoachMessage(
          tone: tone,
          headline: '${c.streak.current} Tage Streak',
          body: next == null
              ? 'Läuft. Weiter wie gestern.'
              : 'Noch ${next - c.dayNumber} Tage bis Tag $next. '
                  '${_pick(random, <String>[
                  'Nichts Spektakuläres nötig — nur nicht aufhören.',
                  'Konstanz schlägt Intensität. Immer.',
                  'Der Plan funktioniert, solange du ihn machst.',
                ])}',
          ctaLabel: 'Weitermachen',
        );

      case CoachTone.socialPressure:
        final active = c.peersActiveToday;
        if (active.isEmpty) {
          final ahead = c.peersAhead;
          if (ahead.isEmpty) {
            return CoachMessage(
              tone: tone,
              headline: 'Heute steht noch offen',
              body: 'Du führst gerade. Führen heißt, nicht der Erste zu sein, '
                  'der aufhört.',
              ctaLabel: 'Jetzt abhaken',
            );
          }
          final leader = ahead.first;
          return CoachMessage(
            tone: tone,
            headline: '${leader.profile.displayName} liegt vor dir',
            body: '${leader.profile.avatarEmoji} '
                '${leader.profile.displayName}: '
                '${leader.currentStreak} Tage. Du: ${c.streak.current}. '
                'Das ist noch aufholbar — heute.',
            ctaLabel: 'Jetzt abhaken',
          );
        }
        return CoachMessage(
          tone: tone,
          headline: _activeHeadline(active),
          body: '${_nameList(active)} '
              '${active.length == 1 ? 'war' : 'waren'} heute schon dran. '
              'Du stehst noch auf 0. '
              '${_pick(random, <String>[
            'Willst du das so stehen lassen?',
            'Die sehen deinen Feed auch.',
            'In zwei Stunden ist der Tag durch.',
          ])}',
          ctaLabel: 'Jetzt abhaken',
        );

      case CoachTone.urgent:
        return CoachMessage(
          tone: tone,
          headline: c.isLateNight
              ? 'Letzte Chance'
              : '${c.streak.current} Tage stehen auf dem Spiel',
          body: c.isLateNight
              ? 'Noch ${24 - c.now.hour} Stunden. ${c.streak.current} Tage '
                  'Arbeit gegen ein paar Minuten. Rechne selbst.'
              : 'Der Tag ist fast rum und heute fehlt noch alles. '
                  'Mach die kleinste Version davon — sie zählt genauso.',
          ctaLabel: 'Retten',
        );

      case CoachTone.celebrate:
        return CoachMessage(
          tone: tone,
          headline: 'Tag ${c.dayNumber} 🎉',
          body: _milestoneLine(c.dayNumber, c.challenge.tier.nameDe),
          ctaLabel: 'Teilen',
        );

      case CoachTone.recover:
        final relapsedHabit = _relapsedHabit(c);
        return CoachMessage(
          tone: tone,
          headline: 'Neuer Tag 1',
          body: relapsedHabit == null
              ? 'Streak ist weg, die 100 Tage sind es nicht. '
                  'Der Unterschied zwischen einem Rückfall und einem Abbruch '
                  'ist genau das, was du in den nächsten 24 Stunden machst.'
              : 'Rückfall bei ${relapsedHabit.displayTitle}. '
                  'Das ist Teil der Kurve, nicht ihr Ende. '
                  '${_recoveryHint(relapsedHabit)}',
          ctaLabel: 'Neu starten',
        );

      case CoachTone.raiseTheBar:
        return CoachMessage(
          tone: tone,
          headline: '${c.streak.current} Tage — das läuft zu glatt',
          body: 'Du triffst '
              '${(c.streak.completionRate * 100).round()} % deiner Tage. '
              '${_pick(random, <String>[
            'Zeit, das Ziel härter zu machen: ein Tag mehr pro Woche oder '
                'ein höheres Tagesziel.',
            'Gewohnheiten, die keine Kraft mehr kosten, bringen auch keine '
                'mehr. Erhöh eine Zahl.',
            'Nimm dir eine zweite Baustelle dazu. Du hast Kapazität.',
          ])}',
          ctaLabel: 'Ziel anpassen',
        );
    }
  }

  @override
  Future<List<NudgeSuggestion>> nudgeSuggestions(CoachContext c) async {
    final suggestions = <NudgeSuggestion>[];
    for (final peer in c.peers) {
      if (peer.activeToday) continue;
      if (!peer.isSlipping && c.streak.current <= peer.currentStreak) continue;
      final random = math.Random(peer.did.hashCode ^ c.today.hashCode);
      suggestions.add(NudgeSuggestion(
        targetDid: peer.did,
        text: _pick(random, <String>[
          'Ich war heute schon. Und du?',
          'Tag ${c.dayNumber}. Dein Streak schaut dich an.',
          '${peer.currentStreak} Tage warst du dabei. Heute auch?',
          'Kein Druck. Aber ich sehe deinen Feed.',
        ]),
        reason: peer.isSlipping
            ? 'Seit zwei Tagen inaktiv'
            : 'Heute noch nichts gemacht',
      ));
    }
    suggestions.sort((NudgeSuggestion a, NudgeSuggestion b) =>
        a.targetDid.compareTo(b.targetDid));
    return suggestions.take(5).toList();
  }

  @override
  Future<List<String>> planAdjustments(CoachContext c) async {
    final tips = <String>[];

    if (c.streak.completionRate < 0.6 && c.streak.scheduledDays >= 7) {
      tips.add('Du triffst nur '
          '${(c.streak.completionRate * 100).round()} % deiner Tage. '
          'Nimm eine Gewohnheit raus statt weiter zu scheitern — '
          'drei sichere Tage schlagen fünf geplante.');
    }

    for (final habit in c.challenge.habits) {
      final streak = c.habitStreaks[habit.id] ?? 0;
      if (habit.kind == HabitKind.abstain) {
        final next = nextMilestone(habit.category, streak);
        if (next != null) {
          tips.add('${habit.emoji} ${habit.displayTitle}: noch '
              '${next.day - streak} Tage bis "${next.titleDe}".');
        }
      } else if (streak >= 21) {
        tips.add('${habit.emoji} ${habit.displayTitle} läuft seit $streak '
            'Tagen. Erhöh das Tagesziel um 20 %.');
      } else if (streak == 0 && c.dayNumber > 7) {
        tips.add('${habit.emoji} ${habit.displayTitle} läuft nicht. '
            'Halbier das Ziel, bis es wieder greift.');
      }
    }

    if (c.peers.isEmpty) {
      tips.add('Du hast noch niemanden verbunden. '
          'Allein durchzuhalten ist messbar schwerer — lade jemanden ein.');
    }

    return tips.take(6).toList();
  }

  String _activeHeadline(List<PeerState> active) {
    if (active.length == 1) {
      return '${active.first.profile.displayName} war heute schon dran';
    }
    return '${active.length} deiner Leute waren heute schon dran';
  }

  String _nameList(List<PeerState> peers) {
    final names = peers
        .take(3)
        .map((PeerState p) => '${p.profile.avatarEmoji} '
            '${p.profile.displayName}')
        .toList();
    if (peers.length > 3) {
      return '${names.join(', ')} und ${peers.length - 3} weitere';
    }
    if (names.length == 1) return names.first;
    return '${names.sublist(0, names.length - 1).join(', ')} und ${names.last}';
  }

  Habit? _relapsedHabit(CoachContext c) {
    final log = c.todayLog;
    if (log == null) return null;
    for (final entry in log.entries) {
      if (entry.relapse) return c.challenge.habitById(entry.habitId);
    }
    return null;
  }

  String _recoveryHint(Habit habit) {
    switch (habit.category) {
      case HabitCategory.noFap:
      case HabitCategory.dopamineDetox:
        return 'Handy heute Abend aus dem Schlafzimmer. Das ist der Trigger, '
            'nicht die Willenskraft.';
      case HabitCategory.noAlcohol:
        return 'Schreib auf, wo du warst und mit wem. Das Muster ist wichtiger '
            'als der eine Abend.';
      case HabitCategory.noSugar:
        return 'Mehr Protein zum Frühstück. Heißhunger ist meistens ein '
            'Frühstücksproblem.';
      default:
        return 'Morgen die kleinste mögliche Version. Nur nicht null.';
    }
  }

  String _milestoneLine(int day, String tierName) {
    switch (day) {
      case 7:
        return 'Eine Woche. Die meisten hören genau hier auf.';
      case 30:
        return '30 Tage. Ab jetzt musst du dich weniger überreden.';
      case 66:
        return '66 Tage — der Durchschnitt, bis ein Verhalten automatisch '
            'läuft. Du bist durch.';
      case 100:
        return 'Hundert Tage. Und jetzt kommt der Teil, für den die App '
            'gebaut ist: es hört hier nicht auf. Willkommen in "$tierName".';
      case 365:
        return 'Ein Jahr. Das ist keine Challenge mehr, das bist du.';
      default:
        return '$day Tage am Stück. Das ist der Beweis, nicht das Gefühl.';
    }
  }

  String _pick(math.Random random, List<String> options) =>
      options[random.nextInt(options.length)];
}
