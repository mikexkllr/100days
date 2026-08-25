import 'dart:async';

import '../domain/habit.dart';
import '../domain/peer.dart';
import 'coach.dart';
import 'heuristic_coach.dart';
import 'local_llm.dart';

/// Coach backed by an on-device language model, with the rule-based coach as
/// a hard fallback.
///
/// Every failure mode — no model, slow model, empty or malformed output —
/// degrades to [HeuristicCoach] rather than surfacing an error, because a
/// motivation screen that says "generation failed" is worse than a slightly
/// generic sentence.
class LocalLlmCoach implements CoachEngine {
  LocalLlmCoach({
    required this.runtime,
    this.fallback = const HeuristicCoach(),
    this.timeout = const Duration(seconds: 12),
  });

  final LocalLlmRuntime runtime;
  final CoachEngine fallback;
  final Duration timeout;

  @override
  bool get isReady => runtime.isReady;

  @override
  String get name => runtime.isReady
      ? '${runtime.modelName} (on-device)'
      : fallback.name;

  @override
  Future<CoachMessage> dailyBriefing(CoachContext context) async {
    if (!runtime.isReady) return fallback.dailyBriefing(context);
    final tone = selectTone(context);
    try {
      final raw = await runtime
          .generate(_briefingPrompt(context, tone), maxTokens: 140)
          .timeout(timeout);
      final parsed = _parseHeadlineBody(raw);
      if (parsed == null) return await fallback.dailyBriefing(context);
      return CoachMessage(
        tone: tone,
        headline: parsed.$1,
        body: parsed.$2,
        ctaLabel: _ctaFor(tone),
        source: 'llm',
      );
    } on Object {
      return fallback.dailyBriefing(context);
    }
  }

  @override
  Future<List<NudgeSuggestion>> nudgeSuggestions(CoachContext context) async {
    final base = await fallback.nudgeSuggestions(context);
    if (!runtime.isReady || base.isEmpty) return base;
    final result = <NudgeSuggestion>[];
    for (final suggestion in base) {
      final peer = context.peers.firstWhere(
        (PeerState p) => p.did == suggestion.targetDid,
        orElse: () => context.peers.first,
      );
      try {
        final raw = await runtime
            .generate(_nudgePrompt(context, peer), maxTokens: 40)
            .timeout(timeout);
        final line = _firstLine(raw);
        result.add(line == null
            ? suggestion
            : NudgeSuggestion(
                targetDid: suggestion.targetDid,
                text: line,
                reason: suggestion.reason,
              ));
      } on Object {
        result.add(suggestion);
      }
    }
    return result;
  }

  @override
  Future<List<String>> planAdjustments(CoachContext context) async {
    final base = await fallback.planAdjustments(context);
    if (!runtime.isReady) return base;
    try {
      final raw = await runtime
          .generate(_adjustmentPrompt(context), maxTokens: 180)
          .timeout(timeout);
      final lines = raw
          .split('\n')
          .map((String l) => l.replaceFirst(RegExp(r'^\s*[-*\d.)]+\s*'), '')
              .trim())
          .where((String l) => l.length > 12)
          .take(5)
          .toList();
      return lines.isEmpty ? base : lines;
    } on Object {
      return base;
    }
  }

  String _persona(CoachTone tone) {
    switch (tone) {
      case CoachTone.recover:
        return 'Du bist nüchtern und respektvoll. Kein Mitleid, keine Vorwürfe.';
      case CoachTone.celebrate:
        return 'Du bist kurz und stolz, ohne Kitsch.';
      case CoachTone.urgent:
      case CoachTone.socialPressure:
        return 'Du bist direkt und leicht provokant, aber nie beleidigend.';
      case CoachTone.raiseTheBar:
        return 'Du bist fordernd und konkret.';
      case CoachTone.welcome:
      case CoachTone.steady:
        return 'Du bist ruhig und sachlich.';
    }
  }

  String _briefingPrompt(CoachContext c, CoachTone tone) {
    final habits = c.challenge.habits
        .map((Habit h) =>
            '- ${describeHabitState(h, c.habitStreaks[h.id] ?? 0)}')
        .join('\n');
    final peers = c.peers.isEmpty
        ? '- keine Freunde verbunden'
        : c.peers
            .take(5)
            .map((PeerState p) => '- ${p.profile.displayName}: '
                '${p.currentStreak} Tage Streak, '
                '${p.activeToday ? 'HEUTE schon aktiv' : 'heute noch nichts'}')
            .join('\n');

    return '''
Du bist der Coach in einer 100-Tage-Challenge-App. Sprache: Deutsch, Du-Form.
${_persona(tone)}
Maximal 2 Sätze. Keine Emojis am Zeilenanfang. Keine Anführungszeichen.

Ziel des Nutzers: "${c.challenge.goal.statement}"
Tag ${c.dayNumber} von ${c.challenge.lengthDays} (Stufe: ${c.challenge.tier.nameDe})
Aktueller Streak: ${c.streak.current} Tage, längster: ${c.streak.longest}
Heute erledigt: ${c.streak.doneToday ? 'ja' : 'nein'}
Uhrzeit: ${c.now.hour}:00

Gewohnheiten:
$habits

Freunde:
$peers

Antworte in genau diesem Format:
TITEL: <maximal 6 Wörter>
TEXT: <1-2 Sätze>
''';
  }

  String _nudgePrompt(CoachContext c, PeerState peer) => '''
Schreibe eine einzelne, kurze Stichel-Nachricht auf Deutsch an
${peer.profile.displayName}, der/die heute noch nichts für die eigene
Challenge getan hat. Der Absender ist bei Tag ${c.dayNumber} mit
${c.streak.current} Tagen Streak. Maximal 12 Wörter, frech aber freundlich,
kein Mobbing, keine Anführungszeichen. Nur die Nachricht, sonst nichts.
''';

  String _adjustmentPrompt(CoachContext c) {
    final habits = c.challenge.habits
        .map((Habit h) => '- ${h.displayTitle}: Ziel ${h.target}, '
            '${h.daysPerWeek}x/Woche, Streak ${c.habitStreaks[h.id] ?? 0}')
        .join('\n');
    return '''
Du bist Trainings- und Gewohnheitscoach. Sprache: Deutsch, Du-Form.
Der Nutzer ist bei Tag ${c.dayNumber} von ${c.challenge.lengthDays}.
Trefferquote: ${(c.streak.completionRate * 100).round()} %.
Ziel: "${c.challenge.goal.statement}"

$habits

Gib maximal 4 konkrete Anpassungen, je eine Zeile, je maximal 15 Wörter.
Keine Einleitung, keine Nummerierung, keine Emojis.
''';
  }

  (String, String)? _parseHeadlineBody(String raw) {
    String? title;
    final bodyLines = <String>[];
    for (final line in raw.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.toUpperCase().startsWith('TITEL:')) {
        title = trimmed.substring(6).trim();
      } else if (trimmed.toUpperCase().startsWith('TEXT:')) {
        bodyLines.add(trimmed.substring(5).trim());
      } else if (title != null) {
        bodyLines.add(trimmed);
      }
    }
    final body = bodyLines.join(' ').trim();
    if (title == null || title.isEmpty || body.isEmpty) return null;
    return (title, body);
  }

  String? _firstLine(String raw) {
    for (final line in raw.split('\n')) {
      final trimmed = line.trim().replaceAll('"', '');
      if (trimmed.length > 3) return trimmed;
    }
    return null;
  }

  String _ctaFor(CoachTone tone) {
    switch (tone) {
      case CoachTone.celebrate:
        return 'Teilen';
      case CoachTone.recover:
        return 'Neu starten';
      case CoachTone.raiseTheBar:
        return 'Ziel anpassen';
      case CoachTone.urgent:
        return 'Retten';
      case CoachTone.welcome:
      case CoachTone.steady:
      case CoachTone.socialPressure:
        return 'Jetzt abhaken';
    }
  }
}
