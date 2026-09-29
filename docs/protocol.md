# Protocol

The goal: two devices that can see each other reconcile their feeds in one
round and hang up. There is no client and no server — both sides run the same
routine.

## Identity

An Ed25519 key pair generated on device from 32 bytes of randomness. Addressed
as `did:key:z…` (multicodec prefix `0xed 0x01`, base58btc). The seed lives in
the Keychain or Android Keystore and *is* the entire account — there is no
provider who could reset it.

The recovery key is that same seed in base58. Base58 rather than base64 because
the alphabet contains no confusable characters: no `0/O`, no `1/l/I`, which
matters the moment somebody copies the string off a screen by hand.

## Event format

```json
{
  "author": "did:key:z6Mk…",
  "seq": 42,
  "prev": "9f2c…",
  "timestamp": "2026-03-14T18:22:05.000Z",
  "type": "checkin",
  "payload": { "habitId": "gym", "category": "gym", "day": "2026-03-14",
               "value": 1, "streak": 41 },
  "hash": "a17b…",
  "sig": "MEUCIQ…"
}
```

- `hash` = SHA-256 over `canonicalJson({author, seq, prev, timestamp, type,
  payload})`. Canonical means: object keys sorted, no whitespace, whole floats
  written as integers. Without that rule two implementations derive different
  bytes and no signature verifies.
- `sig` = Ed25519 over the UTF-8 bytes of `hash`, base64.
- `prev` is `null` exactly on the first event (`seq == 1`).

Payloads carry identifiers, never localized strings. A `challenge.ascended`
event holds `cycle: 3`, so a German and an English reader each see the tier
named in their own language from the same signed bytes.

A check-in read from a watch instead of typed carries one extra block:

```json
"payload": { "habitId": "steps", "category": "steps", "day": "2026-03-14",
             "value": 11500,
             "health": { "platform": "healthConnect", "metric": "steps",
                         "raw": 11500, "device": "Pixel Watch" } }
```

Its absence is what "a person entered this" means, on this device and on every
peer's — which is what lets a later import know it must not overwrite the
entry. A reader that does not recognise the `platform` or `metric` name treats
the entry as manual rather than failing, so an older build can still fold a
feed written by a newer one. The block is a claim about provenance and nothing
more: the signature proves the entry is the author's and unaltered, not that a
watch was ever involved.

Event types: `profile`, `challenge.started`, `challenge.ascended`, `checkin`,
`missed`, `streak.freeze`, `nudge`, `cheer`, `friend.request`.

## Validation on receipt

An event is accepted when **all** of these hold:

| Check | Rejection reason |
| --- | --- |
| Type is known | `unknownType` |
| `hash` matches the canonical body | `badHash` |
| `timestamp` ≤ now + 10 min | `timestampInFuture` |
| `seq` == predecessor + 1 (or 1) | `seqOutOfOrder` |
| `prev` == hash of the predecessor | `chainBroken` |
| `timestamp` ≥ the predecessor's | `timestampRegression` |
| Signature verifies against `author` | `badSignature` |

After the first rejected event from an author, the rest of **that author's**
events in the same delivery are dropped: nothing behind a broken link is
verifiable, and carrying on would mean accepting a forged tail.

Incoming events whose predecessor is missing are held back rather than
rejected — the next round asks for the gap.

## A round

Framing: one JSON object per line (NDJSON) over TCP. Deliberately boring, so a
second client stays implementable.

```
A                                        B
│── hello {did, name, v} ───────────────►│
│◄─────────────── hello {did, name, v} ──│
│── have {heads:[{did,seq,hash}, …]} ───►│
│◄──────────────────────── have {heads} ─│
│── want {ranges:[{did, from}, …]} ─────►│
│◄──────────────────────── want {ranges} │
│── events {events:[…], more} ──────────►│
│── done ───────────────────────────────►│
│◄───────────────────────────── events ──│
│◄─────────────────────────────── done ──│
```

The round ends when both sides have sent *and* received `done`. A device that
walks out of Wi-Fi mid-round leaves both sides consistent — every single event
is independently verifiable, so there is nothing that could arrive "half done".

**Processed sequentially.** One frame is fully applied before the next is read.
Handling frames concurrently would let a `done` arrive while a batch of events
is still being written, and the round would report success over a half
replicated feed.

**Limits.** At most 200 events per frame, at most 4 MB per line. A peer must not
be able to make us hold their entire history in memory at once.

**Followed feeds only.** Only feeds from your own friend list (plus your own)
are offered and accepted. Otherwise your friends' friend lists quietly land on
your device.

## Transports

`PeerTransport` supplies discoveries and sessions; the `Syncer` does not know
what it is talking over.

**LAN** (bundled): a UDP multicast beacon on `239.100.100.1:47101` every five
seconds carrying `{did, name, port}`, replication over TCP. Needs no
infrastructure — flatmates and training partners are physically close. If
multicast is blocked (guest Wi-Fi, mobile networks), the TCP half still works
for addresses taken from a scanned invite.

A 20-second lock applies per peer: a device announcing itself every five
seconds must not trigger a round every five seconds.

## Invites

```
hundreddays://invite?d=<base64url({did, name, emoji, addr[], ts})>
```

There is no registry to look anyone up in, so the invite carries everything
needed itself. The addresses are shorthand for "we are on the same Wi-Fi right
now", not a durable locator — discovery takes over afterwards.
