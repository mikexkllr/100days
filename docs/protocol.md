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

Event types: `profile`, `challenge.started`, `challenge.updated`,
`challenge.ascended`, `checkin`, `missed`, `streak.freeze`, `nudge`, `cheer`,
`friend.request`, `workout.logged`, `food.logged`, `food.removed`, `private`.

- `challenge.updated` replaces goal and habits after an edit (a new split, own
  nutrition targets, a sharing change). Start day and the cycle reached stay
  as they were — an edit changes what the challenge asks for, never where it
  is. Habits carry an optional `from` day and a `history` of earlier weekly
  frequencies, so switching from four to five training days does not turn
  past Wednesdays into misses.
- `workout.logged` holds one session set by set:
  `{day, kind, session, ex: [{id, s: [[kg, reps], …]}], min}`.
- A `checkin` may carry `tracked: true` when it is backed by the full tool — a
  logged workout or a food diary closed on target. It earns the plan bonus
  (×1.5 XP) on every device that folds the feed.
- `food.logged` / `food.removed` are the diary. They are always sealed (below).

## Sealed events

Some things are written to the feed but must not be readable by friends:
body stats, nutrition targets, the food diary, habits the user keeps private,
and — if the user says so — workout details. Those go in as a `private`
event:

```json
{ "type": "private",
  "payload": { "v": 1, "n": "<nonce>", "c": "<ciphertext>", "m": "<mac>" } }
```

ChaCha20-Poly1305 under a key derived with HKDF-SHA256 from the identity seed
(`info: "private-events-v1"`). Inside is `{t: <type>, p: <payload>}` — an
ordinary event. The owner's device opens these before folding the feed, so
they behave like any other event at home.

Why sealed events in the same feed rather than a second, local-only store:

- **The chain stays whole.** A friend verifies hash, sequence and signature
  of a sealed event like any other. Nothing is "missing" from the log.
- **Restore keeps working.** Friends replicate the bytes they cannot read; a
  restore from the recovery key gets the diary back from them.

What a friend *can* see: that a sealed event exists, and when it was
written. That is the honest limit of this scheme.

A challenge is therefore written twice: the **public view** first (private
habits removed, no body stats, no nutrition targets, the goal sentence only if
shared), then the full challenge sealed. A friend's device computes the streak
from the public view — the shared habits only, which is the honest number to
show them. A habit that was private and is shared later carries a
`sharedSince` day in the public view, so its sealed past does not look like
misses.

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
│── hello {did, name, emoji, nonce, v} ─►│
│◄─ hello {did, name, emoji, nonce, v} ──│
│── auth {sig over B's nonce} ──────────►│
│◄────────────── auth {sig over A's nonce}│
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

**Friends only (protocol v2).** A name in a `hello` is a claim; the `auth`
frame is proof. Each side signs
`hundred-days-sync-v2|<the other side's nonce>|<own DID>|<other DID>` with its
identity key, and the other side verifies it against the DID before sending
anything. Binding both DIDs keeps a signature from being replayed elsewhere.
Then:

- a peer that fails the check gets `error: auth-failed` and nothing else;
- a peer that proves who it is but is **not on the friend list** gets
  `error: not-friends` and nothing else — no heads, no events. The app shows
  it as a friend request ("Marcel wants to connect"); accepting adds them and
  the next round replicates;
- `have`, `want` and `events` frames that arrive before the handshake
  completed are ignored.

A stranger on the same Wi-Fi learns that this phone runs the app and which
name it uses — nothing more. Adding someone by QR is therefore mutual: the
person who scanned shows up as a request on the other phone.

**Followed feeds only.** Only feeds from your own friend list (plus your own)
are offered and accepted. Otherwise your friends' friend lists quietly land on
your device.

Version 1 had no handshake. A v1 peer gets `protocol version mismatch` and the
round ends — both sides need the update.

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
