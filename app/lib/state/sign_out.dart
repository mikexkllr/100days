import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/push_service.dart';
import 'providers.dart';

/// Forgets everything of the signed-in account that lives on this phone
/// outside its feed cache: the push registration, the scheduled reminders,
/// the home screen widget and the user's own API key — then the cache, then
/// the session. The next person to sign in on this phone starts clean.
///
/// Each step is best effort: a phone without a network still signs out.
Future<void> forgetThisPhoneAndSignOut(WidgetRef ref) async {
  Future<void> attempt(Future<void> Function() step) async {
    try {
      await step();
    } on Object {
      // Keep going: the remaining steps matter more than this one.
    }
  }

  await attempt(() => PushService.stop(ref.read(supabaseClientProvider)));
  await attempt(() => ref.read(notificationsProvider).cancelAll());
  await attempt(() => ref.read(streakWidgetProvider).clear());
  await attempt(() => ref.read(ownKeyProvider.notifier).clear());
  await attempt(() => ref.read(repositoryProvider).clearLocal());
  await ref.read(authServiceProvider).signOut();
}
