import 'package:flutter/material.dart';

import '../../../theme/theme.dart';
import '../onboarding_flow.dart';

class WelcomeStep extends StatelessWidget {
  const WelcomeStep({super.key});

  @override
  Widget build(BuildContext context) {
    return const OnboardingScaffold(
      eyebrow: '100 Tage und weit darüber hinaus',
      title: 'Du brauchst kein neues Ich.\nDu brauchst 100 Tage.',
      subtitle: 'Setz ein Ziel. Bekomm einen Plan. Und danach zählt nur noch '
          'eins: ob du heute dran warst — und ob deine Leute es sehen.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Point(
            emoji: '🎯',
            title: 'Erst das Ziel',
            body: 'Ohne Ziel kein Plan. Du sagst, worum es geht — die App '
                'baut Training, Ernährung oder Streak drumherum.',
          ),
          _Point(
            emoji: '👀',
            title: 'Deine Leute sehen alles',
            body: 'Kein anonymer Zähler. Wenn Marcel heute im Gym war und du '
                'nicht, steht das da. Genau das ist der Punkt.',
          ),
          _Point(
            emoji: '🔒',
            title: 'Niemand sonst',
            body: 'Kein Konto, kein Server, keine Cloud. Deine Daten liegen '
                'auf deinem Gerät und gehen direkt zu deinen Freunden.',
          ),
          _Point(
            emoji: '♾️',
            title: 'Tag 100 ist nicht das Ende',
            body: 'Danach geht es weiter — nächste Stufe, härtere Ziele, '
                'gleicher Streak.',
          ),
        ],
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.emoji, required this.title, required this.body});

  final String emoji;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
