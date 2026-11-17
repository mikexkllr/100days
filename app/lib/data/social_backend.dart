import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Where a friendship stands, seen from the signed-in user.
enum FriendStatus {
  /// Accepted: both see each other's shared events.
  friends,

  /// They asked, the user has not answered yet.
  incoming,

  /// The user asked, they have not answered yet.
  outgoing,
}

/// Someone the user is, or might become, friends with.
class FriendLink {
  const FriendLink({
    required this.userId,
    required this.displayName,
    required this.emoji,
    required this.status,
    this.since,
  });

  final String userId;
  final String displayName;
  final String emoji;
  final FriendStatus status;
  final DateTime? since;
}

/// Who an invite code belongs to, shown before the user redeems it.
class InvitePreview {
  const InvitePreview({
    required this.userId,
    required this.displayName,
    required this.emoji,
  });

  final String userId;
  final String displayName;
  final String emoji;
}

/// Why redeeming an invite did not work.
enum InviteProblem { invalid, self, offline }

class InviteRejection implements Exception {
  const InviteRejection(this.problem);

  final InviteProblem problem;

  @override
  String toString() => 'InviteRejection(${problem.name})';
}

/// Someone found by search or in the address book.
class PersonResult {
  const PersonResult({
    required this.userId,
    required this.displayName,
    required this.emoji,
    this.username,
  });

  final String userId;
  final String displayName;
  final String emoji;
  final String? username;
}

/// Why a username was not taken.
enum UsernameProblem { invalid, taken }

class UsernameRejection implements Exception {
  const UsernameRejection(this.problem);
  final UsernameProblem problem;
}

/// What the user decides about being found and being notified.
class SocialSettings {
  const SocialSettings({
    this.findable = false,
    this.leagueOptIn = true,
    this.language = 'de',
    this.notify = const <String, bool>{
      'nudge': true,
      'cheer': true,
      'friend_request': true,
      'friend_activity': true,
    },
  });

  final bool findable;
  final bool leagueOptIn;
  final String language;
  final Map<String, bool> notify;

  SocialSettings copyWith({
    bool? leagueOptIn,
    String? language,
    Map<String, bool>? notify,
  }) =>
      SocialSettings(
        findable: findable,
        leagueOptIn: leagueOptIn ?? this.leagueOptIn,
        language: language ?? this.language,
        notify: notify ?? this.notify,
      );
}

/// One row of the weekly league group.
class GlobalLeagueRow {
  const GlobalLeagueRow({
    required this.userId,
    required this.displayName,
    required this.emoji,
    required this.xp,
    required this.rank,
  });

  final String userId;
  final String displayName;
  final String emoji;
  final int xp;
  final int rank;
}

class GlobalLeague {
  const GlobalLeague({required this.division, required this.rows});

  /// Index into hundred_core's League enum.
  final int division;
  final List<GlobalLeagueRow> rows;
}

/// The username rule the server enforces: 3–20 of a–z, 0–9 and _.
bool isValidUsername(String name) =>
    RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(name);

/// The server side of friends and profiles. The rules — who may befriend
/// whom, which invite is still valid — live in the database functions of
/// `supabase/migrations`; this is the thin client for them.
abstract class SocialBackend {
  /// Accepted friends and open requests in both directions.
  Future<List<FriendLink>> friendships();

  /// Fires when a friendship of the user changes on the server.
  Stream<void> get changes;

  Future<String> myInviteCode();

  /// Invalidates every invite code the user handed out.
  Future<void> revokeInviteCodes();

  /// Null when the code is unknown, used up, expired or revoked.
  Future<InvitePreview?> previewInvite(String code);

  /// Makes the user and the code's owner friends. Returns the owner's id.
  /// Throws [InviteRejection].
  Future<String> redeemInvite(String code);

  /// True when this made them friends straight away (they had asked too).
  Future<bool> sendFriendRequest(String userId);

  Future<void> respondToRequest(String requesterId, {required bool accept});

  Future<void> removeFriend(String userId);

  /// The name and emoji everyone else sees, e.g. in a friend request.
  Future<void> updateProfile({
    required String displayName,
    required String emoji,
  });

  /// The user's own username, or null.
  Future<String?> username();

  /// Sets or clears the username. Throws [UsernameRejection].
  Future<void> setUsername(String? username);

  /// People with a username, by its start or their name.
  Future<List<PersonResult>> search(String query);

  /// Who of these contacts uses the app and wants to be found.
  Future<List<PersonResult>> matchContacts({
    required List<String> emails,
    required List<String> phones,
  });

  /// Lets people who have the user's verified e-mail or phone in their
  /// contacts find them — or stops it.
  Future<void> setFindable(bool findable);

  Future<SocialSettings> settings();
  Future<void> saveSettings(SocialSettings settings);

  /// The user's XP this week for the public league.
  Future<void> reportWeekXp(String week, int xp);

  /// The user's league group this week, or null before the first report.
  Future<GlobalLeague?> league(String week);

  Future<void> registerPushToken(String token, {required String platform});

  /// Asks the server to tell the friends an event concerns, or the person a
  /// request went to. Best effort: a missed push is not an error.
  Future<void> notify({String? eventId, String? friendRequestTo});

  Future<void> dispose();
}

/// [SocialBackend] on Supabase.
class SupabaseSocialBackend implements SocialBackend {
  SupabaseSocialBackend(this._client, {required this.userId});

  final SupabaseClient _client;
  final String userId;
  final StreamController<void> _changes = StreamController<void>.broadcast();
  RealtimeChannel? _channel;

  @override
  Stream<void> get changes {
    _channel ??= _client
        .channel('friendships:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'friendships',
          callback: (PostgresChangePayload _) => _changes.add(null),
        )
        .subscribe();
    return _changes.stream;
  }

  @override
  Future<List<FriendLink>> friendships() async {
    final List<Map<String, dynamic>> rows =
        await _client.from('friendships').select();
    if (rows.isEmpty) return const <FriendLink>[];

    final Map<String, Map<String, dynamic>> byOther =
        <String, Map<String, dynamic>>{
      for (final Map<String, dynamic> row in rows)
        (row['requester'] == userId ? row['addressee'] : row['requester'])
            as String: row,
    };
    final List<Map<String, dynamic>> profiles = await _client
        .from('profiles')
        .select('id, display_name, emoji')
        .inFilter('id', byOther.keys.toList());
    final Map<String, Map<String, dynamic>> profileById =
        <String, Map<String, dynamic>>{
      for (final Map<String, dynamic> p in profiles) p['id'] as String: p,
    };

    return <FriendLink>[
      for (final MapEntry<String, Map<String, dynamic>> e in byOther.entries)
        FriendLink(
          userId: e.key,
          displayName:
              (profileById[e.key]?['display_name'] as String?) ?? '',
          emoji: (profileById[e.key]?['emoji'] as String?) ?? '🙂',
          status: e.value['status'] == 'accepted'
              ? FriendStatus.friends
              : e.value['requester'] == userId
                  ? FriendStatus.outgoing
                  : FriendStatus.incoming,
          since: DateTime.tryParse(
              (e.value['responded_at'] ?? e.value['created_at']) as String? ??
                  ''),
        ),
    ];
  }

  @override
  Future<String> myInviteCode() async =>
      await _client.rpc('my_invite_code') as String;

  @override
  Future<void> revokeInviteCodes() => _client.rpc('revoke_invite_codes');

  @override
  Future<InvitePreview?> previewInvite(String code) async {
    final Object? result =
        await _client.rpc('invite_preview', params: <String, dynamic>{
      'p_code': normalizeInviteCode(code),
    });
    if (result is! List || result.isEmpty) return null;
    final Map<String, dynamic> row = Map<String, dynamic>.from(result.first as Map);
    return InvitePreview(
      userId: row['user_id'] as String,
      displayName: row['display_name'] as String? ?? '',
      emoji: row['emoji'] as String? ?? '🙂',
    );
  }

  @override
  Future<String> redeemInvite(String code) async {
    try {
      final String owner = await _client.rpc('redeem_invite',
          params: <String, dynamic>{'p_code': normalizeInviteCode(code)}) as String;
      if (owner == userId) throw const InviteRejection(InviteProblem.self);
      return owner;
    } on PostgrestException catch (error) {
      if (error.code == 'P0002') {
        throw const InviteRejection(InviteProblem.invalid);
      }
      rethrow;
    }
  }

  @override
  Future<bool> sendFriendRequest(String otherId) async =>
      await _client.rpc('send_friend_request',
          params: <String, dynamic>{'p_target': otherId}) ==
      'accepted';

  @override
  Future<void> respondToRequest(String requesterId, {required bool accept}) =>
      _client.rpc('respond_friend_request', params: <String, dynamic>{
        'p_requester': requesterId,
        'p_accept': accept,
      });

  @override
  Future<void> removeFriend(String otherId) => _client
      .rpc('remove_friend', params: <String, dynamic>{'p_other': otherId});

  @override
  Future<void> updateProfile({
    required String displayName,
    required String emoji,
  }) =>
      _client.from('profiles').update(<String, dynamic>{
        'display_name': displayName,
        'emoji': emoji,
      }).eq('id', userId);

  @override
  Future<String?> username() async {
    final Map<String, dynamic>? row = await _client
        .from('profiles')
        .select('username')
        .eq('id', userId)
        .maybeSingle();
    return row?['username'] as String?;
  }

  @override
  Future<void> setUsername(String? name) async {
    final String? clean = name?.trim().toLowerCase();
    if (clean != null && clean.isNotEmpty && !isValidUsername(clean)) {
      throw const UsernameRejection(UsernameProblem.invalid);
    }
    try {
      await _client.from('profiles').update(<String, dynamic>{
        'username': clean == null || clean.isEmpty ? null : clean,
      }).eq('id', userId);
    } on PostgrestException catch (error) {
      if (error.code == '23505') {
        throw const UsernameRejection(UsernameProblem.taken);
      }
      if (error.code == '23514') {
        throw const UsernameRejection(UsernameProblem.invalid);
      }
      rethrow;
    }
  }

  @override
  Future<List<PersonResult>> search(String query) async {
    final Object? rows = await _client
        .rpc('search_profiles', params: <String, dynamic>{'p_query': query});
    return <PersonResult>[
      for (final Object? r in rows is List ? rows : const <Object?>[])
        if (r is Map)
          PersonResult(
            userId: r['user_id'] as String,
            displayName: r['display_name'] as String? ?? '',
            emoji: r['emoji'] as String? ?? '🙂',
            username: r['username'] as String?,
          ),
    ];
  }

  @override
  Future<List<PersonResult>> matchContacts({
    required List<String> emails,
    required List<String> phones,
  }) async {
    final FunctionResponse response = await _client.functions.invoke(
      'match-contacts',
      body: <String, dynamic>{
        'action': 'match',
        'emails': emails,
        'phones': phones,
      },
    );
    final Object? matches = (response.data as Map?)?['matches'];
    return <PersonResult>[
      for (final Object? m in matches is List ? matches : const <Object?>[])
        if (m is Map)
          PersonResult(
            userId: m['userId'] as String,
            displayName: m['displayName'] as String? ?? '',
            emoji: m['emoji'] as String? ?? '🙂',
            username: m['username'] as String?,
          ),
    ];
  }

  @override
  Future<void> setFindable(bool findable) => _client.functions.invoke(
        'match-contacts',
        body: <String, dynamic>{
          'action': findable ? 'register' : 'unregister',
        },
      );

  @override
  Future<SocialSettings> settings() async {
    final Map<String, dynamic>? row = await _client
        .from('user_settings')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) return const SocialSettings();
    return SocialSettings(
      findable: row['discoverable'] as bool? ?? false,
      leagueOptIn: row['league_opt_in'] as bool? ?? true,
      language: row['language'] as String? ?? 'de',
      notify: <String, bool>{
        for (final MapEntry<String, dynamic> e
            in ((row['notify'] as Map?) ?? const <String, dynamic>{})
                .cast<String, dynamic>()
                .entries)
          e.key: e.value == true,
      },
    );
  }

  @override
  Future<void> saveSettings(SocialSettings settings) =>
      _client.from('user_settings').upsert(<String, dynamic>{
        'user_id': userId,
        'league_opt_in': settings.leagueOptIn,
        'language': settings.language,
        'notify': settings.notify,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

  @override
  Future<void> reportWeekXp(String week, int xp) => _client.rpc(
        'report_week_xp',
        params: <String, dynamic>{'p_week': week, 'p_xp': xp},
      );

  @override
  Future<GlobalLeague?> league(String week) async {
    final Object? rows = await _client
        .rpc('league_standing', params: <String, dynamic>{'p_week': week});
    if (rows is! List || rows.isEmpty) return null;
    return GlobalLeague(
      division: ((rows.first as Map)['division'] as num?)?.toInt() ?? 1,
      rows: <GlobalLeagueRow>[
        for (final Object? r in rows)
          if (r is Map)
            GlobalLeagueRow(
              userId: r['user_id'] as String,
              displayName: r['display_name'] as String? ?? '',
              emoji: r['emoji'] as String? ?? '🙂',
              xp: (r['xp'] as num?)?.toInt() ?? 0,
              rank: (r['rank'] as num?)?.toInt() ?? 0,
            ),
      ],
    );
  }

  @override
  Future<void> registerPushToken(String token, {required String platform}) =>
      _client.from('push_tokens').upsert(<String, dynamic>{
        'token': token,
        'user_id': userId,
        'platform': platform,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

  @override
  Future<void> notify({String? eventId, String? friendRequestTo}) async {
    try {
      await _client.functions.invoke('push', body: <String, dynamic>{
        if (eventId != null) 'eventId': eventId,
        if (friendRequestTo != null) 'friendRequestTo': friendRequestTo,
      });
    } on Object {
      // Push is a courtesy; the event itself is already shared.
    }
  }

  @override
  Future<void> dispose() async {
    final RealtimeChannel? channel = _channel;
    _channel = null;
    if (channel != null) await _client.removeChannel(channel);
    await _changes.close();
  }
}

/// An in-memory [SocialBackend]: for tests, and for running the app's
/// screens without a server.
class MemorySocialBackend implements SocialBackend {
  MemorySocialBackend({this.userId = 'me'});

  final String userId;
  final Map<String, FriendLink> _links = <String, FriendLink>{};
  final Map<String, InvitePreview> invites = <String, InvitePreview>{};
  final StreamController<void> _changes = StreamController<void>.broadcast();
  String displayName = '';
  String emoji = '🙂';

  /// Test hook: someone becomes a friend (or sends a request).
  void link(FriendLink friend) {
    _links[friend.userId] = friend;
    _changes.add(null);
  }

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<List<FriendLink>> friendships() async => _links.values.toList();

  @override
  Future<String> myInviteCode() async => 'TESTCODE42';

  @override
  Future<void> revokeInviteCodes() async {}

  @override
  Future<InvitePreview?> previewInvite(String code) async =>
      invites[normalizeInviteCode(code)];

  @override
  Future<String> redeemInvite(String code) async {
    final InvitePreview? preview = invites[normalizeInviteCode(code)];
    if (preview == null) throw const InviteRejection(InviteProblem.invalid);
    if (preview.userId == userId) {
      throw const InviteRejection(InviteProblem.self);
    }
    link(FriendLink(
      userId: preview.userId,
      displayName: preview.displayName,
      emoji: preview.emoji,
      status: FriendStatus.friends,
    ));
    return preview.userId;
  }

  @override
  Future<bool> sendFriendRequest(String otherId) async {
    final FriendLink? existing = _links[otherId];
    if (existing?.status == FriendStatus.incoming) {
      link(_withStatus(existing!, FriendStatus.friends));
      return true;
    }
    link(FriendLink(
      userId: otherId,
      displayName: existing?.displayName ?? '',
      emoji: existing?.emoji ?? '🙂',
      status: existing?.status ?? FriendStatus.outgoing,
    ));
    return existing?.status == FriendStatus.friends;
  }

  @override
  Future<void> respondToRequest(String requesterId, {required bool accept}) async {
    final FriendLink? existing = _links[requesterId];
    if (existing == null || existing.status != FriendStatus.incoming) return;
    if (accept) {
      link(_withStatus(existing, FriendStatus.friends));
    } else {
      _links.remove(requesterId);
      _changes.add(null);
    }
  }

  @override
  Future<void> removeFriend(String otherId) async {
    _links.remove(otherId);
    _changes.add(null);
  }

  @override
  Future<void> updateProfile({
    required String displayName,
    required String emoji,
  }) async {
    this.displayName = displayName;
    this.emoji = emoji;
  }

  String? _username;
  SocialSettings _settings = const SocialSettings();

  /// Test hooks.
  final List<PersonResult> people = <PersonResult>[];
  final Map<String, int> reportedXp = <String, int>{};
  final List<String> notified = <String>[];

  @override
  Future<String?> username() async => _username;

  @override
  Future<void> setUsername(String? name) async {
    final String? clean = name?.trim().toLowerCase();
    if (clean != null && clean.isNotEmpty && !isValidUsername(clean)) {
      throw const UsernameRejection(UsernameProblem.invalid);
    }
    if (people.any((PersonResult p) => p.username == clean)) {
      throw const UsernameRejection(UsernameProblem.taken);
    }
    _username = clean == null || clean.isEmpty ? null : clean;
  }

  @override
  Future<List<PersonResult>> search(String query) async {
    final String q = query.trim().toLowerCase().replaceFirst('@', '');
    if (q.length < 2) return const <PersonResult>[];
    return people
        .where((PersonResult p) =>
            (p.username?.startsWith(q) ?? false) ||
            p.displayName.toLowerCase().startsWith(q))
        .toList();
  }

  @override
  Future<List<PersonResult>> matchContacts({
    required List<String> emails,
    required List<String> phones,
  }) async =>
      people;

  @override
  Future<void> setFindable(bool findable) async {
    _settings = SocialSettings(
      findable: findable,
      leagueOptIn: _settings.leagueOptIn,
      language: _settings.language,
      notify: _settings.notify,
    );
  }

  @override
  Future<SocialSettings> settings() async => _settings;

  @override
  Future<void> saveSettings(SocialSettings settings) async =>
      _settings = settings;

  @override
  Future<void> reportWeekXp(String week, int xp) async =>
      reportedXp[week] = xp;

  @override
  Future<GlobalLeague?> league(String week) async => reportedXp[week] == null
      ? null
      : GlobalLeague(division: 1, rows: <GlobalLeagueRow>[
          GlobalLeagueRow(
            userId: userId,
            displayName: displayName,
            emoji: emoji,
            xp: reportedXp[week]!,
            rank: 1,
          ),
        ]);

  @override
  Future<void> registerPushToken(String token, {required String platform}) async {}

  @override
  Future<void> notify({String? eventId, String? friendRequestTo}) async =>
      notified.add(eventId ?? 'request:$friendRequestTo');

  @override
  Future<void> dispose() async => _changes.close();

  FriendLink _withStatus(FriendLink link, FriendStatus status) => FriendLink(
        userId: link.userId,
        displayName: link.displayName,
        emoji: link.emoji,
        status: status,
        since: DateTime.now(),
      );
}

/// Invite codes are typed, read aloud and scanned: accept them in any case,
/// with spaces or dashes, or as a whole link.
String normalizeInviteCode(String input) {
  var code = input.trim();
  final Uri? uri = Uri.tryParse(code);
  if (uri != null && uri.hasScheme) {
    code = uri.pathSegments.isNotEmpty
        ? uri.pathSegments.last
        : (uri.queryParameters['code'] ?? uri.host);
  }
  return code.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
}

/// The link a QR code and the share sheet carry.
Uri inviteLink(String code) => Uri.parse('hundreddays://invite/$code');
