// The app with demo data in memory and no sign-in, for store screenshots
// and trying the app without an account:
//
//   flutter run -t lib/main_demo.dart [--dart-define=DEMO_LOCALE=en]
//
// Nothing is sent anywhere: the feed, friends and household live in memory,
// the AI is off. The release builds use lib/main.dart and never include this.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config/backend_config.dart';
import 'data/app_repository.dart';
import 'data/household_backend.dart';
import 'data/locale_store.dart';
import 'data/notifications.dart';
import 'demo/demo_data.dart';
import 'state/household_providers.dart';
import 'state/providers.dart';
import 'package:hundred_core/hundred_core.dart';

const String _demoLocale = String.fromEnvironment('DEMO_LOCALE', defaultValue: 'de');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final BackendConfig backend = await BackendConfig.load();
  // Screens that read the client (settings) need it initialised; the demo
  // never signs in, so nothing is read or written there.
  await Supabase.initialize(
    url: backend.supabaseUrl,
    publishableKey: backend.supabaseKey,
  );
  final NotificationService notifications = NotificationService();
  await notifications.initialize();
  final LocaleStore localeStore = await LocaleStore.open();
  const Locale locale = Locale(_demoLocale);
  await localeStore.write(locale);
  final (AppRepository repository, MemoryHouseholdBackend household) =
      await seedDemo(locale);

  runApp(ProviderScope(
    overrides: <Override>[
      backendConfigProvider.overrideWithValue(backend),
      notificationsProvider.overrideWithValue(notifications),
      localeStoreProvider.overrideWithValue(localeStore),
      sessionRepositoryProvider.overrideWith((Ref ref) async => repository),
      householdBackendProvider.overrideWithValue(household),
      llmClientProvider.overrideWithValue(const UnavailableLlmClient()),
    ],
    child: const HundredDaysApp(),
  ));
}
