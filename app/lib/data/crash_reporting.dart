import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Whether [error] is the world failing rather than the app: no
/// connection, a timeout, a server out of reach, or a sign-in the server
/// refused. The screens tell the user about those; they are not bugs, and
/// reporting them would bury the real ones.
bool isExpectedFailure(Object error) =>
    error is SocketException ||
    error is TimeoutException ||
    error is HandshakeException ||
    error is http.ClientException ||
    error is AuthException;

/// Reports what a provider failed with, unless it was expected.
///
/// Riverpod catches what a provider throws and hands it to the screen as
/// an error state, so without this Sentry would never hear of it. Does
/// nothing in a build without Sentry: there the calls are no-ops.
class CrashReportingObserver extends ProviderObserver {
  const CrashReportingObserver();

  @override
  void providerDidFail(
    ProviderBase<Object?> provider,
    Object error,
    StackTrace stackTrace,
    ProviderContainer container,
  ) {
    if (isExpectedFailure(error)) return;
    unawaited(Sentry.captureException(
      error,
      stackTrace: stackTrace,
      withScope: (Scope scope) => scope.setTag(
        'provider',
        provider.name ?? provider.runtimeType.toString(),
      ),
    ));
  }
}
