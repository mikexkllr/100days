import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/theme.dart';
import '../funki/funki_widgets.dart';
import '../mascot/mascot_mood.dart';
import '../widgets/app_card.dart';

// What a training plan is set up from, asked the same way at the start and
// later: onboarding and the plan editor both build their page from these,
// and both go through `retargetTraining` when an answer changes.

/// Training days a week, two to six.
class TrainingDaysPicker extends StatelessWidget {
  const TrainingDaysPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      for (final int days in const <int>[2, 3, 4, 5, 6])
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: days == 6 ? 0 : AppSpacing.sm),
            child: _Choice(
              key: Key('days-$days'),
              label: '$days',
              sublabel: 'x',
              selected: value == days,
              onTap: () => onChanged(days),
            ),
          ),
        ),
    ],
  );
}

/// Beginner, intermediate, advanced.
class ExperiencePicker extends StatelessWidget {
  const ExperiencePicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final TrainingExperience value;
  final ValueChanged<TrainingExperience> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return _OptionList<TrainingExperience>(
      value: value,
      onChanged: onChanged,
      options: <_Option<TrainingExperience>>[
        for (final TrainingExperience level in TrainingExperience.values)
          _Option<TrainingExperience>(
            key: Key('experience-${level.name}'),
            value: level,
            emoji: const <String>['🌱', '⚙️', '🔥'][level.index],
            title: l10n.experienceTitle(level),
            body: l10n.experienceBody(level),
          ),
      ],
    );
  }
}

/// Full gym, home gym, body weight.
class EquipmentPicker extends StatelessWidget {
  const EquipmentPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final EquipmentAccess value;
  final ValueChanged<EquipmentAccess> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return _OptionList<EquipmentAccess>(
      value: value,
      onChanged: onChanged,
      options: <_Option<EquipmentAccess>>[
        for (final EquipmentAccess access in EquipmentAccess.values)
          _Option<EquipmentAccess>(
            key: Key('equipment-${access.name}'),
            value: access,
            emoji: const <String>['🏟️', '🏠', '🤸'][access.index],
            title: l10n.equipmentTitle(access),
            body: l10n.equipmentBody(access),
          ),
      ],
    );
  }
}

/// Funki puts the plan together from what the user says — "dumbbells up to
/// 20 kg and a bench" — and it lands in the form at once, with a way back.
/// Nothing is saved: the page around it does that, or does not.
///
/// Not shown without a model.
class FunkiTrainingLine extends ConsumerStatefulWidget {
  const FunkiTrainingLine({
    super.key,
    required this.goal,
    required this.setup,
    required this.onChanged,
  });

  /// The goal as the form stands: days, experience, equipment.
  final Goal goal;
  final TrainingSetup setup;

  /// Equipment and plan, as Funki built them or as they were before.
  final void Function(EquipmentAccess equipment, TrainingSetup setup) onChanged;

  @override
  ConsumerState<FunkiTrainingLine> createState() => _FunkiTrainingLineState();
}

class _FunkiTrainingLineState extends ConsumerState<FunkiTrainingLine> {
  final TextEditingController _text = TextEditingController();
  bool _working = false;
  String? _problem;
  int _gulps = 0;

  /// What Funki built, and what was there before it, while one can still
  /// go back to it.
  TrainingProposal? _built;
  ({EquipmentAccess equipment, TrainingSetup setup})? _before;

  @override
  void didUpdateWidget(FunkiTrainingLine old) {
    super.didUpdateWidget(old);
    // Edited since: going back would throw that away too.
    final TrainingProposal? built = _built;
    if (built != null &&
        (widget.setup != built.setup ||
            widget.goal.equipment != built.equipment)) {
      _built = null;
      _before = null;
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final String said = _text.text.trim();
    if (said.isEmpty || _working) return;
    final AppLocalizations l10n = context.l10n;
    FocusScope.of(context).unfocus();
    setState(() {
      _working = true;
      _problem = null;
    });
    final TrainingAssistant? assistant = await ref
        .read(trainingAssistantProvider.future)
        .catchError((Object _) => null);
    Object? failure;
    final TrainingProposal? proposal = await assistant?.propose(
      TrainingRequest(goal: widget.goal, current: widget.setup, wish: said),
      onError: (Object error) => failure = error,
    );
    if (!mounted) return;
    if (proposal == null) {
      setState(() {
        _working = false;
        _problem = failure != null
            ? l10n.aiErrorMessage(failure!)
            : l10n.trainingFunkiFailed;
      });
      return;
    }
    final ({EquipmentAccess equipment, TrainingSetup setup}) before = (
      equipment: widget.goal.equipment,
      setup: widget.setup,
    );
    widget.onChanged(proposal.equipment, proposal.setup);
    _text.clear();
    setState(() {
      _working = false;
      _built = proposal;
      _before = before;
      _gulps++;
    });
  }

  void _undo() {
    final ({EquipmentAccess equipment, TrainingSetup setup})? before = _before;
    if (before == null) return;
    setState(() {
      _built = null;
      _before = null;
    });
    widget.onChanged(before.equipment, before.setup);
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(trainingAssistantProvider).valueOrNull == null) {
      return const SizedBox.shrink();
    }
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    final TrainingProposal? built = _built;
    final bool equipmentChanged =
        built != null && built.equipment != _before?.equipment;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        key: const Key('funki-training'),
        border: AppColors.primary.withValues(alpha: 0.35),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                FunkiAvatar(
                  size: 40,
                  mood: _working ? MascotMood.hungry : MascotMood.happy,
                  gulps: _gulps,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(l10n.trainingFunkiTitle, style: text.titleMedium),
                      Text(
                        l10n.trainingFunkiBody,
                        style: text.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const Key('funki-training-text'),
              controller: _text,
              enabled: !_working,
              minLines: 1,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
              decoration: InputDecoration(
                isDense: true,
                hintText: l10n.trainingFunkiHint,
                suffixIcon: _working
                    ? const Padding(
                        padding: EdgeInsets.all(AppSpacing.md),
                        child: FunkiThinking(),
                      )
                    : IconButton(
                        key: const Key('funki-training-send'),
                        tooltip: l10n.trainingFunkiSend,
                        onPressed: _send,
                        icon: const Icon(Icons.arrow_upward_rounded, size: 20),
                      ),
              ),
            ),
            if (_problem != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  _problem!,
                  key: const Key('funki-training-problem'),
                  style: text.bodySmall?.copyWith(color: AppColors.danger),
                ),
              ),
            if (built != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Row(
                  key: const Key('funki-training-done'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.check_circle_outline,
                        size: 18,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          FunkiSpeech(
                            l10n.trainingFunkiBuilt(
                              l10n.splitName(built.setup.split),
                            ),
                            style: text.bodyMedium,
                          ),
                          if (equipmentChanged)
                            Text(
                              l10n.trainingFunkiEquipment(
                                l10n.equipmentTitle(built.equipment),
                              ),
                              style: text.bodySmall,
                            ),
                          if (built.reason != null)
                            Text(
                              built.reason!,
                              style: text.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    TextButton(
                      key: const Key('funki-training-undo'),
                      onPressed: _undo,
                      child: Text(l10n.plannerUndo),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Option<T> {
  const _Option({
    required this.key,
    required this.value,
    required this.emoji,
    required this.title,
    required this.body,
  });

  final Key key;
  final T value;
  final String emoji;
  final String title;
  final String body;
}

class _OptionList<T> extends StatelessWidget {
  const _OptionList({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final T value;
  final List<_Option<T>> options;
  final void Function(T value) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (final _Option<T> option in options)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: AppCard(
              key: option.key,
              onTap: () => onChanged(option.value),
              border: value == option.value ? AppColors.primary : null,
              color: value == option.value
                  ? AppColors.primary.withValues(alpha: 0.08)
                  : AppColors.surface,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm + 4,
              ),
              child: Row(
                children: <Widget>[
                  Text(option.emoji, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          option.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          option.body,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 12.5,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    super.key,
    required this.label,
    required this.sublabel,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String sublabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 4),
      border: selected ? AppColors.primary : null,
      color: selected
          ? AppColors.primary.withValues(alpha: 0.08)
          : AppColors.surface,
      child: Column(
        children: <Widget>[
          Text(
            label,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: selected ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
          Text(
            sublabel,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}
