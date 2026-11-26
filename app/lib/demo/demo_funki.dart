import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:flutter/widgets.dart';

import '../ai/funki/funki.dart';

/// Funki in the demo: no model is reached, so he answers with a line of his
/// own — enough to see him talk in the store screenshots and on a
/// simulator.
class DemoFunkiBrain implements FunkiBrain {
  const DemoFunkiBrain(this.locale);

  final Locale locale;

  @override
  Future<({String output, List<ChatMessage> messages})> reply(
    String text, {
    required List<ChatMessage> history,
    required List<Tool> tools,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    final String answer = locale.languageCode == 'de'
        ? 'Du bist auf Kurs: Heute fehlt nur noch ein Haken, dann brenne ich '
            'einen Tag länger. Die kleinste Version zählt genauso.'
        : 'You are on track: one more tick today and I burn a day longer. '
            'The smallest version counts just the same.';
    return (
      output: answer,
      messages: <ChatMessage>[ChatMessage.user(text), ChatMessage.model(answer)],
    );
  }
}
