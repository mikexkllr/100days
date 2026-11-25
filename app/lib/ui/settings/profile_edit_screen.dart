import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../data/app_repository.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/theme.dart';
import '../widgets/app_card.dart';

/// The faces to pick from — the same as in onboarding.
const List<String> kProfileEmojis = <String>[
  '🔥', '🐺', '🦍', '🦈', '🐉', '⚡', '🗿', '🧊',
  '🦅', '🐻', '🥷', '👑', '🌱', '🚀', '🎯', '🧠',
];

/// Name, face and goal sentence after onboarding. A profile is an event
/// like everything else; saving appends a new one.
class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  late final AppSnapshot? _snapshot = ref.read(appStateProvider).valueOrNull;
  late final TextEditingController _name =
      TextEditingController(text: _snapshot?.me.profile.displayName ?? '');
  late final TextEditingController _statement = TextEditingController(
      text: _snapshot?.challenge?.goal.statement ?? '');
  late String _emoji = _snapshot?.me.profile.avatarEmoji ?? '🔥';
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _statement.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final AppSnapshot? snapshot = ref.read(appStateProvider).valueOrNull;
    final Challenge? challenge = snapshot?.challenge;
    if (snapshot == null || _name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final AppController controller = ref.read(appStateProvider.notifier);
    final String statement = _statement.text.trim();
    try {
      if (challenge != null &&
          statement.isNotEmpty &&
          statement != challenge.goal.statement) {
        await controller.updateChallenge(challenge.copyWith(
            goal: challenge.goal.copyWith(statement: statement)));
      }
      await controller.saveProfile(
        displayName: _name.text.trim(),
        avatarEmoji: _emoji,
        // The sentence sits on the public profile only when it is shared.
        goalStatement: (challenge?.sharing.shareStatement ?? false)
            ? (statement.isEmpty ? challenge!.goal.statement : statement)
            : null,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.profileSaved)));
      Navigator.of(context).pop();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.errorGeneric('$error'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileEditTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: <Widget>[
          Text(
            l10n.profileEditSub,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              EmojiAvatar(_emoji, size: 64, ringColor: AppColors.primary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: TextField(
                  key: const Key('profile-name'),
                  controller: _name,
                  maxLength: 24,
                  textCapitalization: TextCapitalization.words,
                  style: Theme.of(context).textTheme.titleLarge,
                  decoration: InputDecoration(
                    hintText: l10n.obIdentityNameHint,
                    counterText: '',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final String emoji in kProfileEmojis)
                GestureDetector(
                  onTap: () => setState(() => _emoji = emoji),
                  child: EmojiAvatar(
                    emoji,
                    size: 46,
                    ringColor: _emoji == emoji ? AppColors.primary : null,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            key: const Key('profile-statement'),
            controller: _statement,
            maxLength: 120,
            maxLines: 2,
            decoration: InputDecoration(labelText: l10n.profileStatement),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            key: const Key('profile-save'),
            onPressed:
                _saving || _name.text.trim().isEmpty ? null : _save,
            child: Text(l10n.profileSave),
          ),
        ],
      ),
    );
  }
}
