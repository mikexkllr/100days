import 'package:shared_preferences/shared_preferences.dart';

/// Where the app's backend lives.
///
/// The defaults point at the project's own Supabase instance. Both values are
/// public by design — every installed app carries them, and Row Level
/// Security on the server decides what a signed-in user may read and write.
/// No secret ever ships in the app: the AI provider's key, the payment
/// credentials and the service role key live in the backend's secrets.
///
/// Anyone can run their own backend (see docs/self-hosting.md) and point a
/// build at it, either at build time:
///
/// ```bash
/// flutter run --dart-define-from-file=config/my-backend.json
/// ```
///
/// or at run time, on the sign-in screen under "Own server", which is
/// remembered on the device.
class BackendConfig {
  const BackendConfig({
    required this.supabaseUrl,
    required this.supabaseKey,
    this.googleWebClientId = kDefaultGoogleWebClientId,
    this.googleIosClientId = kDefaultGoogleIosClientId,
    this.isCustom = false,
  });

  /// The project's own backend, unless the build says otherwise.
  static const BackendConfig defaults = BackendConfig(
    supabaseUrl: kDefaultSupabaseUrl,
    supabaseKey: kDefaultSupabaseKey,
  );

  final String supabaseUrl;

  /// The publishable (or legacy anon) key of that project.
  final String supabaseKey;

  /// OAuth client ids for Google sign-in. Public identifiers, not secrets:
  /// the web client id is what Supabase checks the ID token's audience
  /// against, the iOS one is what the native sheet runs as.
  final String googleWebClientId;
  final String googleIosClientId;

  /// True when the user pointed this install at a backend of their own.
  final bool isCustom;

  bool get hasGoogleSignIn => googleWebClientId.isNotEmpty;

  static const String _urlKey = 'backend.url';
  static const String _keyKey = 'backend.key';
  static const String _googleWebKey = 'backend.googleWeb';
  static const String _googleIosKey = 'backend.googleIos';

  /// The backend this install uses: a custom one if the user set it up,
  /// otherwise the build's defaults.
  static Future<BackendConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(_urlKey);
    final key = prefs.getString(_keyKey);
    if (url == null || key == null || url.isEmpty || key.isEmpty) {
      return defaults;
    }
    return BackendConfig(
      supabaseUrl: url,
      supabaseKey: key,
      googleWebClientId: prefs.getString(_googleWebKey) ?? '',
      googleIosClientId: prefs.getString(_googleIosKey) ?? '',
      isCustom: true,
    );
  }

  /// Remembers a custom backend. Takes effect on the next start.
  static Future<void> saveCustom({
    required String supabaseUrl,
    required String supabaseKey,
    String googleWebClientId = '',
    String googleIosClientId = '',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_urlKey, supabaseUrl.trim());
    await prefs.setString(_keyKey, supabaseKey.trim());
    await prefs.setString(_googleWebKey, googleWebClientId.trim());
    await prefs.setString(_googleIosKey, googleIosClientId.trim());
  }

  /// Back to the build's default backend.
  static Future<void> clearCustom() async {
    final prefs = await SharedPreferences.getInstance();
    for (final String key in <String>[
      _urlKey,
      _keyKey,
      _googleWebKey,
      _googleIosKey,
    ]) {
      await prefs.remove(key);
    }
  }

  /// `https://<ref>.supabase.co` → `https://<ref>.supabase.co/functions/v1`
  Uri functionsUri(String path) => Uri.parse(
      '${supabaseUrl.replaceAll(RegExp(r'/+$'), '')}/functions/v1/$path');
}

/// The project's hosted Supabase instance.
const String kDefaultSupabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://kbbfbtevxsfnomvmniyb.supabase.co',
);

/// Publishable key of that instance — safe to ship, see [BackendConfig].
const String kDefaultSupabaseKey = String.fromEnvironment(
  'SUPABASE_KEY',
  defaultValue: 'sb_publishable_uFEHsxoudTMHIuhM8HOayA_6qCrYYFi',
);

/// Google OAuth client ids of the hosted instance. Empty until they are set
/// up in Google Cloud (docs/self-hosting.md); the sign-in screen then hides
/// the Google button rather than offering one that cannot work.
const String kDefaultGoogleWebClientId =
    String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
const String kDefaultGoogleIosClientId =
    String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

/// Where invite links point. Opens the app through its URL scheme.
const String kInviteScheme = 'hundreddays';
