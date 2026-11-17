import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hundred_core/hundred_core.dart';

import '../../config/backend_config.dart';
import '../../data/auth_service.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/theme.dart';
import '../mascot/flame_mascot.dart';
import '../mascot/speech_bubble.dart';
import '../widgets/juicy_button.dart';

/// The front door: sign in with Apple or Google. Nothing else is asked for —
/// name and face come next, in onboarding.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _busy = false;

  Future<void> _signIn(Future<void> Function(AuthService auth) method) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await method(ref.read(authServiceProvider));
    } on SignInException catch (error) {
      if (!mounted || error.problem == SignInProblem.cancelled) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error.problem == SignInProblem.notConfigured
            ? context.l10n.loginNotConfigured
            : context.l10n.loginFailed),
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AuthService auth = ref.watch(authServiceProvider);
    final BackendConfig backend = ref.watch(backendConfigProvider);
    final TextTheme text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.lg),
          children: <Widget>[
            Center(
              child: Column(
                children: <Widget>[
                  SpeechBubble(text: l10n.obWelcomeMascot),
                  FlameMascot(
                    stage: FlameStage.spark,
                    mood: MascotMood.happy,
                    size: 150,
                    onPoke: (_) {},
                    semanticLabel: l10n.mascotSemantics,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(l10n.obWelcomeTitle, style: text.headlineSmall),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.loginSubtitle,
              style: text.bodyLarge?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (auth.canUseApple) ...<Widget>[
              JuicyButton(
                key: const Key('login-apple'),
                label: l10n.loginApple,
                icon: Icons.apple,
                onPressed: _busy
                    ? null
                    : () => _signIn((AuthService a) => a.signInWithApple()),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (auth.canUseGoogle)
              JuicyButton(
                key: const Key('login-google'),
                label: l10n.loginGoogle,
                icon: Icons.g_mobiledata,
                gradient: AppGradients.cool,
                lipColor: const Color(0xFF4F9CC2),
                onPressed: _busy
                    ? null
                    : () => _signIn((AuthService a) => a.signInWithGoogle()),
              ),
            if (!auth.canUseApple && !auth.canUseGoogle)
              Text(
                l10n.loginNotConfigured,
                style: text.bodyMedium?.copyWith(color: AppColors.attention),
              ),
            if (_busy) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              const Center(child: CircularProgressIndicator()),
            ],
            const SizedBox(height: AppSpacing.xl),
            Text(
              l10n.loginPrivacy,
              style: text.bodySmall?.copyWith(color: AppColors.textTertiary),
            ),
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('login-own-server'),
                onPressed: _busy ? null : () => _ownServer(backend),
                icon: const Icon(Icons.dns_outlined, size: 18),
                label: Text(backend.isCustom
                    ? l10n.loginOwnServerActive(
                        Uri.tryParse(backend.supabaseUrl)?.host ??
                            backend.supabaseUrl)
                    : l10n.loginOwnServer),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _ownServer(BackendConfig current) async {
    final bool? changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => _OwnServerSheet(current: current),
    );
    if (changed == true && mounted) {
      await showDialog<void>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          content: Text(context.l10n.loginOwnServerRestart),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.actionOk),
            ),
          ],
        ),
      );
    }
  }
}

/// Points this install at a self-hosted backend (docs/self-hosting.md).
class _OwnServerSheet extends StatefulWidget {
  const _OwnServerSheet({required this.current});

  final BackendConfig current;

  @override
  State<_OwnServerSheet> createState() => _OwnServerSheetState();
}

class _OwnServerSheetState extends State<_OwnServerSheet> {
  late final TextEditingController _url = TextEditingController(
      text: widget.current.isCustom ? widget.current.supabaseUrl : '');
  late final TextEditingController _key = TextEditingController(
      text: widget.current.isCustom ? widget.current.supabaseKey : '');
  late final TextEditingController _google = TextEditingController(
      text: widget.current.isCustom ? widget.current.googleWebClientId : '');

  @override
  void dispose() {
    _url.dispose();
    _key.dispose();
    _google.dispose();
    super.dispose();
  }

  bool get _valid {
    final Uri? uri = Uri.tryParse(_url.text.trim());
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        _key.text.trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg,
          MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l10n.loginOwnServer,
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(l10n.loginOwnServerBody,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            autocorrect: false,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
                labelText: 'Supabase URL', hintText: 'https://…'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _key,
            autocorrect: false,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: l10n.loginOwnServerKey),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _google,
            autocorrect: false,
            decoration:
                InputDecoration(labelText: l10n.loginOwnServerGoogle),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: <Widget>[
              if (widget.current.isCustom)
                TextButton(
                  onPressed: () async {
                    await BackendConfig.clearCustom();
                    if (context.mounted) Navigator.of(context).pop(true);
                  },
                  child: Text(l10n.loginOwnServerReset),
                ),
              const Spacer(),
              FilledButton(
                onPressed: !_valid
                    ? null
                    : () async {
                        await BackendConfig.saveCustom(
                          supabaseUrl: _url.text,
                          supabaseKey: _key.text,
                          googleWebClientId: _google.text,
                        );
                        if (context.mounted) Navigator.of(context).pop(true);
                      },
                child: Text(l10n.actionSave),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
