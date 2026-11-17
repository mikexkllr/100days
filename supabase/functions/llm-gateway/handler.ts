// Request handler of the LLM gateway, with its I/O injected (index.ts wires
// production, handler_test.ts tests).

import { type GuardedUser, type Purpose, purposeOf } from '../_shared/ai_guard.ts';
import { corsHeaders, HttpError } from '../_shared/supabase.ts';
import {
  assertModelAllowed,
  geminiError,
  MAX_BODY_BYTES,
  parseRoute,
  sanitizeGenerateRequest,
  tapSseUsage,
  totalTokensOf,
} from './gateway.ts';

export interface GatewayDeps {
  apiKey: string | undefined;
  authenticate: (req: Request) => Promise<GuardedUser>;
  beginRequest: (user: GuardedUser, purpose: Purpose) => Promise<void>;
  recordUsage: (user: GuardedUser, tokens: number) => Promise<void>;
  runInBackground: (promise: Promise<unknown>) => void;
  fetch: typeof fetch;
  geminiBaseUrl?: string;
}

async function readJson(req: Request): Promise<unknown> {
  const text = await req.text();
  if (new TextEncoder().encode(text).length > MAX_BODY_BYTES) {
    throw new HttpError(413, 'request_too_large');
  }
  try {
    return JSON.parse(text);
  } catch {
    throw new HttpError(400, 'invalid_json');
  }
}

export function createGatewayHandler(deps: GatewayDeps): (req: Request) => Promise<Response> {
  const geminiBaseUrl = deps.geminiBaseUrl ?? 'https://generativelanguage.googleapis.com/v1beta';

  return async (req) => {
    if (req.method === 'OPTIONS') return new Response(null, { headers: corsHeaders });
    if (req.method !== 'POST') return geminiError(405, 'method_not_allowed', corsHeaders);
    if (!deps.apiKey) return geminiError(500, 'server_misconfigured', corsHeaders);

    try {
      const route = parseRoute(new URL(req.url).pathname);
      if (!route) throw new HttpError(404, 'unknown_route');
      assertModelAllowed(route);

      const user = await deps.authenticate(req);
      const purpose = purposeOf(req.headers.get('x-hundred-purpose'));
      const body = sanitizeGenerateRequest(await readJson(req));

      await deps.beginRequest(user, purpose);

      const streaming = route.method === 'streamGenerateContent';
      const upstream = await deps.fetch(
        `${geminiBaseUrl}/models/${route.model}:${route.method}${streaming ? '?alt=sse' : ''}`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', 'x-goog-api-key': deps.apiKey },
          body: JSON.stringify(body),
        },
      );

      const responseHeaders = {
        ...corsHeaders,
        'Content-Type': upstream.headers.get('Content-Type') ?? 'application/json',
      };
      const bill = (total: number) => deps.runInBackground(deps.recordUsage(user, total));

      if (streaming && upstream.ok && upstream.body) {
        return new Response(tapSseUsage(upstream.body, bill), {
          status: upstream.status,
          headers: responseHeaders,
        });
      }

      const text = await upstream.text();
      if (upstream.ok) {
        try {
          bill(totalTokensOf(JSON.parse(text)));
        } catch {
          bill(0);
        }
      } else {
        console.error(`Gemini ${upstream.status} for ${route.model}:${route.method}`, text.slice(0, 500));
      }
      return new Response(text, { status: upstream.status, headers: responseHeaders });
    } catch (err) {
      if (err instanceof HttpError) return geminiError(err.status, err.code, corsHeaders);
      console.error('llm-gateway error', err);
      return geminiError(500, 'internal_error', corsHeaders);
    }
  };
}
