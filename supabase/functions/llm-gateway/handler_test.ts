// deno test supabase/functions/llm-gateway/
import { assertEquals } from 'jsr:@std/assert@1';
import type { GuardedUser, Purpose } from '../_shared/ai_guard.ts';
import { HttpError } from '../_shared/supabase.ts';
import { createGatewayHandler, type GatewayDeps } from './handler.ts';

const user: GuardedUser = { userId: 'u1', tier: 'free' };
const url = (model: string, method: string) => `http://localhost/llm-gateway/v1beta/models/${model}:${method}`;
const MODEL = 'gemini-3.5-flash-lite';
const chatBody = JSON.stringify({ contents: [{ role: 'user', parts: [{ text: 'hi' }] }] });

function setup(overrides: Partial<GatewayDeps> = {}) {
  const calls = {
    upstream: [] as { url: string; headers: Headers; body: unknown }[],
    begun: [] as Purpose[],
    reserved: [] as number[],
    billed: [] as number[],
  };
  const deps: GatewayDeps = {
    apiKey: 'server-key',
    authenticate: () => Promise.resolve(user),
    beginRequest: (_u, purpose, reserve) => {
      calls.begun.push(purpose);
      calls.reserved.push(reserve);
      return Promise.resolve({ month: '2026-11-01', tokens: reserve });
    },
    recordUsage: (_u, tokens, reservation) => {
      calls.billed.push(tokens);
      assertEquals(reservation.month, '2026-11-01');
      return Promise.resolve();
    },
    runInBackground: () => {},
    fetch: (input, init) => {
      calls.upstream.push({
        url: String(input),
        headers: new Headers(init?.headers),
        body: JSON.parse(String(init?.body)),
      });
      return Promise.resolve(Response.json({ candidates: [], usageMetadata: { totalTokenCount: 100 } }));
    },
    ...overrides,
  };
  return { handler: createGatewayHandler(deps), calls };
}

const post = (target: string, body: string, headers: HeadersInit = {}) =>
  new Request(target, { method: 'POST', body, headers });

Deno.test('forwards with the server key, not the client one, and bills the tokens', async () => {
  const { handler, calls } = setup();
  const res = await handler(post(url(MODEL, 'generateContent'), chatBody, { 'x-goog-api-key': 'client' }));
  assertEquals(res.status, 200);
  assertEquals(
    calls.upstream[0].url,
    `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`,
  );
  assertEquals(calls.upstream[0].headers.get('x-goog-api-key'), 'server-key');
  assertEquals(calls.begun, ['food']);
  assertEquals(calls.billed, [100]);
});

Deno.test('the purpose header reaches the guard', async () => {
  const { handler, calls } = setup();
  await handler(post(url(MODEL, 'generateContent'), chatBody, { 'x-hundred-purpose': 'plan' }));
  await handler(post(url(MODEL, 'generateContent'), chatBody, { 'x-hundred-purpose': 'nonsense' }));
  assertEquals(calls.begun, ['plan', 'food']);
});

Deno.test('unauthenticated requests never reach Gemini', async () => {
  const { handler, calls } = setup({ authenticate: () => Promise.reject(new HttpError(401, 'unauthorized')) });
  const res = await handler(post(url(MODEL, 'generateContent'), chatBody));
  assertEquals(res.status, 401);
  assertEquals((await res.json()).error.message, 'unauthorized');
  assertEquals(calls.upstream.length, 0);
});

Deno.test('an exhausted allowance answers 402 without calling Gemini', async () => {
  const { handler, calls } = setup({ beginRequest: () => Promise.reject(new HttpError(402, 'quota_exceeded')) });
  const res = await handler(post(url(MODEL, 'generateContent'), chatBody));
  assertEquals(res.status, 402);
  assertEquals((await res.json()).error, { code: 402, message: 'quota_exceeded', status: 'RESOURCE_EXHAUSTED' });
  assertEquals(calls.upstream.length, 0);
});

Deno.test('other models are rejected before authentication', async () => {
  let authenticated = false;
  const { handler } = setup({ authenticate: () => ((authenticated = true), Promise.resolve(user)) });
  const res = await handler(post(url('gemini-3.8-pro', 'generateContent'), chatBody));
  assertEquals(res.status, 403);
  assertEquals(authenticated, false);
});

Deno.test('streams SSE through and bills the final usage', async () => {
  const sse = 'data: {"usageMetadata":{"totalTokenCount":5}}\n\ndata: {"usageMetadata":{"totalTokenCount":42}}\n\n';
  const { handler, calls } = setup({
    fetch: () => Promise.resolve(new Response(sse, { headers: { 'Content-Type': 'text/event-stream' } })),
  });
  const res = await handler(post(url(MODEL, 'streamGenerateContent'), chatBody));
  assertEquals(res.headers.get('Content-Type'), 'text/event-stream');
  assertEquals(await res.text(), sse);
  assertEquals(calls.billed, [42]);
});

Deno.test('Gemini errors pass through and are not billed', async () => {
  const { handler, calls } = setup({
    fetch: () => Promise.resolve(Response.json({ error: { code: 400, message: 'bad' } }, { status: 400 })),
  });
  const res = await handler(post(url(MODEL, 'generateContent'), chatBody));
  assertEquals(res.status, 400);
  // Settled at nothing: the reservation goes back, no token is billed.
  assertEquals(calls.billed, [0]);
});

Deno.test('a request reserves its worst case up front and settles at what it cost', async () => {
  const { handler, calls } = setup();
  const body = JSON.stringify({
    contents: [{ role: 'user', parts: [{ text: 'x'.repeat(3000) }] }],
    generationConfig: { maxOutputTokens: 500 },
  });
  await handler(post(url(MODEL, 'generateContent'), body));
  // 3000 characters at three a token, plus the output cap.
  assertEquals(calls.reserved, [1000 + 500]);
  assertEquals(calls.billed, [100]);
});

Deno.test('a network failure on the way to Gemini releases the reservation', async () => {
  const { handler, calls } = setup({ fetch: () => Promise.reject(new TypeError('network down')) });
  const res = await handler(post(url(MODEL, 'generateContent'), chatBody));
  assertEquals(res.status, 500);
  assertEquals(calls.billed, [0]);
});

Deno.test('an answer without usage keeps what was reserved', async () => {
  const { handler, calls } = setup({ fetch: () => Promise.resolve(Response.json({ candidates: [] })) });
  await handler(post(url(MODEL, 'generateContent'), chatBody));
  assertEquals(calls.billed, calls.reserved);
});

Deno.test('without a key the gateway says so instead of calling out', async () => {
  const { handler, calls } = setup({ apiKey: undefined });
  const res = await handler(post(url(MODEL, 'generateContent'), chatBody));
  assertEquals(res.status, 500);
  assertEquals(calls.upstream.length, 0);
});
