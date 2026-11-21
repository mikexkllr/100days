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

/// The front door: sign in with Apple or Google, or with e-mail and a
/// password. Nothing else is asked for — name and face come next, in
/// onboarding.
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
      final AppLocalizations l10n = context.l10n;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(switch (error.problem) {
          SignInProblem.notConfigured => l10n.loginNotConfigured,
          SignInProblem.wrongCredentials => l10n.loginWrongCredentials,
          SignInProblem.emailNotConfirmed => l10n.loginEmailNotConfirmed,
          SignInProblem.emailTaken => l10n.loginEmailTaken,
          SignInProblem.weakPassword => l10n.loginWeakPassword,
          SignInProblem.cancelled || SignInProblem.failed => l10n.loginFailed,
        }),
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
                key: const Key('login-email'),
                onPressed: _busy ? null : _emailSignIn,
                icon: const Icon(Icons.mail_outline, size: 18),
                label: Text(l10n.loginEmail),
              ),
            ),
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

  Future<void> _emailSignIn() async {
    final _EmailRequest? request = await showModalBottomSheet<_EmailRequest>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => const _EmailSheet(),
    );
    if (request == null || !mounted) return;
    if (!request.register) {
      await _signIn(
          (AuthService a) => a.signInWithEmail(request.email, request.password));
      return;
    }
    bool? signedIn;
    await _signIn((AuthService a) async {
      signedIn = await a.signUpWithEmail(request.email, request.password);
    });
    // Signed in: the app moves on to onboarding by itself. Otherwise the
    // address needs confirming first.
    if (signedIn != false || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) =>
          _ConfirmEmailDialog(email: request.email),
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

/// What the e-mail sheet hands back: sign in, or make a new account.
/// Asks to confirm the address. The link in the mail signs the account in
/// and the app moves on to onboarding underneath; the dialog closes itself
/// then instead of sitting on top of it.
class _ConfirmEmailDialog extends ConsumerWidget {
  const _ConfirmEmailDialog({required this.email});

  final String email;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<String?>>(signedInUserProvider,
        (AsyncValue<String?>? previous, AsyncValue<String?> next) {
      if (next.valueOrNull != null) Navigator.of(context).pop();
    });
    return AlertDialog(
      key: const Key('login-email-confirm'),
      title: Text(context.l10n.loginEmailConfirmTitle),
      content: Text(context.l10n.loginEmailConfirmBody(email)),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.actionOk),
        ),
      ],
    );
  }
}

typedef _EmailRequest = ({String email, String password, bool register});

/// E-mail and password: sign in, or register a new account with them.
class _EmailSheet extends StatefulWidget {
  const _EmailSheet();

  /// New accounts need at least this many characters. The backend may ask
  /// for more; it says so, and the login screen passes that on.
  static const int minPasswordLength = 8;

  @override
  State<_EmailSheet> createState() => _EmailSheetState();
}

class _EmailSheetState extends State<_EmailSheet> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _passwordTooShort = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit({required bool register}) {
    final String email = _email.text.trim();
    if (email.isEmpty || _password.text.isEmpty) return;
    if (register && _password.text.length < _EmailSheet.minPasswordLength) {
      setState(() => _passwordTooShort = true);
      return;
    }
    Navigator.of(context)
        .pop((email: email, password: _password.text, register: register));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg,
          AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(l10n.loginEmail, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.loginEmailHint,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const Key('login-email-address'),
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            autofillHints: const <String>[AutofillHints.email],
            decoration: InputDecoration(labelText: l10n.loginEmailAddress),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const Key('login-email-password'),
            controller: _password,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            autofillHints: const <String>[AutofillHints.password],
            onChanged: (_) {
              if (_passwordTooShort) setState(() => _passwordTooShort = false);
            },
            decoration: InputDecoration(
              labelText: l10n.loginPassword,
              errorText: _passwordTooShort
                  ? l10n.loginPasswordTooShort(_EmailSheet.minPasswordLength)
                  : null,
            ),
            onSubmitted: (_) => _submit(register: false),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            key: const Key('login-email-submit'),
            onPressed: () => _submit(register: false),
            child: Text(l10n.loginEmailSubmit),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            key: const Key('login-email-register'),
            onPressed: () => _submit(register: true),
            child: Text(l10n.loginEmailRegister),
          ),
        ],
      ),
    );
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
