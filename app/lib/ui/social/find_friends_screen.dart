import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../data/app_repository.dart';
import '../../data/phone_numbers.dart';
import '../../data/social_backend.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/theme.dart';
import '../widgets/app_card.dart';
import 'invite_flow.dart';
import 'invite_screen.dart';

/// Reads the address book: every e-mail address and phone number (in
/// E.164, read in the phone's own region). Overridable in tests.
final Provider<Future<({List<String> emails, List<String> phones})?> Function()>
    addressBookProvider = Provider<
        Future<({List<String> emails, List<String> phones})?> Function()>(
  (Ref ref) => () async {
    final PermissionStatus status =
        await FlutterContacts.permissions.request(PermissionType.read);
    if (status != PermissionStatus.granted && status != PermissionStatus.limited) {
      return null;
    }
    final List<Contact> contacts = await FlutterContacts.getAll(
      properties: <ContactProperty>{ContactProperty.phone, ContactProperty.email},
    );
    final String region =
        PlatformDispatcher.instance.locale.countryCode ?? 'DE';
    return (
      emails: <String>{
        for (final Contact c in contacts)
          for (final Email e in c.emails) e.address.trim().toLowerCase(),
      }.toList(),
      phones: <String>{
        for (final Contact c in contacts)
          for (final Phone p in c.phones)
            if (toE164(p.normalizedNumber ?? p.number, countryCode: region)
                case final String e164)
              e164,
      }.toList(),
    );
  },
);

/// Finding friends the way people expect: search by name or @username, look
/// through the address book, or send a link.
class FindFriendsScreen extends ConsumerStatefulWidget {
  const FindFriendsScreen({super.key});

  @override
  ConsumerState<FindFriendsScreen> createState() => _FindFriendsScreenState();
}

class _FindFriendsScreenState extends ConsumerState<FindFriendsScreen> {
  final TextEditingController _query = TextEditingController();
  Timer? _debounce;
  List<PersonResult> _results = const <PersonResult>[];
  List<PersonResult>? _contacts;
  bool _searchingContacts = false;
  bool _alsoFindMe = true;
  final Set<String> _requested = <String>{};

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onQuery(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final List<PersonResult> found = text.trim().length < 2
          ? const <PersonResult>[]
          : await ref.read(repositoryProvider).social.search(text).catchError(
              (Object _) => const <PersonResult>[]);
      if (mounted) setState(() => _results = found);
    });
  }

  Future<void> _searchContacts() async {
    final AppLocalizations l10n = context.l10n;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() => _searchingContacts = true);
    try {
      final ({List<String> emails, List<String> phones})? book =
          await ref.read(addressBookProvider)();
      if (book == null) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.findContactsDenied)));
        return;
      }
      final SocialBackend social = ref.read(repositoryProvider).social;
      final List<PersonResult> matches =
          await social.matchContacts(emails: book.emails, phones: book.phones);
      if (_alsoFindMe) await social.setFindable(true);
      if (mounted) setState(() => _contacts = matches);
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(l10n.inviteErrorOffline)));
    } finally {
      if (mounted) setState(() => _searchingContacts = false);
    }
  }

  Future<void> _add(PersonResult person) async {
    setState(() => _requested.add(person.userId));
    await ref.read(appStateProvider.notifier).sendFriendRequest(person.userId);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AppSnapshot? snapshot = ref.watch(appStateProvider).valueOrNull;
    final Set<String> friends = <String>{
      for (final UserProjection f in snapshot?.friends ?? const <UserProjection>[])
        f.userId,
    };
    final Set<String> pending = <String>{
      for (final FriendLink l in snapshot?.outgoingRequests ?? const <FriendLink>[])
        l.userId,
      ..._requested,
    };

    Widget person(PersonResult p) => _PersonRow(
          person: p,
          state: friends.contains(p.userId)
              ? _Relation.friends
              : pending.contains(p.userId)
                  ? _Relation.requested
                  : _Relation.none,
          onAdd: () => _add(p),
        );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.findTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, 0, AppSpacing.md, AppSpacing.xxl),
        children: <Widget>[
          TextField(
            key: const Key('find-search'),
            controller: _query,
            onChanged: _onQuery,
            autocorrect: false,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: l10n.findSearchHint,
            ),
          ),
          for (final PersonResult p in _results) person(p),
          if (_query.text.trim().length >= 2 && _results.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(l10n.findNoResults,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textTertiary)),
            ),
          SectionHeader(l10n.findContactsTitle, subtitle: l10n.findContactsSub),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _alsoFindMe,
                  onChanged: (bool? on) => setState(() => _alsoFindMe = on ?? false),
                  title: Text(l10n.findAlsoFindMe),
                  subtitle: Text(l10n.findAlsoFindMeSub),
                ),
                FilledButton.icon(
                  key: const Key('find-contacts'),
                  onPressed: _searchingContacts ? null : _searchContacts,
                  icon: _searchingContacts
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.contacts_outlined, size: 18),
                  label: Text(l10n.findContactsAction),
                ),
              ],
            ),
          ),
          if (_contacts != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            if (_contacts!.isEmpty)
              Text(l10n.findContactsNone,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.textSecondary))
            else
              for (final PersonResult p in _contacts!) person(p),
          ],
          SectionHeader(l10n.findInviteTitle),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) => const InviteScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.ios_share, size: 18),
                  label: Text(l10n.friendsInvite),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => enterInviteCode(context, ref),
                  icon: const Icon(Icons.keyboard_outlined, size: 18),
                  label: Text(l10n.inviteEnterCode),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _Relation { none, requested, friends }

class _PersonRow extends StatelessWidget {
  const _PersonRow({
    required this.person,
    required this.state,
    required this.onAdd,
  });

  final PersonResult person;
  final _Relation state;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return ListTile(
      key: Key('person-${person.userId}'),
      contentPadding: EdgeInsets.zero,
      leading: EmojiAvatar(person.emoji, size: 40),
      title: Text(person.displayName),
      subtitle: person.username == null ? null : Text('@${person.username}'),
      trailing: switch (state) {
        _Relation.friends => Text(l10n.findAlreadyFriends,
            style: const TextStyle(color: AppColors.success)),
        _Relation.requested => Text(l10n.findRequested,
            style: const TextStyle(color: AppColors.textSecondary)),
        _Relation.none => FilledButton(
            onPressed: onAdd,
            style: FilledButton.styleFrom(minimumSize: const Size(80, 36)),
            child: Text(l10n.findAdd),
          ),
      },
    );
  }
}
