// deno test supabase/functions/push/
import { assertEquals, assertStringIncludes } from 'jsr:@std/assert@1';
import { fcmBody, messageFor } from './messages.ts';

Deno.test("pushes speak the recipient's language", () => {
  assertEquals(messageFor('friend_activity', 'de', 'Marcel').title, 'Marcel war heute schon dran');
  assertEquals(messageFor('friend_activity', 'en', 'Marcel').title, 'Marcel already showed up today');
  assertStringIncludes(messageFor('friend_request', 'de', 'Lena').body, 'Lena');
});

Deno.test('a typed nudge travels as typed, capped; an empty one gets a template', () => {
  assertEquals(messageFor('nudge', 'de', 'Lena', 'Hopp, Gym!').body, 'Hopp, Gym!');
  assertEquals(messageFor('nudge', 'en', 'Lena', '   ').body, 'Have you shown up today?');
  assertEquals(messageFor('cheer', 'de', 'Lena', 'x'.repeat(500)).body.length, 180);
  assertEquals(messageFor('cheer', 'de', '  ').title, 'Jemand feiert dich 🔥');
});

Deno.test('the FCM body carries the kind for the app to route on', () => {
  const body = fcmBody('tok', { title: 't', body: 'b' }, 'nudge') as {
    message: { token: string; data: { kind: string } };
  };
  assertEquals(body.message.token, 'tok');
  assertEquals(body.message.data.kind, 'nudge');
});
