import 'dart:async';

import '../domain/peer.dart';
import 'coach.dart';
import 'heuristic_coach.dart';
import 'local_llm.dart';
import 'prompts.dart';

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
    this.prompts = const EnglishCoachPrompts(),
    this.fallback = const HeuristicCoach(),
    this.timeout = const Duration(seconds: 12),
  });

  final LocalLlmRuntime runtime;
  final CoachPromptBuilder prompts;
  final CoachEngine fallback;
  final Duration timeout;

  @override
  bool get isReady => runtime.isReady;

  @override
  String? get modelName => runtime.isReady ? runtime.modelName : null;

  @override
  Future<CoachDirective> dailyBriefing(CoachContext context) async {
    if (!runtime.isReady) return fallback.dailyBriefing(context);
    final tone = selectTone(context);
    try {
      final raw = await runtime
          .generate(prompts.briefing(context, tone), maxTokens: 140)
          .timeout(timeout);
      final parsed = _parseHeadlineBody(raw);
      if (parsed == null) return await fallback.dailyBriefing(context);
      return CoachDirective(
        tone: tone,
        template: CoachTemplate.freeform,
        cta: ctaForTone(tone),
        source: CoachSource.llm,
        dayNumber: context.dayNumber,
        totalDays: context.challenge.lengthDays,
        streak: context.streak.current,
        completionPercent: context.completionPercent,
        cycleIndex: context.challenge.cycle,
        freeformHeadline: parsed.$1,
        freeformBody: parsed.$2,
      );
    } on Object {
      return fallback.dailyBriefing(context);
    }
  }

  @override
  Future<List<NudgeSuggestion>> nudgeSuggestions(CoachContext context) async {
    final base = await fallback.nudgeSuggestions(context);
    if (!runtime.isReady || base.isEmpty) return base;

    final byDid = <String, PeerState>{
      for (final PeerState p in context.peers) p.did: p,
    };

    final result = <NudgeSuggestion>[];
    for (final suggestion in base) {
      final peer = byDid[suggestion.targetDid];
      if (peer == null) {
        result.add(suggestion);
        continue;
      }
      try {
        final raw = await runtime
            .generate(prompts.nudge(context, peer), maxTokens: 40)
            .timeout(timeout);
        final line = _firstLine(raw);
        result.add(line == null
            ? suggestion
            : NudgeSuggestion(
                targetDid: suggestion.targetDid,
                template: NudgeTemplate.freeform,
                reason: suggestion.reason,
                dayNumber: suggestion.dayNumber,
                peerStreak: suggestion.peerStreak,
                text: line,
              ));
      } on Object {
        result.add(suggestion);
      }
    }
    return result;
  }

  @override
  Future<List<PlanAdvice>> planAdjustments(CoachContext context) async {
    final base = await fallback.planAdjustments(context);
    if (!runtime.isReady) return base;
    try {
      final raw = await runtime
          .generate(prompts.adjustments(context), maxTokens: 180)
          .timeout(timeout);
      final lines = raw
          .split('\n')
          .map((String l) =>
              l.replaceFirst(RegExp(r'^\s*[-*\d.)]+\s*'), '').trim())
          .where((String l) => l.length > 12)
          .take(5)
          .map((String l) =>
              PlanAdvice(kind: PlanAdviceKind.freeform, text: l))
          .toList();
      return lines.isEmpty ? base : lines;
    } on Object {
      return base;
    }
  }

  /// Accepts either `TITLE:`/`TEXT:` or `TITEL:`/`TEXT:`, so a localized
  /// prompt builder can use the natural word in its own language.
  (String, String)? _parseHeadlineBody(String raw) {
    String? title;
    final bodyLines = <String>[];
    for (final line in raw.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final upper = trimmed.toUpperCase();
      if (upper.startsWith('TITLE:')) {
        title = trimmed.substring(6).trim();
      } else if (upper.startsWith('TITEL:')) {
        title = trimmed.substring(6).trim();
      } else if (upper.startsWith('TEXT:')) {
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
}
