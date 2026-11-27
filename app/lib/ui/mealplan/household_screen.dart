import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/household_backend.dart';
import '../../l10n/l10n.dart';
import '../../state/household_providers.dart';
import '../../state/providers.dart';
import '../../theme/theme.dart';
import '../widgets/app_card.dart';
import 'household_join.dart';
import 'household_load_error.dart';

/// Who cooks and shops together: members, the two ways of getting more of
/// them into one plan — inviting, joining — what each shares, and when the
/// household shops.
///
/// One way of saving throughout: a switch or a chip saves when tapped, a
/// text field with its card's Save button, which lights up once something
/// changed. Every save says "saved" or, when it failed, puts the old value
/// back and says why.
class HouseholdScreen extends ConsumerWidget {
  const HouseholdScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    ref.watch(sharedTargetsSyncProvider);
    final AsyncValue<Household> household = ref.watch(householdProvider);
    final String me = ref.watch(repositoryProvider).userId;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.householdTitle)),
      // A realtime tick reloads the household; what is on screen stays, and
      // with it whatever is typed into the fields.
      body: household.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace _) => const HouseholdLoadError(),
        data: (Household h) {
          final bool owner = h.member(me)?.owner ?? false;
          final HouseholdMember? mine = h.member(me);
          // A scroll view rather than a list: the fields further down keep
          // their text when scrolled out of sight.
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, 0, AppSpacing.md, AppSpacing.xxl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Someone who joined before the app asked about their own
                // plan: first of all, where it went.
                const HouseholdLeftoverCard(),
                SectionHeader(l10n.householdMembersTitle,
                    subtitle: l10n.householdMembersSub),
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
                                  key: Key('household-remove-${m.userId}'),
                                  tooltip: l10n.actionRemove,
                                  icon: const Icon(Icons.person_remove_outlined),
                                  onPressed: () => _removeMember(context, ref, m),
                                )
                              : (m.owner
                                  ? const Icon(Icons.star_outline, size: 18)
                                  : null),
                        ),
                    ],
                  ),
                ),
                SectionHeader(l10n.householdTogetherTitle,
                    subtitle: l10n.householdTogetherSub),
                _InviteCard(householdId: h.id),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  key: const Key('household-join'),
                  onPressed: () => _join(context, ref),
                  icon: const Icon(Icons.login, size: 18),
                  label: Text(l10n.householdJoin),
                ),
                if (mine != null) ...<Widget>[
                  SectionHeader(l10n.householdMeTitle, subtitle: l10n.householdMeSub),
                  _MyMembership(key: ValueKey<String>('me-${h.id}'), member: mine),
                ],
                SectionHeader(l10n.householdShoppingTitle),
                _CadenceCard(key: ValueKey<String>('cadence-${h.id}'), household: h),
                // Alone, leaving would only make a new household of one.
                if (h.members.length > 1) ...<Widget>[
                  const SizedBox(height: AppSpacing.lg),
                  TextButton.icon(
                    key: const Key('household-leave'),
                    onPressed: () => _leave(context, ref),
                    style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                    icon: const Icon(Icons.logout, size: 18),
                    label: Text(l10n.householdLeave),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _removeMember(
      BuildContext context, WidgetRef ref, HouseholdMember member) async {
    final AppLocalizations l10n = context.l10n;
    final bool? yes = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(l10n.householdRemoveTitle(member.displayName)),
        content: Text(l10n.householdRemoveBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            key: const Key('household-remove-confirm'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.actionRemove),
          ),
        ],
      ),
    );
    if (yes != true || !context.mounted) return;
    try {
      await ref.read(householdActionsProvider).removeMember(member.userId);
    } on Object {
      if (context.mounted) showHouseholdSaveFailed(context);
    }
  }

  Future<void> _leave(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = context.l10n;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final HouseholdActions actions = ref.read(householdActionsProvider);
    final bool? yes = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(l10n.householdLeaveTitle),
        content: Text(l10n.householdLeaveBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            key: const Key('household-leave-confirm'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.householdLeave),
          ),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await actions.leave();
      messenger.showSnackBar(SnackBar(content: Text(l10n.householdLeft)));
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(l10n.householdLeaveFailed)));
    }
  }

  Future<void> _join(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = context.l10n;
    final TextEditingController code = TextEditingController();
    final String? entered = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(l10n.householdJoin),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(l10n.householdJoinCodeBody),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const Key('household-join-code'),
              controller: code,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(hintText: l10n.inviteCodeHint),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            key: const Key('household-join-next'),
            onPressed: () => Navigator.of(context).pop(code.text),
            child: Text(l10n.actionNext),
          ),
        ],
      ),
    );
    code.dispose();
    if (entered == null || entered.trim().isEmpty || !context.mounted) return;
    await joinHouseholdFlow(context, ref, entered);
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
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.householdInviteSub,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
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

/// Runs a household save and tells the user how it went — the same way for
/// every setting on this screen. Returns whether it went through.
Future<bool> _save(BuildContext context, Future<void> Function() write) async {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final AppLocalizations l10n = context.l10n;
  try {
    await write();
  } on Object {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.householdSaveFailed)));
    return false;
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(l10n.householdSaved),
      duration: const Duration(seconds: 2),
    ));
  return true;
}

List<String> _split(String text) => text
    .split(',')
    .map((String s) => s.trim())
    .where((String s) => s.isNotEmpty)
    .toList();

/// Keeps a field in step with the server while the user has not touched
/// it: someone else's change shows, the user's unsaved typing stays.
void _follow(TextEditingController field, String before, String now) {
  if (field.text == before && before != now) field.text = now;
}

class _MyMembership extends ConsumerStatefulWidget {
  const _MyMembership({super.key, required this.member});

  final HouseholdMember member;

  @override
  ConsumerState<_MyMembership> createState() => _MyMembershipState();
}

class _MyMembershipState extends ConsumerState<_MyMembership> {
  late bool _share = widget.member.shareTargets;
  bool _saving = false;
  late final TextEditingController _diet =
      TextEditingController(text: widget.member.diet ?? '');
  late final TextEditingController _dislikes =
      TextEditingController(text: widget.member.dislikes.join(', '));
  late final TextEditingController _allergies =
      TextEditingController(text: widget.member.allergies.join(', '));

  @override
  void initState() {
    super.initState();
    for (final TextEditingController c in <TextEditingController>[
      _diet,
      _dislikes,
      _allergies,
    ]) {
      c.addListener(_changed);
    }
  }

  void _changed() => setState(() {});

  @override
  void didUpdateWidget(_MyMembership old) {
    super.didUpdateWidget(old);
    final HouseholdMember was = old.member;
    final HouseholdMember now = widget.member;
    if (!_saving) _share = now.shareTargets;
    _follow(_diet, was.diet ?? '', now.diet ?? '');
    _follow(_dislikes, was.dislikes.join(', '), now.dislikes.join(', '));
    _follow(_allergies, was.allergies.join(', '), now.allergies.join(', '));
  }

  @override
  void dispose() {
    _diet.dispose();
    _dislikes.dispose();
    _allergies.dispose();
    super.dispose();
  }

  bool get _dirty =>
      _diet.text.trim() != (widget.member.diet ?? '') ||
      _split(_dislikes.text).join(', ') != widget.member.dislikes.join(', ') ||
      _split(_allergies.text).join(', ') != widget.member.allergies.join(', ');

  /// The whole membership, with [share] as the switch: the switch saves on
  /// its own, the text with the button — both send what is on screen.
  Future<bool> _store({required bool share}) {
    final NutritionPlan? plan =
        ref.read(appStateProvider).valueOrNull?.plan?.nutrition;
    final HouseholdActions actions = ref.read(householdActionsProvider);
    final HouseholdMember me = HouseholdMember(
      userId: widget.member.userId,
      displayName: widget.member.displayName,
      emoji: widget.member.emoji,
      diet: _diet.text.trim(),
      dislikes: _split(_dislikes.text),
      allergies: _split(_allergies.text),
    ).withTargets(
      share: share && plan != null,
      kcal: plan?.kcal,
      protein: plan?.proteinG,
    );
    return _save(context, () => actions.updateMe(me));
  }

  Future<void> _toggleShare(bool on) async {
    setState(() {
      _share = on;
      _saving = true;
    });
    final bool ok = await _store(share: on);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (!ok) _share = !on;
    });
  }

  Future<void> _saveText() async {
    setState(() => _saving = true);
    await _store(share: _share);
    if (mounted) setState(() => _saving = false);
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
            onChanged: plan == null || _saving ? null : _toggleShare,
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
            onPressed: _dirty && !_saving ? _saveText : null,
            child: Text(l10n.actionSave),
          ),
        ],
      ),
    );
  }
}

class _CadenceCard extends ConsumerStatefulWidget {
  const _CadenceCard({super.key, required this.household});

  final Household household;

  @override
  ConsumerState<_CadenceCard> createState() => _CadenceCardState();
}

class _CadenceCardState extends ConsumerState<_CadenceCard> {
  /// The rhythm tapped and on its way to the server, shown as chosen.
  ShoppingCadence? _pending;

  static String _key(ShoppingCadence c) => jsonEncode(c.toJson());

  @override
  void didUpdateWidget(_CadenceCard old) {
    super.didUpdateWidget(old);
    final ShoppingCadence? pending = _pending;
    if (pending != null && _key(pending) == _key(widget.household.cadence)) {
      _pending = null;
    }
  }

  Future<void> _choose(ShoppingCadence cadence) async {
    final HouseholdActions actions = ref.read(householdActionsProvider);
    setState(() => _pending = cadence);
    final bool ok =
        await _save(context, () => actions.updateHousehold(cadence: cadence));
    if (!ok && mounted) setState(() => _pending = null);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ShoppingCadence cadence = _pending ?? widget.household.cadence;
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
                  key: Key('cadence-weekday-$weekday'),
                  label: Text(l10n.weekdayShort(weekday)),
                  selected: cadence is WeeklyShopping && cadence.weekday == weekday,
                  onSelected: (_) => _choose(WeeklyShopping(weekday: weekday)),
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
                  onSelected: (_) =>
                      _choose(EveryNDays(days: days, anchor: DayKey.today())),
                ),
              ChoiceChip(
                label: Text(l10n.cadenceManual),
                selected: cadence is ManualShopping,
                onSelected: (_) => _choose(const ManualShopping()),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _PantryField(pantry: widget.household.pantry),
        ],
      ),
    );
  }
}

/// What is usually at home, left off lists made from the plan. Saved with
/// its own button, like the other text on this screen.
class _PantryField extends ConsumerStatefulWidget {
  const _PantryField({required this.pantry});

  final List<String> pantry;

  @override
  ConsumerState<_PantryField> createState() => _PantryFieldState();
}

class _PantryFieldState extends ConsumerState<_PantryField> {
  late final TextEditingController _text =
      TextEditingController(text: widget.pantry.join(', '))
        ..addListener(() => setState(() {}));
  bool _saving = false;

  @override
  void didUpdateWidget(_PantryField old) {
    super.didUpdateWidget(old);
    _follow(_text, old.pantry.join(', '), widget.pantry.join(', '));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _store() async {
    final HouseholdActions actions = ref.read(householdActionsProvider);
    setState(() => _saving = true);
    await _save(context, () => actions.updateHousehold(pantry: _split(_text.text)));
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final bool dirty = _split(_text.text).join(', ') != widget.pantry.join(', ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextField(
          key: const Key('household-pantry'),
          controller: _text,
          decoration: InputDecoration(
            labelText: l10n.householdPantry,
            hintText: l10n.householdPantryHint,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            key: const Key('household-save-pantry'),
            onPressed: dirty && !_saving ? _store : null,
            child: Text(l10n.actionSave),
          ),
        ),
      ],
    );
  }
}
