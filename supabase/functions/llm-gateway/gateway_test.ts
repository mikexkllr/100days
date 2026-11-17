// deno test supabase/functions/llm-gateway/
import { assertEquals, assertThrows } from 'jsr:@std/assert@1';
import { HttpError } from '../_shared/supabase.ts';
import {
  assertModelAllowed,
  MAX_IMAGE_BYTES,
  MAX_OUTPUT_TOKENS,
  parseRoute,
  sanitizeGenerateRequest,
  tapSseUsage,
} from './gateway.ts';

const userText = (text: string) => ({ role: 'user', parts: [{ text }] });
const image = (bytes: number, mimeType = 'image/jpeg') => ({
  inlineData: { mimeType, data: 'A'.repeat(Math.ceil((bytes * 4) / 3)) },
});

function assertHttp(fn: () => unknown, status: number, code: string) {
  const err = assertThrows(fn, HttpError);
  assertEquals([err.status, err.code], [status, code]);
}

Deno.test('parseRoute reads model and method from the function path', () => {
  assertEquals(
    parseRoute('/llm-gateway/v1beta/models/gemini-3.5-flash-lite:streamGenerateContent'),
    { model: 'gemini-3.5-flash-lite', method: 'streamGenerateContent' },
  );
  assertEquals(
    parseRoute('/functions/v1/llm-gateway/v1beta/models/gemini-3.5-flash-lite:generateContent'),
    { model: 'gemini-3.5-flash-lite', method: 'generateContent' },
  );
  assertEquals(parseRoute('/llm-gateway/v1beta/models/gemini-3.5-flash-lite:embedContent'), null);
  assertEquals(parseRoute('/llm-gateway/v1beta/files'), null);
});

Deno.test('only the app model passes', () => {
  assertModelAllowed({ model: 'gemini-3.5-flash-lite', method: 'generateContent' });
  assertHttp(
    () => assertModelAllowed({ model: 'gemini-3.8-pro', method: 'generateContent' }),
    403,
    'model_not_allowed',
  );
});

Deno.test('keeps function tools and drops search, code execution and cache', () => {
  const clean = sanitizeGenerateRequest({
    contents: [userText('hi')],
    systemInstruction: { parts: [{ text: 'be kind' }] },
    cachedContent: 'cachedContents/abc',
    tools: [
      { functionDeclarations: [{ name: 'set_meal' }] },
      { googleSearch: {} },
      { codeExecution: {}, functionDeclarations: [{ name: 'add_item' }] },
    ],
    generationConfig: { temperature: 1, maxOutputTokens: 100000, responseModalities: ['AUDIO'] },
  });
  assertEquals(clean.cachedContent, undefined);
  assertEquals(clean.tools, [
    { functionDeclarations: [{ name: 'set_meal' }] },
    { functionDeclarations: [{ name: 'add_item' }] },
  ]);
  assertEquals(clean.generationConfig, { temperature: 1, maxOutputTokens: MAX_OUTPUT_TOKENS });
});

Deno.test('a meal photo goes through; other media and file links do not', () => {
  const ok = sanitizeGenerateRequest({
    contents: [{ role: 'user', parts: [{ text: 'what is this?' }, image(400_000)] }],
  });
  assertEquals(ok.contents[0].parts.length, 2);

  assertHttp(
    () =>
      sanitizeGenerateRequest({
        contents: [{ role: 'user', parts: [image(1000, 'video/mp4')] }],
      }),
    400,
    'unsupported_media',
  );
  assertHttp(
    () =>
      sanitizeGenerateRequest({
        contents: [{ role: 'user', parts: [{ fileData: { fileUri: 'gs://x' } }] }],
      }),
    400,
    'unsupported_part',
  );
});

Deno.test('images are capped in size and number', () => {
  assertHttp(
    () =>
      sanitizeGenerateRequest({
        contents: [{ role: 'user', parts: [image(MAX_IMAGE_BYTES + 10_000)] }],
      }),
    413,
    'image_too_large',
  );
  assertHttp(
    () =>
      sanitizeGenerateRequest({
        contents: [{ role: 'user', parts: [1, 2, 3, 4, 5].map(() => image(1000)) }],
      }),
    400,
    'too_many_images',
  );
});

Deno.test('rejects requests without contents', () => {
  assertHttp(() => sanitizeGenerateRequest({}), 400, 'invalid_request');
  assertHttp(() => sanitizeGenerateRequest({ contents: [] }), 400, 'invalid_request');
});

Deno.test('tapSseUsage passes bytes through and reports the last usage', async () => {
  const sse = 'data: {"usageMetadata":{"totalTokenCount":5}}\n\ndata: {"usageMetadata":{"totalTokenCount":42}}';
  let billed = -1;
  const stream = tapSseUsage(new Response(sse).body!, (t) => (billed = t));
  assertEquals(await new Response(stream).text(), sse);
  assertEquals(billed, 42);
});
