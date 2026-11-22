import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/backend_config.dart';

/// Why a sign-in did not go through.
enum SignInProblem {
  /// The user closed the sheet. Not an error worth showing.
  cancelled,

  /// The provider is not set up for this backend (no client id).
  notConfigured,

  /// E-mail sign-in: no account with this address and password.
  wrongCredentials,

  /// E-mail sign-in before the link in the confirmation mail was opened.
  emailNotConfirmed,

  /// E-mail sign-up for an address that already has an account.
  emailTaken,

  /// E-mail sign-up with a password the backend refuses as too weak.
  weakPassword,

  /// Anything else: network, the provider, the backend.
  failed,
}

/// The user closed Apple's confirmation sheet while deleting the account.
class AccountDeletionCancelled implements Exception {
  const AccountDeletionCancelled();
}

class SignInException implements Exception {
  const SignInException(this.problem, [this.cause]);

  final SignInProblem problem;
  final Object? cause;

  @override
  String toString() => 'SignInException(${problem.name}: $cause)';
}

/// Sign-in with Google and Apple, through the platform's own sheets, or with
/// e-mail and password.
///
/// The native sheet hands back an ID token, which Supabase Auth verifies
/// against the provider and turns into a session. A random nonce goes into
/// the provider request in hashed form and to Supabase in the clear, which
/// binds the token to this one sign-in — a token lifted from somewhere else
/// cannot be replayed.
///
/// There is no anonymous mode: the AI allowance is per account, and
/// anonymous accounts would let a script mint a fresh allowance per request.
class AuthService {
  AuthService(this._client, this._config);

  /// Where the link in the sign-up confirmation mail leads: back into the
  /// app, which turns it into a session. Opened anywhere else, the link
  /// still confirms the address, and the user signs in by hand.
  static const String emailRedirect = 'hundreddays://login-callback';

  final SupabaseClient _client;
  final BackendConfig _config;
  bool _googleReady = false;
  String? _googleRawNonce;

  Session? get session => _client.auth.currentSession;

  Stream<AuthState> get changes => _client.auth.onAuthStateChange;

  bool get canUseGoogle => _config.hasGoogleSignIn;

  /// Apple's native sheet exists on iOS (and macOS). On Android it would be
  /// a web flow that needs a services id and a rotating secret; Google
  /// covers Android.
  bool get canUseApple => Platform.isIOS || Platform.isMacOS;

  Future<void> signInWithGoogle() async {
    if (!canUseGoogle) throw const SignInException(SignInProblem.notConfigured);
    try {
      if (!_googleReady) {
        _googleRawNonce = _randomNonce();
        await GoogleSignIn.instance.initialize(
          clientId: _config.googleIosClientId.isEmpty
              ? null
              : _config.googleIosClientId,
          serverClientId: _config.googleWebClientId,
          nonce: _sha256(_googleRawNonce!),
        );
        _googleReady = true;
      }
      final GoogleSignInAccount account =
          await GoogleSignIn.instance.authenticate();
      final String? idToken = account.authentication.idToken;
      if (idToken == null) {
        throw const SignInException(SignInProblem.failed, 'no id token');
      }
      await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        nonce: _googleRawNonce,
      );
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw SignInException(SignInProblem.cancelled, error);
      }
      throw SignInException(SignInProblem.failed, error);
    } on SignInException {
      rethrow;
    } on Object catch (error) {
      throw SignInException(SignInProblem.failed, error);
    }
  }

  Future<void> signInWithApple() async {
    if (!canUseApple) throw const SignInException(SignInProblem.notConfigured);
    final String rawNonce = _randomNonce();
    try {
      final AuthorizationCredentialAppleID credential =
          await SignInWithApple.getAppleIDCredential(
        scopes: <AppleIDAuthorizationScopes>[
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: _sha256(rawNonce),
      );
      final String? idToken = credential.identityToken;
      if (idToken == null) {
        throw const SignInException(SignInProblem.failed, 'no identity token');
      }
      await _client.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );
      // Apple sends the name only on the very first sign-in, and never in
      // the token: keep it, or the profile stays nameless.
      final String? given = credential.givenName;
      if (given != null && given.isNotEmpty) {
        await _client.auth.updateUser(UserAttributes(
          data: <String, dynamic>{'given_name': given},
        ));
        await _client
            .from('profiles')
            .update(<String, dynamic>{'display_name': given})
            .eq('id', _client.auth.currentUser!.id)
            .eq('display_name', '');
      }
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) {
        throw SignInException(SignInProblem.cancelled, error);
      }
      throw SignInException(SignInProblem.failed, error);
    } on SignInException {
      rethrow;
    } on Object catch (error) {
      throw SignInException(SignInProblem.failed, error);
    }
  }

  /// E-mail and password, for accounts made with [signUpWithEmail] and the
  /// demo accounts the stores' reviewers get.
  Future<void> signInWithEmail(String email, String password) async {
    try {
      await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
    } on AuthException catch (error) {
      throw SignInException(_emailProblem(error), error);
    } on Object catch (error) {
      throw SignInException(SignInProblem.failed, error);
    }
  }

  /// Creates an account with e-mail and password. Returns true when the
  /// account is signed in right away, false when the backend wants the
  /// address confirmed first: it sent a mail with a link, and the user signs
  /// in once they opened it.
  Future<bool> signUpWithEmail(String email, String password) async {
    final AuthResponse response;
    try {
      response = await _client.auth.signUp(
        email: email.trim(),
        password: password,
        emailRedirectTo: emailRedirect,
      );
    } on AuthException catch (error) {
      throw SignInException(_emailProblem(error), error);
    } on Object catch (error) {
      throw SignInException(SignInProblem.failed, error);
    }
    if (response.session != null) return true;
    // With confirmations on, an address that already has an account comes
    // back as a user without identities instead of an error, and no mail is
    // sent. Waiting for that mail would be waiting forever.
    if (response.user?.identities?.isEmpty ?? false) {
      throw const SignInException(SignInProblem.emailTaken);
    }
    return false;
  }

  static SignInProblem _emailProblem(AuthException error) {
    if (error is AuthWeakPasswordException) return SignInProblem.weakPassword;
    return switch (error.code) {
      'invalid_credentials' => SignInProblem.wrongCredentials,
      'email_not_confirmed' => SignInProblem.emailNotConfirmed,
      'user_already_exists' || 'email_exists' => SignInProblem.emailTaken,
      'weak_password' => SignInProblem.weakPassword,
      _ => SignInProblem.failed,
    };
  }

  /// Sends a link to set a new password. Says nothing about whether the
  /// address has an account — that is nobody's business but its owner's.
  Future<void> sendPasswordReset(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: emailRedirect,
      );
    } on AuthException catch (error) {
      if (error.statusCode == '429') {
        throw const SignInException(SignInProblem.failed);
      }
      // Unknown addresses and the like: the same answer as success.
    }
  }

  /// Sets a new password for the signed-in account — after the link from
  /// [sendPasswordReset] opened the app.
  Future<void> updatePassword(String password) async {
    try {
      await _client.auth.updateUser(UserAttributes(password: password));
    } on AuthException catch (error) {
      throw SignInException(_emailProblem(error));
    }
  }

  /// Fires when a password-reset link has signed the user in, so the app
  /// can ask for the new password.
  Stream<void> get passwordRecoveries => _client.auth.onAuthStateChange
      .where((AuthState s) => s.event == AuthChangeEvent.passwordRecovery)
      .map((AuthState _) {});

  /// Whether the session came from Sign in with Apple — deleting it asks
  /// Apple once more.
  bool get signedInWithApple =>
      _client.auth.currentUser?.appMetadata['provider'] == 'apple' &&
      canUseApple;

  Future<void> signOut() async {
    try {
      if (_googleReady) await GoogleSignIn.instance.signOut();
    } on Object {
      // Signing out of Supabase is what matters.
    }
    await _client.auth.signOut();
  }

  /// Deletes the account and everything in it on the server, through the
  /// `delete-account` function (it needs the service role, which the app
  /// never has). On iOS the user confirms with Apple once more, so the
  /// function can revoke the app's access to their Apple ID as Apple
  /// requires.
  Future<void> deleteAccount() async {
    String? appleCode;
    final bool viaApple = _client.auth.currentUser?.appMetadata['provider'] ==
        'apple';
    if (viaApple && canUseApple) {
      try {
        final AuthorizationCredentialAppleID credential =
            await SignInWithApple.getAppleIDCredential(
          scopes: const <AppleIDAuthorizationScopes>[],
        );
        appleCode = credential.authorizationCode;
      } on SignInWithAppleAuthorizationException catch (error) {
        // Closing Apple's sheet means "not now", not "delete anyway".
        if (error.code == AuthorizationErrorCode.canceled) {
          throw const AccountDeletionCancelled();
        }
      } on Object {
        // Without the code the account is still deleted; only the
        // revocation at Apple is skipped, and the function logs it.
      }
    }
    final FunctionResponse response = await _client.functions.invoke(
      'delete-account',
      body: <String, dynamic>{
        if (appleCode != null) 'appleAuthorizationCode': appleCode,
      },
    );
    if (response.status != 200) {
      throw StateError('delete-account failed: ${response.status}');
    }
    // The caller signs out once it has forgotten everything on this phone:
    // signing out here would close the local store under its feet.
  }

  static String _randomNonce([int length = 32]) {
    const String charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final Random random = Random.secure();
    return List<String>.generate(
        length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  static String _sha256(String input) =>
      sha256.convert(utf8.encode(input)).toString();
}
