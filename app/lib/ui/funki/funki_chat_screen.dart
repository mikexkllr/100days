import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/funki/funki.dart';
import '../../ai/funki/funki_tools.dart';
import '../../l10n/l10n.dart';
import '../../theme/theme.dart';
import '../widgets/app_card.dart';
import 'funki_widgets.dart';

/// Funki, the coach, to talk to: he reads and changes the habits, the
/// diary, the meal plan, the list and the training through tools, and every
/// change shows up as a card that can be undone.
///
/// Opened with a [conversation] it goes on with that one — a question asked
/// in passing elsewhere; otherwise it starts its own about [focus].
class FunkiChatScreen extends ConsumerStatefulWidget {
  const FunkiChatScreen({super.key, required this.focus, this.conversation});

  final FunkiFocus focus;
  final FunkiConversation? conversation;

  @override
  ConsumerState<FunkiChatScreen> createState() => _FunkiChatScreenState();
}

class _FunkiChatScreenState extends ConsumerState<FunkiChatScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  FunkiConversation? _conversation;

  /// Whether this screen made [_conversation] and so ends it.
  bool _owns = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_conversation != null) return;
    _conversation = widget.conversation;
    if (_conversation == null) {
      _conversation = createFunkiConversation(
          ProviderScope.containerOf(context), context.l10n, widget.focus);
      _owns = _conversation != null;
    }
    _conversation?.addListener(_scrollDown);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollDown());
  }

  @override
  void dispose() {
    _conversation?.removeListener(_scrollDown);
    if (_owns) _conversation?.dispose();
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
    final TextTheme text = Theme.of(context).textTheme;
    final FunkiConversation? conversation = _conversation;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const FunkiAvatar(size: 28),
            const SizedBox(width: AppSpacing.sm),
            Text(l10n.funkiChatTitle),
          ],
        ),
      ),
      body: conversation == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(l10n.planNeedsAi, textAlign: TextAlign.center),
              ),
            )
          : ListenableBuilder(
              listenable: conversation,
              builder: (BuildContext context, Widget? _) => Column(
                children: <Widget>[
                  Expanded(
                    child: ListView(
                      controller: _scroll,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      children: <Widget>[
                        if (conversation.isEmpty) ...<Widget>[
                          AppCard(
                            color: AppColors.surfaceHigh,
                            child: Text(_intro(l10n),
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
                                ActionChip(
                                  label: Text(s),
                                  onPressed: () => _send(s),
                                ),
                            ],
                          ),
                        ],
                        for (final FunkiTurn turn in conversation.turns)
                          FunkiTurnView(turn: turn, conversation: conversation),
                        if (conversation.thinking)
                          const Padding(
                            padding: EdgeInsets.all(AppSpacing.md),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                      ],
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.md,
                          AppSpacing.xs, AppSpacing.md, AppSpacing.md),
                      child: TextField(
                        key: const Key('funki-input'),
                        controller: _input,
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
                            icon: const Icon(Icons.send),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
