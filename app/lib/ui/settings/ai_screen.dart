import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../ai/allowance.dart';
import '../../ai/own_key.dart';
import '../../ai/subscription_service.dart';
import '../../config/legal_links.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/theme.dart';
import '../widgets/app_card.dart';

/// AI and subscription: what this month's allowance looks like, Premium, and
/// the option to use one's own API key instead.
class AiScreen extends ConsumerWidget {
  const AiScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final OwnKey? own = ref.watch(ownKeyProvider).valueOrNull;
    final AiAllowance allowance =
        ref.watch(aiAllowanceProvider).valueOrNull ?? AiAllowance.unknown;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.aiTitle)),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(aiAllowanceProvider.future),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, 0, AppSpacing.md, AppSpacing.xxl),
          children: <Widget>[
            _StatusCard(allowance: allowance, own: own),
            if (own == null) ...<Widget>[
              SectionHeader(l10n.aiPremiumTitle, subtitle: l10n.aiPremiumSub),
              _PremiumCard(allowance: allowance),
            ],
            SectionHeader(l10n.aiOwnKeyTitle, subtitle: l10n.aiOwnKeySub),
            _OwnKeyCard(own: own),
            SectionHeader(l10n.aiWhatItSeesTitle),
            AppCard(
              color: AppColors.surfaceHigh,
              child: Text(
                l10n.aiWhatItSeesBody,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.allowance, required this.own});

  final AiAllowance allowance;
  final OwnKey? own;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    final OwnKey? own = this.own;
    final String title = own != null
        ? l10n.aiStatusOwnKey(l10n.aiProviderName(own.provider.name))
        : allowance.premium
            ? l10n.aiStatusPremium
            : l10n.aiStatusFree;
    final double? fraction = allowance.fraction;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.auto_awesome, color: AppColors.reward),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(title, style: text.titleLarge)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (own != null)
            Text(l10n.aiOwnKeyActive,
                style: text.bodyMedium?.copyWith(color: AppColors.textSecondary))
          else ...<Widget>[
            if (fraction != null) ...<Widget>[
              ClipRRect(
                borderRadius: AppRadius.pill,
                child: LinearProgressIndicator(
                  key: const Key('ai-usage'),
                  value: fraction,
                  minHeight: 8,
                  backgroundColor: AppColors.surfaceHigh,
                  color: allowance.exhausted ? AppColors.hot : AppColors.success,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.aiUsage(
                  (allowance.used / 1000).round(),
                  ((allowance.limit ?? 0) / 1000).round(),
                ),
                style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ] else
              Text(l10n.aiUsageUnknown,
                  style:
                      text.bodySmall?.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.sm),
            Text(
              allowance.premium && allowance.premiumUntil != null
                  ? l10n.aiPremiumUntil(MaterialLocalizations.of(context)
                      .formatMediumDate(allowance.premiumUntil!.toLocal()))
                  : l10n.aiFreeExplainer,
              style: text.bodySmall?.copyWith(color: AppColors.textTertiary),
            ),
          ],
        ],
      ),
    );
  }
}

/// Premium through the store, verified by the server.
class _PremiumCard extends ConsumerStatefulWidget {
  const _PremiumCard({required this.allowance});

  final AiAllowance allowance;

  @override
  ConsumerState<_PremiumCard> createState() => _PremiumCardState();
}

class _PremiumCardState extends ConsumerState<_PremiumCard> {
  late final Future<List<ProductDetails>> _products =
      ref.read(subscriptionServiceProvider).products();
  StreamSubscription<PurchaseOutcome>? _outcomes;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _outcomes = ref
        .read(subscriptionServiceProvider)
        .outcomes
        .listen((PurchaseOutcome outcome) {
      if (!mounted) return;
      setState(() => _busy = outcome == PurchaseOutcome.pending);
      final AppLocalizations l10n = context.l10n;
      final String? message = switch (outcome) {
        PurchaseOutcome.premium => l10n.aiPurchaseDone,
        PurchaseOutcome.notVerified => l10n.aiPurchaseNotVerified,
        PurchaseOutcome.failed => l10n.aiPurchaseFailed,
        PurchaseOutcome.pending || PurchaseOutcome.cancelled => null,
      };
      if (message != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    });
  }

  @override
  void dispose() {
    unawaited(_outcomes?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final String line in <String>[
            l10n.aiPremiumPoint1,
            l10n.aiPremiumPoint2,
            l10n.aiPremiumPoint3,
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(Icons.check, size: 18, color: AppColors.success),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(line, style: text.bodyMedium)),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          FutureBuilder<List<ProductDetails>>(
            future: _products,
            builder: (BuildContext context,
                AsyncSnapshot<List<ProductDetails>> snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              final List<ProductDetails> products =
                  snapshot.data ?? const <ProductDetails>[];
              if (widget.allowance.premium) {
                return Text(l10n.aiPremiumActive,
                    style: text.bodyMedium?.copyWith(color: AppColors.success));
              }
              if (products.isEmpty) {
                return Text(l10n.aiPremiumUnavailable,
                    style: text.bodyMedium
                        ?.copyWith(color: AppColors.textSecondary));
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (final ProductDetails product in products)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: FilledButton(
                        key: Key('buy-${product.id}'),
                        onPressed: _busy
                            ? null
                            : () async {
                                setState(() => _busy = true);
                                try {
                                  await ref
                                      .read(subscriptionServiceProvider)
                                      .buy(product);
                                } on Object {
                                  if (mounted) setState(() => _busy = false);
                                }
                              },
                        child: Text(switch (kPremiumProducts[product.id]) {
                          PremiumPeriod.monthly =>
                            l10n.aiPremiumMonthly(product.price),
                          PremiumPeriod.yearly =>
                            l10n.aiPremiumYearly(product.price),
                          null => l10n.aiPremiumBuy(product.price),
                        }),
                      ),
                    ),
                  Text(
                    l10n.aiPremiumRenewal,
                    style: text.bodySmall
                        ?.copyWith(color: AppColors.textTertiary),
                  ),
                ],
              );
            },
          ),
          TextButton(
            onPressed: _busy
                ? null
                : () => ref.read(subscriptionServiceProvider).restore(),
            child: Text(l10n.aiPremiumRestore),
          ),
          const LegalLinks(),
        ],
      ),
    );
  }
}

/// The terms and the privacy policy: next to every subscription offer, as
/// both stores require, and in the settings.
class LegalLinks extends StatelessWidget {
  const LegalLinks({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final Locale locale = Localizations.localeOf(context);
    Future<void> open(Uri uri) =>
        launchUrl(uri, mode: LaunchMode.externalApplication);
    return Wrap(
      spacing: AppSpacing.sm,
      children: <Widget>[
        TextButton(
          key: const Key('legal-terms'),
          onPressed: () => open(termsUri(locale)),
          child: Text(l10n.legalTerms),
        ),
        TextButton(
          key: const Key('legal-privacy'),
          onPressed: () => open(privacyPolicyUri(locale)),
          child: Text(l10n.legalPrivacy),
        ),
      ],
    );
  }
}

/// The user's own API key: requests go straight to the provider.
class _OwnKeyCard extends ConsumerStatefulWidget {
  const _OwnKeyCard({required this.own});

  final OwnKey? own;

  @override
  ConsumerState<_OwnKeyCard> createState() => _OwnKeyCardState();
}

class _OwnKeyCardState extends ConsumerState<_OwnKeyCard> {
  late OwnKeyProvider _provider =
      widget.own?.provider ?? OwnKeyProvider.google;
  late final TextEditingController _key =
      TextEditingController(text: widget.own?.apiKey ?? '');
  late final TextEditingController _model = TextEditingController(
      text: widget.own?.model ?? _provider.defaultModel ?? '');
  bool _testing = false;

  @override
  void dispose() {
    _key.dispose();
    _model.dispose();
    super.dispose();
  }

  OwnKey get _draft => OwnKey(
        provider: _provider,
        apiKey: _key.text.trim(),
        model: _model.text.trim(),
      );

  Future<void> _save() async {
    final AppLocalizations l10n = context.l10n;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() => _testing = true);
    // One tiny request: a key that does not work should not replace the
    // allowance silently.
    final bool works = await _test(_draft);
    if (!mounted) return;
    setState(() => _testing = false);
    if (!works) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.aiOwnKeyInvalid)));
      return;
    }
    await ref.read(ownKeyProvider.notifier).save(_draft);
    messenger.showSnackBar(SnackBar(content: Text(l10n.aiOwnKeySaved)));
  }

  Future<bool> _test(OwnKey key) async {
    if (key.apiKey.isEmpty) return false;
    try {
      final String answer = await testOwnKey(key);
      return answer.trim().isNotEmpty;
    } on Object {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          DropdownButtonFormField<OwnKeyProvider>(
            initialValue: _provider,
            decoration: InputDecoration(labelText: l10n.aiOwnKeyProvider),
            items: <DropdownMenuItem<OwnKeyProvider>>[
              for (final OwnKeyProvider p in OwnKeyProvider.values)
                DropdownMenuItem<OwnKeyProvider>(
                  value: p,
                  child: Text(l10n.aiProviderName(p.name)),
                ),
            ],
            onChanged: (OwnKeyProvider? p) {
              if (p == null) return;
              setState(() {
                _provider = p;
                _model.text = p.defaultModel ?? '';
              });
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const Key('own-key-field'),
            controller: _key,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(labelText: l10n.aiOwnKeyKey),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _model,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: l10n.aiOwnKeyModel,
              hintText: l10n.aiOwnKeyModelDefault,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              if (widget.own != null)
                TextButton(
                  onPressed: () async {
                    await ref.read(ownKeyProvider.notifier).clear();
                    _key.clear();
                  },
                  style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                  child: Text(l10n.aiOwnKeyRemove),
                ),
              const Spacer(),
              FilledButton(
                onPressed: _testing ? null : _save,
                child: _testing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.aiOwnKeySave),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Opens the AI screen when the month's free allowance is used up — called
/// wherever the app notices [AiFailure.quotaExceeded].
Future<void> showPaywall(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(context.l10n.aiPaywallTitle,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(context.l10n.aiPaywallBody,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              key: const Key('paywall-open'),
              onPressed: () {
                Navigator.of(context)
                  ..pop()
                  ..push<void>(MaterialPageRoute<void>(
                    builder: (BuildContext context) => const AiScreen(),
                  ));
              },
              child: Text(context.l10n.aiPaywallAction),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.aiPaywallLater),
            ),
          ],
        ),
      ),
    );
