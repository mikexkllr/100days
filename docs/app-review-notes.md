# App Review notes

What goes into App Store Connect → the version → **App Review Information →
Notes**. Apple asked for exactly these points in the first review
(Guideline 2.1, Information Needed, 25 Nov 2026). The field takes 4,000
characters; the block below is the text to paste, in English.

The demo account itself (user name and password) goes into the "Sign-in
required" fields next to it, not into the notes; the password is in the
operator's Keychain ("100days app review account"). If a reviewer deleted the
account, create it again first (see [`stores.md`](stores.md#review-accounts)).

The screen recording goes into the **Attachment** field of the same section
(drag and drop; the built-in browser cannot upload). What it has to show is
in [Recording](#recording) below.

## Notes

```text
1. SCREEN RECORDING
Attached to this App Review Information (recorded on an iPhone with the latest iOS). It starts at app launch and shows: email registration and confirmation, sign-in, onboarding and a first check-in, adding a friend, reporting and blocking a user, the AI features, buying Premium (sandbox) and restoring it, and deleting the account.

2. PURPOSE AND AUDIENCE
100 Days & Beyond is a habit tracker for a 100-day challenge (e.g. no sugar, reading, training). Users check in once a day, keep a streak, and do it with friends: friend streaks, weekly quests, weekly leagues. Optional nutrition features: log meals by photo, barcode or text and let the AI plan a week of meals and a shared shopping list for a household. Audience: adults and teenagers 16+ who want to build or quit a habit. It solves keeping a goal going day after day; the value is one small daily step, visible progress and friends who notice.

3. HOW TO TEST
Demo account (free tier, so the purchase can be tested): see the sign-in fields of this section. On the first screen tap "Continue with email", enter the address and password, tap "Sign in". Onboarding then asks for a name and a 100-day challenge; any values work. New users can also register with any email (a confirmation link is mailed), or use Sign in with Apple / Google.
- Today tab: press and hold a habit to check it in. Further down, the nutrition card (calories / protein) opens the food diary: add food by photo, barcode or text.
- Plan tab: training plan, AI meal plan, shared shopping list.
- Friends tab -> "Find friends" (contacts, username search) or "Scan" (QR code / link). Friends tab -> League: the public weekly league; tap a person there -> Report or Block. The same for strangers in the username search. On a friend's profile the menu (top right) has Report and Block.
- Profile tab -> AI ("AI & subscription"): Premium (monthly 2.99 EUR, yearly 19.99 EUR, auto-renewing), "Restore purchase", Terms of use and Privacy policy links. Free accounts get a monthly AI allowance; Premium a larger one and the daily coach line.
- Profile tab -> Delete account: deletes the account and all its data on the server (Sign in with Apple users are asked once more so the Apple token can be revoked).
No hardware, sample files or special setup needed.
Privacy policy: https://mikexkllr.github.io/100days/privacy.html
Terms: https://mikexkllr.github.io/100days/terms.html

4. EXTERNAL SERVICES
- Supabase (EU, Ireland): sign-in, database, storage, server functions.
- Sign in with Apple, Google Sign-In: authentication.
- Apple In-App Purchase (StoreKit), checked server-side with the App Store Server API.
- Google Gemini (model gemini-3.5-flash-lite) through our own server function: meal photo estimates, meal plans, coach texts. Meal photos are not stored.
- Open Food Facts: product data for barcode scans (ODbL licence).
- Firebase Cloud Messaging / APNs: push notifications (friend activity, reminders).
- Sentry (EU): crash and error reports, no tracking, no IP addresses.
- Our own mail server: the registration confirmation mail.
Optional and off by default: a user may enter their own API key for Google, Anthropic or OpenAI (Profile -> AI); requests then go directly to that provider. Advanced users may point the open-source app to their own server ("Own server" on the sign-in screen). Neither is needed for review.

5. REGIONS
The app works the same in every country where it is offered; it is not offered in mainland China. Languages: English and German. Prices are set per storefront by Apple.

6. REGULATED CONTENT
Not a medical device and no medical advice: calorie and protein values are estimates for orientation, and the app says so. No regulated industry, no protected third-party material; product data comes from Open Food Facts under its open licence.
```

## Recording

Apple wants a recording "captured on a physical device, running the latest
operating system", starting with the launch of the app. Record it on the
iPhone with the TestFlight build of the version being submitted: Control
Center → Screen Recording, then end it there; the video lands in Photos.
Keep it to 3–5 minutes; Apple does not need sound.

1. Start the recording on the home screen, then open the app (cold start).
2. **Register:** Continue with email → a new address you can read →
   Register with email → the "Check your inbox" dialog → open the mail on the
   phone, tap the link → back in the app, signed in.
3. **Onboarding:** pick a challenge and a habit, finish onboarding.
4. **Today:** press and hold a habit to check in; the celebration.
5. **Friends:** Friends → Find friends → search the other test account's
   username → send the request. Accept it on the other account beforehand
   or show the request arriving.
6. **Report and block:** open that friend's profile → ⋯ (top right) →
   Report → pick a reason → Send report ("Thanks. Your report is in.").
   Then ⋯ → Block → confirm. Show Friends → League and that a stranger's
   row there opens Report and Block too.
7. **AI and paid features:** Today → nutrition card → food diary → add a
   meal by photo; then Profile → AI → Monthly or Yearly → buy with a
   sandbox account → Premium is active → Restore purchase. Show the Terms of
   use and Privacy policy links.
8. **Sign out and sign in** again with the same email and password.
9. **Delete account:** Profile → Delete account → Delete → back on the first
   screen. End the recording.

Use a throwaway email for step 2, not the review account, so the review
account stays intact.
