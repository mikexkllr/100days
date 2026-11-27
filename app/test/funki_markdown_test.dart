import 'package:dartantic_ai/dartantic_ai.dart' hide Provider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hundred_core/hundred_core.dart';
import 'package:hundred_days/ai/funki/funki.dart';
import 'package:hundred_days/ai/funki/funki_tools.dart';
import 'package:hundred_days/ui/funki/funki_markdown.dart';
import 'package:hundred_days/ui/funki/funki_widgets.dart';

import 'helpers.dart';

/// Says one thing, whatever it is asked.
class _Brain implements FunkiBrain {
  const _Brain(this.answer);

  final String answer;

  @override
  Future<({String output, List<ChatMessage> messages})> reply(
    String text, {
    required List<ChatMessage> history,
    required List<Tool> tools,
  }) async =>
      (
        output: answer,
        messages: <ChatMessage>[ChatMessage.user(text), ChatMessage.model(answer)],
      );
}

const MdSpan Function(String, {bool bold, bool italic, bool code, bool strike}) _s = MdSpan.new;

void main() {
  group('inline', () {
    test('bold, italic, both, code and struck words', () {
      expect(parseInline('Das ist **wichtig**, *wirklich* und ***sehr*** `code` ~~alt~~.'), <MdSpan>[
        _s('Das ist '),
        _s('wichtig', bold: true),
        _s(', '),
        _s('wirklich', italic: true),
        _s(' und '),
        _s('sehr', bold: true, italic: true),
        _s(' '),
        _s('code', code: true),
        _s(' '),
        _s('alt', strike: true),
        _s('.'),
      ]);
      expect(parseInline('__fett__ und _schräg_'), <MdSpan>[
        _s('fett', bold: true),
        _s(' und '),
        _s('schräg', italic: true),
      ]);
    });

    test('styles nest', () {
      expect(parseInline('*a **b** c*'), <MdSpan>[
        _s('a ', italic: true),
        _s('b', bold: true, italic: true),
        _s(' c', italic: true),
      ]);
      expect(parseInline('**Lachs *wild***'), <MdSpan>[
        _s('Lachs ', bold: true),
        _s('wild', bold: true, italic: true),
      ]);
    });

    test('signs that are only signs stay signs', () {
      // A tool's name, a multiplication, a lone star, an open bold.
      for (final String text in <String>[
        'Nimm get_meal_plan und set_meal.',
        '3 * 4 = 12 und 2 * 3 = 6',
        'Ein * allein',
        '**nie geschlossen',
        'snake_case_name',
        '5 ~ 6 Stück',
      ]) {
        expect(parseInline(text), <MdSpan>[_s(text)], reason: text);
      }
      expect(parseInline(r'\*kein\* Kursiv'), <MdSpan>[_s('*kein* Kursiv')]);
      // What is in code is not read at all.
      expect(parseInline('`a **b** c`'), <MdSpan>[_s('a **b** c', code: true)]);
    });

    test('a link is its words, with the address where that says more', () {
      expect(parseInline('Schau [hier](https://example.org/rezept) nach.'),
          <MdSpan>[_s('Schau hier (https://example.org/rezept) nach.')]);
      expect(parseInline('[https://example.org](https://example.org)'),
          <MdSpan>[_s('https://example.org')]);
      expect(parseInline('![Lachs auf dem Teller](lachs.jpg)'),
          <MdSpan>[_s('Lachs auf dem Teller')]);
      expect(parseInline('Eine [Klammer] ist keine.'), <MdSpan>[_s('Eine [Klammer] ist keine.')]);
    });
  });

  group('blocks', () {
    test('a recipe the way a model writes it', () {
      final List<MdBlock> blocks = parseMarkdown('''
## Lachs mit Bohnen

**Zutaten** für 2:
- 300 g Lachsfilet
- 1 Dose weiße Bohnen
  abgetropft
* 2 EL Olivenöl

1. Bohnen **erwärmen**.
2) Lachs braten.

> Tipp: Mit Zitrone servieren.

---
Guten Appetit!''');
      expect(blocks.map((MdBlock b) => b.kind), <MdBlockKind>[
        MdBlockKind.heading,
        MdBlockKind.paragraph,
        MdBlockKind.bullet,
        MdBlockKind.bullet,
        MdBlockKind.bullet,
        MdBlockKind.ordered,
        MdBlockKind.ordered,
        MdBlockKind.quote,
        MdBlockKind.rule,
        MdBlockKind.paragraph,
      ]);
      expect(blocks[0].level, 2);
      expect(blocks[0].text, 'Lachs mit Bohnen');
      expect(blocks[1].spans, <MdSpan>[_s('Zutaten', bold: true), _s(' für 2:')]);
      // A line indented under an item belongs to it.
      expect(blocks[3].text, '1 Dose weiße Bohnen\nabgetropft');
      expect(blocks[5].marker, '1.');
      expect(blocks[5].spans.last, _s('.'));
      expect(blocks[6].marker, '2.');
      expect(blocks[7].text, 'Tipp: Mit Zitrone servieren.');
      expect(blocks.last.text, 'Guten Appetit!');
    });

    test('lists nest by their indent, and lines break where they were broken', () {
      final List<MdBlock> blocks = parseMarkdown('Montag:\n- Push\n  - Bankdrücken\n    - 3 × 8\nHeute zwei Zeilen\nund die zweite.');
      expect(blocks.map((MdBlock b) => (b.kind, b.level)), <(MdBlockKind, int)>[
        (MdBlockKind.paragraph, 0),
        (MdBlockKind.bullet, 0),
        (MdBlockKind.bullet, 1),
        (MdBlockKind.bullet, 2),
        (MdBlockKind.paragraph, 0),
      ]);
      expect(blocks.last.text, 'Heute zwei Zeilen\nund die zweite.');
    });

    test('code stays as written, fenced or left open', () {
      final List<MdBlock> blocks = parseMarkdown('So:\n```json\n{"a": **1**}\n```\nUnd:\n```\noffen');
      expect(blocks.map((MdBlock b) => b.kind), <MdBlockKind>[
        MdBlockKind.paragraph,
        MdBlockKind.code,
        MdBlockKind.paragraph,
        MdBlockKind.code,
      ]);
      expect(blocks[1].spans.single, _s('{"a": **1**}', code: true));
      expect(blocks[3].text, 'offen');
    });

    test('a table becomes lines a chat bubble can hold', () {
      final List<MdBlock> blocks = parseMarkdown('| Tag | Gericht |\n|---|:--|\n| Mo | Dal |\n| Di | **Curry** |');
      expect(blocks.map((MdBlock b) => b.text), <String>['Tag · Gericht', 'Mo · Dal', 'Di · Curry']);
      expect(blocks.first.spans.single.bold, isTrue);
      expect(blocks[1].spans.single.bold, isFalse);
    });

    test('plain words are one paragraph, and nothing is nothing', () {
      expect(parseMarkdown('Zwei Brezeln sind drin, 440 kcal.').single.spans,
          <MdSpan>[_s('Zwei Brezeln sind drin, 440 kcal.')]);
      expect(parseMarkdown(''), isEmpty);
      expect(parseMarkdown('\n\n  \n'), isEmpty);
      // Not a list, not a heading, not a rule.
      expect(parseMarkdown('-5 Grad und #hashtag und 2026. war gut').single.kind,
          MdBlockKind.paragraph);
    });
  });

  group('in the chat', () {
    Future<void> say(WidgetTester tester, String answer) async {
      final repository = await testRepository();
      await repository.startChallenge(testChallenge());
      tester.view.physicalSize = const Size(1080, 4200);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(wrapForTest(
        repository: repository,
        overrides: <Override>[funkiBrainProvider.overrideWithValue(_Brain(answer))],
        child: Center(
          child: FunkiAskButton(
            key: const Key('funki-ask'),
            focus: FunkiFocus.home(DayKey.today()),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('funki-ask')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('funki-input')), 'Wie koche ich das?');
      await tester.tap(find.byKey(const Key('funki-send')));
      await tester.pumpAndSettle();
    }

    testWidgets('an answer is drawn as what it is, not as its signs', (WidgetTester tester) async {
      await say(tester, '**So geht\'s:**\n\n1. Bohnen *abgießen*.\n2. Lachs braten.\n\n- Zitrone dazu');

      // No stars, no hashes: the words, in their style.
      expect(find.textContaining('**'), findsNothing);
      expect(find.text('So geht\'s:'), findsOneWidget);
      final Text heading = tester.widget<Text>(find.text('So geht\'s:'));
      final TextSpan bold = (heading.textSpan! as TextSpan).children!.single as TextSpan;
      expect(bold.style!.fontWeight, FontWeight.w700);
      expect(find.text('Bohnen abgießen.'), findsOneWidget);
      expect(find.text('1.'), findsOneWidget);
      expect(find.text('2.'), findsOneWidget);
      expect(find.text('•'), findsOneWidget);
      expect(find.text('Zitrone dazu'), findsOneWidget);
      // The numbers stand left of their steps.
      expect(tester.getTopLeft(find.text('1.')).dx,
          lessThan(tester.getTopLeft(find.text('Bohnen abgießen.')).dx));
    });

    testWidgets('what the user typed stays as typed', (WidgetTester tester) async {
      await say(tester, 'Gern.');
      await tester.enterText(find.byKey(const Key('funki-input')), 'Ich meine **genau** das');
      await tester.tap(find.byKey(const Key('funki-send')));
      await tester.pumpAndSettle();
      expect(find.text('Ich meine **genau** das'), findsOneWidget);
    });
  });

  testWidgets('written out sign by sign, the bubble has its size from the start',
      (WidgetTester tester) async {
    final List<MdBlock> blocks = parseMarkdown('**Fett** und\n\n- ein Punkt');
    Future<Size> pump(int? reveal) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 240,
              child: FunkiMarkdown(blocks, key: const Key('md'), reveal: reveal),
            ),
          ),
        ),
      ));
      return tester.getSize(find.byKey(const Key('md')));
    }

    expect(FunkiMarkdown.lengthOf(blocks), 'Fett und'.length + 'ein Punkt'.length);
    final Size whole = await pump(null);
    // Two signs in: "Fe" is seen, the rest is in place but unseen.
    expect(await pump(2), whole);
    final Text first = tester.widget<Text>(find.text('Fett und'));
    final List<InlineSpan> spans = (first.textSpan! as TextSpan).children!;
    expect((spans[0] as TextSpan).text, 'Fe');
    expect((spans[0] as TextSpan).style!.color, isNot(Colors.transparent));
    expect((spans[1] as TextSpan).text, 'tt');
    expect((spans[1] as TextSpan).style!.color, Colors.transparent);
    // The bullet waits for its item.
    expect(tester.widget<Text>(find.text('•')).style!.color, Colors.transparent);
    await pump(9);
    expect(tester.widget<Text>(find.text('•')).style!.color, isNot(Colors.transparent));
  });
}
