import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/funki/funki.dart';
import '../../ai/funki/funki_tools.dart';
import '../../l10n/l10n.dart';
import '../../theme/theme.dart';
import 'funki_chat_screen.dart';
import 'funki_widgets.dart';

/// "Ask Funki" in one line, where it is needed: a question, his answer and
/// what he changed right below — and the way into the chat to go on.
///
/// Not shown without a model that can call tools.
class FunkiAskBar extends ConsumerStatefulWidget {
  const FunkiAskBar({super.key, required this.focus});

  final FunkiFocus focus;

  @override
  ConsumerState<FunkiAskBar> createState() => _FunkiAskBarState();
}

class _FunkiAskBarState extends ConsumerState<FunkiAskBar> {
  final TextEditingController _input = TextEditingController();
  FunkiConversation? _conversation;

  @override
  void dispose() {
    _conversation?.dispose();
    _input.dispose();
    super.dispose();
  }

  FunkiConversation? _ensure() => _conversation ??= createFunkiConversation(
      ProviderScope.containerOf(context), context.l10n, widget.focus);

  Future<void> _send() async {
    final String question = _input.text.trim();
    final FunkiConversation? conversation = _ensure();
    if (question.isEmpty || conversation == null || conversation.thinking) return;
    FocusScope.of(context).unfocus();
    _input.clear();
    setState(() {});
    await conversation.send(question);
  }

  void _openChat() => Navigator.of(context).push<void>(MaterialPageRoute<void>(
        builder: (BuildContext context) => FunkiChatScreen(
          focus: widget.focus,
          conversation: _ensure(),
        ),
      ));

  @override
  Widget build(BuildContext context) {
    if (ref.watch(funkiBrainProvider) == null) return const SizedBox.shrink();
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    final FunkiConversation? conversation = _conversation;

    final Widget field = TextField(
      key: const Key('funki-ask'),
      controller: _input,
      textCapitalization: TextCapitalization.sentences,
      textInputAction: TextInputAction.send,
      onSubmitted: (_) => _send(),
      onTapOutside: (_) => FocusScope.of(context).unfocus(),
      decoration: InputDecoration(
        isDense: true,
        hintText: funkiHint(l10n, widget.focus.place),
        prefixIcon: const Padding(
          padding: EdgeInsets.all(AppSpacing.xs + 2),
          child: FunkiAvatar(size: 26),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        suffixIcon: IconButton(
          key: const Key('funki-ask-send'),
          tooltip: l10n.funkiAsk,
          onPressed: conversation?.thinking ?? false ? null : _send,
          icon: const Icon(Icons.send, size: 20),
        ),
      ),
    );

    if (conversation == null) return field;
    return ListenableBuilder(
      listenable: conversation,
      builder: (BuildContext context, Widget? _) {
        final FunkiTurn? answer = conversation.lastAnswer;
        final FunkiTurn? asked = conversation.turns.lastOrNull;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            field,
            if (conversation.thinking) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: <Widget>[
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      asked?.text ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ] else if (answer != null) ...<Widget>[
              FunkiTurnView(
                key: const Key('funki-answer'),
                turn: answer,
                conversation: conversation,
                compact: true,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const Key('funki-open-chat'),
                  onPressed: _openChat,
                  child: Text(l10n.funkiContinueInChat),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
