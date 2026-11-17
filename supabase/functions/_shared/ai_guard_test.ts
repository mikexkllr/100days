// deno test supabase/functions/_shared/
import { assertEquals, assertRejects } from 'jsr:@std/assert@1';
import { beginRequest, purposeOf } from './ai_guard.ts';
import { HttpError } from './supabase.ts';

Deno.test('unknown purposes count as food', () => {
  assertEquals(purposeOf('plan'), 'plan');
  assertEquals(purposeOf(null), 'food');
  assertEquals(purposeOf('anything'), 'food');
});

Deno.test('the AI coach is premium only, checked before any quota lookup', async () => {
  const err = await assertRejects(
    () => beginRequest({ userId: 'u', tier: 'free' }, 'coach'),
    HttpError,
  );
  assertEquals([err.status, err.code], [402, 'premium_only']);
});
