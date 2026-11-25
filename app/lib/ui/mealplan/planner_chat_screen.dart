import 'dart:convert';

import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../ai/dartantic_llm_client.dart';
import '../../data/household_backend.dart';
import '../../l10n/l10n.dart';
import '../../state/household_providers.dart';
import '../../state/providers.dart';
import '../../theme/theme.dart';
import '../settings/ai_screen.dart' show showPaywall;
import '../widgets/app_card.dart';
import 'household_load_error.dart';

/// A change the planner made, shown in the chat with a way back.
class _Change {
  _Change(this.label, this.undo);

  final String label;
  final Future<void> Function() undo;
  bool undone = false;

  /// While its undo runs: a second tap must not undo it twice.
  bool undoing = false;
}

class _Turn {
  _Turn.user(this.text)
      : fromUser = true,
        offersPaywall = false;
  _Turn.model(this.text, {this.offersPaywall = false}) : fromUser = false;

  final String text;
  final bool fromUser;

  /// The allowance ran out: the answer carries the way on.
  final bool offersPaywall;
  final List<_Change> changes = <_Change>[];
}

/// Plan by talking: "no fish this week", "Wednesday something quick",
/// "we still have rice". The model reads and changes the plan and the list
/// through tools; every change shows up as a card that can be undone.
class PlannerChatScreen extends ConsumerStatefulWidget {
  const PlannerChatScreen({super.key, required this.weekStart});

  final DayKey weekStart;

  @override
  ConsumerState<PlannerChatScreen> createState() => _PlannerChatScreenState();
}

class _PlannerChatScreenState extends ConsumerState<PlannerChatScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<_Turn> _turns = <_Turn>[];
  final List<ChatMessage> _history = <ChatMessage>[];
  List<_Change> _pending = <_Change>[];
  bool _thinking = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  HouseholdBackend get _backend => ref.read(householdBackendProvider);
  HouseholdActions get _actions => ref.read(householdActionsProvider);

  Future<String> get _householdId => ref.read(householdIdProvider.future);

  Future<void> _send() async {
    final String text = _input.text.trim();
    final LlmClient llm = ref.read(llmClientProvider);
    if (text.isEmpty || _thinking || llm is! DartanticLlmClient) return;
    _input.clear();
    setState(() {
      _turns.add(_Turn.user(text));
      _thinking = true;
      _pending = <_Change>[];
    });
    _scrollDown();

    final AppLocalizations l10n = context.l10n;
    if (_history.isEmpty) {
      _history.add(ChatMessage.system(l10n.promptPlannerChat(
        DayKey.today().toString(),
        l10n.weekdayLong(DayKey.today().toDateTime().weekday),
        widget.weekStart.toString(),
        widget.weekStart.addDays(6).toString(),
      )));
    }

    String answer;
    bool paywall = false;
    try {
      final ChatResult<String> result = await llm
          .agent(LlmPurpose.chat, tools: _tools(l10n))
          .send(text, history: _history)
          .timeout(const Duration(seconds: 120));
      // The result carries the whole exchange: the prompt, tool calls, tool
      // results and the answer — all of it is history for the next turn.
      _history.addAll(result.messages);
      answer = result.output.trim().isEmpty ? l10n.plannerDone : result.output.trim();
    } on Object catch (error) {
      // The chat talks to the agent directly, past the client's paywall
      // hook: it says what happened itself, in a sentence, with the way on.
      switch (classifyAiError(error)) {
        case AiFailure.quotaExceeded || AiFailure.premiumOnly:
          answer = l10n.plannerQuotaUsedUp;
          paywall = true;
        case AiFailure.rateLimited:
          answer = l10n.aiRateLimited;
        case AiFailure.other:
          answer = l10n.plannerFailed;
      }
    }
    if (!mounted) return;
    setState(() {
      _thinking = false;
      _turns.add(_Turn.model(answer, offersPaywall: paywall)..changes.addAll(_pending));
    });
    _scrollDown();
  }

  Future<void> _undo(_Change change) async {
    if (change.undone || change.undoing) return;
    setState(() => change.undoing = true);
    try {
      await change.undo();
      if (mounted) setState(() => change.undone = true);
    } on Object {
      if (mounted) showHouseholdSaveFailed(context);
    } finally {
      if (mounted) setState(() => change.undoing = false);
    }
  }

  void _scrollDown() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
        }
      });

  List<Tool> _tools(AppLocalizations l10n) => <Tool>[
        Tool<Map<String, dynamic>>(
          name: 'get_plan',
          description: 'The household and its meal plan for the week being '
              'planned: members with their targets and tastes, and every planned '
              'meal by day and slot.',
          onCall: (_) async => jsonEncode(await _planSnapshot()),
        ),
        Tool<Map<String, dynamic>>(
          name: 'set_meal',
          description: 'Puts a recipe on a day and slot, replacing what was '
              'there. Give servings for the whole household and the calories '
              'and macros of ONE serving.',
          inputSchema: S.object(
            properties: <String, Schema>{
              'day': S.string(description: 'YYYY-MM-DD'),
              'slot': S.string(enumValues: MealSlotKind.values.map((MealSlotKind s) => s.name).toList()),
              'title': S.string(),
              'servings': S.integer(),
              'minutes': S.integer(),
              'kcal': S.number(),
              'protein': S.number(),
              'carbs': S.number(),
              'fat': S.number(),
              'ingredients': S.list(
                items: S.object(
                  properties: <String, Schema>{
                    'name': S.string(),
                    'qty': S.number(),
                    'unit': S.string(enumValues: <String>['g', 'ml', 'piece', 'tbsp', 'tsp']),
                    'category': S.string(
                        enumValues: ShopCategory.values.map((ShopCategory c) => c.name).toList()),
                  },
                  required: <String>['name', 'qty', 'unit'],
                ),
              ),
              'steps': S.list(items: S.string()),
            },
            required: <String>['day', 'slot', 'title', 'servings', 'kcal', 'ingredients'],
          ),
          onCall: (Map<String, dynamic> input) => _setMeal(input, l10n),
        ),
        Tool<Map<String, dynamic>>(
          name: 'remove_meal',
          description: 'Removes the meal planned on a day and slot.',
          inputSchema: S.object(
            properties: <String, Schema>{
              'day': S.string(description: 'YYYY-MM-DD'),
              'slot': S.string(enumValues: MealSlotKind.values.map((MealSlotKind s) => s.name).toList()),
            },
            required: <String>['day', 'slot'],
          ),
          onCall: (Map<String, dynamic> input) => _removeMeal(input, l10n),
        ),
        Tool<Map<String, dynamic>>(
          name: 'get_shopping_list',
          description: 'The current shopping list: every line with its amount '
              'and whether it is already in the basket.',
          onCall: (_) async => jsonEncode(await _listSnapshot()),
        ),
        Tool<Map<String, dynamic>>(
          name: 'add_to_list',
          description: 'Adds a line to the current shopping list.',
          inputSchema: S.object(
            properties: <String, Schema>{'name': S.string()},
            required: <String>['name'],
          ),
          onCall: (Map<String, dynamic> input) => _addToList(input, l10n),
        ),
        Tool<Map<String, dynamic>>(
          name: 'remove_from_list',
          description: 'Removes a line from the current shopping list, e.g. '
              'because it is still at home.',
          inputSchema: S.object(
            properties: <String, Schema>{'name': S.string()},
            required: <String>['name'],
          ),
          onCall: (Map<String, dynamic> input) => _removeFromList(input, l10n),
        ),
        Tool<Map<String, dynamic>>(
          name: 'make_list_from_plan',
          description: 'Makes a new shopping list for the next trip from the '
              'planned meals.',
          onCall: (_) async {
            final ListFromPlan made = await _actions.listFromPlan();
            if (made.created) {
              _pending.add(_Change(
                  l10n.plannerListMade, () => _backend.closeList(made.list.id)));
              return 'Made a list for ${made.list.period}.';
            }
            // The trip's list was open already and got what it lacked:
            // undo takes exactly that back off.
            _pending.add(_Change(l10n.plannerListToppedUp, () async {
              for (final ShoppingLine line in made.added) {
                await _backend.removeItem(line.id);
              }
            }));
            return 'The list for ${made.list.period} was open already; '
                'added ${made.added.length} missing lines to it.';
          },
        ),
      ];

  Future<Map<String, dynamic>> _planSnapshot() async {
    final String id = await _householdId;
    final Household household = await _backend.household(id);
    final List<PlanEntry> entries =
        await _backend.plan(id, widget.weekStart, widget.weekStart.addDays(6));
    final Map<String, Recipe> recipes = await _backend.recipes(id);
    return <String, dynamic>{
      'members': <String>[
        for (final HouseholdMember m in household.members) describePerson(m.toPlanFor()),
      ],
      'meals': <Map<String, dynamic>>[
        for (final PlanEntry e in entries)
          <String, dynamic>{
            'day': e.day.toString(),
            'slot': e.slot.name,
            'title': recipes[e.recipeId]?.title,
            'kcal_per_serving': recipes[e.recipeId]?.perServing.kcal.round(),
          },
      ],
    };
  }

  Future<ShoppingListInfo?> _currentList() async {
    final List<ShoppingListInfo> open = await _backend.openLists(await _householdId);
    return open.isEmpty ? null : open.first;
  }

  Future<List<Map<String, dynamic>>> _listSnapshot() async {
    final ShoppingListInfo? list = await _currentList();
    if (list == null) return const <Map<String, dynamic>>[];
    return <Map<String, dynamic>>[
      for (final ShoppingLine l in await _backend.items(list.id))
        <String, dynamic>{
          'name': l.name,
          if (l.quantity != null) 'amount': l.quantity.toString(),
          'in_basket': l.checked,
        },
    ];
  }

  Future<String> _setMeal(Map<String, dynamic> input, AppLocalizations l10n) async {
    final DayKey day = DayKey.parse(input['day'] as String);
    final List<ProposedMeal> parsed = parseMealPlan(
      jsonEncode(<String, dynamic>{'meals': <Object>[input]}),
      MealPlanRequest(
        days: <DayKey>[day],
        slots: MealSlotKind.values,
        people: const <PlanFor>[],
      ),
    );
    if (parsed.isEmpty) {
      return 'Rejected: the numbers or ingredients do not add up. Check '
          'that kcal matches the macros for one serving and every ingredient '
          'has an amount in g, ml or pieces.';
    }
    final ProposedMeal meal = parsed.single;
    final String id = await _householdId;
    final List<PlanEntry> before = (await _backend.plan(id, day, day))
        .where((PlanEntry e) => e.slot == meal.slot)
        .toList();
    for (final PlanEntry old in before) {
      await _backend.removeEntry(old.id);
    }
    await _actions.setMeal(meal.day, meal.slot, meal.recipe, fromAi: true);
    final List<PlanEntry> now = (await _backend.plan(id, day, day))
        .where((PlanEntry e) => e.slot == meal.slot)
        .toList();
    _pending.add(_Change(
      l10n.plannerSetMeal(l10n.formatDay(day), l10n.mealName(meal.slot), meal.recipe.title),
      () async {
        for (final PlanEntry e in now) {
          await _backend.removeEntry(e.id);
        }
        for (final PlanEntry e in before) {
          await _backend.saveEntry(id, e);
        }
      },
    ));
    return 'Planned ${meal.recipe.title} on ${meal.day} (${meal.slot.name}).';
  }

  Future<String> _removeMeal(Map<String, dynamic> input, AppLocalizations l10n) async {
    final DayKey day = DayKey.parse(input['day'] as String);
    final MealSlotKind? slot = MealSlotKind.values.asNameMap()[input['slot']];
    final String id = await _householdId;
    final List<PlanEntry> removed = (await _backend.plan(id, day, day))
        .where((PlanEntry e) => e.slot == slot)
        .toList();
    if (removed.isEmpty) return 'Nothing was planned there.';
    for (final PlanEntry e in removed) {
      await _backend.removeEntry(e.id);
    }
    _pending.add(_Change(
      l10n.plannerRemovedMeal(l10n.formatDay(day), l10n.mealName(slot!)),
      () async {
        for (final PlanEntry e in removed) {
          await _backend.saveEntry(id, e);
        }
      },
    ));
    return 'Removed.';
  }

  Future<String> _addToList(Map<String, dynamic> input, AppLocalizations l10n) async {
    final String name = (input['name'] as String? ?? '').trim();
    final ShoppingListInfo list = await _currentList() ?? await _actions.emptyList();
    if (name.isEmpty) return 'No name given.';
    final List<ShoppingLine> added = await _actions.addItem(list.id, name);
    // Only the line this added: a "Milch" that was on the list before stays.
    _pending.add(_Change(l10n.plannerAdded(name), () async {
      for (final ShoppingLine line in added) {
        await _backend.removeItem(line.id);
      }
    }));
    return 'Added $name.';
  }

  Future<String> _removeFromList(Map<String, dynamic> input, AppLocalizations l10n) async {
    final String name = (input['name'] as String? ?? '').trim();
    final ShoppingListInfo? list = await _currentList();
    if (list == null) return 'There is no list.';
    final List<ShoppingLine> matching = (await _backend.items(list.id))
        .where((ShoppingLine l) => shoppingKey(l.name) == shoppingKey(name))
        .toList();
    if (matching.isEmpty) return '$name is not on the list.';
    for (final ShoppingLine l in matching) {
      await _backend.removeItem(l.id);
    }
    _pending.add(_Change(l10n.plannerRemoved(name), () async {
      await _backend.addItems(await _householdId, list.id, <ShoppingItem>[
        for (final ShoppingLine l in matching)
          ShoppingItem(
            name: l.name,
            category: l.category,
            quantity: l.quantity,
            recipeIds: l.recipeIds.toSet(),
          ),
      ]);
    }));
    return 'Removed $name.';
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.planChat)),
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.all(AppSpacing.md),
              children: <Widget>[
                if (_turns.isEmpty)
                  AppCard(
                    color: AppColors.surfaceHigh,
                    child: Text(l10n.plannerIntro,
                        style: text.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                  ),
                for (final _Turn turn in _turns) ...<Widget>[
                  Align(
                    alignment: turn.fromUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                      padding: const EdgeInsets.all(AppSpacing.sm + 4),
                      constraints: const BoxConstraints(maxWidth: 320),
                      decoration: BoxDecoration(
                        color: turn.fromUser ? AppColors.social.withValues(alpha: 0.2) : AppColors.surfaceHigh,
                        borderRadius: AppRadius.cardAll,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(turn.text, style: text.bodyMedium),
                          if (turn.offersPaywall)
                            Padding(
                              padding: const EdgeInsets.only(top: AppSpacing.sm),
                              child: FilledButton(
                                key: const Key('planner-paywall'),
                                onPressed: () => showPaywall(context),
                                child: Text(l10n.aiPaywallAction),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  for (final _Change change in turn.changes)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: AppCard(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                        child: Row(
                          children: <Widget>[
                            Icon(change.undone ? Icons.undo : Icons.check_circle_outline,
                                size: 18,
                                color: change.undone ? AppColors.textTertiary : AppColors.success),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(change.label,
                                  style: change.undone
                                      ? text.bodySmall?.copyWith(
                                          decoration: TextDecoration.lineThrough,
                                          color: AppColors.textTertiary)
                                      : text.bodySmall),
                            ),
                            if (!change.undone)
                              TextButton(
                                onPressed:
                                    change.undoing ? null : () => _undo(change),
                                child: Text(l10n.plannerUndo),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
                if (_thinking)
                  const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.md),
              child: TextField(
                key: const Key('planner-input'),
                controller: _input,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: l10n.plannerHint,
                  suffixIcon: IconButton(
                    onPressed: _thinking ? null : _send,
                    icon: const Icon(Icons.send),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
