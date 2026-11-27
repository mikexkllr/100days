import 'package:flutter/material.dart';

import '../../theme/theme.dart';

/// What Funki writes, read as Markdown — the part of it a language model
/// actually uses in a chat: paragraphs, headings, bullet and numbered
/// lists, quotes, code, rules, and **bold**, *italic*, `code` and
/// ~~struck~~ words. Anything else stays the text it was; nothing a model
/// writes can fail to parse.
///
/// Small on purpose, and the app's own: the answer is written out word by
/// word ([FunkiMarkdown.reveal]), which a ready-made Markdown widget does
/// not do.

/// What a block of a message is.
enum MdBlockKind { paragraph, heading, bullet, ordered, quote, code, rule }

/// A run of text in one style.
@immutable
class MdSpan {
  const MdSpan(
    this.text, {
    this.bold = false,
    this.italic = false,
    this.code = false,
    this.strike = false,
  });

  final String text;
  final bool bold;
  final bool italic;
  final bool code;
  final bool strike;

  @override
  bool operator ==(Object other) =>
      other is MdSpan &&
      other.text == text &&
      other.bold == bold &&
      other.italic == italic &&
      other.code == code &&
      other.strike == strike;

  @override
  int get hashCode => Object.hash(text, bold, italic, code, strike);

  @override
  String toString() => 'MdSpan("$text"'
      '${bold ? ', bold' : ''}${italic ? ', italic' : ''}'
      '${code ? ', code' : ''}${strike ? ', strike' : ''})';
}

/// A paragraph, a heading, one item of a list, …
@immutable
class MdBlock {
  const MdBlock(this.kind, this.spans, {this.level = 0, this.marker});

  final MdBlockKind kind;
  final List<MdSpan> spans;

  /// A heading's rank (1–6); how deep a list item is nested (0 at the top).
  final int level;

  /// The number of an item in a numbered list, as written: "2.".
  final String? marker;

  /// The words alone.
  String get text => spans.map((MdSpan s) => s.text).join();

  @override
  String toString() => '${kind.name}($level${marker == null ? '' : ' $marker'}): $spans';
}

final RegExp _fence = RegExp(r'^\s{0,3}(```|~~~)');
final RegExp _heading = RegExp(r'^\s{0,3}(#{1,6})\s+(.*?)\s*#*\s*$');
final RegExp _rule = RegExp(r'^\s{0,3}([-*_])(\s*\1){2,}\s*$');
final RegExp _bullet = RegExp(r'^(\s*)[-*+•]\s+(.*)$');
final RegExp _ordered = RegExp(r'^(\s*)(\d{1,3})[.)]\s+(.*)$');
final RegExp _quote = RegExp(r'^\s{0,3}>\s?(.*)$');
final RegExp _tableRow = RegExp(r'^\s*\|.*\|\s*$');
final RegExp _tableRule = RegExp(r'^\s*\|?[\s:|-]*-[\s:|-]*\|?\s*$');

/// Reads [source] into blocks, in order.
List<MdBlock> parseMarkdown(String source) {
  final List<String> lines =
      source.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
  final List<MdBlock> blocks = <MdBlock>[];
  // Lines of the paragraph, the list item or the quote being read; a model
  // breaks its lines where it means them to break, so they stay broken.
  final List<String> open = <String>[];
  MdBlockKind openKind = MdBlockKind.paragraph;
  int openLevel = 0;
  String? openMarker;

  void close() {
    if (open.isEmpty) return;
    blocks.add(MdBlock(openKind, parseInline(open.join('\n')),
        level: openLevel, marker: openMarker));
    open.clear();
  }

  void start(MdBlockKind kind, String text, {int level = 0, String? marker}) {
    close();
    openKind = kind;
    openLevel = level;
    openMarker = marker;
    open.add(text);
  }

  for (int i = 0; i < lines.length; i++) {
    final String line = lines[i];
    if (_fence.hasMatch(line)) {
      close();
      final String fence = _fence.firstMatch(line)!.group(1)!;
      final List<String> code = <String>[];
      // Up to the closing fence — or the end, for one left open.
      for (i++; i < lines.length; i++) {
        if (lines[i].trimLeft().startsWith(fence)) break;
        code.add(lines[i]);
      }
      blocks.add(MdBlock(
          MdBlockKind.code, <MdSpan>[MdSpan(code.join('\n'), code: true)]));
      continue;
    }
    if (line.trim().isEmpty) {
      close();
      continue;
    }
    if (_rule.hasMatch(line)) {
      close();
      blocks.add(const MdBlock(MdBlockKind.rule, <MdSpan>[]));
      continue;
    }
    RegExpMatch? m = _heading.firstMatch(line);
    if (m != null) {
      close();
      blocks.add(MdBlock(MdBlockKind.heading, parseInline(m.group(2)!),
          level: m.group(1)!.length));
      continue;
    }
    m = _bullet.firstMatch(line);
    if (m != null) {
      start(MdBlockKind.bullet, m.group(2)!, level: _depth(m.group(1)!));
      continue;
    }
    m = _ordered.firstMatch(line);
    if (m != null) {
      start(MdBlockKind.ordered, m.group(3)!,
          level: _depth(m.group(1)!), marker: '${m.group(2)}.');
      continue;
    }
    m = _quote.firstMatch(line);
    if (m != null) {
      if (open.isNotEmpty && openKind == MdBlockKind.quote) {
        open.add(m.group(1)!);
      } else {
        start(MdBlockKind.quote, m.group(1)!);
      }
      continue;
    }
    if (_tableRow.hasMatch(line)) {
      // A table does not fit a chat bubble: each row is a line, its cells
      // side by side, and the row above the ruler is the bold one.
      if (_tableRule.hasMatch(line)) continue;
      final String cells = line
          .trim()
          .replaceAll(RegExp(r'^\||\|$'), '')
          .split('|')
          .map((String c) => c.trim())
          .join(' · ');
      final bool header =
          i + 1 < lines.length && _tableRule.hasMatch(lines[i + 1]);
      close();
      blocks.add(MdBlock(MdBlockKind.paragraph,
          parseInline(header ? '**$cells**' : cells)));
      continue;
    }
    // Plain words: more of what is being read — an indented line under a
    // list item belongs to the item — or a new paragraph.
    final bool inList = open.isNotEmpty &&
        (openKind == MdBlockKind.bullet || openKind == MdBlockKind.ordered);
    if (open.isEmpty ||
        openKind == MdBlockKind.quote ||
        (inList && !line.startsWith(' '))) {
      start(MdBlockKind.paragraph, line.trim());
    } else {
      open.add(line.trim());
    }
  }
  close();
  return blocks;
}

/// Two spaces of indent are one level of nesting, three at the most.
int _depth(String indent) =>
    (indent.replaceAll('\t', '  ').length ~/ 2).clamp(0, 3);

/// Reads the styles inside one block.
List<MdSpan> parseInline(String text) {
  final List<MdSpan> out = <MdSpan>[];
  _inline(text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n'),
      const MdSpan(''), out);
  // Neighbours in one style are one run.
  final List<MdSpan> merged = <MdSpan>[];
  for (final MdSpan span in out) {
    if (span.text.isEmpty) continue;
    if (merged.isNotEmpty && _sameStyle(merged.last, span)) {
      merged.last = _styled(merged.last.text + span.text, span);
    } else {
      merged.add(span);
    }
  }
  return merged;
}

bool _sameStyle(MdSpan a, MdSpan b) =>
    a.bold == b.bold &&
    a.italic == b.italic &&
    a.code == b.code &&
    a.strike == b.strike;

MdSpan _styled(String text, MdSpan like,
        {bool? bold, bool? italic, bool? code, bool? strike}) =>
    MdSpan(
      text,
      bold: bold ?? like.bold,
      italic: italic ?? like.italic,
      code: code ?? like.code,
      strike: strike ?? like.strike,
    );

final RegExp _wordSign = RegExp(r'[\p{L}\p{N}]', unicode: true);

bool _isWord(String char) => _wordSign.hasMatch(char);

bool _isSpace(String char) => char.trim().isEmpty;

/// How many times [char] repeats in [s] from [at].
int _run(String s, int at, String char) {
  int n = 0;
  while (at + n < s.length && s[at + n] == char) {
    n++;
  }
  return n;
}

void _inline(String s, MdSpan style, List<MdSpan> out) {
  final StringBuffer plain = StringBuffer();
  void flush() {
    if (plain.isEmpty) return;
    out.add(_styled(plain.toString(), style));
    plain.clear();
  }

  int i = 0;
  while (i < s.length) {
    final String c = s[i];
    // A backslash makes the next sign a sign.
    if (c == r'\' && i + 1 < s.length && r'\`*_{}[]()#+-.!~>|'.contains(s[i + 1])) {
      plain.write(s[i + 1]);
      i += 2;
      continue;
    }
    if (c == '`') {
      final int ticks = _run(s, i, '`');
      final int end = s.indexOf('`' * ticks, i + ticks);
      if (end > i) {
        flush();
        out.add(_styled(s.substring(i + ticks, end).trim(), style, code: true));
        i = end + ticks;
        continue;
      }
    }
    if (c == '~' && s.startsWith('~~', i)) {
      final int end = s.indexOf('~~', i + 2);
      if (end > i + 2) {
        flush();
        _inline(s.substring(i + 2, end), _styled('', style, strike: true), out);
        i = end + 2;
        continue;
      }
    }
    if (c == '*' || c == '_') {
      final int run = _run(s, i, c);
      final int n = run.clamp(1, 3);
      final int close = _closing(s, i, c, n);
      if (close > 0) {
        flush();
        _inline(
          s.substring(i + n, close),
          _styled('', style,
              bold: n >= 2 ? true : null, italic: n.isOdd ? true : null),
          out,
        );
        i = close + n;
        continue;
      }
      // No partner: the signs are signs.
      plain.write(c * run);
      i += run;
      continue;
    }
    // A link is its words; the address follows where it says more than
    // they do. A picture is its description.
    if (c == '[' || (c == '!' && i + 1 < s.length && s[i + 1] == '[')) {
      final int open = c == '!' ? i + 1 : i;
      final int label = s.indexOf('](', open);
      final int end = label < 0 ? -1 : s.indexOf(')', label + 2);
      if (label > open && end > label && !s.substring(open, label).contains('\n')) {
        flush();
        final String words = s.substring(open + 1, label);
        final String address = s.substring(label + 2, end).trim();
        _inline(words, style, out);
        if (c != '!' && address.isNotEmpty && address != words.trim()) {
          out.add(_styled(' ($address)', style));
        }
        i = end + 1;
        continue;
      }
    }
    plain.write(c);
    i++;
  }
  flush();
}

/// Where the run of [n] [char]s that closes the one opening at [open]
/// starts, or -1: after something that is not a space, around at least one
/// sign, and — for underscores — not in the middle of a word, so that
/// `get_meal_plan` stays what it is.
int _closing(String s, int open, String char, int n) {
  final int start = open + n;
  if (start >= s.length || _isSpace(s[start])) return -1;
  if (char == '_' && open > 0 && _isWord(s[open - 1])) return -1;
  int i = start;
  while (i < s.length) {
    final String c = s[i];
    if (c == r'\') {
      i += 2;
      continue;
    }
    if (c == '`') {
      final int ticks = _run(s, i, '`');
      final int end = s.indexOf('`' * ticks, i + ticks);
      i = end > i ? end + ticks : i + ticks;
      continue;
    }
    if (c != char) {
      i++;
      continue;
    }
    final int run = _run(s, i, char);
    // A single sign does not close a double one, and a double sign inside
    // an emphasis is a bold of its own.
    final bool fits = n == 1 ? run != 2 : run >= n;
    final int at = i + run - n;
    if (fits &&
        i > start &&
        !_isSpace(s[i - 1]) &&
        (char != '_' || at + n >= s.length || !_isWord(s[at + n]))) {
      return at;
    }
    i += run;
  }
  return -1;
}

/// Markdown blocks, drawn for a chat bubble.
class FunkiMarkdown extends StatelessWidget {
  const FunkiMarkdown(this.blocks, {super.key, this.style, this.reveal});

  final List<MdBlock> blocks;
  final TextStyle? style;

  /// How many signs are to be seen so far, counted through the blocks in
  /// order; null for all of them. The rest is there already, unseen, so
  /// the bubble keeps its size while the words arrive.
  final int? reveal;

  /// The signs in [blocks]: what [reveal] counts up to.
  static int lengthOf(List<MdBlock> blocks) =>
      blocks.fold(0, (int sum, MdBlock b) => sum + b.text.length);

  @override
  Widget build(BuildContext context) {
    final TextStyle base =
        style ?? Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
    final _Budget budget = _Budget(reveal);
    final List<Widget> children = <Widget>[];
    for (int i = 0; i < blocks.length; i++) {
      final MdBlock block = blocks[i];
      final bool listItem = block.kind == MdBlockKind.bullet ||
          block.kind == MdBlockKind.ordered;
      final bool afterListItem = i > 0 &&
          (blocks[i - 1].kind == MdBlockKind.bullet ||
              blocks[i - 1].kind == MdBlockKind.ordered);
      if (i > 0) {
        // Items of a list stand close; everything else gets air.
        children.add(SizedBox(height: listItem && afterListItem ? 3 : 8));
      }
      children.add(_block(context, block, base, budget));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  Widget _block(
      BuildContext context, MdBlock block, TextStyle base, _Budget budget) {
    // A marker shows with the first sign of its item.
    final bool begun = budget.any;
    Widget words(TextStyle style) => Text.rich(
          TextSpan(children: <InlineSpan>[
            for (final MdSpan span in block.spans) ...budget.take(span, style),
          ]),
          style: style,
        );
    Widget marked(String marker, {required double width}) => Padding(
          padding: EdgeInsets.only(left: 2 + block.level * 14.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: width,
                child: Text(
                  marker,
                  style: base.copyWith(
                      color: begun ? AppColors.textTertiary : Colors.transparent),
                ),
              ),
              Expanded(child: words(base)),
            ],
          ),
        );
    switch (block.kind) {
      case MdBlockKind.paragraph:
        return words(base);
      case MdBlockKind.heading:
        final double size = base.fontSize ?? 14;
        return words(base.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: size + (block.level <= 2 ? 2 : 1),
        ));
      case MdBlockKind.bullet:
        return marked('•', width: 14);
      case MdBlockKind.ordered:
        return marked(block.marker ?? '•',
            width: 12 + 8.0 * (block.marker?.length ?? 2).clamp(2, 4) / 2);
      case MdBlockKind.quote:
        return Container(
          padding: const EdgeInsets.only(left: AppSpacing.sm),
          decoration: const BoxDecoration(
            border: Border(left: BorderSide(color: AppColors.glassEdge, width: 3)),
          ),
          child: words(base.copyWith(color: AppColors.textSecondary)),
        );
      case MdBlockKind.code:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: words(base),
        );
      case MdBlockKind.rule:
        return const Divider(height: 8, color: AppColors.glassEdge);
    }
  }
}

/// Counts the signs shown down to zero while the spans are built.
class _Budget {
  _Budget(this._left);

  int? _left;

  /// Whether anything more is to be seen.
  bool get any => _left == null || _left! > 0;

  /// [span] as text spans: what is within the count as written, the rest
  /// in place but unseen.
  List<InlineSpan> take(MdSpan span, TextStyle base) {
    final TextStyle shown = _style(span, base);
    final int? left = _left;
    if (left == null) return <InlineSpan>[TextSpan(text: span.text, style: shown)];
    final int seen = left.clamp(0, span.text.length);
    _left = left - seen;
    final TextStyle hidden = shown.copyWith(
      color: Colors.transparent,
      backgroundColor: Colors.transparent,
      decorationColor: Colors.transparent,
    );
    return <InlineSpan>[
      if (seen > 0) TextSpan(text: span.text.substring(0, seen), style: shown),
      if (seen < span.text.length)
        TextSpan(text: span.text.substring(seen), style: hidden),
    ];
  }

  static TextStyle _style(MdSpan span, TextStyle base) => base.copyWith(
        fontWeight: span.bold ? FontWeight.w700 : null,
        fontStyle: span.italic ? FontStyle.italic : null,
        decoration: span.strike ? TextDecoration.lineThrough : null,
        fontFamily: span.code ? 'monospace' : null,
        backgroundColor:
            span.code ? AppColors.glassEdge.withValues(alpha: 0.35) : null,
      );
}
