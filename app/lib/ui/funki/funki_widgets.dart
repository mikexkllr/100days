import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../ai/dartantic_llm_client.dart';
import '../../ai/funki/funki.dart';
import '../../ai/funki/funki_tools.dart';
import '../../data/app_repository.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/theme.dart';
import '../mascot/flame_mascot.dart';
import '../motion/motion.dart';
import '../settings/ai_screen.dart' show showPaywall;
import '../widgets/app_card.dart';
import 'funki_markdown.dart';
import 'funki_sheet.dart';

/// Funki himself wherever he speaks: the flame the user has raised, at the
/// stage their streak has brought him to — flickering, blinking, and
/// gulping when [gulps] is bumped.
class FunkiAvatar extends ConsumerWidget {
  const FunkiAvatar({
    super.key,
    this.size = 34,
    this.mood = MascotMood.happy,
    this.gulps = 0,
  });

  final double size;
  final MascotMood mood;

  /// Bumped when he has done something: he jumps and throws sparks.
  final int gulps;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int streak = ref.watch(appStateProvider.select(
        (AsyncValue<AppSnapshot> s) => s.valueOrNull?.me.streak.current ?? 0));
    return SizedBox(
      width: size,
      height: size,
      child: FlameMascot(
        stage: flameStageFor(streak),
        mood: mood,
        size: size,
        gulps: gulps,
      ),
    );
  }
}

/// Funki is thinking: three embers that take turns hopping.
class FunkiThinking extends StatelessWidget {
  const FunkiThinking({super.key, this.color = AppColors.primary});

  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
        label: context.l10n.funkiThinking,
        child: AmbientClock(
          builder: (BuildContext context, double seconds, Widget? _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (int i = 0; i < 3; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.5),
                  child: Transform.translate(
                    offset: Offset(
                        0,
                        -4 *
                            math.max(
                                0, math.sin(seconds * 2 * math.pi * 1.1 - i * 0.9))),
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(alpha: 0.55 + 0.15 * i),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
}

/// What Funki says, written out as he says it: the words appear one after
/// the other, once. Where motion is reduced they are simply there.
class FunkiSpeech extends StatefulWidget {
  const FunkiSpeech(
    this.text, {
    super.key,
    this.style,
    this.animate = true,
    this.markdown = false,
  });

  final String text;
  final TextStyle? style;

  /// False for words already read — an old message is not said again.
  final bool animate;

  /// Whether [text] is Markdown, as a model's answer is: lists, bold and
  /// the rest are drawn as such. The app's own lines are plain words.
  final bool markdown;

  @override
  State<FunkiSpeech> createState() => _FunkiSpeechState();
}

class _FunkiSpeechState extends State<FunkiSpeech>
    with SingleTickerProviderStateMixin {
  AnimationController? _say;

  /// [FunkiSpeech.text] read as Markdown, once for as long as it stays.
  List<MdBlock>? _blocks;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_say == null && widget.animate && ambientMotionOf(context)) _start();
  }

  @override
  void didUpdateWidget(FunkiSpeech old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) _blocks = null;
    if (old.text != widget.text && widget.animate && ambientMotionOf(context)) {
      _start();
    }
  }

  void _start() {
    _say?.dispose();
    _say = AnimationController(
      vsync: this,
      duration: Duration(
          milliseconds: (widget.text.length * 16).clamp(250, 1600).toInt()),
    )
      ..addListener(() => setState(() {}))
      ..forward();
  }

  @override
  void dispose() {
    _say?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AnimationController? say = _say;
    final bool saying = say != null && !say.isCompleted;
    if (widget.markdown) {
      final List<MdBlock> blocks = _blocks ??= parseMarkdown(widget.text);
      if (!saying) return FunkiMarkdown(blocks, style: widget.style);
      // Read out as the whole answer, not as the half that is on screen.
      return Semantics(
        label: widget.text,
        child: ExcludeSemantics(
          child: FunkiMarkdown(
            blocks,
            style: widget.style,
            reveal: (FunkiMarkdown.lengthOf(blocks) * say.value).floor(),
          ),
        ),
      );
    }
    if (!saying) {
      return Text(widget.text, style: widget.style);
    }
    final int shown = (widget.text.length * say.value).floor();
    // The rest is there already, unseen: the bubble keeps its size while
    // the words arrive.
    return Text.rich(
      TextSpan(
        children: <InlineSpan>[
          TextSpan(text: widget.text.substring(0, shown)),
          TextSpan(
            text: widget.text.substring(shown),
            style: const TextStyle(color: Colors.transparent),
          ),
        ],
      ),
      style: widget.style,
      semanticsLabel: widget.text,
    );
  }
}

/// "Ask Funki", the same wherever it stands: Funki and a line of words;
/// tapped, his sheet comes up over the screen the user is on.
///
/// Not shown without a model that can call tools.
class FunkiAskButton extends ConsumerWidget {
  const FunkiAskButton({
    super.key,
    required this.focus,
    this.label,
    this.filled = false,
    this.avatar = true,
  });

  final FunkiFocus focus;

  /// What it says; "Ask Funki" when null.
  final String? label;

  /// Looks like a line to type in rather than a button.
  final bool filled;

  /// False where Funki is right next to it already.
  final bool avatar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(funkiBrainProvider) == null) return const SizedBox.shrink();
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    return Material(
      color: filled ? AppColors.surfaceHigh : Colors.transparent,
      shape: StadiumBorder(
        side: BorderSide(
            color: filled ? Colors.transparent : AppColors.glassEdge),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showFunki(context, focus),
        child: Padding(
          padding: EdgeInsets.fromLTRB(avatar ? AppSpacing.xs : AppSpacing.md,
              AppSpacing.xs, AppSpacing.md, AppSpacing.xs),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 34),
            child: Row(
              mainAxisSize: filled ? MainAxisSize.max : MainAxisSize.min,
              children: <Widget>[
                if (avatar) ...<Widget>[
                  const FunkiAvatar(size: 34),
                  const SizedBox(width: AppSpacing.xs),
                ],
                // A line takes the width it is given; a button is as wide
                // as its words.
                Flexible(
                  fit: filled ? FlexFit.tight : FlexFit.loose,
                  child: Text(
                    label ?? l10n.funkiAsk,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: filled
                        ? text.bodyMedium
                            ?.copyWith(color: AppColors.textTertiary)
                        : text.labelLarge,
                  ),
                ),
                if (filled) ...<Widget>[
                  const SizedBox(width: AppSpacing.sm),
                  const Icon(Icons.arrow_upward_rounded,
                      size: 18, color: AppColors.textTertiary),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Funki in a screen's top bar: one tap from wherever the user is.
class FunkiBarButton extends ConsumerWidget {
  const FunkiBarButton({super.key, required this.focus});

  final FunkiFocus focus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(funkiBrainProvider) == null) return const SizedBox.shrink();
    return IconButton(
      key: const Key('funki-bar'),
      tooltip: context.l10n.funkiAsk,
      onPressed: () => showFunki(context, focus),
      icon: const FunkiAvatar(size: 32),
    );
  }
}

/// What a turn says: the answer, or why there is none.
String funkiTurnText(AppLocalizations l10n, FunkiTurn turn) {
  if (turn.fromUser) return turn.text;
  return switch (turn.failure) {
    AiFailure.quotaExceeded || AiFailure.premiumOnly => l10n.funkiQuotaUsedUp,
    AiFailure.rateLimited => l10n.aiRateLimited,
    AiFailure.other => l10n.plannerFailed,
    null => turn.text.isEmpty ? l10n.plannerDone : turn.text,
  };
}

/// One message, with the changes it made below it.
class FunkiTurnView extends StatelessWidget {
  const FunkiTurnView({
    super.key,
    required this.turn,
    required this.conversation,
    this.fresh = false,
  });

  final FunkiTurn turn;
  final FunkiConversation conversation;

  /// Just said: the words are written out as they come.
  final bool fresh;

  Future<void> _undo(BuildContext context, FunkiChange change) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String failed = context.l10n.funkiUndoFailed;
    if (!await conversation.undo(change)) {
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    final Widget bubble = Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.sm + 4),
      constraints: const BoxConstraints(maxWidth: 320),
      decoration: BoxDecoration(
        color: turn.fromUser
            ? AppColors.social.withValues(alpha: 0.2)
            : AppColors.surfaceHigh,
        borderRadius: AppRadius.cardAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (turn.fromUser)
            Text(turn.text, style: text.bodyMedium)
          else
            FunkiSpeech(
              funkiTurnText(l10n, turn),
              style: text.bodyMedium,
              animate: fresh,
              // His answers are a model's and come as Markdown; why he
              // could not answer is the app's own sentence.
              markdown: turn.failure == null,
            ),
          if (turn.offersPaywall)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: FilledButton(
                key: const Key('funki-paywall'),
                onPressed: () => showPaywall(context),
                child: Text(l10n.aiPaywallAction),
              ),
            ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment:
          turn.fromUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: <Widget>[
        bubble,
        for (final FunkiChange change in turn.changes)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: AppCard(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.xs),
              child: Row(
                children: <Widget>[
                  Icon(
                    change.undone ? Icons.undo : Icons.check_circle_outline,
                    size: 18,
                    color: change.undone ? AppColors.textTertiary : AppColors.success,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      change.label,
                      style: change.undone
                          ? text.bodySmall?.copyWith(
                              decoration: TextDecoration.lineThrough,
                              color: AppColors.textTertiary)
                          : text.bodySmall,
                    ),
                  ),
                  if (!change.undone)
                    TextButton(
                      onPressed:
                          change.undoing ? null : () => _undo(context, change),
                      child: Text(l10n.plannerUndo),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// What Funki is good for where he was opened: tapped, it is asked.
List<String> funkiSuggestions(AppLocalizations l10n, FunkiPlace place) =>
    switch (place) {
      FunkiPlace.home => <String>[l10n.funkiSuggestHome1, l10n.funkiSuggestHome2],
      FunkiPlace.diary => <String>[l10n.funkiSuggestDiary1, l10n.funkiSuggestDiary2],
      FunkiPlace.mealPlan => <String>[
          l10n.funkiSuggestPlan1,
          l10n.funkiSuggestPlan3,
          l10n.funkiSuggestPlan2,
        ],
      FunkiPlace.shopping => <String>[
          l10n.funkiSuggestShopping1,
          l10n.funkiSuggestShopping2,
        ],
      FunkiPlace.training => <String>[
          l10n.funkiSuggestTraining1,
          l10n.funkiSuggestTraining2,
        ],
    };

String funkiHint(AppLocalizations l10n, FunkiPlace place) => switch (place) {
      FunkiPlace.home => l10n.funkiHintHome,
      FunkiPlace.diary => l10n.funkiHintDiary,
      FunkiPlace.mealPlan => l10n.plannerHint,
      FunkiPlace.shopping => l10n.funkiHintShopping,
      FunkiPlace.training => l10n.funkiHintTraining,
    };
