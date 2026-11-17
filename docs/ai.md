# AI

Every language model call goes through [dartantic_ai](https://pub.dev/packages/dartantic_ai),
in one of two ways:

- **The gateway** (default): the app's Google provider points at the
  `llm-gateway` edge function, which holds the provider key as a secret and
  counts every request against the user's monthly allowance.
- **The user's own key** (Settings → AI): Google, Anthropic or OpenAI,
  stored in the phone's keychain and checked with one request before it is
  saved. Requests then go straight from the phone to the provider; the
  allowance does not apply.

The app does not run models on the phone any more: the ones that fit a
phone were too slow and too unreliable for photos, plans and the planning
chat.

## What it does

| Feature | Purpose header | Free | Premium / own key |
| --- | --- | --- | --- |
| Meal from a photo | `food` | ✓ within the allowance | ✓ |
| Meal from a description, meal ideas, target proposals | `food` | ✓ within the allowance | ✓ |
| Plan the week | `plan` | ✓ within the allowance | ✓ |
| Planning chat (tools on plan and list) | `chat` | ✓ within the allowance | ✓ |
| The coach's daily line, nudge texts | `coach` | rule-based | ✓ |

Every answer is checked before it counts, and every check lives in
`hundred_core`, where it is tested:

- **Meals** (`NutritionAssistant`): dropped when the calories break physics
  (more than 9.5 kcal a gram) or the portion is absurd. Nothing reaches the
  diary until the user confirms it, and the entry is labelled as an
  estimate.
- **Plans** (`MealPlanner`, `parseMealPlan`): only meals inside the
  requested days and slots, with calories within 30 % of their macros, and
  ingredients in units a shopping list can add up. One meal per slot.
- **Chat tools**: `set_meal` goes through the same check; a refused meal is
  answered with why, so the model can fix it. Every change is shown with an
  undo.

Every failure — no allowance, network, nonsense — falls back: the coach to
its rules, the diary to the food table, the planner to planning by hand.
When the allowance runs out, the app says so and offers premium or one's
own key.

## The gateway

[`supabase/functions/llm-gateway`](../supabase/functions/llm-gateway) is a
thin, authenticated pass-through to the Gemini REST API in its native
protocol, so tool calls, JSON mode and images work unchanged:

- **One model** on the allowlist, `gemini-3.5-flash-lite` — the cheapest
  current one, for everything. A different one is a change to `MODELS` in
  `gateway.ts` and `kAiModel` in the app, gateway first.
- **Parts**: text, tool calls and inline images (JPEG, PNG, WebP, at most
  2 MB each and four per request). No file references, no search grounding,
  no code execution.
- **Allowance**: `ai_usage` per user and month. Free 50k tokens (a photo
  costs about 1–2k, a week's plan 10–20k), premium 3M as fair use; both are
  secrets (`FREE_AI_TOKENS_PER_MONTH`, `PREMIUM_AI_TOKENS_PER_MONTH`), plus
  `AI_REQUESTS_PER_MINUTE`. An exhausted allowance answers 402, not 429, so
  client libraries do not retry it.

## Meal photos

The photo is turned upright, scaled to at most 1024 px and re-encoded as a
new JPEG on the phone — which is what drops EXIF, the GPS position and the
camera's serial before anything is sent. It is sent once and not stored;
what lands in the diary is only what the user confirms.

## What is sent

Only what a feature needs, when the user uses it:

- a meal photo or description;
- for a plan: the days and meals, each member's name, and — if they share
  them — their calorie and protein targets, diet, dislikes and allergies,
  the wish typed, recently planned dish titles;
- for the planning chat: the same, the week's plan and the shopping list;
- for the coach (premium): streak, day number, habits and friends' first
  names.

Through the gateway it goes to Google's Gemini API under the terms of the
operator's API account — check them for your project before you run your
own instance, in particular whether requests may be used for training. The
backend keeps the month's token count, nothing else. With one's own key it
goes to that provider under the user's own terms.

## Prompts

Prompts are written in the language the user reads; asking a small model
for German output with an English prompt works measurably worse. That is
why `NutritionPromptBuilder`, `CoachPromptBuilder` and
`MealPlanPromptBuilder` are ports and the app supplies localized ones from
the ARB files.
