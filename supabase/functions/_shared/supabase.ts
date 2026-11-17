// Clients and helpers shared by the edge functions.

import { createClient, type SupabaseClient, type User } from 'npm:@supabase/supabase-js@2.58.0';

export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-goog-api-key, x-hundred-purpose',
};

export class HttpError extends Error {
  constructor(readonly status: number, readonly code: string, message?: string) {
    super(message ?? code);
  }
}

let admin: SupabaseClient | null = null;

/** Service-role client. Never leaves the function. */
export function adminClient(): SupabaseClient {
  admin ??= createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    { auth: { autoRefreshToken: false, persistSession: false } },
  );
  return admin;
}

/**
 * The signed-in user behind a request. The publishable key ships in every
 * app and is not an identity, so only a user's own access token counts.
 */
export async function requireUser(req: Request): Promise<User> {
  const token = req.headers.get('Authorization')?.replace(/^Bearer\s+/i, '');
  if (!token) throw new HttpError(401, 'unauthorized');
  const { data, error } = await adminClient().auth.getUser(token);
  if (error || !data.user) throw new HttpError(401, 'unauthorized');
  if (data.user.is_anonymous) throw new HttpError(403, 'anonymous_not_allowed');
  return data.user;
}

export function json(body: unknown, status = 200): Response {
  return Response.json(body, { status, headers: corsHeaders });
}

export function errorResponse(err: unknown): Response {
  if (err instanceof HttpError) return json({ error: err.code }, err.status);
  console.error(err);
  return json({ error: 'internal_error' }, 500);
}
