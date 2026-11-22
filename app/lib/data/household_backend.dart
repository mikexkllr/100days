import 'dart:async';

import 'package:hundred_core/hundred_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Someone in the household.
class HouseholdMember {
  const HouseholdMember({
    required this.userId,
    required this.displayName,
    required this.emoji,
    this.owner = false,
    this.shareTargets = false,
    this.kcalTarget,
    this.proteinG,
    this.diet,
    this.dislikes = const <String>[],
    this.allergies = const <String>[],
  });

  final String userId;
  final String displayName;
  final String emoji;
  final bool owner;

  /// Whether this member lets the household see their targets — needed for
  /// portions that fit them. The server deletes the numbers when it is off.
  final bool shareTargets;
  final int? kcalTarget;
  final int? proteinG;
  final String? diet;
  final List<String> dislikes;
  final List<String> allergies;

  /// This member with [kcal] and [protein] as the shared targets.
  HouseholdMember withTargets({required bool share, int? kcal, int? protein}) =>
      HouseholdMember(
        userId: userId,
        displayName: displayName,
        emoji: emoji,
        owner: owner,
        shareTargets: share,
        kcalTarget: share ? kcal : null,
        proteinG: share ? protein : null,
        diet: diet,
        dislikes: dislikes,
        allergies: allergies,
      );

  PlanFor toPlanFor() => PlanFor(
        name: displayName,
        dailyKcal: shareTargets ? kcalTarget : null,
        proteinG: shareTargets ? proteinG : null,
        dislikes: dislikes,
        allergies: allergies,
        diet: diet,
      );

  Map<String, dynamic> preferencesJson() => <String, dynamic>{
        if (diet != null && diet!.isNotEmpty) 'diet': diet,
        'dislikes': dislikes,
        'allergies': allergies,
      };
}

class Household {
  const Household({
    required this.id,
    required this.name,
    required this.cadence,
    required this.members,
    this.pantry = const <String>[],
  });

  final String id;
  final String name;
  final ShoppingCadence cadence;
  final List<HouseholdMember> members;

  /// Things usually at home, left off generated lists.
  final List<String> pantry;

  HouseholdMember? member(String userId) {
    for (final HouseholdMember m in members) {
      if (m.userId == userId) return m;
    }
    return null;
  }
}

class HouseholdInvitePreview {
  const HouseholdInvitePreview({
    required this.householdId,
    required this.name,
    required this.memberNames,
  });

  final String householdId;
  final String name;
  final List<String> memberNames;
}

class ShoppingListInfo {
  const ShoppingListInfo({
    required this.id,
    required this.title,
    required this.period,
    this.done = false,
  });

  final String id;
  final String title;
  final ShoppingPeriod period;
  final bool done;
}

/// One line of a shopping list as stored — ticked off live by everyone.
class ShoppingLine {
  const ShoppingLine({
    required this.id,
    required this.listId,
    required this.name,
    required this.category,
    this.quantity,
    this.checked = false,
    this.checkedBy,
    this.recipeIds = const <String>[],
  });

  final String id;
  final String listId;
  final String name;
  final ShopCategory category;
  final Quantity? quantity;
  final bool checked;
  final String? checkedBy;
  final List<String> recipeIds;

  /// This line ticked by [by], or unticked — what the list shows before
  /// the server has confirmed it.
  ShoppingLine ticked(bool on, {String? by}) => ShoppingLine(
        id: id,
        listId: listId,
        name: name,
        category: category,
        quantity: quantity,
        checked: on,
        checkedBy: on ? by : null,
        recipeIds: recipeIds,
      );
}

/// The server side of households. Rules — who may see and change what —
/// live in the database policies (`supabase/migrations/*_households.sql`).
abstract class HouseholdBackend {
  /// The user's household, created on first use: someone living alone has a
  /// household of one.
  Future<String> ensureHousehold();

  Future<Household> household(String householdId);

  Future<void> updateHousehold(
    String householdId, {
    String? name,
    ShoppingCadence? cadence,
    List<String>? pantry,
  });

  /// The user's own row: whether targets are shared, the targets, tastes.
  Future<void> updateMembership(String householdId, HouseholdMember me);

  Future<String> inviteCode(String householdId);
  Future<HouseholdInvitePreview?> previewInvite(String code);

  /// Joins the household behind [code]. Returns its id.
  Future<String> join(String code);

  /// Takes the user out of [householdId]. The server hands ownership on to
  /// whoever has been in it longest; the plan and the lists stay with the
  /// others. The user's next household is their previous one, or a new one.
  Future<void> leave(String householdId);

  Future<void> removeMember(String householdId, String userId);

  Future<Map<String, Recipe>> recipes(String householdId);

  /// Stores [recipe] (its id included). Returns it as stored.
  Future<Recipe> saveRecipe(String householdId, Recipe recipe, {bool fromAi = false});

  Future<List<PlanEntry>> plan(String householdId, DayKey from, DayKey to);
  Future<void> saveEntry(String householdId, PlanEntry entry);
  Future<void> removeEntry(String entryId);

  Future<List<ShoppingListInfo>> openLists(String householdId);
  Future<ShoppingListInfo> createList(String householdId, ShoppingPeriod period, {String title = ''});
  Future<void> closeList(String listId);
  Future<List<ShoppingLine>> items(String listId);

  /// Returns the lines as stored, so an undo can take exactly these away.
  Future<List<ShoppingLine>> addItems(String householdId, String listId, List<ShoppingItem> items);
  Future<void> setChecked(String itemId, {required bool checked});
  Future<void> removeItem(String itemId);

  /// Moves items to another list of the same household — "next time".
  Future<void> moveItems(List<String> itemIds, String toListId);

  /// Fires on every change anyone in the household makes — the user's own
  /// included, as soon as the write is through rather than when its echo
  /// comes back.
  Stream<void> changes(String householdId);

  Future<void> dispose();
}

/// How long a burst of realtime events is gathered into one more tick.
const Duration kHouseholdTickWindow = Duration(milliseconds: 300);

/// The household tables a phone shows rows of, and so hears about.
const List<String> _rowTables = <String>[
  'meal_plan_entries',
  'shopping_lists',
  'shopping_items',
  'recipes',
];

/// Every tick reloads the plan and the list, and realtime delivers in
/// bursts: a list from the plan is twenty inserts. The first event of a
/// burst goes out at once, the rest as a single tick at its end.
class _Ticks {
  final StreamController<void> _out = StreamController<void>.broadcast();
  Timer? _window;
  bool _pending = false;

  Stream<void> get stream => _out.stream;

  void add() {
    if (_out.isClosed) return;
    if (_window != null) {
      _pending = true;
      return;
    }
    _out.add(null);
    _window = Timer(kHouseholdTickWindow, () {
      _window = null;
      if (_pending) {
        _pending = false;
        add();
      }
    });
  }

  Future<void> close() async {
    _window?.cancel();
    await _out.close();
  }
}

/// [HouseholdBackend] on Supabase.
class SupabaseHouseholdBackend implements HouseholdBackend {
  SupabaseHouseholdBackend(this._client, {required this.userId});

  final SupabaseClient _client;
  final String userId;
  final Map<String, List<RealtimeChannel>> _channels =
      <String, List<RealtimeChannel>>{};
  final Map<String, _Ticks> _ticks = <String, _Ticks>{};

  /// Ids of the rows this phone has shown. Realtime cannot filter deletes
  /// by household, so it hears every household's; only these are ours.
  final Set<String> _known = <String>{};

  /// A write of the user's own went through: tell the screens now, not
  /// when realtime echoes it — on a shop's bad reception that can be never.
  void _touched() {
    for (final _Ticks ticks in _ticks.values) {
      ticks.add();
    }
  }

  void _saw(Iterable<Map<String, dynamic>> rows) {
    for (final Map<String, dynamic> row in rows) {
      if (row['id'] case final String id) _known.add(id);
    }
  }

  @override
  Future<String> ensureHousehold() async {
    final List<Map<String, dynamic>> rows = await _client
        .from('household_members')
        .select('household_id, joined_at')
        .eq('user_id', userId)
        .order('joined_at', ascending: false)
        .limit(1);
    if (rows.isNotEmpty) return rows.first['household_id'] as String;
    return await _client.rpc('create_household') as String;
  }

  @override
  Future<Household> household(String householdId) async {
    final Map<String, dynamic> row = await _client
        .from('households')
        .select('id, name, cadence, pantry')
        .eq('id', householdId)
        .single();
    final List<Map<String, dynamic>> members = await _client
        .from('household_members')
        .select()
        .eq('household_id', householdId)
        .order('joined_at');
    final List<Map<String, dynamic>> profiles = members.isEmpty
        ? const <Map<String, dynamic>>[]
        : await _client.from('profiles').select('id, display_name, emoji').inFilter(
            'id', members.map((Map<String, dynamic> m) => m['user_id']).toList());
    final Map<String, Map<String, dynamic>> byId = <String, Map<String, dynamic>>{
      for (final Map<String, dynamic> p in profiles) p['id'] as String: p,
    };
    return Household(
      id: row['id'] as String,
      name: row['name'] as String? ?? '',
      cadence: ShoppingCadence.fromJson(
          Map<String, dynamic>.from(row['cadence'] as Map? ?? const <String, dynamic>{})),
      pantry: ((row['pantry'] as List?) ?? const <Object?>[]).whereType<String>().toList(),
      members: <HouseholdMember>[
        for (final Map<String, dynamic> m in members)
          _member(m, byId[m['user_id'] as String]),
      ],
    );
  }

  HouseholdMember _member(Map<String, dynamic> m, Map<String, dynamic>? profile) {
    final Map<String, dynamic> prefs =
        Map<String, dynamic>.from(m['preferences'] as Map? ?? const <String, dynamic>{});
    List<String> strings(Object? value) =>
        ((value as List?) ?? const <Object?>[]).whereType<String>().toList();
    return HouseholdMember(
      userId: m['user_id'] as String,
      displayName: profile?['display_name'] as String? ?? '',
      emoji: profile?['emoji'] as String? ?? '🙂',
      owner: m['role'] == 'owner',
      shareTargets: m['share_targets'] as bool? ?? false,
      kcalTarget: (m['kcal_target'] as num?)?.toInt(),
      proteinG: (m['protein_g'] as num?)?.toInt(),
      diet: prefs['diet'] as String?,
      dislikes: strings(prefs['dislikes']),
      allergies: strings(prefs['allergies']),
    );
  }

  @override
  Future<void> updateHousehold(
    String householdId, {
    String? name,
    ShoppingCadence? cadence,
    List<String>? pantry,
  }) async {
    await _client.from('households').update(<String, dynamic>{
      if (name != null) 'name': name,
      if (cadence != null) 'cadence': cadence.toJson(),
      if (pantry != null) 'pantry': pantry,
    }).eq('id', householdId);
    _touched();
  }

  @override
  Future<void> updateMembership(String householdId, HouseholdMember me) async {
    await _client
        .from('household_members')
        .update(<String, dynamic>{
          'share_targets': me.shareTargets,
          'kcal_target': me.shareTargets ? me.kcalTarget : null,
          'protein_g': me.shareTargets ? me.proteinG : null,
          'preferences': me.preferencesJson(),
        })
        .eq('household_id', householdId)
        .eq('user_id', userId);
    _touched();
  }

  @override
  Future<String> inviteCode(String householdId) async => await _client.rpc(
      'household_invite_code',
      params: <String, dynamic>{'p_household': householdId}) as String;

  @override
  Future<HouseholdInvitePreview?> previewInvite(String code) async {
    final Object? result = await _client.rpc('household_invite_preview',
        params: <String, dynamic>{'p_code': _normalize(code)});
    if (result is! List || result.isEmpty) return null;
    final Map<String, dynamic> row = Map<String, dynamic>.from(result.first as Map);
    return HouseholdInvitePreview(
      householdId: row['household_id'] as String,
      name: row['name'] as String? ?? '',
      memberNames: <String>[
        for (final Object? m in (row['members'] as List?) ?? const <Object?>[])
          if (m is Map) '${m['emoji'] ?? ''} ${m['name'] ?? ''}'.trim(),
      ],
    );
  }

  @override
  Future<String> join(String code) async => await _client.rpc('join_household',
      params: <String, dynamic>{'p_code': _normalize(code)}) as String;

  @override
  Future<void> leave(String householdId) async {
    try {
      await _client.rpc('leave_household',
          params: <String, dynamic>{'p_household': householdId});
    } on PostgrestException catch (error) {
      // A server without the function yet: a member may still delete
      // their own row. An owner may not — nobody would be left to hand
      // the household to.
      if (error.code != 'PGRST202' && error.code != '42883') rethrow;
      final Household current = await household(householdId);
      if (current.member(userId)?.owner ?? true) rethrow;
      await removeMember(householdId, userId);
    }
    _touched();
  }

  @override
  Future<void> removeMember(String householdId, String memberId) async {
    await _client
        .from('household_members')
        .delete()
        .eq('household_id', householdId)
        .eq('user_id', memberId);
    _touched();
  }

  @override
  Future<Map<String, Recipe>> recipes(String householdId) async {
    final List<Map<String, dynamic>> rows =
        await _client.from('recipes').select().eq('household_id', householdId);
    _saw(rows);
    return <String, Recipe>{
      for (final Map<String, dynamic> row in rows) row['id'] as String: Recipe.fromJson(row),
    };
  }

  @override
  Future<Recipe> saveRecipe(String householdId, Recipe recipe, {bool fromAi = false}) async {
    final Map<String, dynamic> row = await _client
        .from('recipes')
        .upsert(<String, dynamic>{
          ...recipe.toJson(),
          'household_id': householdId,
          'source': fromAi ? 'ai' : 'manual',
          'created_by': userId,
        })
        .select()
        .single();
    _saw(<Map<String, dynamic>>[row]);
    _touched();
    return Recipe.fromJson(row);
  }

  @override
  Future<List<PlanEntry>> plan(String householdId, DayKey from, DayKey to) async {
    final List<Map<String, dynamic>> rows = await _client
        .from('meal_plan_entries')
        .select()
        .eq('household_id', householdId)
        .gte('day', from.toString())
        .lte('day', to.toString());
    _saw(rows);
    return rows.map(PlanEntry.fromJson).toList();
  }

  @override
  Future<void> saveEntry(String householdId, PlanEntry entry) async {
    await _client.from('meal_plan_entries').upsert(<String, dynamic>{
      ...entry.toJson(),
      'household_id': householdId,
      'created_by': userId,
    });
    _known.add(entry.id);
    _touched();
  }

  @override
  Future<void> removeEntry(String entryId) async {
    await _client.from('meal_plan_entries').delete().eq('id', entryId);
    _touched();
  }

  @override
  Future<List<ShoppingListInfo>> openLists(String householdId) async {
    final List<Map<String, dynamic>> rows = await _client
        .from('shopping_lists')
        .select()
        .eq('household_id', householdId)
        .eq('status', 'open')
        .order('period_start');
    _saw(rows);
    return rows.map(_list).toList();
  }

  ShoppingListInfo _list(Map<String, dynamic> row) => ShoppingListInfo(
        id: row['id'] as String,
        title: row['title'] as String? ?? '',
        period: ShoppingPeriod(
          DayKey.parse(row['period_start'] as String),
          DayKey.parse(row['period_end'] as String),
        ),
        done: row['status'] == 'done',
      );

  @override
  Future<ShoppingListInfo> createList(String householdId, ShoppingPeriod period,
      {String title = ''}) async {
    final Map<String, dynamic> row = await _client
        .from('shopping_lists')
        .insert(<String, dynamic>{
          'household_id': householdId,
          'title': title,
          'period_start': period.start.toString(),
          'period_end': period.end.toString(),
          'created_by': userId,
        })
        .select()
        .single();
    _saw(<Map<String, dynamic>>[row]);
    _touched();
    return _list(row);
  }

  @override
  Future<void> closeList(String listId) async {
    await _client
        .from('shopping_lists')
        .update(<String, dynamic>{'status': 'done'}).eq('id', listId);
    _touched();
  }

  @override
  Future<List<ShoppingLine>> items(String listId) async {
    final List<Map<String, dynamic>> rows =
        await _client.from('shopping_items').select().eq('list_id', listId);
    _saw(rows);
    return rows.map(_line).toList();
  }

  ShoppingLine _line(Map<String, dynamic> row) => ShoppingLine(
        id: row['id'] as String,
        listId: row['list_id'] as String,
        name: row['name'] as String,
        category: ShopCategory.values.asNameMap()[row['category'] as String?] ??
            ShopCategory.other,
        quantity: row['qty'] == null
            ? null
            : Quantity((row['qty'] as num).toDouble(),
                QtyUnit.values.asNameMap()[row['unit'] as String?] ?? QtyUnit.piece),
        checked: row['checked'] as bool? ?? false,
        checkedBy: row['checked_by'] as String?,
        recipeIds: ((row['recipe_ids'] as List?) ?? const <Object?>[])
            .whereType<String>()
            .toList(),
      );

  @override
  Future<List<ShoppingLine>> addItems(
      String householdId, String listId, List<ShoppingItem> items) async {
    if (items.isEmpty) return const <ShoppingLine>[];
    final List<Map<String, dynamic>> rows =
        await _client.from('shopping_items').insert(<Map<String, dynamic>>[
      for (final ShoppingItem item in items)
        <String, dynamic>{
          'list_id': listId,
          'household_id': householdId,
          'name': item.name,
          'qty': item.quantity?.amount,
          'unit': item.quantity?.unit.name,
          'category': item.category.name,
          'recipe_ids': item.recipeIds.toList(),
          'added_by': userId,
        },
    ]).select();
    _saw(rows);
    _touched();
    return rows.map(_line).toList();
  }

  @override
  Future<void> setChecked(String itemId, {required bool checked}) async {
    await _client.from('shopping_items').update(<String, dynamic>{
      'checked': checked,
      'checked_by': checked ? userId : null,
    }).eq('id', itemId);
    _touched();
  }

  @override
  Future<void> removeItem(String itemId) async {
    await _client.from('shopping_items').delete().eq('id', itemId);
    _touched();
  }

  @override
  Future<void> moveItems(List<String> itemIds, String toListId) async {
    if (itemIds.isEmpty) return;
    await _client
        .from('shopping_items')
        .update(<String, dynamic>{'list_id': toListId}).inFilter('id', itemIds);
    _touched();
  }

  /// Three channels, so one the server refuses — a table not yet in the
  /// publication — cannot silence the others:
  ///
  /// - inserts and updates of the household's rows, filtered by household;
  /// - the household's own row, which changes with its settings and with
  ///   every join and leave (its members are not published: realtime
  ///   would hand their deletions to everyone);
  /// - deletions, which realtime cannot filter, so this hears every
  ///   household's and passes on only the rows this phone has shown.
  @override
  Stream<void> changes(String householdId) {
    final _Ticks ticks = _ticks.putIfAbsent(householdId, _Ticks.new);
    _channels.putIfAbsent(householdId, () {
      RealtimeChannel rows = _client.channel('household:$householdId');
      for (final String table in _rowTables) {
        rows = rows.onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: table,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'household_id',
            value: householdId,
          ),
          callback: (PostgresChangePayload change) {
            _saw(<Map<String, dynamic>>[change.newRecord]);
            ticks.add();
          },
        );
      }
      final RealtimeChannel settings = _client
          .channel('household-settings:$householdId')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'households',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: householdId,
            ),
            callback: (PostgresChangePayload _) => ticks.add(),
          );
      RealtimeChannel deletions =
          _client.channel('household-deletions:$householdId');
      for (final String table in _rowTables) {
        deletions = deletions.onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: table,
          callback: (PostgresChangePayload change) {
            if (change.oldRecord['id'] case final String id
                when _known.remove(id)) {
              ticks.add();
            }
          },
        );
      }
      return <RealtimeChannel>[
        rows.subscribe(),
        settings.subscribe(),
        deletions.subscribe(),
      ];
    });
    return ticks.stream;
  }

  @override
  Future<void> dispose() async {
    for (final List<RealtimeChannel> channels in _channels.values) {
      for (final RealtimeChannel channel in channels) {
        await _client.removeChannel(channel);
      }
    }
    _channels.clear();
    for (final _Ticks ticks in _ticks.values) {
      await ticks.close();
    }
    _ticks.clear();
  }

  static String _normalize(String code) {
    var c = code.trim();
    final Uri? uri = Uri.tryParse(c);
    if (uri != null && uri.hasScheme && uri.pathSegments.isNotEmpty) {
      c = uri.pathSegments.last;
    }
    return c.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }
}

/// An in-memory [HouseholdBackend]: for tests, and for the screens without a
/// server.
class MemoryHouseholdBackend implements HouseholdBackend {
  MemoryHouseholdBackend({
    this.userId = 'me',
    this.displayName = 'Ich',
    this.emoji = '🙂',
  });

  final String userId;
  final String displayName;
  final String emoji;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  Household? _household;
  final Map<String, Recipe> _recipes = <String, Recipe>{};
  final Map<String, PlanEntry> _entries = <String, PlanEntry>{};
  final Map<String, ShoppingListInfo> _lists = <String, ShoppingListInfo>{};
  final Map<String, ShoppingLine> _items = <String, ShoppingLine>{};
  int _ids = 0;

  String _id(String prefix) => '$prefix-${++_ids}';
  void _changed() => _changes.add(null);

  /// Test hook: someone else in the household.
  void addMember(HouseholdMember member) {
    final Household h = _household!;
    _household = Household(
      id: h.id,
      name: h.name,
      cadence: h.cadence,
      pantry: h.pantry,
      members: <HouseholdMember>[...h.members, member],
    );
    _changed();
  }

  @override
  Future<String> ensureHousehold() async {
    _household ??= Household(
      id: 'home',
      name: '',
      cadence: const WeeklyShopping(),
      members: <HouseholdMember>[
        HouseholdMember(userId: userId, displayName: displayName, emoji: emoji, owner: true),
      ],
    );
    return _household!.id;
  }

  @override
  Future<Household> household(String householdId) async {
    await ensureHousehold();
    return _household!;
  }

  @override
  Future<void> updateHousehold(String householdId,
      {String? name, ShoppingCadence? cadence, List<String>? pantry}) async {
    final Household h = await household(householdId);
    _household = Household(
      id: h.id,
      name: name ?? h.name,
      cadence: cadence ?? h.cadence,
      pantry: pantry ?? h.pantry,
      members: h.members,
    );
    _changed();
  }

  @override
  Future<void> updateMembership(String householdId, HouseholdMember me) async {
    final Household h = await household(householdId);
    _household = Household(
      id: h.id,
      name: h.name,
      cadence: h.cadence,
      pantry: h.pantry,
      members: <HouseholdMember>[
        for (final HouseholdMember m in h.members)
          if (m.userId == userId)
            HouseholdMember(
              userId: m.userId,
              displayName: m.displayName,
              emoji: m.emoji,
              owner: m.owner,
              shareTargets: me.shareTargets,
              kcalTarget: me.shareTargets ? me.kcalTarget : null,
              proteinG: me.shareTargets ? me.proteinG : null,
              diet: me.diet,
              dislikes: me.dislikes,
              allergies: me.allergies,
            )
          else
            m,
      ],
    );
    _changed();
  }

  @override
  Future<String> inviteCode(String householdId) async => 'HOME2345';

  @override
  Future<HouseholdInvitePreview?> previewInvite(String code) async => null;

  @override
  Future<String> join(String code) async => throw StateError('invalid invite');

  /// The plan and the lists stay with the others; the user starts over in
  /// a household of their own.
  @override
  Future<void> leave(String householdId) async {
    _household = null;
    _recipes.clear();
    _entries.clear();
    _lists.clear();
    _items.clear();
    _changed();
  }

  @override
  Future<void> removeMember(String householdId, String memberId) async {
    final Household h = await household(householdId);
    _household = Household(
      id: h.id,
      name: h.name,
      cadence: h.cadence,
      pantry: h.pantry,
      members: h.members.where((HouseholdMember m) => m.userId != memberId).toList(),
    );
    _changed();
  }

  @override
  Future<Map<String, Recipe>> recipes(String householdId) async =>
      Map<String, Recipe>.of(_recipes);

  @override
  Future<Recipe> saveRecipe(String householdId, Recipe recipe, {bool fromAi = false}) async {
    _recipes[recipe.id] = recipe;
    _changed();
    return recipe;
  }

  @override
  Future<List<PlanEntry>> plan(String householdId, DayKey from, DayKey to) async =>
      _entries.values
          .where((PlanEntry e) => !e.day.isBefore(from) && !e.day.isAfter(to))
          .toList();

  @override
  Future<void> saveEntry(String householdId, PlanEntry entry) async {
    _entries[entry.id] = entry;
    _changed();
  }

  @override
  Future<void> removeEntry(String entryId) async {
    _entries.remove(entryId);
    _changed();
  }

  @override
  Future<List<ShoppingListInfo>> openLists(String householdId) async =>
      _lists.values.where((ShoppingListInfo l) => !l.done).toList()
        ..sort((ShoppingListInfo a, ShoppingListInfo b) =>
            a.period.start.compareTo(b.period.start));

  @override
  Future<ShoppingListInfo> createList(String householdId, ShoppingPeriod period,
      {String title = ''}) async {
    final ShoppingListInfo list =
        ShoppingListInfo(id: _id('list'), title: title, period: period);
    _lists[list.id] = list;
    _changed();
    return list;
  }

  @override
  Future<void> closeList(String listId) async {
    final ShoppingListInfo? l = _lists[listId];
    if (l == null) return;
    _lists[listId] = ShoppingListInfo(id: l.id, title: l.title, period: l.period, done: true);
    _changed();
  }

  @override
  Future<List<ShoppingLine>> items(String listId) async =>
      _items.values.where((ShoppingLine i) => i.listId == listId).toList();

  @override
  Future<List<ShoppingLine>> addItems(
      String householdId, String listId, List<ShoppingItem> items) async {
    final List<ShoppingLine> added = <ShoppingLine>[];
    for (final ShoppingItem item in items) {
      final String id = _id('item');
      added.add(_items[id] = ShoppingLine(
        id: id,
        listId: listId,
        name: item.name,
        category: item.category,
        quantity: item.quantity,
        recipeIds: item.recipeIds.toList(),
      ));
    }
    _changed();
    return added;
  }

  @override
  Future<void> setChecked(String itemId, {required bool checked}) async {
    final ShoppingLine? i = _items[itemId];
    if (i == null) return;
    _items[itemId] = ShoppingLine(
      id: i.id,
      listId: i.listId,
      name: i.name,
      category: i.category,
      quantity: i.quantity,
      checked: checked,
      checkedBy: checked ? userId : null,
      recipeIds: i.recipeIds,
    );
    _changed();
  }

  @override
  Future<void> removeItem(String itemId) async {
    _items.remove(itemId);
    _changed();
  }

  @override
  Future<void> moveItems(List<String> itemIds, String toListId) async {
    for (final String id in itemIds) {
      final ShoppingLine? i = _items[id];
      if (i == null) continue;
      _items[id] = ShoppingLine(
        id: i.id,
        listId: toListId,
        name: i.name,
        category: i.category,
        quantity: i.quantity,
        checked: i.checked,
        checkedBy: i.checkedBy,
        recipeIds: i.recipeIds,
      );
    }
    _changed();
  }

  @override
  Stream<void> changes(String householdId) => _changes.stream;

  @override
  Future<void> dispose() => _changes.close();
}
