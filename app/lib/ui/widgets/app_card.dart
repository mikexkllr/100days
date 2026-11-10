import 'package:flutter/material.dart';

import '../../theme/fire.dart';
import '../../theme/theme.dart';

/// The one container the whole app uses: a matte panel over the night sky,
/// dark enough to read on whatever the sky is doing behind it. A panel has
/// no colour unless it means something — then it takes a tint and a rim.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.color,
    this.border,
    this.onTap,
    this.gradient,
    this.glow,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Tints the panel.
  final Color? color;

  /// Colours the rim instead of the neutral hairline.
  final Color? border;
  final VoidCallback? onTap;

  /// Replaces the fill.
  final Gradient? gradient;

  /// A halo, for the rare panel that is lit.
  final Color? glow;

  @override
  Widget build(BuildContext context) {
    final Widget content = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppRadius.cardAll,
        color: AppColors.ink.withValues(alpha: 0.58),
        boxShadow:
            glow == null ? null : AppShadows.glow(glow!, strength: 0.7),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: AppRadius.cardAll,
          gradient: gradient ?? AppGradients.card(color ?? Colors.white),
          border: Border.all(
            color: border ?? (color ?? Colors.white).withValues(
                alpha: color == null ? 0.1 : 0.4),
          ),
        ),
        // List tiles, switches and chips inside a card paint their ink on
        // the nearest Material; without one here the fill would hide it.
        child: Padding(
          padding: padding,
          child: Material(type: MaterialType.transparency, child: child),
        ),
      ),
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.cardAll,
        child: content,
      ),
    );
  }
}

/// A section title, with an optional line under it and an action beside it.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: AppSpacing.sm + 4,
        top: AppSpacing.lg + 4,
        left: 2,
        right: 2,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.textSecondary, fontSize: 13.5),
                    ),
                  ),
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

/// A face in a ring.
class EmojiAvatar extends StatelessWidget {
  const EmojiAvatar(
    this.emoji, {
    super.key,
    this.size = 44,
    this.ringColor,
    this.dimmed = false,
  });

  final String emoji;
  final double size;
  final Color? ringColor;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surfaceHigh,
        border: Border.all(
          color: ringColor ?? AppColors.glassEdge,
          width: ringColor == null ? 1 : 1.6,
        ),
      ),
      child: Opacity(
        opacity: dimmed ? 0.45 : 1,
        child: Text(emoji, style: TextStyle(fontSize: size * 0.46)),
      ),
    );
  }
}

/// Small uppercase label used for statuses and badges.
class Pill extends StatelessWidget {
  const Pill(
    this.label, {
    super.key,
    this.color = AppColors.textSecondary,
    this.icon,
    this.filled = false,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: filled ? color.withValues(alpha: 0.18) : AppColors.glass,
        borderRadius: AppRadius.pill,
        border: Border.all(color: color.withValues(alpha: filled ? 0.55 : 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label.toUpperCase(),
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: color, fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}

class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    this.color = AppColors.textPrimary,
    this.icon,
  });

  final String value;
  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: displayStyle(21, color: color),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.textTertiary, fontSize: 12.5),
        ),
      ],
    );
  }
}

/// Full-bleed empty state with a single call to action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.emoji,
    required this.title,
    required this.body,
    this.action,
  });

  final String emoji;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 92,
              height: 92,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: <Color>[
                    AppColors.primary.withValues(alpha: 0.14),
                    AppColors.primary.withValues(alpha: 0),
                  ],
                ),
              ),
              child: Text(emoji, style: const TextStyle(fontSize: 48)),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              body,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            if (action != null) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// A tab bar as a segmented control: a dim track with a pill of light that
/// slides to the selected tab.
class GlassTabBar extends StatelessWidget implements PreferredSizeWidget {
  const GlassTabBar({
    super.key,
    required this.tabs,
    this.isScrollable = false,
    this.labelPadding = const EdgeInsets.symmetric(horizontal: 14),
  });

  final List<Widget> tabs;
  final bool isScrollable;
  final EdgeInsetsGeometry labelPadding;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
      child: Container(
        height: 46,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: AppRadius.pill,
          color: AppColors.glass,
          border: Border.all(color: AppColors.glassEdge),
        ),
        child: TabBar(
          isScrollable: isScrollable,
          tabAlignment: isScrollable ? TabAlignment.start : TabAlignment.fill,
          labelPadding: labelPadding,
          tabs: tabs,
        ),
      ),
    );
  }
}

/// A streak as a number with a small flame, in the colour that streak
/// burns in — so a friend on day 60 looks different from one on day 6.
class StreakCount extends StatelessWidget {
  const StreakCount(this.streak, {super.key, this.size = 15});

  final int streak;
  final double size;

  @override
  Widget build(BuildContext context) {
    final Fire fire = Fire.ofStreak(streak);
    final Color color = streak > 0 ? fire.light : AppColors.textTertiary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text('$streak',
            style: displayStyle(size, color: color, weight: FontWeight.w700)),
        const SizedBox(width: 2),
        Icon(Icons.local_fire_department,
            size: size + 3, color: streak > 0 ? fire.main : color),
      ],
    );
  }
}
