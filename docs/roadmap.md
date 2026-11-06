# Status and open items

An honest list. Anything here is not built yet.

## Working

- Onboarding with goal setting, derived habits and a plan preview
- Check-ins, relapses, streak freezes, cycle ascent — all signed
- Optional training plan: own split, editable exercises, set-by-set logging
  with progression recommendations (mesocycles with deloads, RIR, equipment
  fallback)
- Optional nutrition plan: computed or own calorie target, macro presets, food
  diary with food table, free-text parsing, barcode lookup and meal ideas
- Tracked check-ins (logged workout, diary day on target) worth +50 % XP
- Abstinence milestones
- Rule-based coach; on-device model (llama.cpp) chosen by phone memory and
  downloaded on a tap, verified by SHA-256
- Funki, the flame mascot: ten forms by streak, moods, lines in both
  languages; the day-complete slot machine with real-number reels
  ([`docs/design.md`](design.md))
- Home screen widget on Android with a live countdown to midnight
  ([`docs/home-screen-widget.md`](home-screen-widget.md))
- Privacy: per-habit sharing, sealed private events, body stats and diary
  never readable by friends
- Friends-only sync with a signed handshake; friend requests
- Feed, weekly league, nudges, cheers, QR and link invites
- LAN discovery and replication, local notifications
- Recovery key, full wipe
- Manual pipeline that ships a signed AAB to the Google Play internal track
  ([`docs/play-release.md`](play-release.md))
- English and German following the device language, switchable in settings

## Open

**More languages.** The infrastructure is there — a new language is an ARB file
plus one entry in `kSupportedLocales`, no code. Obvious candidates: Spanish,
French, Turkish.

**Global league.** A league with people you do not know would be fun, and it
is the one feature that cannot be built without something in the middle:
strangers have to find each other. A plausible shape: opt-in, a separate
pseudonymous key that is not linked to the friend feed, only weekly XP
published, over a relay or a public Nostr-style network. The unsolved part is
honesty — friends' XP is verifiable because their check-ins are signed and
replicated; a stranger's number is a claim. Until there is an answer to that,
the league stays friends only.

**iOS project.** The repository has no `ios/Runner` project yet. When it gets
one: llamadart needs a deployment target of 16.4, and an App Store build
should add `llamadart_llama_cpp_flutter` so the privacy manifest ships.

**Model download in the background.** The download runs while the app is
open and resumes after an interruption; a WorkManager / URLSession background
transfer would let it finish with the screen off.

**Relay transport.** Friends outside your own Wi-Fi are currently only
reachable if you physically meet. A Nostr-style relay or WebRTC behind
`PeerTransport` would fix that without breaking the serverless claim — the
relay forwards encrypted, signed bytes and cannot read them.

**Background sync.** Right now syncing happens on app start and when returning
to the foreground. WorkManager would work on Android; iOS allows practically
nothing reliable in the background, which deserves saying plainly.

**Bluetooth transport.** For "same gym, no shared Wi-Fi". BLE throughput is
more than enough for feed deltas.

**End-to-end encryption of shared payloads.** Private data is sealed; what is
shared with friends is signed but in the clear. As long as replication only
happens directly between authenticated friends that is defensible; the moment
a relay sits in between, it is not.

**Group challenges.** Several people on the same goal, shared progress. The
data model already supports it, the UI does not.

**The widget on iOS.** The WidgetKit code is in `app/ios/StreakWidget/`; the
extension target and the App Group still have to be added in Xcode
([`docs/home-screen-widget.md`](home-screen-widget.md#ios)).

**Wearables.** A complication with the streak and the countdown.

**Import from Health / Google Fit.** Steps and training duration automatically
instead of by hand.

**BIP39 mnemonic.** The recovery key is base58 rather than twelve words.
Functionally equivalent, but harder to copy down.

**Tracks beyond internal on Play.** The pipeline ships to the internal track
only; promotion to closed, open and production — with release notes and
staged rollout — is a second pipeline that does not exist yet.
