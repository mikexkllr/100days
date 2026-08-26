# Status and open items

An honest list. Anything here is not built yet.

## Working

- Onboarding with goal setting, derived habits and a plan preview
- Check-ins, relapses, streak freezes, cycle ascent — all signed
- Training plan (mesocycles with deloads, RPE, equipment fallback), nutrition
  plan (Mifflin-St Jeor, macros, meal split), abstinence milestones
- Rule-based coach, model port for local inference
- Feed, weekly league, nudges, cheers, QR and link invites
- LAN discovery and replication, local notifications
- Recovery key, full wipe
- English and German following the device language, switchable in settings

## Open

**More languages.** The infrastructure is there — a new language is an ARB file
plus one entry in `kSupportedLocales`, no code. Obvious candidates: Spanish,
French, Turkish.

**Inference engine.** `GgufLlmRuntime.attachBackend` is the socket; the binding
to llama.cpp (FFI) or MediaPipe is missing. Until then the rule-based coach is
always what runs.

**Relay transport.** Friends outside your own Wi-Fi are currently only
reachable if you physically meet. A Nostr-style relay or WebRTC behind
`PeerTransport` would fix that without breaking the serverless claim — the
relay forwards encrypted, signed bytes and cannot read them.

**Background sync.** Right now syncing happens on app start and when returning
to the foreground. WorkManager would work on Android; iOS allows practically
nothing reliable in the background, which deserves saying plainly.

**Bluetooth transport.** For "same gym, no shared Wi-Fi". BLE throughput is
more than enough for feed deltas.

**End-to-end encryption of payloads.** Events are signed but in the clear. As
long as replication only happens directly between friends' devices that is
defensible; the moment a relay sits in between, it is not.

**Group challenges.** Several people on the same goal, shared progress. The
data model already supports it, the UI does not.

**Widgets and wearables.** A home screen widget with the streak would be the
cheapest reminder there is.

**Import from Health / Google Fit.** Steps and training duration automatically
instead of by hand.

**BIP39 mnemonic.** The recovery key is base58 rather than twelve words.
Functionally equivalent, but harder to copy down.

**Signed releases.** The Android config still uses the debug key.
