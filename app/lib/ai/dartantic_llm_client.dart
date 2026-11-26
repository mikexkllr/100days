import 'dart:async';

import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:hundred_core/hundred_core.dart';

/// Why the model could not answer, as far as the user needs to know.
enum AiFailure {
  /// The month's free allowance is used up: time for the paywall.
  quotaExceeded,

  /// Premium-only feature on a free account.
  premiumOnly,

  /// Too many requests in a minute.
  rateLimited,

  /// Network, provider, anything else.
  other,
}

AiFailure classifyAiError(Object error) {
  final String text = '$error';
  if (text.contains('quota_exceeded')) return AiFailure.quotaExceeded;
  if (text.contains('premium_only')) return AiFailure.premiumOnly;
  if (text.contains('rate_limited')) return AiFailure.rateLimited;
  return AiFailure.other;
}

/// Builds the dartantic provider for one purpose. The gateway tags each
/// request with its purpose, so the provider is built per call.
typedef ProviderFactory = Provider<ChatModelOptions, EmbeddingsModelOptions,
        MediaGenerationModelOptions>
    Function(LlmPurpose purpose);

/// [LlmClient] on dartantic_ai: one implementation for the gateway and for a
/// user's own key, which differ only in the provider they are given.
class DartanticLlmClient implements LlmClient {
  DartanticLlmClient({
    required ProviderFactory provider,
    required this.modelName,
    this.chatModelName,
    this.isGoogle = true,
    this.onFailure,
  }) : _provider = provider;

  final ProviderFactory _provider;

  @override
  final String modelName;

  /// Null for the provider's default model.
  final String? chatModelName;

  /// Google models get JSON mode through `responseMimeType`; others are
  /// asked for JSON in the prompt, which the core parses defensively anyway.
  final bool isGoogle;

  /// Told about every failure, so the app can show the paywall when the
  /// allowance runs out instead of a silent fallback.
  final void Function(AiFailure failure)? onFailure;

  @override
  bool get isReady => true;

  /// An agent for [purpose], optionally with tools — what the planning chat
  /// uses directly.
  Agent agent(
    LlmPurpose purpose, {
    List<Tool>? tools,
    double? temperature,
    bool json = false,
    Map<String, Object?>? schema,
    int? maxTokens,
  }) =>
      Agent.forProvider(
        _provider(purpose),
        chatModelName: chatModelName,
        tools: tools,
        temperature: temperature,
        chatModelOptions: isGoogle
            ? GoogleChatModelOptions(
                responseMimeType: json ? 'application/json' : null,
                maxOutputTokens: maxTokens,
              )
            : null,
      );

  @override
  Future<String> generate(
    String prompt, {
    List<LlmImage> images = const <LlmImage>[],
    LlmPurpose purpose = LlmPurpose.food,
    int maxTokens = 400,
    double temperature = 0.7,
    Duration timeout = const Duration(seconds: 30),
    bool json = false,
    Map<String, Object?>? schema,
  }) async {
    try {
      final ChatResult<String> result = await agent(
        purpose,
        temperature: temperature,
        // A schema carries its own JSON mode.
        json: json && schema == null,
        maxTokens: maxTokens,
      )
          .send(
            prompt,
            attachments: <Part>[
              for (final LlmImage image in images)
                DataPart(image.bytes, mimeType: image.mimeType),
            ],
            // Structured output: Gemini constrains its answer to the schema,
            // OpenAI and Anthropic get it the way dartantic maps it for them.
            outputSchema: schema == null ? null : Schema.fromMap(schema),
          )
          .timeout(timeout);
      return result.output;
    } on Object catch (error) {
      onFailure?.call(classifyAiError(error));
      rethrow;
    }
  }
}
