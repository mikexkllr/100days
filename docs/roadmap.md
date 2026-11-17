# Status and open items

An honest list. Anything under "Open" is not built yet.

## Working

- Sign-in with Apple (iOS) and Google; account deletion with Apple token
  revocation
- Onboarding with goal setting, derived habits, a plan preview and what the
  AI offers
- Check-ins, relapses, streak freezes, cycle ascent — append-only events,
  written offline first and synced through the backend
- Optional training plan: own split, editable exercises, set-by-set logging
  with progression recommendations (mesocycles with deloads, RIR, equipment
  fallback)
- Optional nutrition plan: computed or own calorie target, macro presets, food
  diary with food table, photo, free-text parsing, barcode lookup and meal
  ideas
- Households: shared week of meals and shopping list, live; AI week planning
  with portions sized to shared targets; the planning chat with undo; lists
  from the plan by shopping rhythm; eaten as planned
- AI through the project's gateway with a monthly allowance, premium through
  the stores (verified server side), or one's own key
- Tracked check-ins (logged workout, diary day on target) worth +50 % XP
- Abstinence milestones
- Funki, the flame mascot: ten forms by streak, moods, lines in both
  languages; the day-complete slot machine with real-number reels
  ([`docs/design.md`](design.md))
- Home screen widget on Android with a live countdown to midnight
  ([`docs/home-screen-widget.md`](home-screen-widget.md))
- Privacy: per-habit sharing, private events for body stats, targets and the
  diary, enforced by Row Level Security and tested against a database
- Friends: invites by QR, link or code, requests, username search, address
  book matching by keyed hashes; friend streaks and weekly quests
- Feed, nudges and cheers (with pushes when Firebase is set up), a league
  among friends and a public league with divisions
- Local notifications, English and German, switchable in settings
- Manual pipeline that ships a signed AAB to the Google Play internal track
  ([`docs/play-release.md`](play-release.md))

## Needs setting up before it works for real

Code is done; these are accounts and keys outside the repository
([`docs/self-hosting.md`](self-hosting.md)):

- Google OAuth clients for the hosted instance, and the app's build defines
- Sign in with Apple enabled for the bundle id; the revocation key
- The Gemini API key as a function secret
- Premium products in App Store Connect and the Play Console, and the
  store credentials for `verify-purchase`
- A Firebase project for pushes; the APNs key; the iOS push entitlement
- `CONTACT_PEPPER` for address book matching; an SMS provider if phone
  numbers should be verifiable

## Open

**Phone number verification.** Matching works on verified e-mail addresses;
adding a phone number needs Supabase phone sign-in with an SMS provider,
which costs per message and is not wired into the app yet.

**An honest public league.** Strangers' weekly XP is what their phones
report, capped per day. Recomputing it on the server from the shared events
would need the core's rules in the database or a function — possible, since
the events are there, but not built.

**Store server notifications.** A renewal or a cancellation is picked up
when the app restores purchases; App Store Server Notifications and Play
real-time developer notifications would update `subscriptions` at once.

**Offline households.** The feed works offline; the meal plan and the
shopping list need a connection to change.

**More languages.** The infrastructure is there — a new language is an ARB file
plus one entry in `kSupportedLocales`, no code. Obvious candidates: Spanish,
French, Turkish.

**Background sync.** Sync runs on start, on resume, every two minutes while
open and live through realtime. WorkManager would work on Android; iOS
allows practically nothing reliable in the background.

**Group challenges.** Several people on the same goal, shared progress. The
data model supports it, the UI does not.

**The widget on iOS.** The WidgetKit code is in `app/ios/StreakWidget/`; the
extension target and the App Group still have to be added in Xcode
([`docs/home-screen-widget.md`](home-screen-widget.md#ios)).

**Wearables.** A complication with the streak and the countdown.

**Import from Health / Google Fit.** Steps and training duration automatically
instead of by hand.

**Tracks beyond internal on Play.** The pipeline ships to the internal track
only; promotion to closed, open and production — with release notes and
staged rollout — is a second pipeline that does not exist yet.
