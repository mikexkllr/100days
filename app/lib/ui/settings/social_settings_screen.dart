import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/push_service.dart';
import '../../data/social_backend.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/theme.dart';
import '../widgets/app_card.dart';

final FutureProvider<({String? username, SocialSettings settings})>
    _socialSettingsProvider =
    FutureProvider<({String? username, SocialSettings settings})>(
        (Ref ref) async {
  final SocialBackend social = ref.watch(repositoryProvider).social;
  return (username: await social.username(), settings: await social.settings());
});

/// Being found and being told: username, address-book matching, the public
/// league, and which pushes arrive.
class SocialSettingsScreen extends ConsumerWidget {
  const SocialSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<({String? username, SocialSettings settings})> async =
        ref.watch(_socialSettingsProvider);
    final SocialBackend social = ref.watch(repositoryProvider).social;

    Future<void> save(SocialSettings settings) async {
      await social.saveSettings(settings);
      ref.invalidate(_socialSettingsProvider);
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.socialSettingsTitle)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace _) =>
            Center(child: Text(l10n.inviteErrorOffline)),
        data: (({String? username, SocialSettings settings}) data) {
          final SocialSettings s = data.settings;
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
                      onTap: () => _editUsername(context, ref, data.username),
                    ),
                    SwitchListTile(
                      key: const Key('findable-switch'),
                      value: s.findable,
                      onChanged: (bool on) async {
                        await social.setFindable(on);
                        ref.invalidate(_socialSettingsProvider);
                      },
                      title: Text(l10n.socialFindable),
                      subtitle: Text(l10n.socialFindableSub),
                    ),
                    SwitchListTile(
                      value: s.leagueOptIn,
                      onChanged: (bool on) => save(s.copyWith(leagueOptIn: on)),
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
                        value: s.notify[kind] ?? true,
                        onChanged: (bool on) => save(s.copyWith(
                          notify: <String, bool>{...s.notify, kind: on},
                        )),
                        title: Text(label),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _editUsername(
      BuildContext context, WidgetRef ref, String? current) async {
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
      await ref.read(repositoryProvider).social.setUsername(entered);
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
