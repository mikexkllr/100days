import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hundred_days/data/auth_service.dart';
import 'package:hundred_days/data/locale_store.dart';
import 'package:hundred_days/l10n/l10n.dart';
import 'package:hundred_days/state/providers.dart';
import 'package:hundred_days/ui/auth/login_screen.dart';

import 'helpers.dart';

/// Records what the login screen asks of Auth, and answers as told.
class _FakeAuth implements AuthService {
  _FakeAuth({this.signUpSignsIn = false, this.problem});

  final bool signUpSignsIn;
  final SignInProblem? problem;
  final List<String> calls = <String>[];

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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<void> pump(WidgetTester tester, _FakeAuth auth) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authServiceProvider.overrideWithValue(auth),
          ...platformFreeOverrides(),
        ],
        child: const MaterialApp(
          builder: reducedMotion,
          locale: Locale('de'),
          supportedLocales: kSupportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: LoginScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openSheet(
    WidgetTester tester, {
    String password = 'geheim123',
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
    await tester.enterText(
      find.byKey(const Key('login-email-address')),
      ' neu@example.com ',
    );
    await tester.enterText(
      find.byKey(const Key('login-email-password')),
      password,
    );
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
    expect(find.text('Anmelden'), findsOneWidget);
    expect(find.text('Mit E-Mail registrieren'), findsOneWidget);
  });

  testWidgets('registering asks to confirm the address when the backend does', (
    WidgetTester tester,
  ) async {
    final _FakeAuth auth = _FakeAuth();
    await pump(tester, auth);
    await openSheet(tester);
    await tester.tap(find.byKey(const Key('login-email-register')));
    await tester.pumpAndSettle();

    expect(auth.calls, <String>['signUp neu@example.com']);
    expect(find.byKey(const Key('login-email-confirm')), findsOneWidget);
    expect(find.textContaining('neu@example.com'), findsOneWidget);
  });

  testWidgets('registering that signs in right away shows no dialog', (
    WidgetTester tester,
  ) async {
    final _FakeAuth auth = _FakeAuth(signUpSignsIn: true);
    await pump(tester, auth);
    await openSheet(tester);
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
    await openSheet(tester, password: 'kurz');
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
    },
  );

  testWidgets('an address that already has an account is told so', (
    WidgetTester tester,
  ) async {
    await pump(tester, _FakeAuth(problem: SignInProblem.emailTaken));
    await openSheet(tester);
    await tester.tap(find.byKey(const Key('login-email-register')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Mit dieser E-Mail gibt es schon ein Konto. Melde dich damit an.',
      ),
      findsOneWidget,
    );
  });
}
