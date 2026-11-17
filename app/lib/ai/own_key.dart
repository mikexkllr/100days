import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Providers a user can bring their own key for.
enum OwnKeyProvider {
  google('gemini-3.5-flash-lite'),
  anthropic('claude-haiku-5-5'),
  openai(null);

  const OwnKeyProvider(this.defaultModel);

  /// What the model field is prefilled with — the cheapest current model
  /// the app was checked against. Null leaves the choice to dartantic's
  /// default for that provider. The user can type any model it offers.
  final String? defaultModel;
}

/// The user's own API key: requests go straight from the phone to the
/// provider, past the project's gateway and its allowance. Stored in the
/// platform's keychain, never in the feed, never on the server.
class OwnKey {
  const OwnKey({
    required this.provider,
    required this.apiKey,
    required this.model,
  });

  final OwnKeyProvider provider;
  final String apiKey;

  /// Empty for the provider's default.
  final String model;

  /// dartantic's provider for this key.
  Provider<ChatModelOptions, EmbeddingsModelOptions, MediaGenerationModelOptions>
      toProvider() => switch (provider) {
            OwnKeyProvider.google => GoogleProvider(apiKey: apiKey),
            OwnKeyProvider.anthropic => AnthropicProvider(apiKey: apiKey),
            OwnKeyProvider.openai => OpenAIProvider(apiKey: apiKey),
          };
}

class OwnKeyStore {
  OwnKeyStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const String _providerKey = 'ai.own.provider';
  static const String _apiKeyKey = 'ai.own.key';
  static const String _modelKey = 'ai.own.model';

  Future<OwnKey?> read() async {
    final String? provider = await _storage.read(key: _providerKey);
    final String? apiKey = await _storage.read(key: _apiKeyKey);
    if (provider == null || apiKey == null || apiKey.isEmpty) return null;
    final OwnKeyProvider? which =
        OwnKeyProvider.values.asNameMap()[provider];
    if (which == null) return null;
    return OwnKey(
      provider: which,
      apiKey: apiKey,
      model: await _storage.read(key: _modelKey) ?? which.defaultModel ?? '',
    );
  }

  Future<void> write(OwnKey key) async {
    await _storage.write(key: _providerKey, value: key.provider.name);
    await _storage.write(key: _apiKeyKey, value: key.apiKey.trim());
    await _storage.write(key: _modelKey, value: key.model.trim());
  }

  Future<void> clear() async {
    await _storage.delete(key: _providerKey);
    await _storage.delete(key: _apiKeyKey);
    await _storage.delete(key: _modelKey);
  }
}

/// Sends one tiny request with [key] — a key that does not work should not
/// replace the account's allowance unnoticed.
Future<String> testOwnKey(OwnKey key) async {
  final ChatResult<String> result = await Agent.forProvider(
    key.toProvider(),
    chatModelName: key.model.isEmpty ? null : key.model,
  ).send('Reply with the single word OK.').timeout(const Duration(seconds: 20));
  return result.output;
}
