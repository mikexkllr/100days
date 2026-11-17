import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/app_repository.dart';
import '../../data/household_backend.dart';
import '../../l10n/l10n.dart';
import '../../state/household_providers.dart';
import '../../state/providers.dart';
import '../../theme/theme.dart';
import '../widgets/app_card.dart';

/// Who cooks and shops together: members, what each shares, when the
/// household shops, and the invite.
class HouseholdScreen extends ConsumerWidget {
  const HouseholdScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<Household> household = ref.watch(householdProvider);
    final String me = ref.watch(repositoryProvider).userId;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.householdTitle)),
      body: household.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace _) =>
            Center(child: Text(l10n.planLoadFailed)),
        data: (Household h) {
          final bool owner = h.member(me)?.owner ?? false;
          return ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, 0, AppSpacing.md, AppSpacing.xxl),
            children: <Widget>[
              SectionHeader(l10n.householdMembersTitle),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Column(
                  children: <Widget>[
                    for (final HouseholdMember m in h.members)
                      ListTile(
                        leading: EmojiAvatar(m.emoji, size: 36),
                        title: Text(m.userId == me
                            ? l10n.householdYou(m.displayName)
                            : m.displayName),
                        subtitle: Text(m.shareTargets && m.kcalTarget != null
                            ? l10n.householdSharesTarget(m.kcalTarget!)
                            : l10n.householdNoTarget),
                        trailing: owner && m.userId != me
                            ? IconButton(
                                icon: const Icon(Icons.person_remove_outlined),
                                onPressed: () => ref
                                    .read(householdActionsProvider)
                                    .removeMember(m.userId),
                              )
                            : (m.owner ? const Icon(Icons.star_outline, size: 18) : null),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _InviteCard(householdId: h.id),
              TextButton.icon(
                key: const Key('household-join'),
                onPressed: () => _join(context, ref),
                icon: const Icon(Icons.login, size: 18),
                label: Text(l10n.householdJoin),
              ),
              if (h.member(me) != null) ...<Widget>[
                SectionHeader(l10n.householdMeTitle, subtitle: l10n.householdMeSub),
                _MyMembership(member: h.member(me)!),
              ],
              SectionHeader(l10n.householdShoppingTitle),
              _CadenceCard(household: h),
            ],
          );
        },
      ),
    );
  }

  Future<void> _join(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = context.l10n;
    final TextEditingController code = TextEditingController();
    final String? entered = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(l10n.householdJoin),
        content: TextField(
          controller: code,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(hintText: l10n.inviteCodeHint),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(code.text),
            child: Text(l10n.actionConnect),
          ),
        ],
      ),
    );
    code.dispose();
    if (entered == null || entered.trim().isEmpty || !context.mounted) return;
    await joinHouseholdFlow(context, ref, entered);
  }
}

/// Shows whose household an invite is for, asks once, and joins.
Future<void> joinHouseholdFlow(BuildContext context, WidgetRef ref, String code) async {
  final AppLocalizations l10n = context.l10n;
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final HouseholdBackend backend = ref.read(householdBackendProvider);
  HouseholdInvitePreview? preview;
  try {
    preview = await backend.previewInvite(code);
  } on Object {
    messenger.showSnackBar(SnackBar(content: Text(l10n.inviteErrorOffline)));
    return;
  }
  if (preview == null) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.inviteErrorMalformed)));
    return;
  }
  if (!context.mounted) return;
  final HouseholdInvitePreview found = preview;
  final bool? yes = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: Text(l10n.householdJoinTitle(
          found.name.isEmpty ? found.memberNames.join(', ') : found.name)),
      content: Text(l10n.householdJoinBody),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.householdJoinAction),
        ),
      ],
    ),
  );
  if (yes != true) return;
  try {
    await backend.join(code);
    ref.invalidate(householdIdProvider);
    messenger.showSnackBar(SnackBar(content: Text(l10n.householdJoined)));
  } on Object {
    messenger.showSnackBar(SnackBar(content: Text(l10n.inviteErrorMalformed)));
  }
}

final FutureProviderFamily<String, String> _householdCodeProvider =
    FutureProvider.family<String, String>(
        (Ref ref, String householdId) => ref.watch(householdBackendProvider).inviteCode(householdId));

class _InviteCard extends ConsumerWidget {
  const _InviteCard({required this.householdId});

  final String householdId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<String> code = ref.watch(_householdCodeProvider(householdId));
    return AppCard(
      child: code.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace _) => Text(l10n.inviteErrorOffline),
        data: (String code) {
          final String link = 'hundreddays://household/$code';
          return Column(
            children: <Widget>[
              Text(l10n.householdInviteTitle,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: QrImageView(data: link, size: 160, backgroundColor: Colors.white),
              ),
              const SizedBox(height: AppSpacing.sm),
              SelectableText(code,
                  key: const Key('household-code'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontFamily: 'monospace',
                        letterSpacing: 2,
                      )),
              const SizedBox(height: AppSpacing.sm),
              FilledButton.icon(
                onPressed: () => Share.share(l10n.householdShareText(link, code)),
                icon: const Icon(Icons.ios_share, size: 18),
                label: Text(l10n.actionShare),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MyMembership extends ConsumerStatefulWidget {
  const _MyMembership({required this.member});

  final HouseholdMember member;

  @override
  ConsumerState<_MyMembership> createState() => _MyMembershipState();
}

class _MyMembershipState extends ConsumerState<_MyMembership> {
  late bool _share = widget.member.shareTargets;
  late final TextEditingController _diet =
      TextEditingController(text: widget.member.diet ?? '');
  late final TextEditingController _dislikes =
      TextEditingController(text: widget.member.dislikes.join(', '));
  late final TextEditingController _allergies =
      TextEditingController(text: widget.member.allergies.join(', '));

  @override
  void dispose() {
    _diet.dispose();
    _dislikes.dispose();
    _allergies.dispose();
    super.dispose();
  }

  List<String> _split(String text) => text
      .split(',')
      .map((String s) => s.trim())
      .where((String s) => s.isNotEmpty)
      .toList();

  Future<void> _save() async {
    final AppSnapshot? snapshot = ref.read(appStateProvider).valueOrNull;
    final NutritionPlan? plan = snapshot?.plan?.nutrition;
    await ref.read(householdActionsProvider).updateMe(HouseholdMember(
          userId: widget.member.userId,
          displayName: widget.member.displayName,
          emoji: widget.member.emoji,
          shareTargets: _share && plan != null,
          kcalTarget: plan?.kcal,
          proteinG: plan?.proteinG,
          diet: _diet.text.trim(),
          dislikes: _split(_dislikes.text),
          allergies: _split(_allergies.text),
        ));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(context.l10n.householdSaved)));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final NutritionPlan? plan =
        ref.watch(appStateProvider).valueOrNull?.plan?.nutrition;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SwitchListTile(
            key: const Key('household-share-targets'),
            contentPadding: EdgeInsets.zero,
            value: _share && plan != null,
            onChanged: plan == null ? null : (bool on) => setState(() => _share = on),
            title: Text(l10n.householdShareTargets),
            subtitle: Text(plan == null
                ? l10n.householdShareTargetsNoPlan
                : l10n.householdShareTargetsSub(plan.kcal, plan.proteinG)),
          ),
          TextField(
            controller: _diet,
            decoration: InputDecoration(
                labelText: l10n.householdDiet, hintText: l10n.householdDietHint),
          ),
          TextField(
            controller: _dislikes,
            decoration: InputDecoration(
                labelText: l10n.householdDislikes, hintText: l10n.householdListHint),
          ),
          TextField(
            controller: _allergies,
            decoration: InputDecoration(
                labelText: l10n.householdAllergies, hintText: l10n.householdListHint),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            key: const Key('household-save-me'),
            onPressed: _save,
            child: Text(l10n.actionSave),
          ),
        ],
      ),
    );
  }
}

class _CadenceCard extends ConsumerWidget {
  const _CadenceCard({required this.household});

  final Household household;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ShoppingCadence cadence = household.cadence;
    final HouseholdActions actions = ref.read(householdActionsProvider);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l10n.cadenceLabel(cadence), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              for (int weekday = 1; weekday <= 7; weekday++)
                ChoiceChip(
                  label: Text(l10n.weekdayShort(weekday)),
                  selected: cadence is WeeklyShopping && cadence.weekday == weekday,
                  onSelected: (_) =>
                      actions.updateHousehold(cadence: WeeklyShopping(weekday: weekday)),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            children: <Widget>[
              for (final int days in <int>[3, 4, 14])
                ChoiceChip(
                  label: Text(l10n.cadenceEveryNDays(days)),
                  selected: cadence is EveryNDays && cadence.days == days,
                  onSelected: (_) => actions.updateHousehold(
                      cadence: EveryNDays(days: days, anchor: DayKey.today())),
                ),
              ChoiceChip(
                label: Text(l10n.cadenceManual),
                selected: cadence is ManualShopping,
                onSelected: (_) =>
                    actions.updateHousehold(cadence: const ManualShopping()),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _PantryField(pantry: household.pantry),
        ],
      ),
    );
  }
}

class _PantryField extends ConsumerStatefulWidget {
  const _PantryField({required this.pantry});

  final List<String> pantry;

  @override
  ConsumerState<_PantryField> createState() => _PantryFieldState();
}

class _PantryFieldState extends ConsumerState<_PantryField> {
  late final TextEditingController _text =
      TextEditingController(text: widget.pantry.join(', '));

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return TextField(
      controller: _text,
      decoration: InputDecoration(
        labelText: l10n.householdPantry,
        hintText: l10n.householdPantryHint,
        suffixIcon: IconButton(
          icon: const Icon(Icons.check),
          onPressed: () => ref.read(householdActionsProvider).updateHousehold(
                pantry: _text.text
                    .split(',')
                    .map((String s) => s.trim())
                    .where((String s) => s.isNotEmpty)
                    .toList(),
              ),
        ),
      ),
    );
  }
}
