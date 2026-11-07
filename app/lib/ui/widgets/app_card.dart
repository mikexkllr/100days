import 'package:flutter/material.dart';

import '../../theme/theme.dart';

/// The one container the whole app uses: a pane of glass over the aurora,
/// with a bright rim where the light hits it and an optional neon glow.
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

  /// Tints the glass.
  final Color? color;

  /// Colours the rim instead of the neutral white edge.
  final Color? border;
  final VoidCallback? onTap;

  /// Replaces the glass fill.
  final Gradient? gradient;
  final Color? glow;

  @override
  Widget build(BuildContext context) {
    final Color? rim = border;
    final Widget content = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppRadius.cardAll,
        // The rim is a gradient, drawn as the outer box under the fill.
        gradient: AppGradients.edge(rim ?? Colors.white),
        boxShadow:
            glow == null ? null : AppShadows.glow(glow!, strength: 0.75),
      ),
      child: Padding(
        padding: const EdgeInsets.all(1.2),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(25)),
            // A glowing card sits on a darker base, so its own halo does
            // not soak through the glass.
            color: AppColors.ink.withValues(alpha: glow == null ? 0.55 : 0.88),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(Radius.circular(25)),
              gradient: gradient ?? AppGradients.card(color ?? Colors.white),
            ),
            // List tiles, switches and chips inside a card paint their ink
            // on the nearest Material; without one here the fill would hide
            // it.
            child: Padding(
              padding: padding,
              child: Material(type: MaterialType.transparency, child: child),
            ),
          ),
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

/// A section title with a short neon bar in front of it.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm + 2, top: AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 4,
            height: subtitle == null ? 20 : 38,
            margin: const EdgeInsets.only(right: AppSpacing.sm + 2),
            decoration: BoxDecoration(
              borderRadius: AppRadius.pill,
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[AppColors.hot, AppColors.primary, AppColors.social],
              ),
              boxShadow: AppShadows.glow(AppColors.primary, strength: 0.6),
            ),
          ),
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

/// A face in a ring of light.
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
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: ringColor == null
            ? AppGradients.edge()
            : SweepGradient(
                colors: <Color>[
                  ringColor!,
                  AppColors.social,
                  AppColors.hot,
                  ringColor!,
                ],
              ),
        boxShadow: ringColor == null
            ? null
            : AppShadows.glow(ringColor!, strength: 0.5),
      ),
      child: Container(
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surface,
        ),
        child: Opacity(
          opacity: dimmed ? 0.45 : 1,
          child: Text(emoji, style: TextStyle(fontSize: size * 0.44)),
        ),
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
                    AppColors.primary.withValues(alpha: 0.35),
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

/// A tab bar as a segmented control: a glass track with a neon pill that
/// slides to the selected tab.
class GlassTabBar extends StatelessWidget implements PreferredSizeWidget {
  const GlassTabBar({super.key, required this.tabs, this.isScrollable = false});

  final List<Widget> tabs;
  final bool isScrollable;

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
          labelPadding: const EdgeInsets.symmetric(horizontal: 14),
          tabs: tabs,
        ),
      ),
    );
  }
}

/// A streak as a number with a small flame, in the app's own colours.
class StreakCount extends StatelessWidget {
  const StreakCount(this.streak, {super.key, this.size = 15});

  final int streak;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text('$streak',
            style: displayStyle(size,
                color: AppColors.attention, weight: FontWeight.w700)),
        const SizedBox(width: 2),
        Icon(Icons.local_fire_department,
            size: size + 3, color: AppColors.attention),
      ],
    );
  }
}
