// deno test supabase/functions/match-contacts/
import { assertEquals, assertNotEquals } from 'jsr:@std/assert@1';
import { hashByKind, hmac, identifiersOf, normalizeEmail, normalizePhone } from './contacts.ts';

Deno.test('e-mail addresses and phone numbers are normalised before hashing', () => {
  assertEquals(normalizeEmail('  Lena.Example@Mail.DE '), 'lena.example@mail.de');
  assertEquals(normalizeEmail('not an address'), null);
  assertEquals(normalizePhone('+49 (151) 234-56 78'), '+491512345678');
  assertEquals(normalizePhone('0151 2345678'), null, 'the app sends E.164');
  assertEquals(normalizePhone('+12'), null);
});

Deno.test('the same contact gives the same HMAC, another pepper another one', async () => {
  const a = await hmac('pepper-1', 'phone', '+491512345678');
  assertEquals(a, await hmac('pepper-1', 'phone', '+491512345678'));
  assertNotEquals(a, await hmac('pepper-2', 'phone', '+491512345678'));
  assertNotEquals(a, await hmac('pepper-1', 'email', '+491512345678'));
  assertEquals(a.length, 64);
});

Deno.test('a request keeps unique, valid identifiers up to the limit', () => {
  const ids = identifiersOf({
    emails: ['a@b.de', 'A@B.de', 'nope', 42],
    phones: ['+491512345678', '+49 151 2345678', '123'],
  }, 10);
  assertEquals(ids, [
    { kind: 'email', value: 'a@b.de' },
    { kind: 'phone', value: '+491512345678' },
  ]);
  assertEquals(identifiersOf({ emails: ['a@b.de', 'c@d.de', 'e@f.de'] }, 2).length, 2);
});

Deno.test('hashes go to the lookup split by kind, as many as came in', async () => {
  const identifiers = identifiersOf({
    emails: Array.from({ length: 1500 }, (_, i) => `person${i}@example.org`),
    phones: ['+491512345678'],
  }, 2000);
  const { emails, phones } = await hashByKind('pepper', identifiers);
  assertEquals(emails.length, 1500);
  assertEquals(phones, [await hmac('pepper', 'phone', '+491512345678')]);
  assertEquals(emails[0], await hmac('pepper', 'email', 'person0@example.org'));
});
