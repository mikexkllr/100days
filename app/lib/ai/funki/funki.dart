import 'dart:async';

import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:hundred_core/hundred_core.dart';

import '../dartantic_llm_client.dart';

/// Where Funki was opened from — what he looks at first, and which day or
/// week "today" and "this week" mean in what the user types.
enum FunkiPlace { home, diary, mealPlan, shopping, training }

/// What a conversation with Funki is about.
@immutable
class FunkiFocus {
  const FunkiFocus({required this.place, required this.day, DayKey? weekStart})
      : weekStart = weekStart ?? day;

  factory FunkiFocus.home(DayKey today) =>
      FunkiFocus(place: FunkiPlace.home, day: today, weekStart: today.weekStart);

  factory FunkiFocus.diary(DayKey day) =>
      FunkiFocus(place: FunkiPlace.diary, day: day, weekStart: day.weekStart);

  factory FunkiFocus.mealPlan(DayKey weekStart, {DayKey? today}) => FunkiFocus(
        place: FunkiPlace.mealPlan,
        day: today ?? DayKey.today(),
        weekStart: weekStart,
      );

  factory FunkiFocus.shopping(DayKey today) => FunkiFocus(
      place: FunkiPlace.shopping, day: today, weekStart: today.weekStart);

  factory FunkiFocus.training(DayKey today) => FunkiFocus(
      place: FunkiPlace.training, day: today, weekStart: today.weekStart);

  final FunkiPlace place;

  /// The day in view: the diary's, otherwise today.
  final DayKey day;

  /// The Monday of the week in view.
  final DayKey weekStart;
}

/// A change Funki made, shown in the conversation with a way back.
class FunkiChange {
  FunkiChange(this.label, this.undo);

  final String label;
  final Future<void> Function() undo;
  bool undone = false;

  /// While its undo runs: a second tap must not undo it twice.
  bool undoing = false;
}

/// One message in the conversation.
class FunkiTurn {
  FunkiTurn.user(this.text)
      : fromUser = true,
        failure = null;

  FunkiTurn.funki(this.text, {this.failure}) : fromUser = false;

  /// Empty for an answer that was only changes.
  final String text;
  final bool fromUser;

  /// Why Funki could not answer, or null when he did.
  final AiFailure? failure;

  /// The allowance ran out: the answer carries the way on.
  bool get offersPaywall =>
      failure == AiFailure.quotaExceeded || failure == AiFailure.premiumOnly;

  final List<FunkiChange> changes = <FunkiChange>[];
}

/// What answers: the language model with Funki's tools. Tests put a script
/// in its place.
abstract class FunkiBrain {
  /// Answers [text] after [history] — which starts with the system message —
  /// calling [tools] as it likes. Returns the answer and every message of
  /// the exchange: the prompt, tool calls, tool results and the answer.
  Future<({String output, List<ChatMessage> messages})> reply(
    String text, {
    required List<ChatMessage> history,
    required List<Tool> tools,
  });
}

/// The brain on the app's model: through the gateway, or the user's key.
class DartanticFunkiBrain implements FunkiBrain {
  /// Long enough for a tool that asks the model itself: a week planned
  /// from the chat is several full recipes written before the answer.
  DartanticFunkiBrain(this.llm, {this.timeout = const Duration(minutes: 4)});

  final DartanticLlmClient llm;
  final Duration timeout;

  @override
  Future<({String output, List<ChatMessage> messages})> reply(
    String text, {
    required List<ChatMessage> history,
    required List<Tool> tools,
  }) async {
    final ChatResult<String> result = await llm
        .agent(LlmPurpose.chat, tools: tools, temperature: 0.4)
        .send(text, history: history)
        .timeout(timeout);
    return (output: result.output, messages: result.messages);
  }
}

/// Builds Funki's tools; each change a tool makes goes to [record].
typedef FunkiToolsFactory = List<Tool> Function(
    void Function(FunkiChange change) record);

/// A conversation with Funki: the turns the user sees, the history the
/// model sees, and the changes made on the way. The one-line "ask Funki"
/// and the full chat share one, so a question asked in passing can go on
/// in the chat.
class FunkiConversation extends ChangeNotifier {
  FunkiConversation({
    required this.brain,
    required this.focus,
    required String Function() system,
    required FunkiToolsFactory tools,
  })  : _system = system,
        _tools = tools;

  final FunkiBrain brain;
  final FunkiFocus focus;
  final String Function() _system;
  final FunkiToolsFactory _tools;

  final List<FunkiTurn> turns = <FunkiTurn>[];
  final List<ChatMessage> _history = <ChatMessage>[];
  bool _thinking = false;
  bool _disposed = false;

  bool get thinking => _thinking;
  bool get isEmpty => turns.isEmpty;

  /// Funki's latest answer, or null before the first.
  FunkiTurn? get lastAnswer {
    for (final FunkiTurn turn in turns.reversed) {
      if (!turn.fromUser) return turn;
    }
    return null;
  }

  /// Sends [text]; the answer lands in [turns]. Never throws: a failure is
  /// an answer that says so.
  Future<FunkiTurn?> send(String text) async {
    final String question = text.trim();
    if (question.isEmpty || _thinking) return null;
    final List<FunkiChange> pending = <FunkiChange>[];
    turns.add(FunkiTurn.user(question));
    _thinking = true;
    _notify();
    if (_history.isEmpty) _history.add(ChatMessage.system(_system()));

    FunkiTurn answer;
    try {
      final ({String output, List<ChatMessage> messages}) result =
          await brain.reply(question,
              history: List<ChatMessage>.of(_history),
              tools: _tools(pending.add));
      // The whole exchange is history for the next turn: what was asked,
      // the tool calls, their results and the answer.
      _history.addAll(result.messages);
      answer = FunkiTurn.funki(result.output.trim());
    } on Object catch (error) {
      answer = FunkiTurn.funki('', failure: classifyAiError(error));
    }
    answer.changes.addAll(pending);
    turns.add(answer);
    _thinking = false;
    _notify();
    return answer;
  }

  /// Takes [change] back. False when that failed.
  Future<bool> undo(FunkiChange change) async {
    if (change.undone || change.undoing) return true;
    change.undoing = true;
    _notify();
    try {
      await change.undo();
      change.undone = true;
      return true;
    } on Object {
      return false;
    } finally {
      change.undoing = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
