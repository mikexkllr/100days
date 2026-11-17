// LLM gateway — a thin, authenticated pass-through to the Gemini REST API.
//
//   POST /llm-gateway/v1beta/models/<model>:generateContent
//   POST /llm-gateway/v1beta/models/<model>:streamGenerateContent?alt=sse
//
// The app points dartantic_ai's Google provider at this URL. The gateway
// hides the API key, allows only the app's model and text, tool and image
// traffic, and enforces each user's monthly allowance and a per-minute
// request window (see _shared/ai_guard.ts). Header `x-hundred-purpose:
// coach | food | plan | chat` says what a request is for.
//
// Secrets: GEMINI_API_KEY (required); FREE_AI_TOKENS_PER_MONTH,
// PREMIUM_AI_TOKENS_PER_MONTH, AI_REQUESTS_PER_MINUTE (optional).

import { authenticate, beginRequest, recordUsage, runInBackground } from '../_shared/ai_guard.ts';
import { createGatewayHandler } from './handler.ts';

Deno.serve(createGatewayHandler({
  apiKey: Deno.env.get('GEMINI_API_KEY'),
  authenticate,
  beginRequest,
  recordUsage,
  runInBackground,
  fetch,
}));
