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
phone were too slow and too unreliable for photos, plans and Funki.

Where a model supports it, answers that have to be JSON are asked for with
a JSON Schema (structured output): `LlmClient.generate(schema: …)` hands it
to dartantic, which passes it to Gemini as `responseJsonSchema` (and maps it
for OpenAI and Anthropic with one's own key). A schema fixes the shape, not
the sense — the checks below still run on every answer.

## What it does

| Feature | Purpose header | Free | Premium / own key |
| --- | --- | --- | --- |
| Meal from a photo | `food` | ✓ within the allowance | ✓ |
| Meal from a description, meal ideas, target proposals | `food` | ✓ within the allowance | ✓ |
| Plan the week, a recipe from a dish name ("ask Funki" in "What is it?") | `plan` | ✓ within the allowance | ✓ |
| Funki, the coach: chat and one-line question (tools on everything) | `chat` | ✓ within the allowance | ✓ |
| The coach's daily line, nudge texts | `coach` | rule-based | ✓ |

Every answer is checked before it counts, and every check lives in
`hundred_core`, where it is tested:

- **Meals** (`NutritionAssistant`): dropped when the calories break physics
  (more than 9.5 kcal a gram) or the portion is absurd. Nothing reaches the
  diary until the user confirms it, and the entry is labelled as an
  estimate.
- **Plans** (`MealPlanner`, `parseMealPlan`): only meals inside the
  requested days and slots, with calories within 30 % of their macros, and
  ingredients in units a shopping list can add up. One meal per slot, and
  each dish once a week — a dish already planned on a slot the plan leaves
  alone is dropped. A drafted single recipe must land within 30 % of the
  calories asked for. Saving reuses the household's recipe of the same name
  (`recipeNamed`, `reconcileRecipe`) instead of storing a copy.
- **Funki's tools** (`app/lib/ai/funki/funki_tools.dart`): `set_meal` goes
  through `parseMealPlan`, `log_food` through `foodEstimateFrom` (the same
  check as a meal estimate); a refused answer goes back to the model with
  why, so it can fix it. Every change — a diary entry, a check-in, a meal,
  a line on the list — is shown with an undo.

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
- for Funki, only what a tool he calls reads, when he calls it: today's
  habits and streak, the diary of a day with its targets, the week's plan,
  a recipe, the shopping list, today's workout and the last five logged,
  friends' display names with their streaks;
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
the ARB files. Funki's system prompt (`promptFunki`) is in the ARB files
too; his tool descriptions stay English, like the JSON they describe.

## Funki

Funki — the flame — is the coach to talk to. One conversation model
(`FunkiConversation`) backs two surfaces:

- **Funki fragen**: one line on Today and in the diary, for a question in
  passing ("2 pretzels for breakfast", "what still fits today?"). The
  answer and its changes show right below; "go on in the chat" continues
  the same conversation. (The "ask Funki" line in the meal plan's "What is
  it?" sheet is simpler: the dish name and calories typed become one full
  recipe, through `MealPlanner.draftMeal`.)
- **The chat**: the full conversation, opened from the meal plan (where it
  replaced the planning chat) or from a question in passing.

He reads and changes through tools: `get_today`, `check_in`, `get_diary`,
`log_food`, `remove_food`, `eat_planned`, `get_meal_plan`, `get_recipe`,
`set_meal`, `remove_meal`, `get_shopping_list`, `add_to_list`,
`remove_from_list`, `make_list_from_plan`, `get_training`, `get_friends`.
He does not send anything to friends, change settings or targets, or log a
relapse. Diary entries he writes are labelled as AI estimates
(`FoodSource.ai`); unlike a photo estimate they need no extra
confirmation — the user asked for them — and each comes with an undo.
