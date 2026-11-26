import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/funki/funki.dart';
import '../../ai/funki/funki_tools.dart';
import '../../l10n/l10n.dart';
import '../../theme/theme.dart';
import '../mascot/flame_mascot.dart';
import '../widgets/app_card.dart';
import 'funki_widgets.dart';

/// Funki comes up over the screen the user is on — the one way to talk to
/// him, from Today, the diary, the plan or a top bar. He knows where he was
/// called ([focus]) and goes on where the last conversation there stopped.
///
/// With [ask] the question is put to him at once.
Future<void> showFunki(BuildContext context, FunkiFocus focus, {String? ask}) {
  final ProviderContainer container = ProviderScope.containerOf(context);
  final AppLocalizations l10n = context.l10n;
  final FunkiConversation? conversation =
      container.read(funkiSessionProvider).about(container, l10n, focus);
  if (ask != null && ask.trim().isNotEmpty) conversation?.send(ask);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    builder: (BuildContext context) =>
        FunkiSheet(focus: focus, conversation: conversation),
  );
}

/// Funki to talk to: he reads and changes the habits, the diary, the meal
/// plan, the list and the training through tools, and every change shows
/// up as a card that can be undone.
class FunkiSheet extends ConsumerStatefulWidget {
  const FunkiSheet({super.key, required this.focus, required this.conversation});

  final FunkiFocus focus;

  /// Null without a model that can call tools: the sheet says so.
  final FunkiConversation? conversation;

  @override
  ConsumerState<FunkiSheet> createState() => _FunkiSheetState();
}

class _FunkiSheetState extends ConsumerState<FunkiSheet> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  late FunkiConversation? _conversation = widget.conversation;

  /// How many turns were there when the sheet came up: those are not said
  /// again, word by word.
  late int _read = _conversation?.turns.length ?? 0;

  @override
  void initState() {
    super.initState();
    _conversation?.addListener(_scrollDown);
    _scrollDown();
  }

  @override
  void dispose() {
    _conversation?.removeListener(_scrollDown);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send([String? text]) async {
    final FunkiConversation? conversation = _conversation;
    final String question = (text ?? _input.text).trim();
    if (conversation == null || question.isEmpty || conversation.thinking) return;
    _input.clear();
    await conversation.send(question);
  }

  /// A new conversation here; the old one is let go.
  void _startOver() {
    final FunkiConversation? old = _conversation;
    old?.removeListener(_scrollDown);
    final FunkiConversation? fresh = ref.read(funkiSessionProvider).startOver(
        ProviderScope.containerOf(context), context.l10n, widget.focus);
    fresh?.addListener(_scrollDown);
    setState(() {
      _conversation = fresh;
      _read = 0;
    });
    old?.dispose();
  }

  void _scrollDown() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut);
        }
      });

  String _intro(AppLocalizations l10n) => switch (widget.focus.place) {
        FunkiPlace.home => l10n.funkiIntroHome,
        FunkiPlace.diary => l10n.funkiIntroDiary,
        FunkiPlace.mealPlan => l10n.plannerIntro,
      };

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final FunkiConversation? conversation = _conversation;
    return Padding(
      key: const Key('funki-sheet'),
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: FractionallySizedBox(
        heightFactor: 0.92,
        child: conversation == null
            ? Column(
                children: <Widget>[
                  _Header(
                    mood: MascotMood.sleepy,
                    status: l10n.funkiStatusIdle,
                  ),
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child:
                            Text(l10n.planNeedsAi, textAlign: TextAlign.center),
                      ),
                    ),
                  ),
                ],
              )
            : ListenableBuilder(
                listenable: conversation,
                builder: (BuildContext context, Widget? _) =>
                    _conversationView(context, conversation),
              ),
      ),
    );
  }

  Widget _conversationView(BuildContext context, FunkiConversation conversation) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    final FunkiTurn? answer = conversation.lastAnswer;
    final int changes = conversation.turns
        .fold(0, (int sum, FunkiTurn t) => sum + t.changes.length);
    // He shows what is going on: mouth open while he works, a jump when he
    // has done something, small when he could not.
    final MascotMood mood = conversation.thinking
        ? MascotMood.hungry
        : answer?.failure != null
            ? MascotMood.sad
            : answer != null && answer.changes.isNotEmpty
                ? MascotMood.hyped
                : MascotMood.happy;
    return Column(
      children: <Widget>[
        _Header(
          mood: mood,
          gulps: changes,
          status: conversation.thinking
              ? l10n.funkiThinking
              : l10n.funkiStatusIdle,
          onStartOver: conversation.isEmpty || conversation.thinking
              ? null
              : _startOver,
        ),
        Expanded(
          child: ListView(
            controller: _scroll,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
            children: <Widget>[
              if (conversation.isEmpty) ...<Widget>[
                AppCard(
                  color: AppColors.surfaceHigh,
                  child: FunkiSpeech(_intro(l10n),
                      style: text.bodyMedium
                          ?.copyWith(color: AppColors.textSecondary)),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: <Widget>[
                    for (final String s
                        in funkiSuggestions(l10n, widget.focus.place))
                      ActionChip(label: Text(s), onPressed: () => _send(s)),
                  ],
                ),
              ],
              for (int i = 0; i < conversation.turns.length; i++)
                FunkiTurnView(
                  turn: conversation.turns[i],
                  conversation: conversation,
                  fresh: i >= _read && i == conversation.turns.length - 1,
                ),
              if (conversation.thinking)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: FunkiThinking(),
                  ),
                ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.md),
            child: TextField(
              key: const Key('funki-input'),
              controller: _input,
              autofocus: conversation.isEmpty,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: funkiHint(l10n, widget.focus.place),
                suffixIcon: IconButton(
                  key: const Key('funki-send'),
                  onPressed: conversation.thinking ? null : _send,
                  icon: const Icon(Icons.arrow_upward_rounded),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Funki at the head of his sheet, and what he is doing.
class _Header extends StatelessWidget {
  const _Header({
    required this.mood,
    required this.status,
    this.gulps = 0,
    this.onStartOver,
  });

  final MascotMood mood;
  final String status;
  final int gulps;
  final VoidCallback? onStartOver;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.xs, AppSpacing.xs),
      child: Row(
        children: <Widget>[
          FunkiAvatar(size: 60, mood: mood, gulps: gulps),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(l10n.funkiChatTitle, style: text.titleLarge),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    status,
                    key: ValueKey<String>(status),
                    style:
                        text.bodySmall?.copyWith(color: AppColors.textTertiary),
                  ),
                ),
              ],
            ),
          ),
          if (onStartOver != null)
            IconButton(
              key: const Key('funki-new'),
              tooltip: l10n.funkiStartOver,
              onPressed: onStartOver,
              icon: const Icon(Icons.refresh),
            ),
          IconButton(
            key: const Key('funki-close'),
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}
