import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/push_service.dart';
import '../../data/social_backend.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/theme.dart';
import '../widgets/app_card.dart';

/// Read when the screen opens. Disposed with it, so a fetch that failed
/// offline is tried again next time instead of being kept for the session.
final AutoDisposeFutureProvider<({String? username, SocialSettings settings})>
    _socialSettingsProvider = FutureProvider.autoDispose<
        ({String? username, SocialSettings settings})>((Ref ref) async {
  final SocialBackend social = ref.watch(repositoryProvider).social;
  return (username: await social.username(), settings: await social.settings());
});

final AutoDisposeFutureProvider<List<PersonResult>> _blockedProvider =
    FutureProvider.autoDispose<List<PersonResult>>(
        (Ref ref) => ref.watch(repositoryProvider).social.blockedPeople());

/// Being found and being told: username, address-book matching, the public
/// league, which pushes arrive — and who is blocked.
class SocialSettingsScreen extends ConsumerStatefulWidget {
  const SocialSettingsScreen({super.key});

  @override
  ConsumerState<SocialSettingsScreen> createState() =>
      _SocialSettingsScreenState();
}

class _SocialSettingsScreenState extends ConsumerState<SocialSettingsScreen> {
  /// What the switches show: the last fetch with every toggle since applied
  /// on top. Each save sends this merged state, so two quick toggles both
  /// stick instead of the second saving a copy without the first.
  SocialSettings? _local;

  /// Saves run one after another, in the order the switches were flipped.
  Future<void> _saving = Future<void>.value();

  SocialBackend get _social => ref.read(repositoryProvider).social;

  /// Applies [edit] to what the switches show right now — not to the copy
  /// the tapped switch was built with, which a second quick tap may predate
  /// — and saves the result with [save].
  void _change(
    SocialSettings Function(SocialSettings) edit,
    Future<void> Function(SocialSettings) save,
  ) {
    final SocialSettings? current =
        _local ?? ref.read(_socialSettingsProvider).valueOrNull?.settings;
    if (current == null) return;
    final SocialSettings next = edit(current);
    setState(() => _local = next);
    final AppLocalizations l10n = context.l10n;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    _saving = _saving.then((_) async {
      try {
        await save(next);
      } on Object {
        messenger.showSnackBar(SnackBar(content: Text(l10n.inviteErrorOffline)));
        // Back to what the server has.
        if (mounted) setState(() => _local = null);
        ref.invalidate(_socialSettingsProvider);
      }
    });
  }

  void _save(SocialSettings Function(SocialSettings) edit) =>
      _change(edit, (SocialSettings s) => _social.saveSettings(s));

  void _setFindable(bool on) => _change(
        (SocialSettings s) => s.copyWith(findable: on),
        (SocialSettings _) => _social.setFindable(on),
      );

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<({String? username, SocialSettings settings})> async =
        ref.watch(_socialSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.socialSettingsTitle)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(l10n.inviteErrorOffline, textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.md),
                FilledButton(
                  key: const Key('social-settings-retry'),
                  onPressed: () => ref.invalidate(_socialSettingsProvider),
                  child: Text(l10n.actionRetry),
                ),
              ],
            ),
          ),
        ),
        data: (({String? username, SocialSettings settings}) data) {
          final SocialSettings s = _local ?? data.settings;
          return ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, 0, AppSpacing.md, AppSpacing.xxl),
            children: <Widget>[
              SectionHeader(l10n.socialFoundTitle),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Column(
                  children: <Widget>[
                    ListTile(
                      key: const Key('username-row'),
                      title: Text(l10n.usernameTitle),
                      subtitle: Text(data.username == null
                          ? l10n.usernameNone
                          : '@${data.username}'),
                      trailing: const Icon(Icons.edit_outlined, size: 18),
                      onTap: () => _editUsername(context, data.username),
                    ),
                    SwitchListTile(
                      key: const Key('findable-switch'),
                      value: s.findable,
                      onChanged: _setFindable,
                      title: Text(l10n.socialFindable),
                      subtitle: Text(l10n.socialFindableSub),
                    ),
                    SwitchListTile(
                      key: const Key('league-switch'),
                      value: s.leagueOptIn,
                      onChanged: (bool on) => _save(
                          (SocialSettings s) => s.copyWith(leagueOptIn: on)),
                      title: Text(l10n.socialLeague),
                      subtitle: Text(l10n.socialLeagueSub),
                    ),
                  ],
                ),
              ),
              SectionHeader(l10n.socialPushTitle,
                  subtitle: PushService.isConfigured
                      ? null
                      : l10n.socialPushNotConfigured),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Column(
                  children: <Widget>[
                    for (final (String kind, String label) in <(String, String)>[
                      ('nudge', l10n.pushNudge),
                      ('cheer', l10n.pushCheer),
                      ('friend_request', l10n.pushFriendRequest),
                      ('friend_activity', l10n.pushFriendActivity),
                    ])
                      SwitchListTile(
                        key: Key('push-$kind'),
                        value: s.notify[kind] ?? true,
                        onChanged: (bool on) => _save(
                          (SocialSettings s) => s.copyWith(
                            notify: <String, bool>{...s.notify, kind: on},
                          ),
                        ),
                        title: Text(label),
                      ),
                  ],
                ),
              ),
              SectionHeader(l10n.blockedTitle, subtitle: l10n.blockedSub),
              const _BlockedList(),
            ],
          );
        },
      ),
    );
  }

  Future<void> _editUsername(BuildContext context, String? current) async {
    final AppLocalizations l10n = context.l10n;
    final TextEditingController text = TextEditingController(text: current ?? '');
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String? entered = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(l10n.usernameTitle),
        content: TextField(
          key: const Key('username-field'),
          controller: text,
          autofocus: true,
          autocorrect: false,
          decoration: InputDecoration(prefixText: '@', helperText: l10n.usernameRules),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(text.text),
            child: Text(l10n.actionSave),
          ),
        ],
      ),
    );
    text.dispose();
    if (entered == null) return;
    try {
      await _social.setUsername(entered);
      // The switches keep what they show; only the username is new.
      ref.invalidate(_socialSettingsProvider);
    } on UsernameRejection catch (rejection) {
      messenger.showSnackBar(SnackBar(
        content: Text(rejection.problem == UsernameProblem.taken
            ? l10n.usernameTaken
            : l10n.usernameRules),
      ));
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(l10n.inviteErrorOffline)));
    }
  }
}

/// Everyone the user blocked, each with a way back.
class _BlockedList extends ConsumerWidget {
  const _BlockedList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    final AsyncValue<List<PersonResult>> async = ref.watch(_blockedProvider);

    return AppCard(
      key: const Key('blocked-list'),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      child: async.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        error: (Object error, StackTrace _) => ListTile(
          title: Text(l10n.inviteErrorOffline, style: text.bodyMedium),
          trailing: TextButton(
            onPressed: () => ref.invalidate(_blockedProvider),
            child: Text(l10n.actionRetry),
          ),
        ),
        data: (List<PersonResult> people) => people.isEmpty
            ? ListTile(
                title: Text(l10n.blockedNone,
                    style: text.bodyMedium
                        ?.copyWith(color: AppColors.textSecondary)),
              )
            : Column(
                children: <Widget>[
                  for (final PersonResult person in people)
                    ListTile(
                      key: Key('blocked-${person.userId}'),
                      leading: EmojiAvatar(person.emoji, size: 36, dimmed: true),
                      title: Text(person.displayName.isEmpty
                          ? l10n.friendsFallbackName
                          : person.displayName),
                      subtitle: person.username == null
                          ? null
                          : Text('@${person.username}'),
                      trailing: TextButton(
                        onPressed: () => _unblock(context, ref, person),
                        child: Text(l10n.blockedUnblock),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Future<void> _unblock(
    BuildContext context,
    WidgetRef ref,
    PersonResult person,
  ) async {
    final AppLocalizations l10n = context.l10n;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(repositoryProvider).social.unblockUser(person.userId);
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(l10n.inviteErrorOffline)));
      return;
    }
    ref.invalidate(_blockedProvider);
    messenger.showSnackBar(SnackBar(
      content: Text(l10n.blockedUnblocked(person.displayName.isEmpty
          ? l10n.friendsFallbackName
          : person.displayName)),
    ));
  }
}
