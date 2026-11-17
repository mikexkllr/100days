import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:http/http.dart' as http;
import 'package:hundred_core/hundred_core.dart';

/// The one model the app uses for everything. It must also be on the
/// gateway's allowlist (`supabase/functions/llm-gateway/gateway.ts`) —
/// deploy the gateway first when changing it.
const String kAiModel = 'gemini-3.5-flash-lite';

/// Returns the signed-in user's access token, refreshed if it expired.
typedef AccessTokenProvider = Future<String?> Function();

/// HTTP client for the `llm-gateway` edge function: signs every request with
/// the user's own access token and tags it with what it is for.
///
/// The provider's API key never reaches the app — the gateway adds it.
class GatewayHttpClient extends http.BaseClient {
  GatewayHttpClient({
    required AccessTokenProvider accessToken,
    required String publishableKey,
    required this.purpose,
    http.Client? inner,
  })  : _accessToken = accessToken,
        _publishableKey = publishableKey,
        _inner = inner ?? http.Client();

  final AccessTokenProvider _accessToken;
  final String _publishableKey;
  final http.Client _inner;
  final LlmPurpose purpose;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final String? token = await _accessToken();
    if (token == null) {
      throw StateError('Not signed in — the AI gateway needs a session');
    }
    request.headers
      ..remove('x-goog-api-key')
      ..['Authorization'] = 'Bearer $token'
      ..['apikey'] = _publishableKey
      ..['x-hundred-purpose'] = purpose.name;
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}

/// dartantic's Google provider, pointed at the gateway. It speaks the native
/// Gemini protocol, so images, tool calls and JSON output work unchanged.
class GatewayProvider extends GoogleProvider {
  GatewayProvider({required Uri baseUrl, required http.Client client})
      : _client = client,
        // The provider insists on a key; the gateway ignores this placeholder.
        super(apiKey: 'gateway', baseUrl: baseUrl);

  final http.Client _client;

  /// `<supabase url>/functions/v1/llm-gateway/v1beta`
  static Uri baseUrlFor(String supabaseUrl) => Uri.parse(
      '${supabaseUrl.replaceAll(RegExp(r'/+$'), '')}/functions/v1/llm-gateway/v1beta');

  @override
  ChatModel<GoogleChatModelOptions> createChatModel({
    String? name,
    List<Tool>? tools,
    double? temperature,
    bool enableThinking = false,
    GoogleChatModelOptions? options,
  }) {
    return GoogleChatModel(
      name: name ?? kAiModel,
      apiKey: apiKey!,
      baseUrl: baseUrl!,
      client: _client,
      tools: tools,
      temperature: temperature,
      enableThinking: enableThinking,
      defaultOptions: options ?? const GoogleChatModelOptions(),
    );
  }
}
