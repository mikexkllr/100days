import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hundred_days/data/auth_service.dart';
import 'package:hundred_days/data/locale_store.dart';
import 'package:hundred_days/l10n/l10n.dart';
import 'package:hundred_days/state/providers.dart';
import 'package:hundred_days/theme/theme.dart';
import 'package:hundred_days/ui/auth/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'helpers.dart';

/// Records what the login screen asks of Auth, and answers as told.
class _FakeAuth implements AuthService {
  _FakeAuth({this.signUpSignsIn = false, this.problem, this.googleFailure});

  final bool signUpSignsIn;
  final SignInProblem? problem;
  final SignInException? googleFailure;
  final List<String> calls = <String>[];

  @override
  Future<void> signInWithGoogle() async {
    calls.add('google');
    if (googleFailure != null) throw googleFailure!;
  }

  @override
  bool get canUseGoogle => true;

  @override
  bool get canUseApple => false;

  @override
  Future<void> signInWithEmail(String email, String password) async {
    calls.add('signIn $email');
    if (problem != null) throw SignInException(problem!);
  }

  @override
  Future<bool> signUpWithEmail(String email, String password) async {
    calls.add('signUp $email');
    if (problem != null) throw SignInException(problem!);
    return signUpSignsIn;
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    calls.add('reset $email');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<void> pump(
    WidgetTester tester,
    _FakeAuth auth, {
    Stream<String?>? signIns,
    ThemeData? theme,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authServiceProvider.overrideWithValue(auth),
          // Signed out, unless a test signs someone in.
          signedInUserProvider.overrideWith(
            (Ref ref) => signIns ?? Stream<String?>.value(null),
          ),
          ...platformFreeOverrides(),
        ],
        child: MaterialApp(
          theme: theme,
          builder: reducedMotion,
          locale: const Locale('de'),
          supportedLocales: kSupportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const LoginScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openSheet(
    WidgetTester tester, {
    String password = 'geheim123',
    bool register = false,
    String? repeat,
  }) async {
    // Below the fold: the login screen is a scrolling list.
    final Finder email = find.byKey(
      const Key('login-email'),
      skipOffstage: false,
    );
    await tester.ensureVisible(email);
    await tester.pumpAndSettle();
    await tester.tap(email);
    await tester.pumpAndSettle();
    if (register) {
      await tester.tap(find.text('Neues Konto'));
      await tester.pumpAndSettle();
    }
    await tester.enterText(
      find.byKey(const Key('login-email-address')),
      ' neu@example.com ',
    );
    await tester.enterText(
      find.byKey(const Key('login-email-password')),
      password,
    );
    if (register) {
      await tester.enterText(
        find.byKey(const Key('login-email-repeat')),
        repeat ?? password,
      );
    }
  }

  testWidgets('the email sheet offers to register', (
    WidgetTester tester,
  ) async {
    await pump(tester, _FakeAuth());
    expect(
      find.text('Mit E-Mail fortfahren', skipOffstage: false),
      findsOneWidget,
    );
    await openSheet(tester);
    expect(find.byKey(const Key('login-email-submit')), findsOneWidget);
    expect(find.text('Neues Konto'), findsOneWidget);
    await tester.tap(find.text('Neues Konto'));
    await tester.pumpAndSettle();
    expect(find.text('Mit E-Mail registrieren'), findsOneWidget);
    expect(find.byKey(const Key('login-email-repeat')), findsOneWidget);
  });

  testWidgets('two different passwords are caught before the backend', (
    WidgetTester tester,
  ) async {
    final _FakeAuth auth = _FakeAuth();
    await pump(tester, auth);
    await openSheet(tester, register: true, repeat: 'geheim124');
    await tester.tap(find.byKey(const Key('login-email-register')));
    await tester.pumpAndSettle();
    expect(auth.calls, isEmpty);
    expect(
      find.text('Die beiden Passwörter sind nicht gleich.'),
      findsOneWidget,
    );
  });

  testWidgets('a forgotten password sends a reset link', (
    WidgetTester tester,
  ) async {
    final _FakeAuth auth = _FakeAuth();
    await pump(tester, auth);
    await openSheet(tester);
    await tester.tap(find.byKey(const Key('login-forgot')));
    await tester.pumpAndSettle();
    expect(auth.calls, <String>['reset neu@example.com']);
    expect(
      find.textContaining('Link zum Setzen eines neuen Passworts'),
      findsOneWidget,
    );
  });

  testWidgets('registering asks to confirm the address when the backend does', (
    WidgetTester tester,
  ) async {
    final _FakeAuth auth = _FakeAuth();
    await pump(tester, auth);
    await openSheet(tester, register: true);
    await tester.tap(find.byKey(const Key('login-email-register')));
    await tester.pumpAndSettle();

    expect(auth.calls, <String>['signUp neu@example.com']);
    expect(find.byKey(const Key('login-email-confirm')), findsOneWidget);
    expect(find.textContaining('neu@example.com'), findsOneWidget);
  });

  testWidgets('the confirm dialog closes once the mail link signs in', (
    WidgetTester tester,
  ) async {
    final StreamController<String?> signIns = StreamController<String?>();
    addTearDown(signIns.close);
    await pump(tester, _FakeAuth(), signIns: signIns.stream);
    signIns.add(null);
    await openSheet(tester, register: true);
    await tester.tap(find.byKey(const Key('login-email-register')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-email-confirm')), findsOneWidget);

    // The link in the mail opens the app and signs the account in.
    signIns.add('new-user');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login-email-confirm')), findsNothing);
  });

  testWidgets('registering that signs in right away shows no dialog', (
    WidgetTester tester,
  ) async {
    final _FakeAuth auth = _FakeAuth(signUpSignsIn: true);
    await pump(tester, auth);
    await openSheet(tester, register: true);
    await tester.tap(find.byKey(const Key('login-email-register')));
    await tester.pumpAndSettle();

    expect(auth.calls, <String>['signUp neu@example.com']);
    expect(find.byKey(const Key('login-email-confirm')), findsNothing);
  });

  testWidgets('a short password is caught before it reaches the backend', (
    WidgetTester tester,
  ) async {
    final _FakeAuth auth = _FakeAuth();
    await pump(tester, auth);
    await openSheet(tester, password: 'kurz', register: true);
    await tester.tap(find.byKey(const Key('login-email-register')));
    await tester.pumpAndSettle();

    expect(auth.calls, isEmpty);
    expect(find.text('Mindestens 8 Zeichen.'), findsOneWidget);
  });

  testWidgets(
    'signing in still signs in, and says when the password is wrong',
    (WidgetTester tester) async {
      final _FakeAuth auth = _FakeAuth(problem: SignInProblem.wrongCredentials);
      await pump(tester, auth);
      await openSheet(tester, password: 'kurz');
      await tester.tap(find.byKey(const Key('login-email-submit')));
      await tester.pumpAndSettle();

      expect(auth.calls, <String>['signIn neu@example.com']);
      expect(find.text('E-Mail oder Passwort stimmen nicht.'), findsOneWidget);
      // The sheet stays open with what was typed: nothing to type twice.
      expect(find.byKey(const Key('login-email-password')), findsOneWidget);
      expect(find.text(' neu@example.com '), findsOneWidget);
    },
  );

  testWidgets('a failed sign-in says where it broke', (
    WidgetTester tester,
  ) async {
    await pump(
      tester,
      _FakeAuth(
        googleFailure: const SignInException(
          SignInProblem.failed,
          AuthException('Unacceptable audience', statusCode: '400'),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('login-google')));
    await tester.pump();
    expect(
      find.text(
        'Die Anmeldung hat nicht geklappt. Prüf deine Verbindung und versuch '
        'es noch einmal.\n(Server 400)',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a sign-in that never reached the server says so', (
    WidgetTester tester,
  ) async {
    await pump(
      tester,
      _FakeAuth(
        googleFailure: SignInException(
          SignInProblem.offline,
          AuthRetryableFetchException(message: 'SocketException'),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('login-google')));
    await tester.pump();
    expect(
      find.text(
        'Keine Verbindung zum Server. Prüf WLAN oder mobile Daten und versuch '
        'es noch einmal.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('an address that already has an account is told so', (
    WidgetTester tester,
  ) async {
    await pump(tester, _FakeAuth(problem: SignInProblem.emailTaken));
    await openSheet(tester, register: true);
    await tester.tap(find.byKey(const Key('login-email-register')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Mit dieser E-Mail gibt es schon ein Konto. Melde dich damit an.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('the own-server sheet lays out with the app theme', (
    WidgetTester tester,
  ) async {
    // The theme makes filled buttons as wide as they may be; next to a
    // spacer in a row that is infinitely wide and fails to lay out.
    await pump(tester, _FakeAuth(), theme: buildAppTheme());
    final Finder ownServer = find.byKey(
      const Key('login-own-server'),
      skipOffstage: false,
    );
    await tester.ensureVisible(ownServer);
    await tester.pumpAndSettle();
    await tester.tap(ownServer);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.widgetWithText(FilledButton, 'Speichern'), findsOneWidget);
  });
}
