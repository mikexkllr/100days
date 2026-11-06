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

  /// Handed to the runtime too: its own default is shorter, and a phone
  /// that needs 25 seconds for a line would otherwise never get to show it.
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
          .generate(prompts.briefing(context, tone),
              maxTokens: 140, timeout: timeout)
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
            .generate(prompts.nudge(context, peer),
                maxTokens: 40, timeout: timeout)
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
          .generate(prompts.adjustments(context),
              maxTokens: 180, timeout: timeout)
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
    if (mixesScripts(title) || mixesScripts(body)) return null;
    return (title, body);
  }

  String? _firstLine(String raw) {
    for (final line in raw.split('\n')) {
      final trimmed = line.trim().replaceAll('"', '');
      if (trimmed.length > 3) return mixesScripts(trimmed) ? null : trimmed;
    }
    return null;
  }
}

/// True when [text] mixes Latin letters with letters of another script —
/// the way a small model's output degrades ("… bei den kleinen Zलक्ष цель").
///
/// Text entirely in one script passes, whichever it is, so this says nothing
/// about the language; emoji, digits and punctuation are not letters and do
/// not count.
bool mixesScripts(String text) {
  var latin = false;
  var other = false;
  for (final rune in text.runes) {
    if (_isLatinLetter(rune)) {
      latin = true;
    } else if (_isOtherScriptLetter(rune)) {
      other = true;
    }
    if (latin && other) return true;
  }
  return false;
}

bool _isLatinLetter(int r) =>
    (r >= 0x41 && r <= 0x5A) ||
    (r >= 0x61 && r <= 0x7A) ||
    (r >= 0xC0 && r <= 0x24F && r != 0xD7 && r != 0xF7) ||
    (r >= 0x1E00 && r <= 0x1EFF);

/// Greek, Cyrillic, Armenian, Hebrew, Arabic, the Indic scripts, Thai, and
/// the CJK and Hangul blocks — scripts a Latin-language answer has no reason
/// to contain.
bool _isOtherScriptLetter(int r) =>
    (r >= 0x370 && r <= 0x52F) ||
    (r >= 0x530 && r <= 0x6FF) ||
    (r >= 0x900 && r <= 0xDFF) ||
    (r >= 0xE00 && r <= 0xE7F) ||
    (r >= 0x3040 && r <= 0x30FF) ||
    (r >= 0x4E00 && r <= 0x9FFF) ||
    (r >= 0xAC00 && r <= 0xD7AF);
