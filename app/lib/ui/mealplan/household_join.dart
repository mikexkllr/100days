import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../data/household_backend.dart';
import '../../l10n/l10n.dart';
import '../../state/household_providers.dart';
import '../../state/providers.dart';
import '../../theme/theme.dart';
import '../widgets/app_card.dart';

/// Joining a household, and what becomes of the plan the joiner had.
///
/// A person is in one household and a household has one plan. So before
/// anyone joins, the sheet puts both plans side by side: the one they will
/// share from now on, which stays as it is, and their own, which comes along
/// or is deleted — their choice, made here, with nothing left hidden.

/// Looks up whose household [code] is for, shows what joining does, and
/// joins once the user has said what to do with their own plan.
Future<void> joinHouseholdFlow(BuildContext context, WidgetRef ref, String code) async {
  final AppLocalizations l10n = context.l10n;
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final HouseholdBackend backend = ref.read(householdBackendProvider);
  final HouseholdInvitePreview? preview;
  List<OtherHousehold> mine = const <OtherHousehold>[];
  try {
    preview = await backend.previewInvite(code);
    if (preview != null && !preview.alreadyMember) {
      mine = await backend.householdsBesides(preview.householdId);
    }
  } on Object {
    messenger.showSnackBar(SnackBar(content: Text(l10n.inviteErrorOffline)));
    return;
  }
  if (preview == null) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.inviteErrorMalformed)));
    return;
  }
  if (preview.alreadyMember) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.householdAlreadyIn)));
    return;
  }
  if (!context.mounted) return;
  final HouseholdInvitePreview found = preview;
  final List<OtherHousehold> leaving = mine;
  final bool? brought = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext context) =>
        _JoinSheet(code: code, preview: found, mine: leaving),
  );
  if (brought == null) return;
  messenger.showSnackBar(SnackBar(
      content: Text(brought ? l10n.householdJoinedBrought : l10n.householdJoined)));
}

class _JoinSheet extends ConsumerStatefulWidget {
  const _JoinSheet({required this.code, required this.preview, required this.mine});

  final String code;
  final HouseholdInvitePreview preview;

  /// The households the user is in now, all of which joining takes them
  /// out of.
  final List<OtherHousehold> mine;

  @override
  ConsumerState<_JoinSheet> createState() => _JoinSheetState();
}

class _JoinSheetState extends ConsumerState<_JoinSheet> {
  /// Nothing is deleted unless the user picks that.
  bool _bring = true;
  late bool _share = _sharesNow;
  bool _joining = false;
  bool _failed = false;

  /// What the user planned alone: theirs to bring or delete.
  HouseholdContents get _own => widget.mine
      .where((OtherHousehold h) => h.alone)
      .fold(const HouseholdContents(),
          (HouseholdContents sum, OtherHousehold h) => sum + h.contents);

  /// Everyone the user plans with now and will not after joining.
  List<String> get _leaving => <String>[
        for (final OtherHousehold h in widget.mine) ...h.otherNames,
      ];

  /// Whoever shares their targets where they are now is asked to keep
  /// doing so; whoever does not is not signed up for it by a default.
  bool get _sharesNow =>
      ref
          .read(householdProvider)
          .valueOrNull
          ?.member(ref.read(repositoryProvider).userId)
          ?.shareTargets ??
      false;

  Future<void> _join() async {
    final bool bring = _bring || _own.isEmpty;
    setState(() {
      _joining = true;
      _failed = false;
    });
    try {
      await ref
          .read(householdActionsProvider)
          .join(widget.code, bring: bring, shareTargets: _share);
      if (mounted) Navigator.of(context).pop(bring && !_own.isEmpty);
    } on Object {
      if (mounted) {
        setState(() {
          _joining = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    final HouseholdInvitePreview preview = widget.preview;
    final HouseholdContents own = _own;
    final List<String> leaving = _leaving;
    final NutritionPlan? plan =
        ref.watch(appStateProvider).valueOrNull?.plan?.nutrition;
    final String who = preview.memberNames.join(', ');
    final bool deletes = !_bring && !own.isEmpty;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg,
            AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              l10n.householdJoinTitle(preview.name.isEmpty ? who : preview.name),
              style: text.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(l10n.householdJoinBody,
                style: text.bodyMedium?.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              key: const Key('join-theirs'),
              color: AppColors.social,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _Label(l10n.householdJoinTheirs, color: AppColors.social),
                  const SizedBox(height: AppSpacing.xs),
                  if (preview.name.isNotEmpty && who.isNotEmpty)
                    Text(who,
                        style: text.bodyMedium
                            ?.copyWith(color: AppColors.textSecondary)),
                  Text(
                    preview.contents.isEmpty
                        ? l10n.householdJoinTheirsEmpty
                        : l10n.householdContentsLabel(preview.contents),
                    style: text.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(l10n.householdJoinTheirsNote,
                      style: text.bodySmall
                          ?.copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              key: const Key('join-mine'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _Label(l10n.householdJoinMine),
                  const SizedBox(height: AppSpacing.xs),
                  if (own.isEmpty && leaving.isEmpty)
                    Text(l10n.householdJoinMineNothing, style: text.bodyMedium),
                  if (!own.isEmpty) ...<Widget>[
                    Text(l10n.householdContentsLabel(own), style: text.titleMedium),
                    RadioGroup<bool>(
                      groupValue: _bring,
                      onChanged: (bool? bring) {
                        if (!_joining) setState(() => _bring = bring ?? true);
                      },
                      child: Column(
                        children: <Widget>[
                          RadioListTile<bool>(
                            key: const Key('join-bring'),
                            value: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(l10n.householdJoinBring),
                            subtitle: Text(l10n.householdJoinBringSub),
                          ),
                          RadioListTile<bool>(
                            key: const Key('join-drop'),
                            value: false,
                            contentPadding: EdgeInsets.zero,
                            title: Text(l10n.householdJoinDrop),
                            subtitle: Text(l10n.householdJoinDropSub),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (leaving.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: own.isEmpty ? 0 : AppSpacing.xs),
                      child: Text(
                        l10n.householdJoinLeaves(leaving.join(', ')),
                        key: const Key('join-leaves'),
                        style: text.bodyMedium,
                      ),
                    ),
                ],
              ),
            ),
            if (plan != null)
              SwitchListTile(
                key: const Key('join-share-targets'),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                value: _share,
                onChanged:
                    _joining ? null : (bool on) => setState(() => _share = on),
                title: Text(l10n.householdShareTargets),
                subtitle:
                    Text(l10n.householdShareTargetsSub(plan.kcal, plan.proteinG)),
              ),
            if (_failed)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  l10n.householdJoinFailed,
                  key: const Key('join-failed'),
                  style: text.bodyMedium?.copyWith(color: AppColors.danger),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              key: const Key('join-confirm'),
              style: deletes
                  ? FilledButton.styleFrom(backgroundColor: AppColors.danger)
                  : null,
              onPressed: _joining ? null : _join,
              child: _joining
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(deletes
                      ? l10n.householdJoinActionDrop
                      : l10n.householdJoinAction),
            ),
            TextButton(
              onPressed: _joining ? null : () => Navigator.of(context).pop(),
              child: Text(l10n.actionCancel),
            ),
          ],
        ),
      ),
    );
  }
}

/// The small line over a card that says whose plan it is about.
class _Label extends StatelessWidget {
  const _Label(this.text, {this.color = AppColors.textSecondary});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: color, letterSpacing: 0.8),
      );
}

/// What someone planned alone before they joined, when the app joined
/// without asking: it stayed in a household of one that nothing shows any
/// more. Offers to bring it into the household they are in, or to delete
/// it. Nothing for everyone else.
class HouseholdLeftoverCard extends ConsumerStatefulWidget {
  const HouseholdLeftoverCard({super.key});

  @override
  ConsumerState<HouseholdLeftoverCard> createState() => _HouseholdLeftoverCardState();
}

class _HouseholdLeftoverCardState extends ConsumerState<HouseholdLeftoverCard> {
  bool _working = false;

  Future<void> _settle({required bool bring}) async {
    final AppLocalizations l10n = context.l10n;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() => _working = true);
    try {
      await ref.read(householdActionsProvider).settle(bring: bring);
      messenger.showSnackBar(SnackBar(
          content: Text(bring
              ? l10n.householdLeftoverBrought
              : l10n.householdLeftoverDropped)));
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(l10n.householdSaveFailed)));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _drop(String contents) async {
    final AppLocalizations l10n = context.l10n;
    final bool? yes = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(l10n.householdLeftoverDropTitle),
        content: Text(l10n.householdLeftoverDropBody(contents)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            key: const Key('leftover-drop-confirm'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.actionDelete),
          ),
        ],
      ),
    );
    if (yes == true && mounted) await _settle(bring: false);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    // Offline, or a server that cannot say: then there is nothing to offer.
    final List<OtherHousehold> others =
        ref.watch(otherHouseholdsProvider).valueOrNull ?? const <OtherHousehold>[];
    final HouseholdContents own = others
        .where((OtherHousehold h) => h.alone)
        .fold(const HouseholdContents(),
            (HouseholdContents sum, OtherHousehold h) => sum + h.contents);
    if (own.isEmpty) return const SizedBox.shrink();
    final String contents = l10n.householdContentsLabel(own);

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: AppCard(
        key: const Key('household-leftover'),
        color: AppColors.attention,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(l10n.householdLeftoverTitle, style: text.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(contents, style: text.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(l10n.householdLeftoverBody,
                style: text.bodyMedium?.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.sm),
            FilledButton(
              key: const Key('leftover-bring'),
              onPressed: _working ? null : () => _settle(bring: true),
              child: Text(l10n.householdLeftoverBring),
            ),
            TextButton(
              key: const Key('leftover-drop'),
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              onPressed: _working ? null : () => _drop(contents),
              child: Text(l10n.actionDelete),
            ),
          ],
        ),
      ),
    );
  }
}
