// Pure request/response logic of the LLM gateway (no I/O — see handler.ts).
//
// The gateway speaks the native Gemini REST protocol, so the app's
// dartantic_ai Google provider can use it as its base URL. It only adds what
// the client cannot be trusted with: the API key, the model allowlist,
// request limits and usage accounting.

import { HttpError } from '../_shared/supabase.ts';

export type Method = 'generateContent' | 'streamGenerateContent';

export interface Route {
  model: string;
  method: Method;
}

/**
 * The one model the app uses for everything — photos, estimates, plans and
 * the planning chat. A cheaper or newer one is a change here and in the
 * app's `kAiModel`.
 */
export const MODELS = new Set(['gemini-3.5-flash-lite']);

export const MAX_BODY_BYTES = 6 * 1024 * 1024;
export const MAX_OUTPUT_TOKENS = 8192;
export const MAX_CONTENTS = 200;

/**
 * Text, tool declarations and tool traffic of one request, in characters:
 * about 50,000 tokens, a whole free month. Far beyond a long planning chat,
 * and it bounds what a single request can reserve.
 */
export const MAX_TEXT_CHARS = 200_000;

/**
 * What an image is reserved at: four 768-pixel tiles of 258 tokens, rounded
 * up — a downscaled meal photo. The real count replaces it afterwards.
 */
export const IMAGE_TOKEN_ESTIMATE = 1_100;

/** Meal photos: what the app sends after downscaling, with room to spare. */
export const IMAGE_MIME_TYPES = new Set(['image/jpeg', 'image/png', 'image/webp']);
export const MAX_IMAGE_BYTES = 2 * 1024 * 1024;
export const MAX_IMAGES = 4;

const GENERATE_KEYS = ['contents', 'systemInstruction', 'tools', 'toolConfig', 'generationConfig', 'safetySettings'];
const GENERATION_CONFIG_KEYS = [
  'temperature',
  'topP',
  'topK',
  'maxOutputTokens',
  'stopSequences',
  'responseMimeType',
  'responseSchema',
  'responseJsonSchema',
  'thinkingConfig',
  'presencePenalty',
  'frequencyPenalty',
  'seed',
];
// Text, tool traffic and inline images — no file references, no URLs the
// provider would fetch, no code execution.
const ALLOWED_PART_KEYS = new Set([
  'text',
  'thought',
  'thoughtSignature',
  'functionCall',
  'functionResponse',
  'inlineData',
]);

/** `/llm-gateway/v1beta/models/<model>:<method>` → route. */
export function parseRoute(pathname: string): Route | null {
  const match = pathname.match(/\/v1beta\/models\/([A-Za-z0-9._-]+):([A-Za-z]+)$/);
  if (!match) return null;
  const [, model, method] = match;
  if (method !== 'generateContent' && method !== 'streamGenerateContent') return null;
  return { model, method };
}

export function assertModelAllowed(route: Route): void {
  if (!MODELS.has(route.model)) {
    throw new HttpError(403, 'model_not_allowed', `Model ${route.model} is not available`);
  }
}

// deno-lint-ignore no-explicit-any
type Json = any;

function pick(source: Json, keys: string[]): Json {
  const out: Json = {};
  for (const key of keys) if (source?.[key] !== undefined) out[key] = source[key];
  return out;
}

/** Approximate decoded size of base64 data. */
const base64Bytes = (data: string) => Math.floor((data.length * 3) / 4);

/** What a request carries, counted while it is checked. */
interface Tally {
  images: number;
  chars: number;
}

/** Characters of a part's text, thoughts and tool traffic. */
function charsOf(part: Json): number {
  let chars = 0;
  for (const key of ['text', 'thought', 'thoughtSignature']) {
    if (typeof part?.[key] === 'string') chars += part[key].length;
  }
  for (const key of ['functionCall', 'functionResponse']) {
    if (part?.[key] !== undefined) chars += JSON.stringify(part[key]).length;
  }
  return chars;
}

function checkParts(parts: Json, where: string, tally: Tally): void {
  if (!Array.isArray(parts)) throw new HttpError(400, 'invalid_request', `${where}.parts must be an array`);
  for (const part of parts) {
    for (const key of Object.keys(part ?? {})) {
      if (!ALLOWED_PART_KEYS.has(key)) {
        throw new HttpError(400, 'unsupported_part', `Part type "${key}" is not allowed`);
      }
    }
    if (part?.inlineData !== undefined) {
      const { mimeType, data } = part.inlineData ?? {};
      if (!IMAGE_MIME_TYPES.has(mimeType)) throw new HttpError(400, 'unsupported_media', `${mimeType}`);
      if (typeof data !== 'string' || base64Bytes(data) > MAX_IMAGE_BYTES) {
        throw new HttpError(413, 'image_too_large');
      }
      if (++tally.images > MAX_IMAGES) throw new HttpError(400, 'too_many_images');
    }
    tally.chars += charsOf(part);
  }
}

/** Whitelists a generateContent request and caps its output and its text. */
export function sanitizeGenerateRequest(body: Json): Json {
  if (!body || !Array.isArray(body.contents) || body.contents.length === 0) {
    throw new HttpError(400, 'invalid_request', 'contents is required');
  }
  if (body.contents.length > MAX_CONTENTS) {
    throw new HttpError(400, 'too_many_contents', `At most ${MAX_CONTENTS} contents`);
  }
  const tally: Tally = { images: 0, chars: 0 };
  body.contents.forEach((c: Json, i: number) => checkParts(c?.parts, `contents[${i}]`, tally));
  if (body.systemInstruction) checkParts(body.systemInstruction.parts, 'systemInstruction', tally);

  const clean = pick(body, GENERATE_KEYS);

  // Only the app's own function tools — no search grounding, code execution.
  if (clean.tools !== undefined) {
    if (!Array.isArray(clean.tools)) throw new HttpError(400, 'invalid_request', 'tools must be an array');
    clean.tools = clean.tools
      .filter((t: Json) => Array.isArray(t?.functionDeclarations))
      .map((t: Json) => ({ functionDeclarations: t.functionDeclarations }));
    if (clean.tools.length === 0) delete clean.tools;
    else tally.chars += JSON.stringify(clean.tools).length;
  }
  if (tally.chars > MAX_TEXT_CHARS) throw new HttpError(413, 'text_too_large');

  const config = pick(body.generationConfig ?? {}, GENERATION_CONFIG_KEYS);
  const requested = Number(config.maxOutputTokens);
  config.maxOutputTokens = Number.isFinite(requested) && requested > 0
    ? Math.min(requested, MAX_OUTPUT_TOKENS)
    : MAX_OUTPUT_TOKENS;
  clean.generationConfig = config;
  return clean;
}

/**
 * The most a sanitized request can cost: its input, estimated generously
 * (three characters a token, where English averages four), plus its output
 * cap. It is reserved against the allowance before the request goes out, so
 * parallel requests cannot all spend the same remainder.
 */
export function reservationFor(clean: Json): number {
  let chars = 0;
  let images = 0;
  const parts: Json[] = [
    ...(clean?.contents ?? []).flatMap((c: Json) => c?.parts ?? []),
    ...(clean?.systemInstruction?.parts ?? []),
  ];
  for (const part of parts) {
    chars += charsOf(part);
    if (part?.inlineData !== undefined) images++;
  }
  if (clean?.tools !== undefined) chars += JSON.stringify(clean.tools).length;
  const output = Number(clean?.generationConfig?.maxOutputTokens) || MAX_OUTPUT_TOKENS;
  return Math.ceil(chars / 3) + images * IMAGE_TOKEN_ESTIMATE + output;
}

export function totalTokensOf(json: Json): number {
  const total = Number(json?.usageMetadata?.totalTokenCount);
  return Number.isFinite(total) ? total : 0;
}

/**
 * Passes an SSE body through byte for byte while reading `usageMetadata`
 * from its events. Gemini repeats cumulative usage in each event, so the
 * last one wins. [onDone] runs once — at the end, on error, or when the
 * client hangs up.
 */
export function tapSseUsage(
  upstream: ReadableStream<Uint8Array>,
  onDone: (totalTokens: number) => void,
): ReadableStream<Uint8Array> {
  const reader = upstream.getReader();
  const decoder = new TextDecoder();
  let buffer = '';
  let total = 0;
  let finished = false;

  const scanLine = (line: string) => {
    if (!line.startsWith('data:')) return;
    try {
      const tokens = totalTokensOf(JSON.parse(line.slice(5)));
      if (tokens > 0) total = tokens;
    } catch {
      // partial or non-JSON event
    }
  };
  const finish = () => {
    if (finished) return;
    finished = true;
    scanLine(buffer.trim());
    onDone(total);
  };

  return new ReadableStream<Uint8Array>({
    async pull(controller) {
      try {
        const { done, value } = await reader.read();
        if (done) {
          finish();
          controller.close();
          return;
        }
        buffer += decoder.decode(value, { stream: true });
        const lines = buffer.split('\n');
        buffer = lines.pop() ?? '';
        lines.forEach((l) => scanLine(l.trim()));
        controller.enqueue(value);
      } catch (err) {
        finish();
        controller.error(err);
      }
    },
    async cancel(reason) {
      finish();
      await reader.cancel(reason);
    },
  });
}

const STATUS_NAMES: Record<number, string> = {
  400: 'INVALID_ARGUMENT',
  401: 'UNAUTHENTICATED',
  402: 'RESOURCE_EXHAUSTED',
  403: 'PERMISSION_DENIED',
  404: 'NOT_FOUND',
  405: 'INVALID_ARGUMENT',
  413: 'INVALID_ARGUMENT',
  500: 'INTERNAL',
};

/** Error in Gemini's shape, so client libraries surface `message` verbatim. */
export function geminiError(status: number, code: string, headers: HeadersInit = {}): Response {
  return Response.json(
    { error: { code: status, message: code, status: STATUS_NAMES[status] ?? 'UNKNOWN' } },
    { status, headers },
  );
}
